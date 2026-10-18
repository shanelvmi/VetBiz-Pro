import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_dimens.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../widgets/announcement_message.dart';
import '../utils/navigator_key.dart';
import 'legal/privacy_policy_screen.dart';
import 'legal/terms_of_service_screen.dart';
import '../data/collections.dart';
import '../config/app_timeouts.dart';
import '../config/app_info.dart';
import '../l10n/l10n.dart';
import '../ui/feedback/auth_error_messages.dart';
import '../ui/feedback/app_feedback.dart';
import '../ui/feedback/friendly_error.dart';
import '../theme/app_breakpoints.dart';
import '../theme/app_motion.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';

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

  // The announcement carousel's page slide (was 600 ms), snapped to the
  // nearest motion step (parked_values.md C4).
  static const Duration _announcementSlide = AppMotion.slowest;
  // Alert timings, snapped to the nearest token (parked_values.md C5-C7):
  // the countdown restart after the pointer leaves the alert (3 s, same
  // value), the form card's shake (was 420 ms), and the alert's
  // fade-and-slide in (was 260 ms; a tie between normal and slow, so up).
  static const Duration _alertHoverGrace = AppMotion.toastLong;
  static const Duration _shakeDuration = AppMotion.slower;
  static const Duration _alertSwitch = AppMotion.slow;

  OutlineInputBorder _fieldBorder(Color color) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.r16), borderSide: BorderSide(color: color));

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

    // Only checks that both fields were filled. No length check here:
    // Firebase's own password-reset page accepts 6-character passwords and
    // older accounts may have shorter ones, so a minimum at login could stop
    // someone from even trying to sign in (docs/FIXES.md, item 1).
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      setState(() {
        error = L10n.current.login_credentialsTooShort;
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
      Future.delayed(AppTimeouts.loginSafetyNet, () {
        if (mounted && isLoggingIn) {
          debugPrint('[LOGIN] Still mounted 6s after a successful sign-in - resetting loading state');
          // Never silently: this screen should have been replaced long ago.
          // Say so, instead of just handing the person back an idle form.
          setState(() {
            isLoggingIn = false;
            error = L10n.current.login_slowSignIn;
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
        error = FriendlyError.messageFor(e);
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
  // handled (those fall through to Firebase's own message). The mapping
  // itself is shared with FriendlyError: ui/feedback/auth_error_messages.dart.
  String _friendlyAuthError(FirebaseAuthException e) => authErrorMessage(e);

  Future<void> _forgotPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        error = L10n.current.login_resetNeedsEmail;
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
    final vagueMessage = L10n.current.login_resetSent;
    try {
      await _authService.sendPasswordReset(email);
      AppFeedback.info(vagueMessage);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        AppFeedback.info(vagueMessage);
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
        error = L10n.current.login_resetFailed(FriendlyError.messageFor(e));
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.colors.primary, context.colors.brandTeal],
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
          final isNarrow = constraints.maxWidth < AppBreakpoints.loginHeaderNarrow;

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
                        decoration: BoxDecoration(color: context.colors.surface, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(AppInfo.logoMark, style: TextStyle(color: context.colors.primary, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16)),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(context.l10n.common_appSystem(AppInfo.name),
                                style: TextStyle(color: context.colors.onPrimary, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16)),
                            if (!isNarrow)
                              Text(context.l10n.login_tagline,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: context.colors.onPrimary.withValues(alpha: AppAlpha.a70), fontSize: AppFontSize.f11_5)),
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
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s6),
                        decoration: BoxDecoration(
                          color: context.colors.surface.withValues(alpha: AppAlpha.a15),
                          borderRadius: BorderRadius.circular(AppRadius.r20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: AppSizes.statusDot,
                              height: AppSizes.statusDot,
                              decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: AppSpacing.s6),
                            Text(context.l10n.login_systemOnline,
                                style: TextStyle(color: context.colors.onPrimary, fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold)),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s10),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: context.colors.surface.withValues(alpha: AppAlpha.a15), shape: BoxShape.circle),
                        child: Icon(Icons.wb_sunny_outlined, color: context.colors.onPrimary, size: AppIconSize.i18),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24, vertical: AppSpacing.s12),
      color: context.colors.primary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Enough room for everything on a single line, spanning the
          // full width edge to edge - only falls back to a reflowing
          // layout when there genuinely isn't room for that, on small
          // screens specifically.
          if (constraints.maxWidth >= AppBreakpoints.compact) {
            return Row(
              children: [
                Icon(Icons.shield_outlined, color: context.colors.onPrimary.withValues(alpha: AppAlpha.a70), size: AppIconSize.i16),
                const SizedBox(width: AppSpacing.s8),
                Text(context.l10n.login_copyright(AppInfo.name),
                    style: TextStyle(color: context.colors.onPrimary.withValues(alpha: AppAlpha.a70), fontSize: AppFontSize.f12)),
                const Spacer(),
                Text(AppInfo.versionLabel, style: TextStyle(color: context.colors.onPrimary.withValues(alpha: AppAlpha.a70), fontSize: AppFontSize.f12)),
                const SizedBox(width: AppSpacing.s20),
                _FooterLink(label: context.l10n.common_privacyPolicy, destination: const PrivacyPolicyScreen()),
                const SizedBox(width: AppSpacing.s20),
                _FooterLink(label: context.l10n.common_termsOfService, destination: const TermsOfServiceScreen()),
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
                  Icon(Icons.shield_outlined, color: context.colors.onPrimary.withValues(alpha: AppAlpha.a70), size: AppIconSize.i16),
                  const SizedBox(width: AppSpacing.s8),
                  Text(context.l10n.login_copyright(AppInfo.name),
                      style: TextStyle(color: context.colors.onPrimary.withValues(alpha: AppAlpha.a70), fontSize: AppFontSize.f12)),
                ],
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 20,
                runSpacing: 4,
                children: [
                  Text(AppInfo.versionLabel, style: TextStyle(color: context.colors.onPrimary.withValues(alpha: AppAlpha.a70), fontSize: AppFontSize.f12)),
                  _FooterLink(label: context.l10n.common_privacyPolicy, destination: const PrivacyPolicyScreen()),
                  _FooterLink(label: context.l10n.common_termsOfService, destination: const TermsOfServiceScreen()),
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
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.colors.primary, context.colors.brandTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.r16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.brandTealGlow.withValues(alpha: AppAlpha.a15),
              borderRadius: BorderRadius.circular(AppRadius.r12),
              border: Border.all(color: context.colors.brandTealGlow.withValues(alpha: AppAlpha.a50), width: 1.2),
              boxShadow: [
                BoxShadow(color: context.colors.brandTealGlow.withValues(alpha: AppAlpha.a30), blurRadius: 8),
              ],
            ),
            child: Icon(Icons.chat_bubble_outline, color: context.colors.onPrimary, size: AppIconSize.i20),
          ),
          const SizedBox(width: AppSpacing.s14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.login_welcomeTo, style: TextStyle(color: context.colors.onPrimary.withValues(alpha: AppAlpha.a85), fontSize: AppFontSize.f13)),
                Text(AppInfo.name,
                    style: TextStyle(color: context.colors.brandTealGlow, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f19)),
                const SizedBox(height: AppSpacing.s8),
                Text(context.l10n.login_stayUpdated,
                    style: TextStyle(color: context.colors.onPrimary.withValues(alpha: AppAlpha.a85), fontSize: AppFontSize.f12_5)),
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
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        boxShadow: [BoxShadow(color: context.colors.shadow.withValues(alpha: AppAlpha.a10), blurRadius: 8, offset: const Offset(0, 4))],
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
                        Icon(Icons.campaign_outlined, color: context.colors.textPrimary, size: AppIconSize.i18),
                        const SizedBox(width: AppSpacing.s8),
                        Flexible(
                          child: Text(context.l10n.login_announcements,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: AppFontWeight.bold, color: context.colors.textPrimary, fontSize: AppFontSize.f15)),
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
                    child: Icon(Icons.chevron_right, color: context.colors.textDisabled, size: AppIconSize.i18),
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
          .collection(Collections.publicAnnouncements)
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
        _announcementTimer = Timer.periodic(AppTimeouts.loginAnnouncementRotate, (_) {
          if (!controller.hasClients || docs.isEmpty) return;
          currentIndex = (currentIndex + 1) % docs.length;
          controller.animateToPage(currentIndex,
              duration: _announcementSlide,
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
                    final title = data['title'] ?? context.l10n.login_announcementFallbackTitle;
                    final ts = data['timestamp'] as Timestamp?;
                    final bool isNew = ts != null &&
                        DateTime.now().difference(ts.toDate()).inHours < 48;
                    final bool isUrgent = data['urgent'] == true;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      decoration: BoxDecoration(
                        color: context.colors.background,
                        borderRadius: BorderRadius.circular(AppRadius.r16),
                        border: Border.all(color: isUrgent ? context.colors.danger.withValues(alpha: AppAlpha.a40) : context.colors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isUrgent)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.s6),
                              child: Chip(
                                label: Text(context.l10n.login_urgent, style: TextStyle(fontSize: AppFontSize.f10, color: context.colors.onPrimary)),
                                backgroundColor: context.colors.danger,
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
                                        fontSize: AppFontSize.f18,
                                        fontWeight: AppFontWeight.bold,
                                        color: context.colors.primary)),
                              ),
                              if (isNew) const _NewBadge(),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s8),
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
              const SizedBox(height: AppSpacing.s8),
              // Dot indicators
              SmoothPageIndicator(
                controller: controller,
                count: docs.length,
                effect: ExpandingDotsEffect(
                  dotHeight: 6,
                  dotWidth: 6,
                  activeDotColor: context.colors.primary,
                  dotColor: context.colors.textDisabled,
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
            Icon(Icons.inbox_outlined, size: AppIconSize.i48, color: context.colors.border),
            const SizedBox(height: AppSpacing.s10),
            Text(context.l10n.login_noAnnouncements, style: TextStyle(fontWeight: AppFontWeight.bold, color: context.colors.textPrimary, fontSize: AppFontSize.f14)),
            const SizedBox(height: AppSpacing.s4),
            Text(context.l10n.login_allCaughtUp, style: TextStyle(color: context.colors.textHint, fontSize: AppFontSize.f12_5)),
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
            color: context.colors.brandTealGlow.withValues(alpha: AppAlpha.a10),
            shape: BoxShape.circle,
            border: Border.all(color: context.colors.brandTealGlow.withValues(alpha: AppAlpha.a30), width: 1),
            boxShadow: [
              BoxShadow(color: context.colors.brandTealGlow.withValues(alpha: AppAlpha.a15), blurRadius: 5),
            ],
          ),
          child: Icon(Icons.verified_user_outlined, color: context.colors.primary, size: AppIconSize.i18),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.login_trustTitle,
                  style: TextStyle(fontWeight: AppFontWeight.bold, color: context.colors.textPrimary, fontSize: AppFontSize.f13)),
              const SizedBox(height: AppSpacing.s2),
              Text(context.l10n.login_trustBody,
                  style: TextStyle(color: context.colors.textMuted, fontSize: AppFontSize.f12)),
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
    final restColor = hasError ? context.colors.dangerAccent.withValues(alpha: AppAlpha.a70) : context.colors.border;
    final focusColor = hasError ? context.colors.dangerAccent : context.colors.primary;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: context.colors.textDisabled),
      prefixIcon: Icon(icon, size: AppIconSize.i20, color: hasError ? context.colors.dangerAccent : context.colors.textHint),
      suffixIcon: suffix,
      filled: true,
      fillColor: context.colors.surfaceMuted,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s16),
      border: _fieldBorder(restColor),
      enabledBorder: _fieldBorder(restColor),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.r16),
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
      onExit: (_) => _startErrorTimer(after: _alertHoverGrace),
      child: Semantics(
        liveRegion: true,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s10, AppSpacing.s6, AppSpacing.s10),
            decoration: BoxDecoration(
              color: context.colors.dangerSurface,
              borderRadius: BorderRadius.circular(AppRadius.r12),
              border: Border.all(color: context.colors.dangerAccent.withValues(alpha: AppAlpha.a40)),
              boxShadow: [
                BoxShadow(color: context.colors.dangerAccent.withValues(alpha: AppAlpha.a20), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: AppSpacing.s2),
                  child: Icon(Icons.error_outline, color: context.colors.dangerAccent, size: AppIconSize.i18),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  // A very long message scrolls inside the alert rather than
                  // growing it over the whole form.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 96),
                    child: SingleChildScrollView(
                      child: Text(
                        error!,
                        style: TextStyle(color: context.colors.dangerDeep, fontSize: AppFontSize.f12_5, height: 1.35),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: AppIconSize.i16),
                  color: context.colors.dangerAccent,
                  tooltip: context.l10n.common_dismiss,
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
      duration: _shakeDuration,
      builder: (context, value, child) {
        final progress = value - value.floorToDouble();
        final dx = math.sin(progress * math.pi * 6) * 8 * (1 - progress);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.r20),
          border: Border.all(color: context.colors.border),
          // Two layers: a wide, teal-tinted one that lifts the card off the
          // panel behind it, and a tight one for a crisp edge.
          boxShadow: [
            BoxShadow(color: context.colors.primary.withValues(alpha: AppAlpha.a15), blurRadius: 32, offset: const Offset(0, 14)),
            BoxShadow(color: context.colors.shadow.withValues(alpha: AppAlpha.a05), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.r20),
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
                      gradient: LinearGradient(colors: [context.colors.primary, context.colors.brandTeal, context.colors.brandTealGlow]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.s28, AppSpacing.s28, AppSpacing.s28, AppSpacing.s24),
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
                                color: context.colors.brandTealGlow.withValues(alpha: AppAlpha.a20),
                                shape: BoxShape.circle,
                                border: Border.all(color: context.colors.brandTealGlow.withValues(alpha: AppAlpha.a70), width: 1.4),
                                boxShadow: [
                                  BoxShadow(color: context.colors.brandTealGlow.withValues(alpha: AppAlpha.a50), blurRadius: 14),
                                ],
                              ),
                              child: Icon(Icons.lock_outline, color: context.colors.primary, size: AppIconSize.i20),
                            ),
                            const SizedBox(width: AppSpacing.s14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(context.l10n.login_welcomeBack,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: AppFontSize.f20, fontWeight: AppFontWeight.extraBold, color: context.colors.textPrimary)),
                                  const SizedBox(height: AppSpacing.s2),
                                  Text(context.l10n.login_logIntoFacility,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textMuted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s28),
                        Text(context.l10n.common_email, style: TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold, color: context.colors.textPrimary)),
                        const SizedBox(height: AppSpacing.s6),
                        TextField(
                          controller: emailController,
                          style: TextStyle(color: context.colors.textPrimary),
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _onCredentialsEdited(),
                          onSubmitted: (_) => passwordFocusNode.requestFocus(),
                          decoration: _loginInputDecoration(
                            hint: context.l10n.login_emailHint,
                            icon: Icons.mail_outline,
                            hasError: fieldsInError,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s18),
                        Text(context.l10n.common_password, style: TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold, color: context.colors.textPrimary)),
                        const SizedBox(height: AppSpacing.s6),
                        TextField(
                          controller: passwordController,
                          focusNode: passwordFocusNode,
                          obscureText: obscurePassword,
                          style: TextStyle(color: context.colors.textPrimary),
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => _onCredentialsEdited(),
                          onSubmitted: (_) => _login(),
                          decoration: _loginInputDecoration(
                            hint: context.l10n.login_passwordHint,
                            icon: Icons.lock_outline,
                            hasError: fieldsInError,
                            suffix: GestureDetector(
                              onTap: () => setState(() => obscurePassword = !obscurePassword),
                              child: Icon(
                                obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: context.colors.textHint,
                                size: AppIconSize.i20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: rememberMe,
                                onChanged: (value) => setState(() => rememberMe = value ?? false),
                                activeColor: context.colors.primary,
                                checkColor: context.colors.onPrimary,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Text(context.l10n.login_rememberMe, style: TextStyle(color: context.colors.textPrimary, fontSize: AppFontSize.f13)),
                            const Spacer(),
                            MouseRegion(
                              onEnter: (_) => setState(() => isForgotHovered = true),
                              onExit: (_) => setState(() => isForgotHovered = false),
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: _forgotPassword,
                                child: Text(
                                  context.l10n.login_forgotPassword,
                                  style: TextStyle(
                                    color: isForgotHovered ? context.colors.accent : context.colors.brandTeal,
                                    fontSize: AppFontSize.f13,
                                    fontWeight: AppFontWeight.semibold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s20),
                        _AnimatedLoginButton(
                          isLoading: isLoggingIn,
                          onPressed: isLoggingIn ? null : _login,
                          primaryColor: context.colors.primary,
                          accentColor: context.colors.brandTeal,
                        ),
                        const SizedBox(height: AppSpacing.s20),
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
                                  style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textPrimary),
                                  children: [
                                    TextSpan(text: context.l10n.login_noAccount),
                                    TextSpan(
                                      text: context.l10n.login_register,
                                      style: TextStyle(
                                        color: isRegisterHovered ? context.colors.accent : context.colors.brandTeal,
                                        fontWeight: AppFontWeight.bold,
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
                  duration: _alertSwitch,
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
              stream: FirebaseFirestore.instance.collection(Collections.appConfig).doc('login_poster').snapshots(),
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
          Positioned.fill(child: Container(color: context.colors.scrim.withValues(alpha: AppAlpha.a20))),

          // The single floating card holding every piece of content -
          // header, welcome/announcements, login form, and footer all
          // live inside this one unified surface on every screen size,
          // reflowing between two columns and a single stacked column
          // rather than switching to a stripped-down alternate layout.
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // The actual space available to the card, after the
                  // 24px padding on each side above - not the raw
                  // screen width, which doesn't account for that and
                  // was the real cause of the two-column layout
                  // overflowing at widths just above the old cutoff.
                  final isWide = constraints.maxWidth > AppBreakpoints.twoPane;
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
                        color: context.colors.surface.withValues(alpha: 0.97),
                        borderRadius: BorderRadius.circular(AppRadius.r24),
                        boxShadow: [
                          BoxShadow(color: context.colors.shadow.withValues(alpha: AppAlpha.a40), blurRadius: 40, offset: const Offset(0, 20)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.s28),
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
                                              const SizedBox(height: AppSpacing.s16),
                                              Expanded(child: _buildAnnouncementsCard()),
                                              const SizedBox(height: AppSpacing.s16),
                                              _buildTrustFooter(),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.s28),
                                        // Right: Login
                                        Expanded(
                                          flex: 1,
                                          // A softly tinted panel behind the form
                                          // card: the card is white with a deep
                                          // shadow, so it lifts off this instead
                                          // of blending into the white surface
                                          // around it.
                                          child: Container(
                                            padding: const EdgeInsets.all(AppSpacing.s24),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [context.colors.divider, context.colors.surfaceMuted],
                                              ),
                                              borderRadius: BorderRadius.circular(AppRadius.r24),
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
                                      const SizedBox(height: AppSpacing.s20),
                                      _buildWelcomeCard(),
                                      const SizedBox(height: AppSpacing.s16),
                                      _buildAnnouncementsCard(),
                                      const SizedBox(height: AppSpacing.s16),
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
  // The hover sweep (was 450 ms; a tie between slower and slowest, so up;
  // parked_values.md C8).
  static const Duration _hoverSweep = AppMotion.slowest;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _hoverSweep);
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
          label: context.l10n.login_loginButton,
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
                    borderRadius: BorderRadius.circular(AppRadius.r24),
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
                                        context.colors.onPrimary.withValues(alpha: 0),
                                        context.colors.onPrimary.withValues(alpha: AppAlpha.a40 * t),
                                        context.colors.onPrimary.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
                          child: widget.isLoading
                              ? Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: context.colors.onPrimary),
                                  ),
                                )
                              : Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Center(
                                      child: Text(context.l10n.login_loginButton,
                                          style: TextStyle(
                                              color: Color.lerp(context.colors.onPrimary, context.colors.accent, t),
                                              fontWeight: AppFontWeight.semibold,
                                              fontSize: AppFontSize.f15)),
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
                                          color: context.colors.surface.withValues(alpha: AppAlpha.a20),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: context.colors.brandTealGlow.withValues(alpha: AppAlpha.a50), width: 1.2),
                                          boxShadow: [
                                            BoxShadow(color: context.colors.brandTealGlow.withValues(alpha: AppAlpha.a30), blurRadius: 8),
                                          ],
                                        ),
                                        child: Icon(Icons.arrow_forward, color: Color.lerp(context.colors.onPrimary, context.colors.accent, t), size: AppIconSize.i16),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Padding(
                                        padding: EdgeInsets.only(right: AppSpacing.s4),
                                        child: Icon(Icons.arrow_forward, color: context.colors.onPrimary, size: AppIconSize.i18),
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
  // Blink step (was 600 ms) and how long the badge stays before fading (3 s,
  // same value), snapped to the nearest token (parked_values.md C9, C10).
  static const Duration _blinkStep = AppMotion.slowest;
  static const Duration _blinkHold = AppMotion.toastLong;

  @override
  void initState() {
    super.initState();
    // Blink twice like car indicator, then fade out
    _blinkTimer =
        Timer.periodic(_blinkStep, (timer) {
      setState(() => visible = !visible);
      blinkCount++;
      if (blinkCount >= 4) {
        timer.cancel();
        setState(() => visible = true);
        Future.delayed(_blinkHold, () {
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
      duration: AppMotion.slower,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s2),
        decoration: BoxDecoration(
          color: context.colors.danger,
          borderRadius: BorderRadius.circular(AppRadius.r4),
        ),
        child: Text(
          context.l10n.login_newBadge,
          style: TextStyle(
              color: context.colors.onPrimary,
              fontSize: AppFontSize.f10,
              fontWeight: AppFontWeight.bold),
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
              color: _hovered ? context.colors.accent : context.colors.onPrimary.withValues(alpha: AppAlpha.a70),
              fontSize: AppFontSize.f12,
              decoration: TextDecoration.underline,
              decorationColor: _hovered ? context.colors.accent : context.colors.onPrimary.withValues(alpha: AppAlpha.a40),
            )),
      ),
    );
  }
}
