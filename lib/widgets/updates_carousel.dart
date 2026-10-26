import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/announcement_service.dart';
import 'auth_footer.dart';

/// Places the Updates area, or nothing (null) when there is nothing to show.
typedef UpdatesLayoutBuilder = Widget Function(BuildContext context, Widget? updates);

/// The login page's Updates (AN2). This first commit is only the API the
/// tests are written against; it draws nothing yet.
class UpdatesCarousel extends StatefulWidget {
  const UpdatesCarousel({super.key, required this.firestore, required this.builder, this.launcher = launchUrl, this.imageFor});

  final FirebaseFirestore firestore;
  final UpdatesLayoutBuilder builder;
  final AuthFooterLauncher launcher;

  /// A poster's image from its URL: NetworkImage in the app, a fake in tests.
  final ImageProvider Function(String url)? imageFor;

  @override
  State<UpdatesCarousel> createState() => _UpdatesCarouselState();
}

class _UpdatesCarouselState extends State<UpdatesCarousel> {
  @override
  Widget build(BuildContext context) => widget.builder(context, null);
}

/// The Updates area for [slides] (at least one).
class UpdatesSlides extends StatefulWidget {
  const UpdatesSlides({super.key, required this.slides, this.launcher = launchUrl, this.imageFor, this.now});

  final List<Announcement> slides;
  final AuthFooterLauncher launcher;
  final ImageProvider Function(String url)? imageFor;

  /// The clock for the New chip; DateTime.now in the app.
  final DateTime Function()? now;

  static const frameKey = Key('updatesFrame');
  static const labelRowKey = Key('updatesLabelRow');
  static const linkKey = Key('updatesLink');

  /// How many auto-advance timers were started (tests: none on a rebuild).
  @visibleForTesting
  static int debugTimerStarts = 0;

  @override
  State<UpdatesSlides> createState() => _UpdatesSlidesState();
}

class _UpdatesSlidesState extends State<UpdatesSlides> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
