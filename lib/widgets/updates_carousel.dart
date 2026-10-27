import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_timeouts.dart';
import '../config/app_limits.dart';
import '../data/announcement_fields.dart';
import '../services/announcement_service.dart';
import '../services/updates_store.dart';
import '../theme/app_breakpoints.dart';
import '../theme/app_dimens.dart';
import '../theme/app_motion.dart';
import '../utils/updates_selection.dart';
import 'auth_footer.dart';
import 'announcement_poster.dart';
import 'update_slide.dart';
import 'updates_parts.dart';

/// Places the Updates area: the slides, the skeleton or the calm panel.
typedef UpdatesLayoutBuilder = Widget Function(BuildContext context, Widget updates);

/// The login page's Updates (AN2, the owner's approved design). AN6: reads
/// the app's one [UpdatesStore] (started at app start, with the device's
/// last-known copy) instead of a stream of its own, picks what to show for
/// the current language, and ALWAYS hands [builder] an area: a skeleton
/// while nothing is known, the slides, or a calm panel when there are none,
/// all in the same layout, so the page never jumps when the answer comes.
class UpdatesCarousel extends StatefulWidget {
  const UpdatesCarousel({
    super.key,
    this.firestore,
    this.store,
    required this.builder,
    this.launcher = launchUrl,
    this.imageFor,
  });

  /// Firestore for the store's one subscription (the app's; a fake in tests).
  final FirebaseFirestore? firestore;

  /// The app's store unless given (tests).
  final UpdatesStore? store;

  final UpdatesLayoutBuilder builder;
  final AuthFooterLauncher launcher;

  /// A poster's image from its URL: NetworkImage in the app, a fake in tests.
  final ImageProvider Function(String url)? imageFor;

  /// For tests: the frame kept while nothing is known yet (G6).
  static const skeletonKey = Key('updatesSkeleton');

  /// For tests: the calm panel shown when there are no updates (AN6).
  static const emptyKey = Key('updatesEmpty');

  @override
  State<UpdatesCarousel> createState() => _UpdatesCarouselState();
}

class _UpdatesCarouselState extends State<UpdatesCarousel> {
  UpdatesStore get _store => widget.store ?? UpdatesStore.instance;
  String? _language;

  @override
  void initState() {
    super.initState();
    // Already running since app start; this only makes sure (one
    // subscription, whoever asks).
    _store.start(widget.firestore);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    if (language != _language) {
      _language = language;
      _store.warmFor(language);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final slides = _store.slidesFor(Localizations.localeOf(context).languageCode);
        final Widget updates;
        if (slides == null) {
          updates = const UpdatesSkeleton(key: UpdatesCarousel.skeletonKey);
        } else if (slides.isEmpty) {
          updates = const UpdatesEmpty(key: UpdatesCarousel.emptyKey);
        } else {
          updates = UpdatesSlides(slides: slides, launcher: widget.launcher, imageFor: widget.imageFor);
        }
        return widget.builder(context, updates);
      },
    );
  }
}

/// The Updates area for [slides] (at least one): the quiet label, ONE fixed
/// 16:9 frame, the optional link button below, and with several slides a
/// gentle fade every [AppTimeouts.updatesAdvance], dots, swipe and (on wide
/// windows) arrows. The timer lives here, made and cancelled with this
/// State, never in a builder. It pauses while the pointer hovers, a finger
/// touches or focus is inside, and never runs when the system asks for less
/// motion. Roles, tokens and named limits only, so a later restyle is here.
class UpdatesSlides extends StatefulWidget {
  const UpdatesSlides({super.key, required this.slides, this.launcher = launchUrl, this.imageFor, this.now});

  final List<Announcement> slides;
  final AuthFooterLauncher launcher;
  final ImageProvider Function(String url)? imageFor;

  /// The clock for the New chip; DateTime.now in the app.
  final DateTime Function()? now;

  static const frameKey = Key('updatesFrame');
  static const labelRowKey = UpdatesLabel.rowKey;
  static const linkKey = Key('updatesLink');

  /// How many auto-advance timers were started (tests: none on a rebuild).
  @visibleForTesting
  static int debugTimerStarts = 0;

  @override
  State<UpdatesSlides> createState() => _UpdatesSlidesState();
}

class _UpdatesSlidesState extends State<UpdatesSlides> {
  Timer? _timer;
  int _index = 0;
  bool _hovering = false;
  bool _touching = false;
  bool _focused = false;
  bool _reduceMotion = false;

  List<Announcement> get _slides => widget.slides;
  Announcement get _current => _slides[_index];

  ImageProvider? _imageOf(Announcement a) {
    final url = a.imageUrl;
    if (a.kind != AnnouncementKind.poster || url == null) return null;
    return (widget.imageFor ?? NetworkImage.new)(url);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncTimer();
    _preloadNext();
  }

  @override
  void didUpdateWidget(UpdatesSlides old) {
    super.didUpdateWidget(old);
    if (_index >= _slides.length) _index = 0;
    _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _shouldRun => _slides.length > 1 && !_reduceMotion && !_hovering && !_touching && !_focused;

  /// Starts the timer when it should run and is not running; stops it when
  /// it should not. A rebuild never makes a new one.
  void _syncTimer({bool restart = false}) {
    if (restart || !_shouldRun) {
      _timer?.cancel();
      _timer = null;
    }
    if (_shouldRun && _timer == null) {
      UpdatesSlides.debugTimerStarts++;
      _timer = Timer.periodic(AppTimeouts.updatesAdvance, (_) => _show(_index + 1, byPerson: false));
    }
  }

  /// The next poster's image is fetched before its turn.
  void _preloadNext() {
    if (_slides.length < 2) return;
    final next = _imageOf(_slides[(_index + 1) % _slides.length]);
    if (next != null) precacheImage(next, context, onError: (_, _) {});
  }

  void _show(int index, {bool byPerson = true}) {
    if (!mounted) return;
    setState(() => _index = index % _slides.length);
    _preloadNext();
    // A person's choice gets a full turn before the next slide.
    if (byPerson) _syncTimer(restart: true);
  }

  void _setPause({bool? hovering, bool? touching, bool? focused}) {
    _hovering = hovering ?? _hovering;
    _touching = touching ?? _touching;
    _focused = focused ?? _focused;
    _syncTimer();
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    final isNew = UpdatesSelection.isNew(current, (widget.now ?? DateTime.now)());
    final isPoster = current.kind == AnnouncementKind.poster;
    final link = AnnouncementLinkButton.addressOf(current);
    // The link's line is kept for every slide once any has a link, so the
    // area does not jump as they change.
    final anyLink = _slides.any((a) => AnnouncementLinkButton.addressOf(a) != null);
    final several = _slides.length > 1;
    final wide = MediaQuery.sizeOf(context).width > AppBreakpoints.twoPane;
    // AN4: in the wide card (UpdatesCard) the area fills the card's height
    // and the controls sit at its bottom, on a line kept even for one slide
    // (nothing drawn on it), so the card is as tall with one as with several.
    final inCard = UpdatesPlacement.wideOf(context);
    final controls =
        several ? UpdatesDots(count: _slides.length, index: _index, arrows: wide, reduceMotion: _reduceMotion, onSelect: _show) : null;

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) => _setPause(focused: focused),
      child: MouseRegion(
        onEnter: (_) => _setPause(hovering: true),
        onExit: (_) => _setPause(hovering: false),
        child: Listener(
          onPointerDown: (e) {
            if (e.kind == PointerDeviceKind.touch) _setPause(touching: true);
          },
          onPointerUp: (e) {
            if (e.kind == PointerDeviceKind.touch) _setPause(touching: false);
          },
          onPointerCancel: (e) {
            if (e.kind == PointerDeviceKind.touch) _setPause(touching: false);
          },
          child: Column(
            mainAxisSize: inCard ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UpdatesLabel(showChips: isPoster, urgent: current.urgent, isNew: isNew),
              const SizedBox(height: AppSpacing.s6),
              GestureDetector(
                onHorizontalDragEnd:
                    several
                        ? (d) {
                          final v = d.primaryVelocity ?? 0;
                          if (v.abs() < kMinFlingVelocity) return;
                          _show(v < 0 ? _index + 1 : _index - 1 + _slides.length);
                        }
                        : null,
                child: AspectRatio(
                  key: UpdatesSlides.frameKey,
                  aspectRatio: AppLimits.posterAspectRatio,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.r16),
                    child: AnimatedSwitcher(
                      duration: _reduceMotion ? Duration.zero : AppMotion.slowest,
                      child: UpdateSlide(
                        key: ValueKey(current.id),
                        announcement: current,
                        isNew: isNew,
                        image: _imageOf(current),
                      ),
                    ),
                  ),
                ),
              ),
              if (inCard) const Spacer(),
              if (anyLink)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s6),
                  child: SizedBox(
                    height: kMinInteractiveDimension,
                    child:
                        link == null
                            ? null
                            : Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: AnnouncementLinkButton(
                                key: UpdatesSlides.linkKey,
                                announcement: current,
                                launcher: widget.launcher,
                              ),
                            ),
                  ),
                ),
              if (inCard)
                SizedBox(height: kMinInteractiveDimension, child: controls)
              else if (controls != null)
                controls,
            ],
          ),
        ),
      ),
    );
  }
}
