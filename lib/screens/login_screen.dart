import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../services/auth_service.dart';
import '../providers/facility_provider.dart';
import '../providers/product_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool rememberMe = false;
  bool obscurePassword = true;
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
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _announcementTimer?.cancel();
    super.dispose();
  }

  // ==================== LOGIN LOGIC ====================
  Future<void> _login() async {
  setState(() => error = null);

  if (emailController.text.isEmpty || passwordController.text.length < 6) {
    setState(() => error = "Enter valid email and password (min 6 chars).");
    return;
  }

  try {
    // Clear previous provider data
    final facilityProvider = Provider.of<FacilityProvider>(context, listen: false);
    Provider.of<ProductProvider>(context, listen: false).clear();
    facilityProvider.clearFacility();

    // Authenticate user
    final userCredential = await _authService.login(
      emailController.text.trim(),
      passwordController.text.trim(),
    );

    final user = userCredential.user;
    if (user == null) throw Exception('User authentication failed');

    // Load user profile from Firestore
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!doc.exists) throw Exception('User profile not found');

    final data = doc.data()!;
    final role = (data['role'] ?? '').toString().toLowerCase();

    if (role == 'assistant') {
      // Ensure account is active
      final status = (data['status'] ?? '').toString().toLowerCase();
      if (status != 'active') {
        throw Exception('Your account is not active yet. Please wait for admin approval.');
      }

      final facilitiesRaw = data['facilities'];
      if (facilitiesRaw == null || facilitiesRaw is! List || facilitiesRaw.isEmpty) {
        throw Exception('Assistant has no facility assigned');
      }

      final facilityMap = facilitiesRaw.first;
      if (facilityMap is! Map || facilityMap['facilityId'] == null) {
        throw Exception('Assistant facility data is invalid');
      }

      final facilityId = facilityMap['facilityId'];
      final facilityName = facilityMap['name'] ?? '';
      final facilityType = facilityMap['type'] ?? '';

      // Await provider to finish async set
      await facilityProvider.setFacility(
        id: facilityId,
        name: facilityName,
        type: facilityType,
      );

      Navigator.pushReplacementNamed(context, '/dashboard', arguments: {
        'role': 'assistant',
        'facilityId': facilityId,
        'facilityName': facilityName,
        'facilityType': facilityType,
      });

    } else if (role == 'admin') {
      final facilitiesRaw = data['facilities'];
      if (facilitiesRaw == null || facilitiesRaw is! List) {
        throw Exception('Admin has no registered facilities');
      }

      final facilities = facilitiesRaw
          .map<Map<String, dynamic>?>((f) {
            if (f is Map && f.containsKey('facilityId')) {
              return {
                'facilityId': f['facilityId'],
                'facilityName': f['name'] ?? '',
                'facilityType': f['type'] ?? '',
              };
            }
            return null;
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      if (facilities.isEmpty) throw Exception('Admin has no valid facility data');

      final facilityProvider = Provider.of<FacilityProvider>(context, listen: false);

      if (facilities.length == 1) {
        final f = facilities.first;

        // Await provider to finish async set
        await facilityProvider.setFacility(
          id: f['facilityId'],
          name: f['facilityName'],
          type: f['facilityType'],
        );

        Navigator.pushReplacementNamed(context, '/dashboard', arguments: {
          'role': 'admin',
          'facilityId': f['facilityId'],
          'facilityName': f['facilityName'],
          'facilityType': f['facilityType'],
        });

      } else {
        // Multiple facilities -> select facility screen
        Navigator.pushReplacementNamed(context, '/selectFacility', arguments: {
          'role': 'admin',
          'facilities': facilities,
        });
      }
    } else {
      throw Exception('Unrecognized user role');
    }
  } catch (e) {
    setState(() => error = e.toString().replaceAll('Exception:', '').trim());
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
    } catch (e) {
      setState(() => error = "Error: ${e.toString()}");
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

        final docs = snapshot.data!.docs;
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
                    final message = data['message'] ?? '';
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
                                    fontSize: 14, color: neutralBlack),
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
                obscureText: obscurePassword,
                style: TextStyle(color: neutralBlack),
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
                  child: Text(
                    obscurePassword ? 'Show' : 'Hide',
                    style: TextStyle(
                        color: neutralBlack,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
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
            onPressed: _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDeepGreen,
              foregroundColor: Colors.white,
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.hovered)
                      ? warmAmber
                      : null),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Login'),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
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

                    // Center: Illustration
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
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Image.asset(
                            'assets/vetbizpro_illustration.png',
                            height: cardHeight * 0.9,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const SizedBox(),
                          ),
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
                child: _buildLoginForm(),
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
