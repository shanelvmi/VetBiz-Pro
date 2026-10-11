import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/sentence_capitalization_formatter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../services/auth_service.dart';
import '../services/membership_service.dart';
import '../utils/facility_activation.dart';
import '../utils/facility_code_generator.dart';
import '../constants/facility_types.dart';
import '../utils/facility_limit_helper.dart';
import 'facilities/facility_picker_screen.dart';
import 'legal/privacy_policy_screen.dart';
import 'legal/terms_of_service_screen.dart';
import '../widgets/auth_background.dart';
import '../services/role_change_service.dart';
import '../data/collections.dart';
import '../data/fields.dart';
import '../data/user_role.dart';
import '../config/app_timeouts.dart';
import '../config/app_info.dart';
import '../theme/app_text.dart';
import '../theme/app_dimens.dart';
import '../theme/theme_context.dart';
import '../theme/app_breakpoints.dart';
import '../theme/app_motion.dart';
import '../ui/feedback/app_feedback.dart';
import '../ui/feedback/friendly_error.dart';

class RegisterScreen extends StatefulWidget {
  final bool isUpdating;
  final Map<String, dynamic>? userData;
  // True when Edit Profile is shown as a modal over the Dashboard (see
  // showEditProfileScreen) rather than as a full page.
  final bool isModal;

  const RegisterScreen({super.key, this.isUpdating = false, this.userData, this.isModal = false});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();
  // Checking an invite code, and everything else that decides who belongs to
  // which facility, is done by the server - see MembershipService.
  final MembershipService _membershipService = MembershipService();

  // Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController assistantFacilityNameController = TextEditingController();
  final TextEditingController assistantFacilityCodeController = TextEditingController();

  // Live lookup as the invite code is typed - shows the real facility
  // name and type once a valid, unused, unexpired invite is found.
  // Previously this queried the facilities collection directly by its
  // own permanent code - now it validates against the short-lived
  // invite code system instead, so the facility's permanent code can
  // no longer be used to join at all, only these one-time invites can.
  Map<String, dynamic>? _foundFacility;
  bool _isLookingUpFacility = false;
  String? _facilityLookupError;
  Timer? _facilityLookupDebounce;

  void _onFacilityCodeChanged(String value) {
    _facilityLookupDebounce?.cancel();
    final code = value.trim();

    if (code.isEmpty) {
      setState(() {
        _foundFacility = null;
        _facilityLookupError = null;
        _isLookingUpFacility = false;
      });
      return;
    }

    setState(() => _isLookingUpFacility = true);

    _facilityLookupDebounce = Timer(AppTimeouts.facilityLookupDebounce, () async {
      try {
        final check = await _membershipService.checkInviteCode(code);

        if (!mounted) return;

        if (check == null) {
          setState(() {
            _isLookingUpFacility = false;
            _foundFacility = null;
            _facilityLookupError = 'Invalid, expired, or already-used invite code';
          });
          return;
        }

        setState(() {
          _isLookingUpFacility = false;
          // Just the name and type, to show "you're joining X" - the server
          // never reveals the facility's id. The code is kept to redeem it.
          _foundFacility = {
            'name': check.facilityName,
            'type': check.facilityType,
            'code': code,
          };
          _facilityLookupError = null;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLookingUpFacility = false;
          _foundFacility = null;
          _facilityLookupError = 'Could not check this code - try again';
        });
      }
    });
  }
  final TextEditingController facilityNameController = TextEditingController();
  String? _selectedFacilityType;

  // Dropdowns
  final List<String> prefixes = ['Mr.', 'Mrs.', 'Ms.', 'Dr.'];
  String selectedPrefix = 'Mr.';
  String selectedRole = 'Admin';

  // UI
  Uint8List? _imageBytes;
  String? avatarUrl;
  String? error;

  // Facilities
  List<Map<String, dynamic>> facilities = [];

  // Live listener for Edit Profile mode only - a person's facility
  // list can change while this screen is open (an admin assigns them
  // to a new one, or they add one themselves via View Facilities), so
  // the read-only display here shouldn't stay frozen on whatever
  // snapshot was passed in when this screen first opened. Not used
  // during fresh registration - there's no existing account yet to
  // listen to, and the facilities list there is the user's own
  // locally-built list of what they're about to create.
  StreamSubscription<DocumentSnapshot>? _facilitiesSub;

  void _startLiveFacilitiesListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _facilitiesSub = FirebaseFirestore.instance
        .collection(Collections.users)
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      if (data == null || !mounted) return;
      final updatedFacilities = data['facilities'];
      if (updatedFacilities is! List) return;

      setState(() {
        facilities = List<Map<String, dynamic>>.from(updatedFacilities);
        if (selectedRole == 'Assistant' && facilities.isNotEmpty) {
          assistantFacilityNameController.text = facilities.first['name'] ?? '';
          assistantFacilityCodeController.text = facilities.first['code'] ?? '';
        }
      });
    }, onError: (e) {
      debugPrint('RegisterScreen facilities listener error: $e');
    });
  }

  @override
  void dispose() {
    _facilityLookupDebounce?.cancel();
    _facilitiesSub?.cancel();
    _maxFacilitiesSubscription?.cancel();
    _errorTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _maxFacilitiesSubscription = streamMaxFacilitiesPerAdmin().listen((limit) {
      if (mounted) setState(() => _maxFacilities = limit);
    });
    final data = widget.userData;

    if (widget.isUpdating && data != null) {
      // Name & Prefix
      final fullName = data['fullName'] ?? '';
      for (var p in prefixes) {
        if (fullName.startsWith(p)) {
          selectedPrefix = p;
          nameController.text = fullName.substring(p.length).trim();
          break;
        }
      }

      // Email & Phone
      emailController.text = data['email'] ?? '';
      phoneController.text = data['phone'] ?? '';

      // Role
      final roleFromDb = (data[Fields.role] ?? '').toString().toLowerCase();
      selectedRole = roleFromDb == UserRole.admin.key ? 'Admin' : 'Assistant';

      // Avatar
      avatarUrl = data['avatarUrl'];

      // Facilities
      if (data['facilities'] != null && data['facilities'] is List) {
        facilities = List<Map<String, dynamic>>.from(data['facilities']);
        if (selectedRole == 'Assistant' && facilities.isNotEmpty) {
          assistantFacilityNameController.text = facilities.first['name'] ?? '';
          assistantFacilityCodeController.text = facilities.first['code'] ?? '';
        }
      }

      // The above is just the initial value, from whatever snapshot
      // was passed in when this screen opened - this keeps it current
      // for as long as the screen stays open.
      _startLiveFacilitiesListener();
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      _imageBytes = await file.readAsBytes();
      setState(() {});
    }
  }

  Future<String?> uploadImage(String uid) async {
    if (_imageBytes == null) return avatarUrl;
    final ref = FirebaseStorage.instance.ref().child('avatars/$uid.jpg');
    await ref.putData(_imageBytes!);
    return await ref.getDownloadURL();
  }

  bool _isAddingFacility = false;
  int _maxFacilities = kDefaultMaxFacilitiesPerAdmin;
  StreamSubscription<int>? _maxFacilitiesSubscription;

  Future<void> addFacility() async {
    final name = facilityNameController.text.trim();
    final type = _selectedFacilityType;
    if (_isAddingFacility) return;
    // Say what's missing rather than doing nothing - pressing Add with the
    // name or type left empty used to be a silent no-op.
    if (name.isEmpty || type == null) {
      AppFeedback.warning(name.isEmpty ? 'Enter the facility name first' : 'Choose the facility type first');
      return;
    }

    if (facilities.length >= _maxFacilities) {
      AppFeedback.warning("You've reached the limit of $_maxFacilities facilities per account");
      return;
    }

    setState(() => _isAddingFacility = true);
    try {
      final code = await generateUniqueFacilityCode();
      if (!mounted) return;
      setState(() {
        facilities.add({'name': name, 'type': type, 'code': code, Fields.facilityId: ''});
        facilityNameController.clear();
        _selectedFacilityType = null;
      });
    } catch (e, st) {
      // Was uncaught, so any failure here looked like Add just did nothing.
      AppFeedback.error("Couldn't add this facility", error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isAddingFacility = false);
    }
  }

  void removeFacility(int index) => setState(() => facilities.removeAt(index));

  // A small, deliberately short denylist of the most common weak
  // passwords - not a full breach-database check (overkill for this
  // app), just a floor against the most obvious ones.
  static const Set<String> _commonWeakPasswords = {
    'password', 'password1', 'password123', '12345678', '123456789',
    'qwerty123', 'letmein', 'admin123', 'welcome1', '87654321',
  };

  /// Returns null if the password is acceptable, or a short reason why
  /// it isn't. Deliberately moderate for this audience - length plus a
  /// letter and a number, not special-character requirements that tend
  /// to frustrate more than they protect.
  String? _passwordIssue(String password) {
    if (password.length < 8) return 'At least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(password)) return 'Add at least one letter';
    if (!RegExp(r'[0-9]').hasMatch(password)) return 'Add at least one number';
    if (_commonWeakPasswords.contains(password.toLowerCase())) return 'This password is too common - choose another';
    return null;
  }

  Future<void> _submit() async {
  setState(() => error = null);
  final fullName = "$selectedPrefix ${nameController.text.trim()}";
  final email = emailController.text.trim();
  final phone = phoneController.text.trim();
  final password = passwordController.text.trim();
  final confirmPassword = confirmPasswordController.text.trim();

  try {
    // ---------------- Validation ----------------
    if (!widget.isUpdating) {
      final passwordIssue = _passwordIssue(password);
      if (passwordIssue != null) {
        setState(() => error = passwordIssue);
        return;
      }
    }

    if (!widget.isUpdating && password != confirmPassword) {
      setState(() => error = "Passwords do not match");
      return;
    }

    if (selectedRole == 'Admin' && facilities.isEmpty) {
      setState(() => error = "Please add at least one facility");
      return;
    }

    if (selectedRole == 'Assistant' && !widget.isUpdating) {
      if (_foundFacility == null) {
        setState(() => error = "Enter a valid invite code");
        return;
      }
    }

    final user = _authService.getCurrentUser();
    String? uid = user?.uid;

    // ---------------- Updating User ----------------
    if (widget.isUpdating && uid != null) {
      final imageUrl = await uploadImage(uid);

      // Only what a person may change about themselves: their name, phone and
      // photo. Role, status and which facilities they belong to are not theirs
      // to write - they're set by the server (and the security rules refuse
      // them from here) - so they're not sent, which also means this screen
      // can no longer overwrite them with stale data.
      final Map<String, dynamic> updateData = {
        'fullName': fullName,
        'phone': phone,
        'avatarUrl': imageUrl,
      };
      await FirebaseFirestore.instance.collection(Collections.users).doc(uid).update(updateData);
      if (mounted) {
        AppFeedback.success('Profile updated');
        if (widget.isModal) {
          // Opened as a modal over the Dashboard, which follows the user's
          // profile live - closing is all it takes to show the changes.
          Navigator.of(context).pop(true);
        } else {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      }
      return;
    }

    // ---------------- New Admin Registration ----------------
    if (selectedRole == 'Admin') {
      // The server creates the profile and the facilities together - and
      // works out the trial and checks the facility limit itself. The main
      // session is signed in only once all of that exists.
      final List<Map<String, dynamic>> facilitiesWithId = await _authService.registerOwnerAccount(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        facilities: facilities,
      );
      uid = _authService.getCurrentUser()?.uid;

      // The photo is optional and the account is already complete, so a failed
      // upload is noted but never fails the registration.
      if (_imageBytes != null && uid != null) {
        try {
          final imageUrl = await uploadImage(uid);
          await FirebaseFirestore.instance.collection(Collections.users).doc(uid).update({'avatarUrl': imageUrl});
        } catch (e) {
          debugPrint('Could not save the profile photo: $e');
        }
      }

      if (mounted) {
        AppFeedback.success(
          'Account registered',
          detail: "We've sent a verification link to your email. Check your Spam folder if it doesn't appear within a few minutes.",
        );

        if (facilitiesWithId.length == 1) {
          final selected = facilitiesWithId.first;
          await activateFacilityAndGoToDashboard(
            context: context,
            facility: {
              Fields.facilityId: selected[Fields.facilityId],
              'facilityName': selected['name'],
              'facilityType': selected['type'],
            },
            role: UserRole.admin.key,
          );
        } else {
          final facilityList = facilitiesWithId.map((f) {
            return {
              Fields.facilityId: f[Fields.facilityId],
              'facilityName': f['name'],
              'facilityType': f['type']
            };
          }).toList();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => FacilityPickerScreen(facilities: facilityList, role: UserRole.admin.key),
            ),
          );
        }
      }
    } else {
      // ---------------- Assistant Registration ----------------
      // _foundFacility was already verified via the live invite-code
      // lookup as it was typed - no need to re-validate here.
      if (_foundFacility == null) {
        setState(() => error = 'Enter a valid invite code first');
        return;
      }
      final facility = _foundFacility!;

      // The server puts them in the facility the invite was made for, as
      // "pending", and uses the invite up in the same step - so a code
      // genuinely works once. The person chooses none of it.
      await _authService.registerAssistantWithInvite(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        inviteCode: facility['code'] as String,
        avatarBytes: _imageBytes,
      );

      if (mounted) {
        AppFeedback.success(
          'Assistant registered, waiting for admin approval',
          detail: "We've also sent a verification link to your email. Check your Spam folder if it doesn't appear.",
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  } on FirebaseAuthException catch (e) {
    if (e.code == 'email-already-in-use') {
      setState(() {
        _submitAttempted = true;
        _fieldErrors = {..._fieldErrors, 'email': 'This email is already registered'};
        error = 'An account with this email already exists. If you\'re switching '
            'facilities, this email can\'t register a second time - ask your '
            'Platform Admin to add you to the new facility instead.';
      });
    } else if (e.code == 'invalid-email') {
      setState(() {
        _submitAttempted = true;
        _fieldErrors = {..._fieldErrors, 'email': 'Enter a valid email address, like name@example.com'};
        error = 'Enter a valid email address.';
      });
    } else if (e.code == 'weak-password') {
      setState(() {
        _submitAttempted = true;
        _fieldErrors = {..._fieldErrors, 'password': 'Choose a stronger password'};
        error = 'Choose a stronger password.';
      });
    } else {
      // Through FriendlyError: Firebase's own text can be technical.
      setState(() => error = "Couldn't create the account. ${FriendlyError.messageFor(e)}");
    }
  } on FirebaseFunctionsException catch (e) {
    // The server refused or couldn't finish: a bad or used-up invite, the
    // facility limit, a connection problem. Its message is written to be shown.
    final message = MembershipService.errorMessage(e);
    setState(() {
      if (selectedRole == 'Assistant' && e.code == 'failed-precondition') {
        _submitAttempted = true;
        _fieldErrors = {..._fieldErrors, 'invite': message};
        _foundFacility = null;
      }
      error = message;
    });
  } catch (e, stackTrace) {
    debugPrint('🔥 Error: $e\n📌 Stack: $stackTrace');
    // AccountCreatedException's message is written to be shown; anything
    // else is raw exception text.
    setState(() => error = e is AccountCreatedException ? e.message : FriendlyError.messageFor(e));
  }
 }

  // ======================================================================
  // UI - split in two: REGISTRATION (a floating card on the login page's
  // background, welcome panel beside a sectioned two-column form) and EDIT
  // PROFILE (the same sections as a modal, no marketing panel). Everything
  // above this point - lookup, facilities, validation, _submit - is the
  // logic both share, and is unchanged.
  // ======================================================================

  // The login page's two teals (no role; listed in design-open-questions.md, D8).
  static const Color tealAccent = Color(0xFF3E8E82);
  static const Color tealGlow = Color(0xFF7EE8CB);
  // Alert timings with no token, the same as the login page's (D8): the fade-in,
  // and the countdown restart after the pointer leaves the alert.
  static const Duration _alertSwitch = Duration(milliseconds: 260);
  static const Duration _alertHoverGrace = Duration(seconds: 3);
  // Scrolling to the first field in error: 350 ms, between AppMotion.slow and
  // slower. Kept exact (D8).
  static const Duration _scrollToField = Duration(milliseconds: 350);
  // The welcome panel beside the form on wide screens: a size. Kept exact.
  static const double _welcomePanelWidth = 290;

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  Timer? _errorTimer;
  String? _errorTimerFor;

  // _submit has no "already running" guard of its own, so a second tap on
  // Create account while the first was still working could register twice.
  // This wraps it (rather than editing it) and drives the button's spinner.
  Future<void> _submitGuarded() async {
    if (_isSubmitting) return;
    // Every problem flagged on its own field first (an empty form flags all
    // of them); _submit only runs once the form is complete and well-formed.
    if (!_validateForm()) return;
    setState(() => _isSubmitting = true);
    try {
      await _submit();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _goBack() {
    if (widget.isModal) {
      Navigator.of(context).pop();
    } else if (widget.isUpdating) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else if (Navigator.canPop(context)) {
      // Pops back to whatever was underneath (AppEntryPoint, still showing
      // LoginScreen reactively) instead of destroying it - a previous
      // pushAndRemoveUntil(..., (route) => false) removed every route
      // including AppEntryPoint itself, which is why the URL stuck at
      // #/register and a subsequent login had nothing left listening.
      Navigator.pop(context);
    } else {
      // Reached directly (e.g. a bookmarked /register) with nothing to pop.
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _goToLogin() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // ---------------- error alert (auto-dismissing) ----------------
  //
  // `error` is set in a dozen places in _submit and friends, so rather than
  // touch each one, the countdown is (re)started here whenever a NEW message
  // appears. It floats at the top of the screen - not inside the form - so it
  // is visible however far down a long form has been scrolled, and takes no
  // layout space, so showing it never moves anything.

  void _syncErrorTimer() {
    if (error == _errorTimerFor) return;
    _errorTimerFor = error;
    _errorTimer?.cancel();
    final message = error;
    if (message == null) return;
    // Long enough to read: 4s plus ~1s per 20 characters, between 5 and 12.
    final seconds = (4 + message.length ~/ 20).clamp(5, 12).toInt();
    _startErrorCountdown(Duration(seconds: seconds));
  }

  void _startErrorCountdown(Duration after) {
    _errorTimer?.cancel();
    final message = error;
    if (message == null) return;
    _errorTimer = Timer(after, () {
      if (mounted && error == message) setState(() => error = null);
    });
  }

  void _dismissError() {
    _errorTimer?.cancel();
    if (error != null) setState(() => error = null);
  }

  Widget _buildErrorToastLayer() {
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: AnimatedSwitcher(
            duration: _alertSwitch,
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            child: error == null ? const SizedBox.shrink(key: ValueKey('no-error')) : _buildErrorToast(),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorToast() {
    // Hovering pauses the countdown so a long message can be read at leisure
    // on desktop; moving away restarts it with a short grace.
    return MouseRegion(
      // New message -> new key on the OUTERMOST widget (the only one
      // AnimatedSwitcher looks at), so a changed message animates in.
      key: ValueKey(error),
      onEnter: (_) => _errorTimer?.cancel(),
      onExit: (_) => _startErrorCountdown(_alertHoverGrace),
      child: Semantics(
        liveRegion: true,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s14, AppSpacing.s12, AppSpacing.s8, AppSpacing.s12),
            decoration: BoxDecoration(
              color: context.colors.dangerSurface,
              borderRadius: BorderRadius.circular(AppRadius.r14),
              border: Border.all(color: context.colors.dangerAccent.withValues(alpha: AppAlpha.a40)),
              boxShadow: [
                BoxShadow(color: context.colors.dangerAccent.withValues(alpha: AppAlpha.a20), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: AppSpacing.s2),
                  child: Icon(Icons.error_outline, color: context.colors.dangerAccent, size: AppIconSize.i20),
                ),
                const SizedBox(width: AppSpacing.s10),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 110),
                    child: SingleChildScrollView(
                      child: Text(
                        error!,
                        style: TextStyle(color: context.colors.dangerDeep, fontSize: AppFontSize.f13, height: 1.35),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: AppIconSize.i18),
                  color: context.colors.dangerAccent,
                  tooltip: 'Dismiss',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
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

  // ======================================================================
  // BUILD
  // ======================================================================

  @override
  Widget build(BuildContext context) {
    _syncErrorTimer();
    return widget.isUpdating ? _buildEditView() : _buildRegisterView();
  }

  // ---------------- REGISTRATION ----------------

  Widget _buildRegisterView() {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AuthBackground()),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // The space actually available to the card, after the 24px
                  // padding either side - same approach as the login page.
                  final isWide = constraints.maxWidth > AppBreakpoints.medium;
                  final targetWidth = isWide ? 1100.0 : 560.0;
                  final cardWidth = constraints.maxWidth < targetWidth ? constraints.maxWidth : targetWidth;

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
                          _buildRegisterHeader(),
                          Padding(
                            padding: EdgeInsets.all(isWide ? AppSpacing.s28 : AppSpacing.s18),
                            child: isWide
                                ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(width: _welcomePanelWidth, child: _buildWelcomePanel()),
                                      const SizedBox(width: AppSpacing.s24),
                                      Expanded(child: _buildRegisterForm(twoColumns: true)),
                                    ],
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildWelcomeStrip(),
                                      const SizedBox(height: AppSpacing.s16),
                                      _buildRegisterForm(twoColumns: false),
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
          _buildErrorToastLayer(),
        ],
      ),
    );
  }

  Widget _buildRegisterHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.colors.primary, tealAccent],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: context.colors.surface, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('VB.', style: TextStyle(color: context.colors.primary, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16)),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(
              '${AppInfo.name} System',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.colors.onPrimary, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16),
            ),
          ),
          TextButton.icon(
            onPressed: _goToLogin,
            icon: Icon(Icons.login, size: AppIconSize.i18, color: context.colors.onPrimary),
            label: Text('Log in', style: TextStyle(color: context.colors.onPrimary, fontWeight: AppFontWeight.semibold)),
            style: TextButton.styleFrom(
              backgroundColor: context.colors.surface.withValues(alpha: AppAlpha.a15),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r20)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomePanel() {
    Widget benefit(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: tealGlow, size: AppIconSize.i20),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Text(text, style: TextStyle(color: context.colors.onPrimary, fontSize: AppFontSize.f13_5, height: 1.4)),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.colors.primary, tealAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.r20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: tealGlow.withValues(alpha: AppAlpha.a20),
              shape: BoxShape.circle,
              border: Border.all(color: tealGlow.withValues(alpha: AppAlpha.a70), width: 1.4),
            ),
            child: Icon(Icons.rocket_launch_outlined, color: context.colors.onPrimary, size: AppIconSize.i22),
          ),
          const SizedBox(height: AppSpacing.s18),
          Text(
            'Create your account',
            style: TextStyle(color: context.colors.onPrimary, fontSize: AppFontSize.f24, fontWeight: AppFontWeight.extraBold, height: 1.15),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            'Set up ${AppInfo.name} for your agrovet or veterinary centre in a few minutes.',
            style: TextStyle(color: context.colors.onPrimary.withValues(alpha: AppAlpha.a85), fontSize: AppFontSize.f13_5, height: 1.45),
          ),
          const SizedBox(height: AppSpacing.s24),
          benefit(Icons.check_circle_outline, 'Sales, stock, clients and debts in one place'),
          benefit(Icons.check_circle_outline, 'Invite your team with secure, one-time codes'),
          benefit(Icons.check_circle_outline, 'Every new facility starts with a trial period'),
          const SizedBox(height: AppSpacing.s6),
          Divider(color: context.colors.onPrimary.withValues(alpha: AppAlpha.a30)),
          const SizedBox(height: AppSpacing.s10),
          Text('Already have an account?', style: TextStyle(color: context.colors.onPrimary.withValues(alpha: AppAlpha.a85), fontSize: AppFontSize.f13)),
          const SizedBox(height: AppSpacing.s8),
          OutlinedButton(
            onPressed: _goToLogin,
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.onPrimary,
              side: BorderSide(color: context.colors.onPrimary.withValues(alpha: 0.6)),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s22, vertical: AppSpacing.s12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r12)),
            ),
            child: const Text('Log in', style: TextStyle(fontWeight: AppFontWeight.semibold)),
          ),
        ],
      ),
    );
  }

  // A compact version of the welcome panel for narrow screens.
  Widget _buildWelcomeStrip() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.colors.primary, tealAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.r16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tealGlow.withValues(alpha: AppAlpha.a20),
              shape: BoxShape.circle,
              border: Border.all(color: tealGlow.withValues(alpha: AppAlpha.a70), width: 1.2),
            ),
            child: Icon(Icons.rocket_launch_outlined, color: context.colors.onPrimary, size: AppIconSize.i20),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create your account',
                  style: TextStyle(color: context.colors.onPrimary, fontSize: AppFontSize.f17, fontWeight: AppFontWeight.extraBold),
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  'Set up your agrovet or veterinary centre in a few minutes.',
                  style: TextStyle(color: context.colors.onPrimary.withValues(alpha: AppAlpha.a85), fontSize: AppFontSize.f12_5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm({required bool twoColumns}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (twoColumns)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPersonalSection(),
                    const SizedBox(height: AppSpacing.s16),
                    _buildSecuritySection(),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildRoleSection(),
                    const SizedBox(height: AppSpacing.s16),
                    _buildFacilitySection(),
                  ],
                ),
              ),
            ],
          )
        else ...[
          _buildPersonalSection(),
          const SizedBox(height: AppSpacing.s16),
          _buildRoleSection(),
          const SizedBox(height: AppSpacing.s16),
          _buildFacilitySection(),
          const SizedBox(height: AppSpacing.s16),
          _buildSecuritySection(),
        ],
        const SizedBox(height: AppSpacing.s20),
        _buildTermsLine(),
        const SizedBox(height: AppSpacing.s14),
        _buildSubmitButton('Create account'),
      ],
    );
  }

  // "By creating an account you agree to our Terms of Service and Privacy
  // Policy." - the two names are real links to the same screens the login
  // page's footer opens.
  Widget _buildTermsLine() {
    final base = TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textSoft);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('By creating an account you agree to our ', style: base),
        const _LegalLink(label: 'Terms of Service', destination: TermsOfServiceScreen()),
        Text(' and ', style: base),
        const _LegalLink(label: 'Privacy Policy', destination: PrivacyPolicyScreen()),
        Text('.', style: base),
      ],
    );
  }

  // ---------------- EDIT PROFILE ----------------

  Widget _buildEditView() {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          color: context.colors.primary,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Icon(Icons.manage_accounts_outlined, color: context.colors.onPrimary, size: AppIconSize.i22),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text('Edit Profile',
                      style: TextStyle(color: context.colors.onPrimary, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f18)),
                ),
                if (widget.isModal)
                  IconButton(
                    icon: Icon(Icons.close, color: context.colors.onPrimary),
                    tooltip: 'Close',
                    onPressed: _goBack,
                  )
                else
                  BackButton(color: context.colors.onPrimary, onPressed: _goBack),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= AppBreakpoints.registerTwoColumn;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    child: twoColumns
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildPersonalSection()),
                              const SizedBox(width: AppSpacing.s16),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildRoleSection(),
                                    const SizedBox(height: AppSpacing.s16),
                                    _buildFacilitySection(),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildPersonalSection(),
                              const SizedBox(height: AppSpacing.s16),
                              _buildRoleSection(),
                              const SizedBox(height: AppSpacing.s16),
                              _buildFacilitySection(),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
          _buildErrorToastLayer(),
        ],
      ),
      // Full-width footer pinned to the bottom, same as Add Sale and Add
      // Product: Cancel at the far left, the primary action at the far right.
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s14, AppSpacing.s20, AppSpacing.s14 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a15))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.close, size: AppIconSize.i16),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.textPrimary,
                side: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a40)),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20, vertical: AppSpacing.s14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r12)),
              ),
              onPressed: _isSubmitting ? null : _goBack,
            ),
            _buildSubmitButton('Save changes', fullWidth: false),
          ],
        ),
      ),
    );
  }

  // ======================================================================
  // FIELD VALIDATION
  // ======================================================================
  //
  // Run when Register / Save is pressed, BEFORE _submit - so every problem is
  // shown at once, on its own field, in plain words. Pressing Register on an
  // empty form flags every required field. _submit still does its own checks
  // as a backstop, but it can only report one problem at a time, in the toast.

  final Map<String, GlobalKey> _fieldKeys = {
    for (final k in ['name', 'email', 'phone', 'invite', 'facility', 'password', 'confirm']) k: GlobalKey(),
  };
  Map<String, String> _fieldErrors = {};
  bool _submitAttempted = false;

  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final RegExp _phoneChars = RegExp(r'^[0-9+\-\s().]+$');

  // Top-to-bottom reading order: the toast lists them in this order and the
  // screen scrolls to the first one.
  static const List<String> _fieldOrder = ['name', 'email', 'phone', 'invite', 'facility', 'password', 'confirm'];
  static const Map<String, String> _fieldLabels = {
    'name': 'Full name',
    'email': 'Email',
    'phone': 'Phone number',
    'invite': 'Invite code',
    'facility': 'Facility',
    'password': 'Password',
    'confirm': 'Confirm password',
  };

  // Tanzanian numbers (0712 345 678, +255 712 345 678) and international ones
  // alike: digits with the usual separators, 9 to 15 digits in all.
  bool _isPlausiblePhone(String phone) {
    if (!_phoneChars.hasMatch(phone)) return false;
    final digits = phone.replaceAll(RegExp(r'\D'), '').length;
    return digits >= 9 && digits <= 15;
  }

  /// Every problem with the form as it stands, keyed by field - empty when
  /// it's good to go. Only checks what's on screen: Edit Profile has no
  /// editable email, role or password.
  Map<String, String> _validateAll() {
    final errors = <String, String>{};

    final name = nameController.text.trim();
    if (name.isEmpty) {
      errors['name'] = 'Enter your full name';
    } else if (name.length < 2) {
      errors['name'] = 'Your name looks too short - enter your full name';
    }

    if (!widget.isUpdating) {
      final email = emailController.text.trim();
      if (email.isEmpty) {
        errors['email'] = 'Enter your email address';
      } else if (!_emailPattern.hasMatch(email)) {
        errors['email'] = 'Enter a valid email address, like name@example.com';
      }
    }

    final phone = phoneController.text.trim();
    if (phone.isEmpty) {
      errors['phone'] = 'Enter your phone number';
    } else if (!_isPlausiblePhone(phone)) {
      errors['phone'] = 'Enter a valid phone number, like 0712 345 678';
    }

    if (!widget.isUpdating) {
      if (selectedRole == 'Admin') {
        if (facilities.isEmpty) {
          // The most common slip: filling in the name and type but never
          // pressing Add, so nothing was actually added.
          final pendingName = facilityNameController.text.trim();
          if (pendingName.isNotEmpty && _selectedFacilityType != null) {
            errors['facility'] = 'Press Add to include "$pendingName" before you register';
          } else if (pendingName.isNotEmpty) {
            errors['facility'] = 'Choose the facility type, then press Add';
          } else {
            errors['facility'] = 'Add at least one facility: enter its name, choose its type, then press Add';
          }
        }
      } else {
        final code = assistantFacilityCodeController.text.trim();
        if (code.isEmpty) {
          errors['invite'] = 'Enter your invite code';
        } else if (_isLookingUpFacility) {
          errors['invite'] = 'Still checking your invite code - try again in a moment';
        } else if (_foundFacility == null) {
          errors['invite'] = _facilityLookupError ?? 'Enter a valid invite code';
        }
      }

      final password = passwordController.text.trim();
      if (password.isEmpty) {
        errors['password'] = 'Create a password';
      } else {
        final issue = _passwordIssue(password);
        if (issue != null) errors['password'] = issue;
      }

      final confirm = confirmPasswordController.text.trim();
      if (confirm.isEmpty) {
        errors['confirm'] = 'Re-enter your password to confirm it';
      } else if (confirm != password) {
        errors['confirm'] = 'Passwords do not match';
      }
    }

    return errors;
  }

  // The toast: one problem says what it is (it may be off-screen); several
  // name the fields.
  String _summaryFor(Map<String, String> errors) {
    if (errors.length == 1) return errors.values.first;
    final labels = _fieldOrder.where(errors.containsKey).map((k) => _fieldLabels[k]!).toList();
    final shown = labels.take(3).join(', ');
    final more = labels.length - 3;
    return 'Please fix ${labels.length} fields: $shown${more > 0 ? ' and $more more' : ''}.';
  }

  // Typing after a failed attempt re-checks the form, so a field's error
  // clears the moment it's put right. Before the first attempt nothing is
  // flagged - nobody gets told off for a field they haven't reached yet.
  void _onFieldChanged() {
    setState(() {
      if (_submitAttempted) _fieldErrors = _validateAll();
    });
  }

  /// Returns true if the form can be submitted. Otherwise flags every problem
  /// on its own field, shows the toast, and scrolls to the first one.
  bool _validateForm() {
    final errors = _validateAll();
    setState(() {
      _submitAttempted = true;
      _fieldErrors = errors;
      if (errors.isNotEmpty) error = _summaryFor(errors);
    });
    if (errors.isEmpty) return true;

    // On a long form the first problem may be off-screen.
    final first = _fieldOrder.firstWhere(errors.containsKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _fieldKeys[first]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: _scrollToField,
          curve: Curves.easeOutCubic,
          alignment: 0.2,
        );
      }
    });
    return false;
  }

  // ======================================================================
  // SHARED PIECES
  // ======================================================================

  Widget _fieldLabel(String text, {bool required = false}) => Text.rich(
        TextSpan(
          text: text,
          style: TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold, color: context.colors.textPrimary),
          children: [
            // Required fields wear a red asterisk; the legend ("* Required")
            // sits at the top of the form.
            if (required)
              TextSpan(text: ' *', style: TextStyle(color: context.colors.dangerAccent, fontWeight: AppFontWeight.bold)),
          ],
        ),
      );

  Widget _labeled(String label, Widget field, {bool required = false, GlobalKey? fieldKey}) => Column(
        // The key is what lets a failed Register scroll to this field.
        key: fieldKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _fieldLabel(label, required: required),
          const SizedBox(height: AppSpacing.s6),
          field,
        ],
      );

  InputDecoration _decoration({
    required String hint,
    IconData? icon,
    Widget? suffix,
    String? helper,
    Color? helperColor,
    String? errorText,
    bool locked = false,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.r14),
          borderSide: BorderSide(color: color, width: width),
        );
    final rest = context.colors.border;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: context.colors.textDisabled, fontSize: AppFontSize.f14),
      prefixIcon: icon == null ? null : Icon(icon, size: AppIconSize.i20, color: context.colors.textHint),
      suffixIcon: locked ? Icon(Icons.lock_outline, size: AppIconSize.i16, color: context.colors.textDisabled) : suffix,
      helperText: helper,
      helperStyle: TextStyle(color: helperColor ?? context.colors.textMuted, fontSize: AppFontSize.f12),
      helperMaxLines: 2,
      // Replaces the helper line while there's a problem, and turns the
      // outline red.
      errorText: errorText,
      errorMaxLines: 2,
      errorStyle: TextStyle(color: context.colors.dangerDeep, fontSize: AppFontSize.f12),
      filled: true,
      fillColor: locked ? context.colors.divider : context.colors.surfaceMuted,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s14),
      border: border(rest),
      enabledBorder: border(rest),
      focusedBorder: border(context.colors.primary, 1.6),
      errorBorder: border(context.colors.dangerAccent),
      focusedErrorBorder: border(context.colors.dangerAccent, 1.6),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s18),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: context.colors.divider),
        boxShadow: [
          BoxShadow(color: context.colors.shadow.withValues(alpha: AppAlpha.a05), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: tealGlow.withValues(alpha: AppAlpha.a30), shape: BoxShape.circle),
                child: Icon(icon, color: context.colors.primary, size: AppIconSize.i18),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: AppFontSize.f15, fontWeight: AppFontWeight.bold)),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSubmitButton(String label, {bool fullWidth = true}) {
    final button = ElevatedButton(
      onPressed: _isSubmitting ? null : _submitGuarded,
      style: ElevatedButton.styleFrom(
        foregroundColor: context.colors.background,
        disabledForegroundColor: context.colors.background,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16, horizontal: AppSpacing.s28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r12)),
        elevation: AppElevation.e2,
      ).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) return context.colors.primary.withValues(alpha: AppAlpha.a70);
          if (states.contains(WidgetState.hovered)) return context.colors.accent;
          return context.colors.primary;
        }),
      ),
      child: _isSubmitting
          // A spinner alone looks like nothing is happening, and creating an
          // account takes a few seconds (the account, the email, then the
          // server building the profile).
          ? Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: context.colors.background),
                ),
                const SizedBox(width: AppSpacing.s12),
                Text(
                  widget.isUpdating ? 'Saving...' : 'Creating your account...',
                  style: const TextStyle(fontSize: AppFontSize.f15, fontWeight: AppFontWeight.semibold),
                ),
              ],
            )
          : Text(label, style: const TextStyle(fontSize: AppFontSize.f16, fontWeight: AppFontWeight.semibold)),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }

  // ======================================================================
  // SECTIONS - shared by registration and Edit Profile
  // ======================================================================

  Widget _buildPersonalSection() {
    // Email is never editable once an account exists.
    final lockEmail = widget.isUpdating;

    return _section(
      icon: Icons.person_outline,
      title: 'Personal details',
      trailing: Text('* Required', style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
      children: [
        _buildAvatarPicker(),
        const SizedBox(height: AppSpacing.s18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 104,
              child: _labeled(
                'Title',
                DropdownButtonFormField<String>(
                  initialValue: selectedPrefix,
                  isExpanded: true,
                  items: prefixes.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (val) => setState(() => selectedPrefix = val!),
                  decoration: _decoration(hint: ''),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: _labeled(
                'Full name',
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [SentenceCapitalizationFormatter()],
                  onChanged: (_) => _onFieldChanged(),
                  decoration: _decoration(
                    hint: 'Enter your full name',
                    icon: Icons.person_outline,
                    errorText: _fieldErrors['name'],
                  ),
                ),
                required: true,
                fieldKey: _fieldKeys['name'],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s14),
        _labeled(
          'Email',
          TextField(
            controller: emailController,
            readOnly: lockEmail,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: lockEmail ? context.colors.textMuted : context.colors.textPrimary),
            onChanged: (_) => _onFieldChanged(),
            decoration: _decoration(
              hint: 'name@example.com',
              icon: Icons.mail_outline,
              locked: lockEmail,
              errorText: _fieldErrors['email'],
            ),
          ),
          required: !lockEmail,
          fieldKey: _fieldKeys['email'],
        ),
        const SizedBox(height: AppSpacing.s14),
        _labeled(
          'Phone number',
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            onChanged: (_) => _onFieldChanged(),
            decoration: _decoration(
              hint: '07XX XXX XXX',
              icon: Icons.phone_outlined,
              errorText: _fieldErrors['phone'],
            ),
          ),
          required: true,
          fieldKey: _fieldKeys['phone'],
        ),
      ],
    );
  }

  Widget _buildAvatarPicker() {
    final hasUploaded = avatarUrl != null && avatarUrl!.isNotEmpty;
    final hasImage = _imageBytes != null || hasUploaded;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: pickImage,
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: tealGlow.withValues(alpha: AppAlpha.a30),
                  backgroundImage: _imageBytes != null
                      ? MemoryImage(_imageBytes!)
                      : (hasUploaded ? NetworkImage(avatarUrl!) as ImageProvider : null),
                  child: hasImage ? null : Icon(Icons.person_outline, size: AppIconSize.i32, color: context.colors.primary),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.s6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.colors.primary,
                      border: Border.all(color: context.colors.surface, width: 2),
                    ),
                    child: Icon(Icons.camera_alt, size: AppIconSize.i14, color: context.colors.onPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Profile photo', style: TextStyle(fontSize: AppFontSize.f14, fontWeight: AppFontWeight.semibold)),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    hasImage ? 'Tap to change your photo' : 'Optional - tap to add a photo',
                    style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- role ----------------

  // Same behaviour the old Role dropdown had: clears the assistant fields
  // when switching to Assistant, and clears any stale error.
  void _selectRole(String role) {
    if (widget.isUpdating || role == selectedRole) return;
    setState(() {
      selectedRole = role;
      error = null;
      if (selectedRole == 'Assistant') {
        assistantFacilityNameController.clear();
        assistantFacilityCodeController.clear();
      }
      // The other role's problems no longer apply (and this role's now do).
      if (_submitAttempted) _fieldErrors = _validateAll();
    });
  }

  Widget _buildRoleSection() {
    final locked = widget.isUpdating;
    // A promoted Assistant is an Admin by role but a Co-admin by name - the
    // card they see selected should say so.
    final isCoAdmin = locked && widget.userData != null && RoleChangeService.isCoAdmin(widget.userData!);
    return _section(
      icon: Icons.badge_outlined,
      title: 'Your role',
      children: [
        // IntrinsicHeight so the two cards match heights when one subtitle
        // wraps and the other doesn't. (stretch on its own would throw here:
        // this Row sits in a Column, so its available height is unbounded.)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _roleCard(
                  role: 'Admin',
                  icon: Icons.storefront_outlined,
                  title: isCoAdmin ? 'Co-admin' : 'Admin',
                  subtitle: isCoAdmin ? 'I help manage a facility' : 'I own or manage a facility',
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: _roleCard(
                  role: 'Assistant',
                  icon: Icons.groups_outlined,
                  title: 'Assistant',
                  subtitle: 'I have an invite code',
                ),
              ),
            ],
          ),
        ),
        // A role is changed only by a Platform Admin (Platform Admin > Users >
        // the person > Change role) - never from here, and never by the person
        // themselves: an Admin freely demoting themselves could leave a
        // facility with nobody able to manage it. The Firestore rule enforces
        // this at the data layer too; this is the corresponding honest UI.
        if (locked) ...[
          const SizedBox(height: AppSpacing.s12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, size: AppIconSize.i14, color: context.colors.textHint),
              const SizedBox(width: AppSpacing.s6),
              Expanded(
                child: Text(
                  "Your role can't be changed here.",
                  style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _roleCard({
    required String role,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = selectedRole == role;
    final locked = widget.isUpdating;
    // A locked card keeps its selected state but in grey - clearly "this is
    // yours", clearly "not changeable here".
    final accent = locked ? context.colors.textMuted : context.colors.primary;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.r14),
      side: BorderSide(
        color: selected ? (locked ? context.colors.borderStrong : context.colors.primary) : context.colors.border,
        width: selected ? 1.6 : 1,
      ),
    );

    return Material(
      color: selected ? accent.withValues(alpha: AppAlpha.a05) : context.colors.surface,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: locked ? null : () => _selectRole(role),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: selected ? accent.withValues(alpha: AppAlpha.a15) : context.colors.surfaceMuted,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: AppIconSize.i18, color: selected ? accent : context.colors.textMuted),
                  ),
                  const Spacer(),
                  if (selected) Icon(Icons.check_circle, size: AppIconSize.i20, color: accent),
                ],
              ),
              const SizedBox(height: AppSpacing.s10),
              Text(title, style: const TextStyle(fontSize: AppFontSize.f14_5, fontWeight: AppFontWeight.bold)),
              const SizedBox(height: AppSpacing.s2),
              Text(subtitle, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted, height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- facility ----------------

  Widget _buildFacilitySection() {
    final isAssistantUpdating = widget.isUpdating && selectedRole == 'Assistant';

    if (selectedRole == 'Assistant') {
      return _section(
        icon: Icons.storefront_outlined,
        title: 'Your facility',
        children: isAssistantUpdating ? _assistantReadOnlyFacility() : _assistantInviteFields(),
      );
    }
    return _section(
      icon: Icons.storefront_outlined,
      title: 'Your facilities',
      children: _adminFacilityFields(),
    );
  }

  // Already a member - the invite code that got them here was consumed the
  // moment they registered, so there's nothing left to look up or re-enter.
  // Shown read-only, purely for reference.
  List<Widget> _assistantReadOnlyFacility() {
    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: context.colors.divider,
          borderRadius: BorderRadius.circular(AppRadius.r12),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.storefront_outlined, color: context.colors.textMuted, size: AppIconSize.i18),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                facilities.isNotEmpty
                    ? '${facilities.first['name'] ?? ''} (${facilities.first['type'] ?? ''})'
                    : 'Unknown facility',
                style: TextStyle(color: context.colors.textSoft, fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13_5),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _assistantInviteFields() {
    // Once a valid code has been found any earlier complaint is moot.
    final inviteError = _foundFacility != null ? null : _fieldErrors['invite'];

    return [
      Text(
        'Ask your facility Admin for an invite code to join their team.',
        style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.primary, fontStyle: FontStyle.italic),
      ),
      const SizedBox(height: AppSpacing.s12),
      _labeled(
        'Invite code',
        TextField(
          controller: assistantFacilityCodeController,
          onChanged: (value) {
            _onFacilityCodeChanged(value);
            _onFieldChanged();
          },
          decoration: _decoration(
            hint: 'Enter your invite code',
            icon: Icons.vpn_key_outlined,
            errorText: inviteError,
            suffix: _isLookingUpFacility
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.s12),
                    child: SizedBox(width: AppSpacing.s16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : (_foundFacility != null ? Icon(Icons.check_circle, color: context.colors.success) : null),
          ),
        ),
        required: true,
        fieldKey: _fieldKeys['invite'],
      ),
      const SizedBox(height: AppSpacing.s10),
      if (_foundFacility != null)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: context.colors.success.withValues(alpha: AppAlpha.a10),
            borderRadius: BorderRadius.circular(AppRadius.r12),
            border: Border.all(color: context.colors.success.withValues(alpha: AppAlpha.a30)),
          ),
          child: Row(
            children: [
              Icon(Icons.storefront_outlined, color: context.colors.success, size: AppIconSize.i18),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  'Joining: ${_foundFacility!['name']} (${_foundFacility!['type']})',
                  style: TextStyle(color: context.colors.success, fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13),
                ),
              ),
            ],
          ),
        )
      // Not shown twice: once Register has been pressed the same message is
      // already on the field itself.
      else if (_facilityLookupError != null && inviteError == null)
        Text(_facilityLookupError!, style: TextStyle(color: context.colors.dangerAccent, fontSize: AppFontSize.f12_5)),
    ];
  }

  Widget _facilityTile(int index) {
    final f = facilities[index];
    final locked = widget.isUpdating;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      padding: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s10, AppSpacing.s6, AppSpacing.s10),
      decoration: BoxDecoration(
        color: locked ? context.colors.surfaceMuted : context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: tealGlow.withValues(alpha: AppAlpha.a20), shape: BoxShape.circle),
            child: Icon(Icons.storefront_outlined, color: context.colors.primary, size: AppIconSize.i18),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f['name'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFontSize.f14,
                    fontWeight: AppFontWeight.bold,
                    color: locked ? context.colors.textSoft : context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s3),
                Text(
                  '${f['type'] ?? ''}  \u00b7  Code: ${f['code'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted),
                ),
              ],
            ),
          ),
          if (!locked)
            IconButton(
              icon: Icon(Icons.delete_outline, color: context.colors.dangerAccent, size: AppIconSize.i20),
              tooltip: 'Remove',
              onPressed: () => removeFacility(index),
            ),
        ],
      ),
    );
  }

  List<Widget> _adminFacilityFields() {
    final atLimit = facilities.length >= _maxFacilities;
    // The first facility is required; further ones are optional.
    final needsFirst = facilities.isEmpty && !widget.isUpdating;
    final facilityError = needsFirst ? _fieldErrors['facility'] : null;

    return [
      // A plain Column, not a shrink-wrapped ListView: the facility list is
      // short, and this keeps the surrounding layout free to size itself.
      if (facilities.isNotEmpty)
        for (var i = 0; i < facilities.length; i++) _facilityTile(i)
      else if (!widget.isUpdating && facilityError == null)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s12),
          child: Text(
            'Add at least one facility to continue.',
            style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted),
          ),
        ),
      if (facilityError != null)
        Container(
          key: _fieldKeys['facility'],
          margin: const EdgeInsets.only(bottom: AppSpacing.s12),
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: context.colors.dangerAccent.withValues(alpha: AppAlpha.a05),
            borderRadius: BorderRadius.circular(AppRadius.r12),
            border: Border.all(color: context.colors.dangerAccent.withValues(alpha: AppAlpha.a40)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: context.colors.dangerAccent, size: AppIconSize.i18),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  facilityError,
                  style: TextStyle(color: context.colors.dangerDeep, fontSize: AppFontSize.f12_5, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      if (widget.isUpdating)
        Text(
          'To add or change facilities, use View Facilities.',
          style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted),
        )
      else ...[
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s10),
          child: Text(
            '${facilities.length} of $_maxFacilities facilities added',
            style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted),
          ),
        ),
        _labeled(
          'Facility name',
          TextField(
            controller: facilityNameController,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [SentenceCapitalizationFormatter()],
            onChanged: (_) => _onFieldChanged(),
            decoration: _decoration(hint: 'e.g. Ukuli', icon: Icons.storefront_outlined),
          ),
          required: needsFirst,
        ),
        const SizedBox(height: AppSpacing.s12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _labeled(
                'Type',
                DropdownButtonFormField<String>(
                  // initialValue only applies when the field is first built,
                  // so after adding a facility (which resets
                  // _selectedFacilityType) this kept SHOWING the old type
                  // while the code thought nothing was chosen, and the next
                  // Add silently did nothing. A key that changes with the
                  // list rebuilds it fresh after every add or remove.
                  key: ValueKey('facility-type-${facilities.length}'),
                  initialValue: _selectedFacilityType,
                  isExpanded: true,
                  decoration: _decoration(hint: 'Select type'),
                  items: kFacilityTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (value) {
                    setState(() => _selectedFacilityType = value);
                    _onFieldChanged();
                  },
                ),
                required: needsFirst,
              ),
            ),
            const SizedBox(width: AppSpacing.s10),
            Tooltip(
              message: atLimit ? 'Maximum of $_maxFacilities facilities reached' : '',
              child: SizedBox(
                height: 47,
                child: ElevatedButton.icon(
                  onPressed: (_isAddingFacility || atLimit) ? null : addFacility,
                  icon: _isAddingFacility
                      ? const SizedBox(width: AppSpacing.s16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add, size: AppIconSize.i18),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.accent,
                    foregroundColor: context.colors.textPrimary,
                    disabledBackgroundColor: context.colors.divider,
                    elevation: AppElevation.e0,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r12)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ];
  }

  // ---------------- security (registration only) ----------------

  Widget _buildSecuritySection() {
    final password = passwordController.text;
    final confirm = confirmPasswordController.text;
    final matches = password == confirm;

    return _section(
      icon: Icons.lock_outline,
      title: 'Account security',
      children: [
        _labeled(
          'Password',
          TextField(
            controller: passwordController,
            obscureText: _obscurePassword,
            onChanged: (_) => _onFieldChanged(),
            decoration: _decoration(
              hint: 'Create a password',
              icon: Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: AppIconSize.i20,
                  color: context.colors.textHint,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              helper: password.isEmpty
                  ? 'At least 8 characters, with a letter and a number'
                  : (_passwordIssue(password) ?? 'Looks good'),
              helperColor: password.isEmpty
                  ? context.colors.textMuted
                  : (_passwordIssue(password) == null ? context.colors.success : context.colors.dangerAccent),
              errorText: _fieldErrors['password'],
            ),
          ),
          required: true,
          fieldKey: _fieldKeys['password'],
        ),
        const SizedBox(height: AppSpacing.s14),
        _labeled(
          'Confirm password',
          TextField(
            controller: confirmPasswordController,
            obscureText: _obscureConfirm,
            onChanged: (_) => _onFieldChanged(),
            decoration: _decoration(
              hint: 'Re-enter your password',
              icon: Icons.lock_outline,
              suffix: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (confirm.isNotEmpty)
                    Icon(
                      matches ? Icons.check_circle : Icons.error_outline,
                      size: AppIconSize.i20,
                      color: matches ? context.colors.success : context.colors.dangerAccent,
                    ),
                  IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: AppIconSize.i20,
                      color: context.colors.textHint,
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ],
              ),
              helper: confirm.isEmpty ? null : (matches ? 'Passwords match' : 'Passwords do not match'),
              helperColor: matches ? context.colors.success : context.colors.dangerAccent,
              errorText: _fieldErrors['confirm'],
            ),
          ),
          required: true,
          fieldKey: _fieldKeys['confirm'],
        ),
      ],
    );
  }
}

// A name in the "By creating an account you agree to..." line: a real link,
// teal and underlined at rest, amber on hover - opening the same screens the
// login page's footer links to.
class _LegalLink extends StatefulWidget {
  final String label;
  final Widget destination;

  const _LegalLink({required this.label, required this.destination});

  @override
  State<_LegalLink> createState() => _LegalLinkState();
}

class _LegalLinkState extends State<_LegalLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovered ? context.colors.accent : _RegisterScreenState.tealAccent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => widget.destination)),
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: AppFontSize.f12_5,
            fontWeight: AppFontWeight.bold,
            color: color,
            decoration: TextDecoration.underline,
            decorationColor: color,
          ),
        ),
      ),
    );
  }
}

/// Opens Edit Profile as a centered modal on wide screens (same size and
/// transition as the other Add/Edit screens), or a full-screen push on narrow
/// ones. Returns true if the profile was saved.
///
/// The Dashboard reads the signed-in user's profile through live Firestore
/// streams, so closing the modal after a save is all it takes for the name
/// and photo to update - there is nothing to reload.
Future<bool?> showEditProfileScreen(BuildContext context, {required Map<String, dynamic> userData}) {
  final isWideScreen = MediaQuery.of(context).size.width >= AppBreakpoints.medium;

  if (!isWideScreen) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RegisterScreen(userData: userData, isUpdating: true)),
    );
  }

  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Edit Profile',
    barrierColor: context.colors.scrim.withValues(alpha: AppAlpha.a50),
    transitionDuration: AppMotion.normal,
    pageBuilder: (context, animation, secondaryAnimation) {
      final screenSize = MediaQuery.of(context).size;
      final modalWidth = (screenSize.width * 0.60).clamp(0, 940).toDouble();
      final modalHeight = (screenSize.height * 0.88) < 480 ? 480.0 : screenSize.height * 0.88;
      return Center(
        child: SizedBox(
          width: modalWidth,
          height: modalHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r16),
            child: Material(
              child: RegisterScreen(userData: userData, isUpdating: true, isModal: true),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}
