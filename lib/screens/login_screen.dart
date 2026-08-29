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
  Timer? _posterTimer;
  final PageController _posterController = PageController();
  int _posterIndex = 0;

  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color tealAccent = const Color(0xFF3E8E82);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);
  final Color neutralBlack = Colors.black87;

  // Each a plain string - the brand mark, icon trio, and overall card
  // stay identical across every slide; only this tagline alternates,
  // which is what the dot indicators below the card track.
  static const List<String> _taglines = [
    'Better Care.\nStronger Business.\nHealthier Future.',
    'One Platform.\nEvery Facility.\nTotal Control.',
    'Smarter Records.\nFaster Service.\nHappier Clients.',
    'Built for Vets.\nTrusted by Owners.\nReady to Grow.',
  ];

  OutlineInputBorder _fieldBorder(Color color) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: color));

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
    // Alternates the poster card's tagline on a fixed cycle -
    // independent of the announcements carousel below, which runs on
    // its own timer keyed to how many announcements actually exist.
    _posterTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_posterController.hasClients) return;
      _posterIndex = (_posterIndex + 1) % _taglines.length;
      _posterController.animateToPage(
        _posterIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
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
    _posterTimer?.cancel();
    _posterController.dispose();
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryDeepGreen, tealAccent],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('VB.', style: TextStyle(color: primaryDeepGreen, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('VetBiz Pro System',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Smart Business & Vet Services Monitor',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11.5)),
            ],
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
            child: const Icon(Icons.settings_outlined, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  // ==================== BOTTOM FOOTER ====================
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: primaryDeepGreen,
      child: Row(
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
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome to', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                const Text('VetBiz Pro System',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 19)),
                const SizedBox(height: 8),
                Text('Stay updated with the latest news and system announcements.',
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
              Text('Announcements', style: TextStyle(fontWeight: FontWeight.bold, color: neutralBlack, fontSize: 15)),
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
          decoration: BoxDecoration(color: primaryDeepGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
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

  // ==================== MIDDLE: POSTER CAROUSEL ====================
  // Admin-uploaded poster (Platform Admin > Announcements) takes over
  // entirely when set, replacing the alternating tagline slides below
  // with that single static image - same upload mechanism as before,
  // just given priority over the default branded carousel rather than
  // being the only option.
  Widget _buildPosterCarousel() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('app_config').doc('login_poster').snapshots(),
      builder: (context, snapshot) {
        final posterUrl = snapshot.data?.data() != null
            ? (snapshot.data!.data() as Map<String, dynamic>)['posterUrl'] as String?
            : null;

        if (posterUrl != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(
              posterUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => _buildDefaultPosterCarousel(),
            ),
          );
        }
        return _buildDefaultPosterCarousel();
      },
    );
  }

  Widget _buildDefaultPosterCarousel() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryDeepGreen, tealAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // A faint dot-grid decoration in the corners - a small,
          // consistent nod to this brand's other promotional material,
          // rather than an empty gradient with nothing else going on.
          Positioned(top: 20, left: 20, child: _buildDotGrid()),
          Positioned(bottom: 90, right: 20, child: _buildDotGrid()),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _posterController,
                    itemCount: _taglines.length,
                    itemBuilder: (context, index) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          _taglines[index],
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22, height: 1.3),
                        ),
                        const Spacer(),
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('VB.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 30)),
                                    Text('VetBiz Pro', style: TextStyle(color: Colors.white, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
                SmoothPageIndicator(
                  controller: _posterController,
                  count: _taglines.length,
                  effect: WormEffect(
                    dotHeight: 6,
                    dotWidth: 6,
                    activeDotColor: Colors.white,
                    dotColor: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFeatureIcon(Icons.show_chart, 'Monitor', 'Track performance\nin real-time'),
                    _buildFeatureIcon(Icons.assignment_outlined, 'Manage', 'Manage operations\nefficiently'),
                    _buildFeatureIcon(Icons.trending_up, 'Grow', 'Grow your vet\nbusiness'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDotGrid() {
    return SizedBox(
      width: 48,
      height: 36,
      child: GridView.count(
        crossAxisCount: 4,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(
          12,
          (_) => Container(
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureIcon(IconData icon, String label, String caption) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 2),
          Text(caption, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 10.5)),
        ],
      ),
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
                decoration: BoxDecoration(color: primaryDeepGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.lock_outline, color: primaryDeepGreen, size: 18),
              ),
              const SizedBox(width: 12),
              Text('Log into your facility',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: neutralBlack)),
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
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isLoggingIn ? null : _login,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: primaryDeepGreen,
                disabledBackgroundColor: primaryDeepGreen.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ).copyWith(
                overlayColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.hovered) ? warmAmber : null),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primaryDeepGreen, tealAccent]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Container(
                  alignment: Alignment.center,
                  child: isLoggingIn
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_forward, color: Colors.white, size: 14),
                            ),
                            const SizedBox(width: 10),
                            const Text('Login', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                            const SizedBox(width: 10),
                            const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                          ],
                        ),
                ),
              ),
            ),
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
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: offWhite,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: isWide
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left: Welcome + Announcements + Trust footer
                            Expanded(
                              flex: 3,
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
                            const SizedBox(width: 20),

                            // Center: Poster carousel (admin-uploaded, via
                            // Platform Admin > Announcements, or the
                            // default alternating branded slides).
                            Expanded(
                              flex: 4,
                              child: _buildPosterCarousel(),
                            ),
                            const SizedBox(width: 20),

                            // Right: Login
                            Expanded(
                              flex: 3,
                              child: Center(child: _buildLoginForm()),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // A dedicated upload (Platform Admin > Announcements
                          // > "Login Screen Logo"), separate from the
                          // wide-screen poster above - that one's sized and
                          // intended for a much larger space, not a compact
                          // phone-screen logo. Shown alone, no text label
                          // alongside it - a cleaner, more modern mobile
                          // presentation than icon-plus-wordmark.
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('app_config')
                                .doc('login_logo')
                                .snapshots(),
                            builder: (context, snapshot) {
                              // Waiting for the very first snapshot - reserves
                              // the same space rather than flashing the
                              // fallback illustration only to swap it out
                              // moments later once the real logo arrives.
                              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                                return const SizedBox(height: 72);
                              }

                              final logoUrl = snapshot.data?.data() != null
                                  ? (snapshot.data!.data() as Map<String, dynamic>)['logoUrl'] as String?
                                  : null;

                              return AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: KeyedSubtree(
                                  key: ValueKey(logoUrl ?? 'default'),
                                  child: logoUrl != null
                                      ? Image.network(
                                          logoUrl,
                                          height: 72,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) => Icon(Icons.pets, size: 44, color: primaryDeepGreen),
                                        )
                                      : Container(
                                          width: 72,
                                          height: 72,
                                          decoration: BoxDecoration(color: primaryDeepGreen, shape: BoxShape.circle),
                                          alignment: Alignment.center,
                                          child: const Text('VB.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                                        ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          _buildLoginForm(),
                        ],
                      ),
                    ),
                  ),
          ),
          _buildFooter(),
        ],
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
