import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../widgets/announcement_message.dart';

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
  bool isForgotHovered = false;
  bool isRegisterHovered = false;

  Timer? _announcementTimer;

  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color tealAccent = const Color(0xFF3E8E82);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color tealGlow = const Color(0xFF7EE8CB);
  final Color offWhite = const Color(0xFFFDFDF9);
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
        if (mounted) setState(() => error = widget.errorMessage);
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
    super.dispose();
  }

  // ==================== LOGIN LOGIC ====================
  // Deliberately does nothing after a successful sign-in beyond that -
  // no Firestore fetch, no status check, no navigation. The moment
  // sign-in succeeds, Firebase's own auth-state stream fires and
  // AppEntryPoint (in main.dart) reacts to it independently - if this
  // method also tried to navigate here, the two would race: this
  // screen can get torn down and replaced by AppEntryPoint's own
  // rebuild while this method is still mid-flight (fetching Firestore,
  // checking status), and its result gets silently discarded once that
  // happens. That race was the actual cause of login intermittently
  // "doing nothing" after a login/logout cycle - not a Firebase error,
  // two separate pieces of code deciding what screen to show next.
  Future<void> _login() async {
  if (isLoggingIn) return; // guards against a double-tap firing two logins at once
  setState(() {
    error = null;
    isLoggingIn = true;
  });

  if (emailController.text.isEmpty || passwordController.text.length < 6) {
    setState(() {
      error = "Enter valid email and password (min 6 chars).";
      isLoggingIn = false;
    });
    return;
  }

  try {
    // Remember Me only ever stores the email, never the password - just
    // a convenience so it's pre-filled next time, not a session/login
    // bypass of any kind. Done before the sign-in attempt itself so it
    // never depends on anything that could race with AppEntryPoint.
    final prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      await prefs.setString('remembered_email', emailController.text.trim());
    } else {
      await prefs.remove('remembered_email');
    }

    await _authService.login(
      emailController.text.trim(),
      passwordController.text.trim(),
    );

    // No navigation here - see the note above. AppEntryPoint takes it
    // from here the moment this succeeds. isLoggingIn intentionally
    // stays true; this whole widget is about to be torn down anyway.
  } on FirebaseAuthException catch (e) {
    if (!mounted) return;
    setState(() {
      error = _friendlyAuthError(e);
      isLoggingIn = false;
    });
  } catch (e) {
    if (!mounted) return;
    setState(() {
      error = e.toString().replaceAll('Exception:', '').trim();
      isLoggingIn = false;
    });
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
      setState(() => error = "Enter your email first to reset password.");
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
        setState(() => error = _friendlyAuthError(e));
      }
    } catch (e) {
      setState(() => error = "Could not send reset email: $e");
    }
  }

  // ==================== TOP HEADER ====================
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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

          return Row(
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
              const Spacer(),
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
                    const Text('System Online', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
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
                Text('Privacy Policy', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                const SizedBox(width: 20),
                Text('Terms of Service', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
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
                  Text('Privacy Policy', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                  Text('Terms of Service', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
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
          Row(
            children: [
              Icon(Icons.campaign_outlined, color: neutralBlack, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text('Announcements',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, color: neutralBlack, fontSize: 15)),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
            ],
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
  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tealGlow.withValues(alpha: 0.24),
                  shape: BoxShape.circle,
                  border: Border.all(color: tealGlow.withValues(alpha: 0.75), width: 1.4),
                  boxShadow: [
                    BoxShadow(color: tealGlow.withValues(alpha: 0.5), blurRadius: 14),
                  ],
                ),
                child: Icon(Icons.lock_outline, color: primaryDeepGreen, size: 18),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text('Log into your facility',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: neutralBlack)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: neutralBlack)),
          const SizedBox(height: 6),
          TextField(
            controller: emailController,
            style: TextStyle(color: neutralBlack),
            autofocus: true,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => passwordFocusNode.requestFocus(),
            decoration: InputDecoration(
              hintText: 'Enter your email',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: _fieldBorder(Colors.grey.shade300),
              enabledBorder: _fieldBorder(Colors.grey.shade300),
              focusedBorder: _fieldBorder(primaryDeepGreen),
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
            onSubmitted: (_) => _login(),
            decoration: InputDecoration(
              hintText: 'Enter your password',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: _fieldBorder(Colors.grey.shade300),
              enabledBorder: _fieldBorder(Colors.grey.shade300),
              focusedBorder: _fieldBorder(primaryDeepGreen),
              suffixIcon: GestureDetector(
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
          if (error != null)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
                  ),
                ],
              ),
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
                                          child: Center(child: _buildLoginForm()),
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
                                    const Center(
                                      child: Text('Login',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
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
                                        child: const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
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
