import 'dart:async';

/// Fires on any real pointer activity (tap/click or scroll) anywhere
/// in the app, including inside dialogs and other content rendered on
/// the Overlay - fed from a Listener wrapping the whole MaterialApp
/// (see main.dart's builder parameter), not scoped to any one screen's
/// own widget subtree. A Listener wrapping just one screen's content
/// would miss activity inside any dialog pushed on top of it, since
/// dialogs render above that screen in the Overlay, not nested inside
/// it.
///
/// Broadcast so more than one interested screen (today: just Platform
/// Admin's inactivity timer) can listen at once without stepping on
/// each other.
final StreamController<void> globalActivitySignal = StreamController<void>.broadcast();
