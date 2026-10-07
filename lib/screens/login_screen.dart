import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../widgets/announcement_message.dart';
import '../utils/navigator_key.dart';
import 'legal/privacy_policy_screen.dart';
import 'legal/terms_of_service_screen.dart';
import '../theme/app_palette.dart';

class LoginScreen extends StatefulWidget {
  final String? errorMessage;
  const LoginScreen({super.key, this.errorMessage});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool rememberMe = false;
  bool obscurePassword = true;
  bool isLoggingIn = false;
  final FocusNode passwordFocusNode = FocusNode();
  String? error;
  // True when the current error is about the credentials themselves (unknown
  // email, wrong password, empty fields) - the two inputs are outlined in
  // red so the problem is still visible after the alert is dismissed. Other
  // errors (network down, account blocked) aren't about what was typed.
  bool errorIsAboutCredentials = false;
  // Bumped on every new error to replay the form card's shake.
  int _shakeCount = 0;
  bool isForgotHovered = false;
  bool isRegisterHovered = false;

  Timer? _announcementTimer;

  final Color primaryDeepGreen = AppPalette.primary;
  final Color tealAccent = const Color(0xFF3E8E82);
  final Color warmAmber = AppPalette.accent;
  final Color tealGlow = const Color(0xFF7EE8CB);
  final Color offWhite = AppPalette.background;
  final Color neutralBlack = Colors.black87;

  OutlineInputBorder _fieldBorder(Color color) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: color));

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
    if (widget.errorMessage != null) {
      // Deferred to after the first frame - setState during initState
      // itself is unsafe.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => error = widget.errorMessage);
        _startErrorTimer();
      });
    }
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('remembered_email');
    if (savedEmail != null && savedEmail.isNotEmpty && mounted) {
      setState(() {
        emailController.text = savedEmail;
        rememberMe = true;
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    passwordFocusNode.dispose();
    _announcementTimer?.cancel();
    _errorTimer?.cancel();
    super.dispose();
  }

  // ==================== LOGIN LOGIC ====================
  // Deliberately does nothing after a successful sign-in beyond
  // pushing the signed-in user directly to AppEntryPoint - no
  // Firestore fetch, no status check, no navigation here. AppEntryPoint
  // (in main.dart) owns deciding what screen to show next; if this
  // method also tried to navigate itself, the two would race: this
  // screen can get torn down and replaced by AppEntryPoint's own
  // rebuild while this method is still mid-flight (fetching Firestore,
  // checking status), and its result gets silently discarded once that
  // happens. That race was the actual cause of login intermittently
  // "doing nothing" after a login/logout cycle - not a Firebase error,
  // two separate pieces of code deciding what screen to show next.
  Future<void> _login() async {
    if (isLoggingIn) return; // guards against a double-tap firing two logins at once
    _errorTimer?.cancel();
    setState(() {
      error = null;
      errorIsAboutCredentials = false;
      isLoggingIn = true;
    });

    if (emailController.text.isEmpty || passwordController.text.length < 6) {
      setState(() {
        error = "Enter valid email and password (min 6 chars).";
        errorIsAboutCredentials = true;
        _shakeCount++;
        isLoggingIn = false;
      });
      _startErrorTimer();
      return;
    }

    try {
      // Remember Me only ever stores the email, never the password -
      // just a convenience so it's pre-filled next time, not a
      // session/login bypass of any kind. Done before the sign-in
      // attempt itself so it never depends on anything that could race
      // with AppEntryPoint.
      final prefs = await SharedPreferences.getInstance();
      if (rememberMe) {
        await prefs.setString('remembered_email', emailController.text.trim());
      } else {
        await prefs.remove('remembered_email');
      }

      debugPrint('[LOGIN] Attempting sign-in for ${emailController.text.trim()}');
      final credential = await _authService.login(
        emailController.text.trim(),
        passwordController.text.trim(),
      );
      final signedInUser = credential.user;
      debugPrint('[LOGIN] Sign-in succeeded for uid=${signedInUser?.uid ?? "unknown"}');

      // The direct fix - tells AppEntryPoint about this newly
      // signed-in user immediately, rather than only ever finding out
      // via authStateChanges() (a known, occasionally-unreliable path
      // specifically on Flutter web, especially right after a
      // logout-then-login-as-someone-else sequence) or waiting for the
      // periodic poll's next tick.
      if (signedInUser != null) {
        if (pushAuthUser != null) {
          debugPrint('[LOGIN] Pushing signed-in user directly to AppEntryPoint');
          pushAuthUser!(signedInUser);
        } else {
          debugPrint('[LOGIN] No push callback registered - relying on stream/poll fallback');
        }
      }

      // A defensive safety net, not the primary mechanism for getting
      // to the dashboard - if AppEntryPoint still hasn't navigated
      // away within a few seconds, this screen would already be
      // disposed if it had, so this stops the button spinning forever
      // instead of leaving it stuck indefinitely for any reason not
      // otherwise anticipated.
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted && isLoggingIn) {
          debugPrint('[LOGIN] Still mounted 6s after a successful sign-in - resetting loading state');
          // Never silently: this screen should have been replaced long ago.
          // Say so, instead of just handing the person back an idle form.
          setState(() {
            isLoggingIn = false;
            error = 'Signing in is taking longer than expected. '
                'Check your internet connection and try again.';
            errorIsAboutCredentials = false;
          });
          _startErrorTimer();
        }
      });

      // No further navigation here - see the note above. AppEntryPoint
      // takes it from here.
    } on FirebaseAuthException catch (e) {
      debugPrint('[LOGIN] FirebaseAuthException: ${e.code} - ${e.message}');
      if (!mounted) return;
      setState(() {
        error = _friendlyAuthError(e);
        errorIsAboutCredentials = _isCredentialError(e);
        _shakeCount++;
        isLoggingIn = false;
      });
      _startErrorTimer();
    } catch (e) {
      debugPrint('[LOGIN] Unexpected error: $e');
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceAll('Exception:', '').trim();
        errorIsAboutCredentials = false;
        _shakeCount++;
        isLoggingIn = false;
      });
      _startErrorTimer();
    }
  }

  // Firebase's own exception messages are technical and inconsistent in
  // tone - this maps the common cases to something a shop owner would
  // actually understand, without guessing at ones not explicitly
  // handled (those fall through to Firebase's own message).
  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'invalid-email':
        return 'No account found with that email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        // Recent Firebase SDKs report both "wrong password" and
        // "no such user" under this one unified code, for security
        // reasons (so a login form can't be used to check which emails
        // are registered).
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled. Contact your admin.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error - check your connection and try again.';
      default:
        return e.message ?? 'Login failed. Please try again.';
    }
  }

  Future<void> _forgotPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        error = "Enter your email first to reset password.";
        errorIsAboutCredentials = true; // it's the email field that's empty
        _shakeCount++;
      });
      _startErrorTimer();
      return;
    }
    // Deliberately the same message whether this succeeds or the email
    // doesn't exist - confirming or denying an account's existence here
    // would let this form be used to build a list of every registered
    // email on the platform. Handled at this level rather than relying
    // solely on Firebase's own project-level email-enumeration-
    // protection setting, which this code has no way to verify is
    // actually turned on.
    const vagueMessage = "If an account exists for this email, a reset link "
        "has been sent. Check your inbox (and spam folder).";
    try {
      await _authService.sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(vagueMessage, style: TextStyle(color: Colors.white)),
          backgroundColor: primaryDeepGreen,
        ));
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text(vagueMessage, style: TextStyle(color: Colors.white)),
            backgroundColor: primaryDeepGreen,
          ));
        }
      } else {
        setState(() {
          error = _friendlyAuthError(e);
          errorIsAboutCredentials = _isCredentialError(e);
          _shakeCount++;
        });
        _startErrorTimer();
      }
    } catch (e) {
      setState(() {
        error = "Could not send reset email: $e";
        errorIsAboutCredentials = false;
        _shakeCount++;
      });
      _startErrorTimer();
    }
  }

  // ==================== TOP HEADER ====================
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryDeepGreen, tealAccent],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Enough room for the subtitle plus everything else on one
          // line without anything needing to shrink or shift - below
          // this, the subtitle (the least critical piece here) is
          // dropped instead, keeping the title, status pill, and
          // settings icon exactly where they belong.
          final isNarrow = constraints.maxWidth < 560;

          return SizedBox(
            height: 44,
            child: Stack(
            children: [
              // Left group - logo, title, subtitle. Positioned rather
              // than Row's default left alignment, so both groups use
              // the same explicit-coordinate mechanism.
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                right: 180, // leaves room for the right group so long titles don't run under it
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text('VB.', style: TextStyle(color: primaryDeepGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('VetBiz Pro System',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            if (!isNarrow)
                              Text('Smart Business & Vet Services Monitor',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Right group - status pill and sun icon. Pinned directly
              // to an explicit right coordinate (16px from the actual
              // container edge) rather than pushed there by a Spacer
              // inside a Row - a direct position, not a computed one.
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            const Text('System Online',
                                style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                        child: const Icon(Icons.wb_sunny_outlined, color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            ),
          );
        },
      ),
    );
  }

  // ==================== BOTTOM FOOTER ====================
  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: primaryDeepGreen,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Enough room for everything on a single line, spanning the
          // full width edge to edge - only falls back to a reflowing
          // layout when there genuinely isn't room for that, on small
          // screens specifically.
          if (constraints.maxWidth >= 600) {
            return Row(
              children: [
                Icon(Icons.shield_outlined, color: Colors.white.withValues(alpha: 0.7), size: 16),
                const SizedBox(width: 8),
                Text('© 2026 VetBiz Pro System. All rights reserved.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                const Spacer(),
                Text('v2.0.0', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                const SizedBox(width: 20),
                const _FooterLink(label: 'Privacy Policy', destination: PrivacyPolicyScreen()),
                const SizedBox(width: 20),
                const _FooterLink(label: 'Terms of Service', destination: TermsOfServiceScreen()),
              ],
            );
          }
          return Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, color: Colors.white.withValues(alpha: 0.7), size: 16),
                  const SizedBox(width: 8),
                  Text('© 2026 VetBiz Pro System. All rights reserved.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                ],
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 20,
                runSpacing: 4,
                children: [
                  Text('v2.0.0', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                  const _FooterLink(label: 'Privacy Policy', destination: PrivacyPolicyScreen()),
                  const _FooterLink(label: 'Terms of Service', destination: TermsOfServiceScreen()),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ==================== LEFT: WELCOME CARD ====================
  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryDeepGreen, tealAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tealGlow.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tealGlow.withValues(alpha: 0.5), width: 1.2),
              boxShadow: [
                BoxShadow(color: tealGlow.withValues(alpha: 0.3), blurRadius: 8),
              ],
            ),
            child: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome to', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                Text('VetBiz Pro',
                    style: TextStyle(color: Color(0xFF7EE8CB), fontWeight: FontWeight.bold, fontSize: 19)),
                const SizedBox(height: 8),
                Text('Stay updated with the latest news and announcements.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== LEFT: ANNOUNCEMENTS ====================
  Widget _buildAnnouncementsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 22,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  right: 30,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.campaign_outlined, color: neutralBlack, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text('Announcements',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.bold, color: neutralBlack, fontSize: 15)),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 20),
          _buildAnnouncementsScrollable(),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsScrollable() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('public_announcements')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildAnnouncementsEmptyState();
        }

        final allDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['hidden'] != true;
        }).toList();

        final urgentDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['urgent'] == true;
        }).toList();

        // While at least one urgent announcement is active, it takes
        // over completely - every other announcement is automatically
        // paused rather than needing to be hidden one by one.
        final docs = urgentDocs.isNotEmpty ? urgentDocs : allDocs;

        if (docs.isEmpty) {
          return _buildAnnouncementsEmptyState();
        }
        final PageController controller = PageController();
        int currentIndex = 0;

        // Auto-scroll timer
        _announcementTimer?.cancel();
        _announcementTimer = Timer.periodic(const Duration(seconds: 6), (_) {
          if (!controller.hasClients || docs.isEmpty) return;
          currentIndex = (currentIndex + 1) % docs.length;
          controller.animateToPage(currentIndex,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut);
        });

        return SizedBox(
          height: 210,
          child: Column(
            children: [
              // Announcements
              Expanded(
                child: PageView.builder(
                  controller: controller,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final title = data['title'] ?? 'Notice';
                    final ts = data['timestamp'] as Timestamp?;
                    final bool isNew = ts != null &&
                        DateTime.now().difference(ts.toDate()).inHours < 48;
                    final bool isUrgent = data['urgent'] == true;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: offWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isUrgent ? Colors.red.withValues(alpha: 0.4) : Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isUrgent)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Chip(
                                label: const Text('URGENT', style: TextStyle(fontSize: 10, color: Colors.white)),
                                backgroundColor: Colors.red,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          // Title + NEW badge
                          Row(
                            children: [
                              Expanded(
                                child: Text(title,
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: primaryDeepGreen)),
                              ),
                              if (isNew) const _NewBadge(),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Scrollable message
                          Expanded(
                            child: SingleChildScrollView(
                              child: AnnouncementMessage(data: data),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Dot indicators
              SmoothPageIndicator(
                controller: controller,
                count: docs.length,
                effect: ExpandingDotsEffect(
                  dotHeight: 6,
                  dotWidth: 6,
                  activeDotColor: primaryDeepGreen,
                  dotColor: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnnouncementsEmptyState() {
    return SizedBox(
      height: 210,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 44, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text('No announcements', style: TextStyle(fontWeight: FontWeight.bold, color: neutralBlack, fontSize: 14)),
            const SizedBox(height: 4),
            Text("You're all caught up!", style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }

  // ==================== LEFT: TRUST FOOTER ====================
  Widget _buildTrustFooter() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: tealGlow.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: tealGlow.withValues(alpha: 0.3), width: 1),
            boxShadow: [
              BoxShadow(color: tealGlow.withValues(alpha: 0.15), blurRadius: 5),
            ],
          ),
          child: Icon(Icons.verified_user_outlined, color: primaryDeepGreen, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Secure. Reliable. Always Connected.',
                  style: TextStyle(fontWeight: FontWeight.bold, color: neutralBlack, fontSize: 13)),
              const SizedBox(height: 2),
              Text('Your trusted partner in animal health and business growth.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== RIGHT: LOGIN FORM ====================
  // ==================== ERROR HANDLING ====================

  Timer? _errorTimer;

  // How long an alert stays up before dismissing itself: long enough to read
  // - 4 seconds plus one more per ~20 characters, between 5 and 12 - so a
  // short "Incorrect email or password." doesn't linger, while a long
  // message isn't gone before it can be read. It floats over the card's
  // "Welcome back" heading, so it shouldn't stay longer than it's needed.
  Duration _errorDisplayDuration(String message) {
    final seconds = (4 + message.length ~/ 20).clamp(5, 12).toInt();
    return Duration(seconds: seconds);
  }

  // (Re)starts the countdown for the error currently showing. Safe to call
  // with no error showing - it does nothing then.
  void _startErrorTimer({Duration? after}) {
    _errorTimer?.cancel();
    final message = error;
    if (message == null) return;
    _errorTimer = Timer(after ?? _errorDisplayDuration(message), () {
      // Only if it's still the same alert - a newer one has its own timer.
      if (mounted && error == message) _dismissError();
    });
  }

  // Hides the alert: the X, or the timer running out. The red outline on the
  // two fields is deliberately NOT cleared here - it's what keeps the problem
  // visible once the alert has gone - and lasts until the person edits a
  // field or tries again.
  void _dismissError() {
    _errorTimer?.cancel();
    if (error == null) return;
    setState(() => error = null);
  }

  // Typing in either field: the problem is being fixed, so the alert (if
  // still up) and the red outlines both go.
  void _onCredentialsEdited() {
    _errorTimer?.cancel();
    if (error == null && !errorIsAboutCredentials) return;
    setState(() {
      error = null;
      errorIsAboutCredentials = false;
    });
  }

  // Whether a sign-in failure is about what was typed (unknown email, wrong
  // password), as opposed to the network being down or the account being
  // blocked - only the former outlines the two fields in red.
  bool _isCredentialError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'invalid-email':
      case 'wrong-password':
      case 'invalid-credential':
        return true;
      default:
        return false;
    }
  }

  // ==================== LOGIN FORM ====================

  InputDecoration _loginInputDecoration({
    required String hint,
    required IconData icon,
    required bool hasError,
    Widget? suffix,
  }) {
    final restColor = hasError ? Colors.redAccent.withValues(alpha: 0.7) : const Color(0xFFE2E8E6);
    final focusColor = hasError ? Colors.redAccent : primaryDeepGreen;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon: Icon(icon, size: 19, color: hasError ? Colors.redAccent : Colors.grey.shade500),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF6F9F8),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: _fieldBorder(restColor),
      enabledBorder: _fieldBorder(restColor),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: focusColor, width: 1.6),
      ),
    );
  }

  // The alert. It is an OVERLAY on the card (see _buildLoginForm's Stack),
  // not a row in the form's column: it used to sit under the Login button,
  // so every error made the form taller - which made the whole two-column
  // card taller and shoved everything below it down. As an overlay it
  // takes no layout space at all, so showing or hiding it moves nothing,
  // whatever the message length.
  Widget _buildErrorBanner() {
    // Hovering the alert pauses its countdown, so a long message can be read
    // at leisure on desktop; moving away restarts it with a short grace.
    return MouseRegion(
      // New message -> new key on the OUTERMOST widget (the only one
      // AnimatedSwitcher looks at), so a changed message animates in.
      key: ValueKey(error),
      onEnter: (_) => _errorTimer?.cancel(),
      onExit: (_) => _startErrorTimer(after: const Duration(seconds: 3)),
      child: Semantics(
        liveRegion: true,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(color: Colors.redAccent.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  // A very long message scrolls inside the alert rather than
                  // growing it over the whole form.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 96),
                    child: SingleChildScrollView(
                      child: Text(
                        error!,
                        style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12.5, height: 1.35),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  color: Colors.redAccent,
                  tooltip: 'Dismiss',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  visualDensity: VisualDensity.compact,
                  onPressed: _dismissError,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    // The flag alone - not 'an alert is showing' - so the outline outlives
    // the alert (see _dismissError).
    final fieldsInError = errorIsAboutCredentials;

    // A short side-to-side shake on every new error. Driven by _shakeCount
    // rather than a controller: each increment animates the value up by one,
    // and its fractional part is the 0..1 progress of the current shake
    // (and exactly 0 - no offset - when it isn't shaking).
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: _shakeCount.toDouble()),
      duration: const Duration(milliseconds: 420),
      builder: (context, value, child) {
        final progress = value - value.floorToDouble();
        final dx = math.sin(progress * math.pi * 6) * 8 * (1 - progress);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDDEAE7)),
          // Two layers: a wide, teal-tinted one that lifts the card off the
          // panel behind it, and a tight one for a crisp edge.
          boxShadow: [
            BoxShadow(color: primaryDeepGreen.withValues(alpha: 0.15), blurRadius: 32, offset: const Offset(0, 14)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Thin gradient accent along the top edge.
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [primaryDeepGreen, tealAccent, tealGlow]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: tealGlow.withValues(alpha: 0.24),
                                shape: BoxShape.circle,
                                border: Border.all(color: tealGlow.withValues(alpha: 0.75), width: 1.4),
                                boxShadow: [
                                  BoxShadow(color: tealGlow.withValues(alpha: 0.5), blurRadius: 14),
                                ],
                              ),
                              child: Icon(Icons.lock_outline, color: primaryDeepGreen, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Welcome back',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: neutralBlack)),
                                  const SizedBox(height: 2),
                                  Text('Log into your facility',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        Text('Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: neutralBlack)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: emailController,
                          style: TextStyle(color: neutralBlack),
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _onCredentialsEdited(),
                          onSubmitted: (_) => passwordFocusNode.requestFocus(),
                          decoration: _loginInputDecoration(
                            hint: 'Enter your email',
                            icon: Icons.mail_outline,
                            hasError: fieldsInError,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: neutralBlack)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: passwordController,
                          focusNode: passwordFocusNode,
                          obscureText: obscurePassword,
                          style: TextStyle(color: neutralBlack),
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => _onCredentialsEdited(),
                          onSubmitted: (_) => _login(),
                          decoration: _loginInputDecoration(
                            hint: 'Enter your password',
                            icon: Icons.lock_outline,
                            hasError: fieldsInError,
                            suffix: GestureDetector(
                              onTap: () => setState(() => obscurePassword = !obscurePassword),
                              child: Icon(
                                obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: Colors.grey.shade500,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Text('Minimum 6 characters', style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5)),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: rememberMe,
                                onChanged: (value) => setState(() => rememberMe = value ?? false),
                                activeColor: primaryDeepGreen,
                                checkColor: Colors.white,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('Remember Me', style: TextStyle(color: neutralBlack, fontSize: 13)),
                            const Spacer(),
                            MouseRegion(
                              onEnter: (_) => setState(() => isForgotHovered = true),
                              onExit: (_) => setState(() => isForgotHovered = false),
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: _forgotPassword,
                                child: Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: isForgotHovered ? warmAmber : tealAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _AnimatedLoginButton(
                          isLoading: isLoggingIn,
                          onPressed: isLoggingIn ? null : _login,
                          primaryColor: primaryDeepGreen,
                          accentColor: tealAccent,
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: MouseRegion(
                            onEnter: (_) => setState(() => isRegisterHovered = true),
                            onExit: (_) => setState(() => isRegisterHovered = false),
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(context, '/register');
                              },
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(fontSize: 13, color: neutralBlack),
                                  children: [
                                    const TextSpan(text: "Don't have an account? "),
                                    TextSpan(
                                      text: 'Register',
                                      style: TextStyle(
                                        color: isRegisterHovered ? warmAmber : tealAccent,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // The alert floats over the top of the card - see
              // _buildErrorBanner. Positioned children take no part in
              // the Stack's sizing, so this can never resize the card.
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, -0.25), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  ),
                  child: error == null ? const SizedBox.shrink(key: ValueKey('no-error')) : _buildErrorBanner(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full-bleed background - an admin-uploaded poster (Platform
          // Admin > Announcements) takes over entirely when set, same
          // upload mechanism as before, just repurposed as the page
          // background rather than a separate panel. Falls back to the
          // bundled default otherwise.
          Positioned.fill(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('app_config').doc('login_poster').snapshots(),
              builder: (context, snapshot) {
                final posterUrl = snapshot.data?.data() != null
                    ? (snapshot.data!.data() as Map<String, dynamic>)['posterUrl'] as String?
                    : null;

                if (posterUrl != null) {
                  return Image.network(
                    posterUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Image.asset('assets/background.jpeg', fit: BoxFit.cover),
                  );
                }
                return Image.asset('assets/background.jpeg', fit: BoxFit.cover);
              },
            ),
          ),
          // A subtle dark scrim - keeps the floating card and its
          // shadow clearly readable against the background photo
          // regardless of how bright or busy that photo is.
          Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.18))),

          // The single floating card holding every piece of content -
          // header, welcome/announcements, login form, and footer all
          // live inside this one unified surface on every screen size,
          // reflowing between two columns and a single stacked column
          // rather than switching to a stripped-down alternate layout.
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // The actual space available to the card, after the
                  // 24px padding on each side above - not the raw
                  // screen width, which doesn't account for that and
                  // was the real cause of the two-column layout
                  // overflowing at widths just above the old cutoff.
                  final isWide = constraints.maxWidth > 820;
                  final targetWidth = isWide ? 1100.0 : 480.0;
                  // The card is forced to be exactly this wide (not
                  // just "up to" it) - otherwise its own width follows
                  // whatever its content naturally demands, which can
                  // end up narrower than the target and is why the
                  // header's right-aligned elements weren't reaching
                  // the true card edge. Capped against the actual
                  // available space so this can never demand more room
                  // than genuinely exists.
                  final cardWidth =
                      constraints.maxWidth < targetWidth ? constraints.maxWidth : targetWidth;

                  return ConstrainedBox(
                    constraints: BoxConstraints(minWidth: cardWidth, maxWidth: cardWidth),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.97),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 40, offset: const Offset(0, 20)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          Padding(
                            padding: const EdgeInsets.all(28),
                            child: isWide
                                ? IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Left: Welcome + Announcements + Trust footer
                                        Expanded(
                                          flex: 1,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              _buildWelcomeCard(),
                                              const SizedBox(height: 16),
                                              Expanded(child: _buildAnnouncementsCard()),
                                              const SizedBox(height: 16),
                                              _buildTrustFooter(),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 28),
                                        // Right: Login
                                        Expanded(
                                          flex: 1,
                                          // A softly tinted panel behind the form
                                          // card: the card is white with a deep
                                          // shadow, so it lifts off this instead
                                          // of blending into the white surface
                                          // around it.
                                          child: Container(
                                            padding: const EdgeInsets.all(24),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [Color(0xFFE8F4F1), Color(0xFFF6FAF9)],
                                              ),
                                              borderRadius: BorderRadius.circular(24),
                                            ),
                                            child: Center(child: _buildLoginForm()),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                // Narrow screens: the same content, all
                                // of it, stacked in one column instead
                                // of a separate, stripped-down layout -
                                // login first since it's the action
                                // most people came here for, everything
                                // else available below it.
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildLoginForm(),
                                      const SizedBox(height: 20),
                                      _buildWelcomeCard(),
                                      const SizedBox(height: 16),
                                      _buildAnnouncementsCard(),
                                      const SizedBox(height: 16),
                                      _buildTrustFooter(),
                                    ],
                                  ),
                          ),
                          _buildFooter(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ==================== ANIMATED LOGIN BUTTON ====================
class _AnimatedLoginButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final Color primaryColor;
  final Color accentColor;

  const _AnimatedLoginButton({
    required this.isLoading,
    required this.onPressed,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  State<_AnimatedLoginButton> createState() => _AnimatedLoginButtonState();
}

class _AnimatedLoginButtonState extends State<_AnimatedLoginButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  // Same teal used for the glow treatment on the other icon badges
  // throughout this screen - defined locally since this is a separate
  // widget class from _LoginScreenState and can't reach that class's
  // own instance field.
  static const Color _tealGlow = Color(0xFF7EE8CB);
  static const Color _warmAmber = AppPalette.accent;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setHovered(bool hovered) {
    if (hovered) {
      _controller.forward(from: 0);
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.isLoading && widget.onPressed != null;
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? widget.onPressed : null,
        child: Semantics(
          button: true,
          enabled: enabled,
          label: 'Login',
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                return Opacity(
                  opacity: enabled ? 1 : 0.6,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Stack(
                      children: [
                        // Base gradient - reverses direction as hover
                        // progresses, rather than a solid amber overlay.
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color.lerp(widget.primaryColor, widget.accentColor, t)!,
                                  Color.lerp(widget.accentColor, widget.primaryColor, t)!,
                                ],
                              ),
                            ),
                          ),
                        ),
                        // A soft light band sweeping left to right once as
                        // t goes 0->1 - purely decorative, so it's wrapped
                        // in IgnorePointer to never intercept the tap.
                        if (t > 0)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Align(
                                alignment: Alignment(-1.6 + t * 3.2, 0),
                                child: Container(
                                  width: 60,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0),
                                        Colors.white.withValues(alpha: 0.35 * t),
                                        Colors.white.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: widget.isLoading
                              ? const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  ),
                                )
                              : Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Center(
                                      child: Text('Login',
                                          style: TextStyle(
                                              color: Color.lerp(Colors.white, _warmAmber, t),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15)),
                                    ),
                                    // Slides from the left edge toward
                                    // center as t goes 0->1 - the uncircled
                                    // arrow at the right stays fixed.
                                    Align(
                                      alignment: Alignment(-1 + t * 1.3, 0),
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.22),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: _tealGlow.withValues(alpha: 0.55), width: 1.2),
                                          boxShadow: [
                                            BoxShadow(color: _tealGlow.withValues(alpha: 0.3), blurRadius: 8),
                                          ],
                                        ),
                                        child: Icon(Icons.arrow_forward, color: Color.lerp(Colors.white, _warmAmber, t), size: 16),
                                      ),
                                    ),
                                    const Align(
                                      alignment: Alignment.centerRight,
                                      child: Padding(
                                        padding: EdgeInsets.only(right: 4),
                                        child: Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== NEW BADGE ====================
class _NewBadge extends StatefulWidget {
  const _NewBadge();

  @override
  State<_NewBadge> createState() => _NewBadgeState();
}

class _NewBadgeState extends State<_NewBadge> {
  bool visible = true;
  int blinkCount = 0;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    // Blink twice like car indicator, then fade out
    _blinkTimer =
        Timer.periodic(const Duration(milliseconds: 600), (timer) {
      setState(() => visible = !visible);
      blinkCount++;
      if (blinkCount >= 4) {
        timer.cancel();
        setState(() => visible = true);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => visible = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 400),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'NEW',
          style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ==================== FOOTER LINK (Privacy Policy / Terms) ====================
// A dedicated widget rather than a plain method - each of the four
// instances of this (two links, two responsive layouts) needs its own
// independent hover state, which a method returning a Widget has no
// way to hold across separate calls.
class _FooterLink extends StatefulWidget {
  final String label;
  final Widget destination;
  const _FooterLink({required this.label, required this.destination});

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  static const Color _warmAmber = AppPalette.accent;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => widget.destination)),
        child: Text(widget.label,
            style: TextStyle(
              color: _hovered ? _warmAmber : Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              decoration: TextDecoration.underline,
              decorationColor: _hovered ? _warmAmber : Colors.white.withValues(alpha: 0.4),
            )),
      ),
    );
  }
}
