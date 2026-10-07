/// Outside links the app opens. Each builder produces exactly the URL the
/// screens built by hand before (config_test compares them).
class AppLinks {
  AppLinks._();

  /// A WhatsApp chat: `https://wa.me/<digits>`, plus `?text=<encoded>` when
  /// [text] is given (even if empty, as the debt reminder always adds it).
  /// [phone] may contain '+', spaces or dashes; only the digits are used.
  static Uri whatsApp(String phone, {String? text}) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final query = text == null ? '' : '?text=${Uri.encodeComponent(text)}';
    return Uri.parse('https://wa.me/$digits$query');
  }

  /// A text message: `sms:<digits and +>?body=<encoded>`. Unlike WhatsApp,
  /// the '+' is kept.
  static Uri sms(String phone, {required String body}) {
    final number = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    return Uri.parse('sms:$number?body=${Uri.encodeComponent(body)}');
  }

  /// A phone call: `tel:<phone>`, the number exactly as given.
  static Uri tel(String phone) => Uri.parse('tel:$phone');

  /// An email: `mailto:<address>`.
  static Uri mailto(String address) => Uri.parse('mailto:$address');
}

/// VetBiz support. Kept as constants for now; making them editable by the
/// platform admin is optional step 2H.
class AppContact {
  AppContact._();

  static const String supportPhone = '+255719199916';
  static const String supportEmail = 'shanelvmi@gmail.com';
}
