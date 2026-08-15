import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../providers/facility_provider.dart';
import '../providers/product_provider.dart';

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
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);
  final Color neutralBlack = Colors.black87;

  OutlineInputBorder get _neutralBorder =>
      OutlineInputBorder(borderSide: BorderSide(color: neutralBlack));

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
    try {
      await _authService.sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text("Password reset link sent.",
              style: TextStyle(color: Colors.white)),
          backgroundColor: primaryDeepGreen,
        ));
      }
    } on FirebaseAuthException catch (e) {
      setState(() => error = _friendlyAuthError(e));
    } catch (e) {
      setState(() => error = "Could not send reset email: $e");
    }
  }

  // ==================== ANNOUNCEMENTS ====================
  Widget _buildAnnouncementsScrollable() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('public_announcements')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return SizedBox(
            height: 250,
            child: Center(
                child: Text('No announcements',
                    style: TextStyle(color: neutralBlack))),
          );
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
          return SizedBox(
            height: 250,
            child: Center(
                child: Text('No announcements',
                    style: TextStyle(color: neutralBlack))),
          );
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
          height: 250,
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
                    final rawMessage = (data['message'] ?? '').toString();
                    final isBold = data['bold'] == true;
                    final isItalic = data['italic'] == true;
                    final isUppercase = data['uppercase'] == true;
                    final colorValue = data['color'] as int?;
                    final message = isUppercase ? rawMessage.toUpperCase() : rawMessage;
                    final ts = data['timestamp'] as Timestamp?;
                    final bool isNew = ts != null &&
                        DateTime.now().difference(ts.toDate()).inHours < 48;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: offWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                              child: Text(
                                message,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: colorValue != null ? Color(colorValue) : neutralBlack,
                                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                                    fontStyle: isItalic ? FontStyle.italic : FontStyle.normal),
                              ),
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

  // ==================== LOGIN FORM ====================
  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: primaryDeepGreen,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Text(
              "Log into your facility",
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.normal,
                  color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: emailController,
            style: TextStyle(color: neutralBlack),
            autofocus: true,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => passwordFocusNode.requestFocus(),
            decoration: InputDecoration(
              labelText: 'Email',
              labelStyle: TextStyle(color: neutralBlack),
              border: _neutralBorder,
            ),
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.centerRight,
            children: [
              TextField(
                controller: passwordController,
                focusNode: passwordFocusNode,
                obscureText: obscurePassword,
                style: TextStyle(color: neutralBlack),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: neutralBlack),
                  helperText: 'Minimum 6 characters',
                  helperStyle:
                      TextStyle(color: neutralBlack, fontSize: 12),
                  border: _neutralBorder,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () =>
                      setState(() => obscurePassword = !obscurePassword),
                  child: Icon(
                    obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: neutralBlack,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: Text('Remember Me', style: TextStyle(color: neutralBlack)),
            value: rememberMe,
            onChanged: (value) =>
                setState(() => rememberMe = value ?? false),
            activeColor: primaryDeepGreen,
            checkColor: Colors.white,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: MouseRegion(
              onEnter: (_) => setState(() => isForgotHovered = true),
              onExit: (_) => setState(() => isForgotHovered = false),
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _forgotPassword,
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color:
                        isForgotHovered ? warmAmber : primaryDeepGreen,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: isLoggingIn ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDeepGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: primaryDeepGreen.withValues(alpha: 0.6),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.hovered)
                      ? warmAmber
                      : null),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: isLoggingIn
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Login'),
            ),
          ),
          if (error != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          MouseRegion(
            onEnter: (_) => setState(() => isRegisterHovered = true),
            onExit: (_) => setState(() => isRegisterHovered = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/register');
              },
              child: Text(
                'Don\'t have an account? Register',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isRegisterHovered ? warmAmber : primaryDeepGreen,
                  decoration: TextDecoration.underline,
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
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: offWhite,
      appBar: AppBar(
        automaticallyImplyLeading: false, // 🚀 disables back button completely
        title: Column(
          children: [
            Text('VetBiz Pro System',
                style: TextStyle(fontSize: 20, color: offWhite)),
            const SizedBox(height: 2),
            Text('Smart Business & Vet Services Monitor',
                style: TextStyle(fontSize: 12, color: offWhite)),
          ],
        ),
        centerTitle: true,
        backgroundColor: primaryDeepGreen,
      ),
      body: isWide
          ? LayoutBuilder(
              builder: (context, constraints) {
                final cardHeight =
                    constraints.maxHeight - 48; // leave some margin
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Welcome + Announcements
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: cardHeight,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                                color: Colors.grey.shade300, width: 1),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              color: primaryDeepGreen,
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                "Welcome to VetBiz Pro System",
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: offWhite,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 8,
                                        offset: Offset(0, 4)),
                                  ],
                                ),
                                child: _buildAnnouncementsScrollable(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Center: Poster (admin-uploaded, via Platform Admin >
                    // Announcements) - falls back to the default local
                    // illustration if no poster has been set.
                    Expanded(
                      flex: 4,
                      child: Container(
                        height: cardHeight,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                                color: Colors.grey.shade300, width: 1),
                          ),
                        ),
                        child: StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('app_config')
                              .doc('login_poster')
                              .snapshots(),
                          builder: (context, snapshot) {
                            final posterUrl = snapshot.data?.data() != null
                                ? (snapshot.data!.data() as Map<String, dynamic>)['posterUrl'] as String?
                                : null;

                            return Align(
                              alignment: Alignment.topCenter,
                              child: posterUrl != null
                                  ? Image.network(
                                      posterUrl,
                                      height: cardHeight * 0.9,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Image.asset(
                                        'assets/vetbizpro_illustration.png',
                                        height: cardHeight * 0.9,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => const SizedBox(),
                                      ),
                                    )
                                  : Image.asset(
                                      'assets/vetbizpro_illustration.png',
                                      height: cardHeight * 0.9,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const SizedBox(),
                                    ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Right: Login
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: cardHeight,
                        padding: const EdgeInsets.all(16),
                        child: _buildLoginForm(),
                      ),
                    ),
                  ],
                );
              },
            )
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pets, size: 44, color: primaryDeepGreen),
                    const SizedBox(height: 8),
                    Text(
                      'VetBiz Pro',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold, color: primaryDeepGreen),
                    ),
                    const SizedBox(height: 24),
                    _buildLoginForm(),
                  ],
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
