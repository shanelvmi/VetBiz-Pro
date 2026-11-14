import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../config/app_date_format.dart';
import '../../config/app_defaults.dart';
import '../../config/money.dart';
import '../../data/activity_type.dart';
import '../../l10n/l10n.dart';
import '../../utils/merged_query_stream.dart';

/// HUB3 (2): what the live line says about one activity entry. Read from the
/// entry as stored (its type, its English description, its time): nothing
/// is written or changed. A sale, a visit (a service) and a payment name
/// their client; a sale and a payment their amount; anything else (an
/// expense, a product, a deletion) only its type, so no amount an assistant
/// may not see reaches the line.
enum HomeLiveKind { sale, visit, payment, other }

class HomeLiveEvent {
  final String id;
  final HomeLiveKind kind;

  /// The stored actionType ('Sales', 'Debtors'...), shown through its lookup
  /// for [HomeLiveKind.other].
  final String type;

  /// The client as stored ('Walk-in' for a walk-in), or null.
  final String? client;
  final double? amount;

  /// Null while the server's stamp is pending (an entry just written).
  final DateTime? at;

  const HomeLiveEvent({required this.id, required this.kind, required this.type, this.client, this.amount, this.at});

  /// The stored client name of a walk-in (sale_provider, service_provider).
  static const walkIn = 'Walk-in';

  // The descriptions as the app writes them (sale_provider, service_provider,
  // add_payment_screen); older ones spelled the currency with another case
  // or as the code (D4: old entries stay as they are).
  static final _money =
      '(?:${RegExp.escape(AppDefaults.currencySymbol)}|${RegExp.escape(AppDefaults.currencyCode)})' r'\s?([\d,]+(?:\.\d+)?)';
  static final _sale = RegExp('^Recorded sale to (.+) - $_money\$', caseSensitive: false);
  static final _visit = RegExp('^Recorded service for (.+) - $_money\$', caseSensitive: false);
  static final _payment = RegExp('^Recorded payment of $_money from (.+)\$', caseSensitive: false);

  static double? _amount(String digits) => double.tryParse(digits.replaceAll(',', ''));

  /// The event for the entry [id] with [data], or null for an entry with no
  /// type and no description.
  static HomeLiveEvent? fromEntry(String id, Map<String, dynamic> data) {
    final type = ActivityType.canonicalKey((data['actionType'] as String?) ?? '');
    final description = ((data['description'] as String?) ?? '').trim();
    if (type.isEmpty && description.isEmpty) return null;
    final stamp = data['timestamp'];
    final at = stamp is Timestamp ? stamp.toDate() : (stamp is DateTime ? stamp : null);
    HomeLiveEvent event(HomeLiveKind kind, {String? client, double? amount}) =>
        HomeLiveEvent(id: id, kind: kind, type: type, client: client?.trim(), amount: amount, at: at);
    if (type == ActivityType.sales.key) {
      final m = _sale.firstMatch(description);
      if (m != null) return event(HomeLiveKind.sale, client: m[1], amount: _amount(m[2]!));
    } else if (type == ActivityType.services.key) {
      final m = _visit.firstMatch(description);
      if (m != null) return event(HomeLiveKind.visit, client: m[1]);
    } else if (type == ActivityType.debtors.key) {
      final m = _payment.firstMatch(description);
      if (m != null) return event(HomeLiveKind.payment, client: m[2], amount: _amount(m[1]!));
    }
    return event(HomeLiveKind.other);
  }

  /// The newest entry of [docs] (newest first) as an event. A sale's
  /// expired-stock note is written with its sale; the sale itself is told.
  static HomeLiveEvent? latestOf(List<LogDoc> docs) {
    if (docs.isEmpty) return null;
    final first = docs.length > 1 && docs.first.id.endsWith('_expired') ? docs[1] : docs.first;
    return fromEntry(first.id, first.data());
  }

  @override
  bool operator ==(Object other) =>
      other is HomeLiveEvent &&
      other.id == id &&
      other.kind == kind &&
      other.type == type &&
      other.client == client &&
      other.amount == amount &&
      other.at == at;

  @override
  int get hashCode => Object.hash(id, kind, type, client, amount, at);
}

/// The latest event of an activity stream (null: none), the same events
/// passed through: no listener of its own.
Stream<HomeLiveEvent?> homeLiveEvents(Stream<List<LogDoc>> entries) => entries.map(HomeLiveEvent.latestOf).distinct();

/// The amount's place in [homeLiveText] when the line draws it itself.
const homeLiveAmountMark = '\u0000';

/// The line for [e]: "Sale · Amina Juma · Tsh 45,000 · 10:15". The time is
/// HH:mm today, "Yesterday 16:40", else "Wed 04 Nov"; [showAmount] false
/// leaves the amount out. With [amountMark] the amount is that text.
String homeLiveText(
  AppLocalizations l,
  HomeLiveEvent e, {
  required DateTime now,
  required String locale,
  required bool showAmount,
  String? amountMark,
}) {
  final kind = switch (e.kind) {
    HomeLiveKind.sale => l.activityType_sale,
    HomeLiveKind.visit => l.home_liveVisit,
    HomeLiveKind.payment => l.notifications_catPayment,
    HomeLiveKind.other => l.activityTypeLabel(e.type),
  };
  final time = e.at == null ? null : _time(l, e.at!, now: now, locale: locale);
  if (e.kind == HomeLiveKind.other || e.client == null) {
    return time == null ? kind : l.home_liveTypeTime(kind, time);
  }
  final client = e.client == HomeLiveEvent.walkIn ? l.common_walkIn : e.client!;
  final amount = showAmount && e.amount != null ? amountMark ?? Money.format(e.amount!) : null;
  if (time == null) {
    return amount == null ? l.home_liveTypeClient(kind, client) : l.home_liveTypeClientAmount(kind, client, amount);
  }
  return amount == null ? l.home_liveLine(kind, client, time) : l.home_liveLineAmount(kind, client, amount, time);
}

String _time(AppLocalizations l, DateTime at, {required DateTime now, required String locale}) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final hhmm = DateFormat(AppDateFormat.time24Pattern, locale).format(at);
  if (day == today) return hhmm;
  if (day == DateTime(today.year, today.month, today.day - 1)) return l.home_liveYesterday(hhmm);
  return DateFormat(AppDateFormat.weekdayDayPadMonthShortPattern, locale).format(at);
}

