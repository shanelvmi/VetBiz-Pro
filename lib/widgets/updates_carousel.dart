import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_timeouts.dart';
import '../data/announcement_fields.dart';
import '../services/announcement_service.dart';
import '../services/updates_store.dart';
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
/// 16:9 frame, the optional link button below, and with several slides the
/// dots. AN6: the frame is a horizontal PageView that follows the finger
/// and the mouse; the next slide slides in from the right with a soft
/// parallax, auto-advance always moves forward and loops from the last to
/// the first in the same direction (an effectively endless page list), a
/// dot slides in its own direction, and Left and Right move when the
/// keyboard is on the carousel. The active dot's pill fills over
/// [AppTimeouts.updatesAdvance] (the timer, made and disposed with this
/// State, never in a builder); it pauses where it is while the pointer
/// hovers, a finger touches or focus is inside, and never runs under
/// reduced motion, where every change is instant.
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

  /// How many times the timer was started from rest (tests: none on a
  /// rebuild, none under reduced motion).
  @visibleForTesting
  static int debugTimerStarts = 0;

  @override
  State<UpdatesSlides> createState() => _UpdatesSlidesState();
}

class _UpdatesSlidesState extends State<UpdatesSlides> with SingleTickerProviderStateMixin {
  // Laps of the slides before the first page: far more than anyone swipes
  // back, so the list is endless both ways and the loop never jumps.
  static const int _laps = 10000;

  late PageController _pages;
  late final AnimationController _fill = AnimationController(vsync: this, duration: AppTimeouts.updatesAdvance)
    ..addStatusListener(_onFill);
  final FocusNode _dotsFocus = FocusNode(debugLabel: 'updatesDots');
  int _page = 0;
  bool _hovering = false;
  bool _touching = false;
  bool _focused = false;
  bool _reduceMotion = false;

  List<Announcement> get _slides => widget.slides;
  int get _count => _slides.length;
  bool get _several => _count > 1;
  int get _index => _page % _count;

  int _firstPage(int index) => _several ? _count * _laps + index : 0;

  ImageProvider? _imageOf(Announcement a) {
    final url = a.imageUrl;
    if (a.kind != AnnouncementKind.poster || url == null) return null;
    return (widget.imageFor ?? NetworkImage.new)(url);
  }

  @override
  void initState() {
    super.initState();
    _page = _firstPage(0);
    _pages = PageController(initialPage: _page);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncFill();
    _preloadAround();
  }

  @override
  void didUpdateWidget(UpdatesSlides old) {
    super.didUpdateWidget(old);
    if (old.slides.length != _count) {
      // A new count changes every page's slide: start a new page list at
      // the slide shown (or the first), and let the old one go after this
      // frame, once the new PageView holds the new controller.
      final previous = _pages;
      _page = _firstPage(old.slides.isEmpty ? 0 : (_page % old.slides.length) % _count);
      _pages = PageController(initialPage: _page);
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
      _fill.reset();
    }
    _syncFill();
  }

  @override
  void dispose() {
    _fill.dispose();
    _pages.dispose();
    _dotsFocus.dispose();
    super.dispose();
  }

  bool get _shouldRun => _several && !_reduceMotion && !_hovering && !_touching && !_focused;

  /// Runs the timer from where it is when it should run; stops it where it
  /// is when it should not. A rebuild never starts a new one.
  void _syncFill() {
    if (!_shouldRun) {
      if (_fill.isAnimating) _fill.stop();
      return;
    }
    if (!_fill.isAnimating && _fill.status != AnimationStatus.completed) {
      UpdatesSlides.debugTimerStarts++;
      _fill.forward();
    }
  }

  void _onFill(AnimationStatus status) {
    if (status == AnimationStatus.completed) _go(_page + 1);
  }

  /// Moves to [page]: forward when it is after the current one, back when
  /// before; instantly under reduced motion.
  void _go(int page) {
    if (!mounted || !_several || !_pages.hasClients) return;
    if (_reduceMotion) {
      _pages.jumpToPage(page);
    } else {
      _pages.animateToPage(page, duration: AppMotion.updatesSlide, curve: Curves.easeOutCubic);
    }
  }

  void _onPageChanged(int page) {
    setState(() => _page = page);
    // Every new slide, chosen or not, gets a full turn.
    _fill.reset();
    _syncFill();
    _preloadAround();
  }

  /// The posters before and after this one are fetched before their turn.
  void _preloadAround() {
    if (!_several) return;
    for (final i in {(_index + 1) % _count, (_index - 1 + _count) % _count}) {
      final image = _imageOf(_slides[i]);
      if (image != null) precacheImage(image, context, onError: (_, _) {});
    }
  }

  void _setPause({bool? hovering, bool? touching, bool? focused}) {
    _hovering = hovering ?? _hovering;
    _touching = touching ?? _touching;
    _focused = focused ?? _focused;
    _syncFill();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_several || event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _go(_page + 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _go(_page - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// The soft parallax: the slide on the left of the two in view (the
  /// outgoing one when moving forward) travels only
  /// [AppMotion.updatesOutgoingTravel] of the way, under the one coming in.
  Widget _slideAt(BuildContext context, int page) {
    final a = _slides[page % _count];
    final slide = UpdateSlide(
      announcement: a,
      isNew: UpdatesSelection.isNew(a, (widget.now ?? DateTime.now)()),
      image: _imageOf(a),
    );
    if (!_several || _reduceMotion) return slide;
    return AnimatedBuilder(
      animation: _pages,
      child: slide,
      builder: (context, child) {
        final position = _pages.hasClients && _pages.position.haveDimensions ? _pages.page! : _page.toDouble();
        final offset = page - position;
        if (offset >= 0 || offset <= -1) return child!;
        return FractionalTranslation(translation: Offset(-offset * (1 - AppMotion.updatesOutgoingTravel), 0), child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _slides[_index];
    final isNew = UpdatesSelection.isNew(current, (widget.now ?? DateTime.now)());
    final isPoster = current.kind == AnnouncementKind.poster;
    final link = AnnouncementLinkButton.addressOf(current);
    // The link's line is kept for every slide once any has a link, so the
    // area does not jump as they change.
    final anyLink = _slides.any((a) => AnnouncementLinkButton.addressOf(a) != null);

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) => _setPause(focused: focused),
      onKeyEvent: _onKey,
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
          child: UpdatesFrameLayout(
            label: UpdatesLabel(showChips: isPoster, urgent: current.urgent, isNew: isNew),
            frameKey: UpdatesSlides.frameKey,
            // Dragged by finger, mouse, trackpad or pen: the web's default
            // leaves the mouse out.
            frame: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                scrollbars: false,
                dragDevices: const {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.invertedStylus,
                },
              ),
              child: PageView.builder(
                key: ObjectKey(_pages),
                controller: _pages,
                physics: _several ? null : const NeverScrollableScrollPhysics(),
                itemCount: _several ? null : 1,
                onPageChanged: _several ? _onPageChanged : null,
                itemBuilder: _slideAt,
              ),
            ),
            link:
                !anyLink
                    ? null
                    : link == null
                    ? const SizedBox.shrink()
                    : Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: AnnouncementLinkButton(key: UpdatesSlides.linkKey, announcement: current, launcher: widget.launcher),
                    ),
            controls:
                _several
                    ? UpdatesDots(
                      count: _count,
                      index: _index,
                      progress: _reduceMotion ? kAlwaysCompleteAnimation : _fill,
                      reduceMotion: _reduceMotion,
                      focusNode: _dotsFocus,
                      onSelect: (i) => _go(_page + i - _index),
                    )
                    : null,
          ),
        ),
      ),
    );
  }
}
