import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/services/support_contact_store.dart';
import 'package:vetbiz_pro/services/updates_store.dart';
import 'package:vetbiz_pro/widgets/reveal/reveal_image.dart';

// Runs around every test file. G6, AN6: the support contact and the Updates
// store live for the whole app (a session), so each test starts
// with fresh ones instead of what an earlier test left behind. RV2b: so do
// the mock preferences. A test that reached SharedPreferences before setting
// its own values worked only after a test that had (its static platform
// store); run first, it asked the real platform channel, which never
// answers in a test (an6's "persisted copy" test hung with seed 4242).
// RV2b: a list or card image (RevealImage) fails at once, as a network image
// with no network does, instead of never answering in the fake clock (which
// would hold a list's reveal for its grace); a test that needs a real image
// sets RevealImage.providerFor itself.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SupportContactStore.debugReset();
    UpdatesStore.debugReset();
    RevealImage.providerFor = _NoNetworkImage.new;
  });
  await testMain();
}

/// An image that fails as soon as it is asked for.
class _NoNetworkImage extends ImageProvider<_NoNetworkImage> {
  const _NoNetworkImage(this.url);

  final String url;

  @override
  Future<_NoNetworkImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_NoNetworkImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(Future<ImageInfo>.error(StateError('no network in a test: $url')));

  @override
  bool operator ==(Object other) => other is _NoNetworkImage && other.url == url;

  @override
  int get hashCode => url.hashCode;
}
