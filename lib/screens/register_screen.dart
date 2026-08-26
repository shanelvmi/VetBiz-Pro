import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/invite_code_service.dart';
import '../providers/facility_provider.dart';
import '../utils/facility_activation.dart';
import '../utils/facility_code_generator.dart';
import '../constants/facility_types.dart';
import '../utils/trial_period_helper.dart';
import '../utils/facility_limit_helper.dart';
import 'facilities/facility_picker_screen.dart';

class RegisterScreen extends StatefulWidget {
  final bool isUpdating;
  final Map<String, dynamic>? userData;

  const RegisterScreen({super.key, this.isUpdating = false, this.userData});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();
  final InviteCodeService _inviteCodeService = InviteCodeService();

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

    _facilityLookupDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final facilityId = await _inviteCodeService.validateInviteCode(code);

        if (!mounted) return;

        if (facilityId == null) {
          setState(() {
            _isLookingUpFacility = false;
            _foundFacility = null;
            _facilityLookupError = 'Invalid, expired, or already-used invite code';
          });
          return;
        }

        // The invite code only carries the facilityId - fetch the
        // actual facility document for its name/type to show what
        // this invite is actually joining.
        final facilityDoc = await FirebaseFirestore.instance
            .collection('facilities')
            .doc(facilityId)
            .get();

        if (!mounted) return;

        if (!facilityDoc.exists) {
          setState(() {
            _isLookingUpFacility = false;
            _foundFacility = null;
            _facilityLookupError = 'This invite points to a facility that no longer exists';
          });
          return;
        }

        setState(() {
          _isLookingUpFacility = false;
          _foundFacility = {
            'facilityId': facilityId,
            'name': facilityDoc.data()?['name'] ?? '',
            'type': facilityDoc.data()?['type'] ?? '',
            'code': code, // the invite code itself, kept for markInviteCodeUsed at submit time
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
  final List<String> roles = ['Admin', 'Assistant'];
  String selectedPrefix = 'Mr.';
  String selectedRole = 'Admin';

  // UI
  Uint8List? _imageBytes;
  String? avatarUrl;
  String? error;

  // Colors & style
  final Color deepTealGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);
  final OutlineInputBorder blackBorder = const OutlineInputBorder(
    borderSide: BorderSide(color: Colors.black, width: 1.2),
  );

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
        .collection('users')
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
      final roleFromDb = (data['role'] ?? '').toString().toLowerCase();
      selectedRole = roleFromDb == 'admin' ? 'Admin' : 'Assistant';

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
    if (name.isEmpty || type == null || _isAddingFacility) return;

    if (facilities.length >= _maxFacilities) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You've reached the limit of $_maxFacilities facilities per account.")),
      );
      return;
    }

    setState(() => _isAddingFacility = true);
    try {
      final code = await generateUniqueFacilityCode();
      if (!mounted) return;
      setState(() {
        facilities.add({'name': name, 'type': type, 'code': code, 'facilityId': ''});
        facilityNameController.clear();
        _selectedFacilityType = null;
      });
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
  final roleLower = selectedRole.toLowerCase();

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
      Map<String, dynamic> updateData = {
        'fullName': fullName,
        'phone': phone,
        'role': roleLower,
        'avatarUrl': imageUrl,
        'facilities': selectedRole == 'Admin'
            ? facilities
            : [
                {
                  'facilityId': facilities.isNotEmpty ? facilities.first['facilityId'] ?? '' : '',
                  'name': assistantFacilityNameController.text.trim(),
                  'type': facilities.isNotEmpty ? facilities.first['type'] ?? '' : '',
                  'code': assistantFacilityCodeController.text.trim(),
                }
              ],
      };
      await FirebaseFirestore.instance.collection('users').doc(uid).update(updateData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!")),
        );
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
      return;
    }

    // ---------------- New Admin Registration ----------------
    if (selectedRole == 'Admin') {
      uid = await _authService.register(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        role: roleLower,
        facilities: [],
        avatarUrl: '',
      );

      List<Map<String, dynamic>> facilitiesWithId = [];
      List<String> facilityIds = [];

      // Looked up once, not per-facility inside the loop below - the
      // configured trial length can't change mid-registration, so
      // there's no reason to re-fetch it for every facility being
      // created in this one registration.
      final trialExpiresAt = await computeNewFacilityTrialExpiry();

      // Add facilities to Firestore
      for (var f in facilities) {
        final docRef = await FirebaseFirestore.instance.collection('facilities').add({
          'name': f['name'],
          'type': f['type'],
          'code': f['code'],
          'createdBy': uid,
          'createdAt': FieldValue.serverTimestamp(),
          'trialExpiresAt': Timestamp.fromDate(trialExpiresAt),
        });

        // FIXED: Ensure facilityId is set correctly
        facilitiesWithId.add({...f, 'facilityId': docRef.id});
        facilityIds.add(docRef.id);

        // Written immediately, not just accumulated in the local list
        // above and saved once after the loop - the facility-limit
        // rule (isUnderFacilityLimit in firestore.rules) reads this
        // field live on every facility create, so it needs to reflect
        // the real, growing count as each one is created in this same
        // registration, not just the count from before it started.
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'facilityIds': FieldValue.arrayUnion([docRef.id]),
        });
      }

      final imageUrl = await uploadImage(uid);

      // Update user document with facilities and avatar
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'avatarUrl': imageUrl,
        'facilities': facilitiesWithId,
        'facilityIds': facilityIds,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Account registered successfully! We've sent a verification link to your email - check your Spam folder if it doesn't appear within a few minutes."),
            duration: Duration(seconds: 6),
          ),
        );

        if (facilitiesWithId.length == 1) {
          final selected = facilitiesWithId.first;
          await activateFacilityAndGoToDashboard(
            context: context,
            facility: {
              'facilityId': selected['facilityId'],
              'facilityName': selected['name'],
              'facilityType': selected['type'],
            },
            role: 'admin',
          );
        } else {
          final facilityList = facilitiesWithId.map((f) {
            return {
              'facilityId': f['facilityId'],
              'facilityName': f['name'],
              'facilityType': f['type']
            };
          }).toList();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => FacilityPickerScreen(facilities: facilityList, role: 'admin'),
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

      await _authService.registerAssistantSilently(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        facilities: [
          {
            'facilityId': facility['facilityId'],
            'name': facility['name'],
            'type': facility['type'] ?? '',
            'code': facility['code'],
          }
        ],
        avatarBytes: _imageBytes,
      );

      // Only marked as used now that registration has actually
      // succeeded - a failed attempt above (e.g. a duplicate email)
      // returns via the catch blocks below without ever reaching this,
      // so the invite stays valid for a genuine retry.
      try {
        await _inviteCodeService.markInviteCodeUsed(facility['code'] as String, email);
      } catch (e) {
        // The account was already created successfully at this point -
        // failing to mark the invite as used is a minor bookkeeping
        // miss, not a reason to show the user an error about their own
        // registration, which already succeeded.
        debugPrint('Could not mark invite code as used: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              duration: Duration(seconds: 6),
              content: Text(
                  "Assistant registered successfully! Waiting for admin approval. We've also sent a verification link to your email - check your Spam folder if it doesn't appear.")),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  } on FirebaseAuthException catch (e) {
    if (e.code == 'email-already-in-use') {
      setState(() => error =
          'An account with this email already exists. If you\'re switching '
          'facilities, this email can\'t register a second time - ask your '
          'Platform Admin to add you to the new facility instead.');
    } else {
      setState(() => error = e.message ?? 'Registration failed. Please try again.');
    }
  } catch (e, stackTrace) {
    print('🔥 Error: $e\n📌 Stack: $stackTrace');
    setState(() => error = e.toString());
  }
 }

 @override
 Widget build(BuildContext context) {
  final bool isAssistantUpdating = widget.isUpdating && selectedRole == 'Assistant';

  return Scaffold(
    backgroundColor: offWhite,
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          if (widget.isUpdating) {
            Navigator.pushReplacementNamed(context, '/dashboard');
          } else if (Navigator.canPop(context)) {
            // Pops back to whatever was underneath (AppEntryPoint,
            // still showing LoginScreen reactively) instead of
            // destroying it - the previous pushAndRemoveUntil(...,
            // (route) => false) removed every route including
            // AppEntryPoint itself, which is exactly why the URL stuck
            // at #/register and a subsequent login attempt had nothing
            // left listening for it to ever spin down.
            Navigator.pop(context);
          } else {
            // Edge case: registration was reached directly (e.g. a
            // bookmarked /register URL) with nothing to pop back to.
            Navigator.pushReplacementNamed(context, '/login');
          }
        },
      ),
      title: Text(
        widget.isUpdating ? 'Edit Profile' : 'Register',
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: deepTealGreen,
      centerTitle: true,
      elevation: 1,
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Column(
            children: [
              // ---------------- AVATAR ----------------
              GestureDetector(
                onTap: pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: _imageBytes != null
                      ? MemoryImage(_imageBytes!)
                      : (avatarUrl != null ? NetworkImage(avatarUrl!) : null),
                  child: _imageBytes == null && avatarUrl == null
                      ? Icon(Icons.camera_alt, size: 40, color: Colors.grey[800])
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              // ---------------- NAME & PREFIX ----------------
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedPrefix,
                      items: prefixes
                          .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      onChanged: (val) => setState(() => selectedPrefix = val!),
                      decoration: InputDecoration(
                        labelText: 'Title',
                        enabledBorder: blackBorder,
                        focusedBorder: blackBorder,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        enabledBorder: blackBorder,
                        focusedBorder: blackBorder,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ---------------- EMAIL ----------------
              TextField(
                controller: emailController,
                readOnly: isAssistantUpdating || widget.isUpdating,
                style: TextStyle(
                  color: isAssistantUpdating || widget.isUpdating
                      ? Colors.grey
                      : Colors.black,
                ),
                decoration: InputDecoration(
                  labelText: 'Email',
                  enabledBorder: blackBorder,
                  focusedBorder: blackBorder,
                ),
              ),
              const SizedBox(height: 16),

              // ---------------- PHONE ----------------
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  enabledBorder: blackBorder,
                  focusedBorder: blackBorder,
                ),
              ),
              const SizedBox(height: 16),

              // ---------------- ROLE ----------------
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                // Role changes for your own account go through an
                // actual admin managing someone else's account, not
                // self-service Edit Profile - this now applies
                // regardless of which role is doing the editing.
                // Previously only Assistants were blocked here; an
                // Admin could freely demote themselves, and if they
                // were a facility's only Admin, that left nobody able
                // to promote anyone back. Matches the Firestore rule,
                // which enforces this the same way at the data layer -
                // this is the corresponding, honest UI, not the only
                // protection.
                onChanged: widget.isUpdating
                    ? null
                    : (val) => setState(() {
                          selectedRole = val!;
                          error = null;
                          if (selectedRole == 'Assistant') {
                            assistantFacilityNameController.clear();
                            assistantFacilityCodeController.clear();
                          }
                        }),
                items: roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                decoration: InputDecoration(
                  labelText: 'Role',
                  enabledBorder: blackBorder,
                  focusedBorder: blackBorder,
                ),
                style: TextStyle(
                  color: widget.isUpdating ? Colors.grey : Colors.black,
                ),
              ),
              const SizedBox(height: 16),

              // ---------------- ASSISTANT FIELDS ----------------
              if (selectedRole == 'Assistant') ...[
                if (isAssistantUpdating) ...[
                  // Already a member - the invite code that got them
                  // here was already consumed the moment they
                  // registered, so there's nothing left to look up or
                  // re-enter here. Shown read-only, purely for
                  // reference, not as an editable field.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Facility',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: deepTealGreen),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.storefront_outlined, color: Colors.grey[600], size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            facilities.isNotEmpty
                                ? '${facilities.first['name'] ?? ''} (${facilities.first['type'] ?? ''})'
                                : 'Unknown facility',
                            style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Ask your facility Admin for an invite code to join their team.",
                    style: TextStyle(
                      fontSize: 12,
                      color: deepTealGreen,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: assistantFacilityCodeController,
                  onChanged: _onFacilityCodeChanged,
                  decoration: InputDecoration(
                    labelText: 'Invite Code',
                    enabledBorder: blackBorder,
                    focusedBorder: blackBorder,
                    suffixIcon: _isLookingUpFacility
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : (_foundFacility != null ? const Icon(Icons.check_circle, color: Colors.green) : null),
                  ),
                ),
                const SizedBox(height: 8),
                if (_foundFacility != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront_outlined, color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Joining: ${_foundFacility!['name']} (${_foundFacility!['type']})',
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_facilityLookupError != null)
                  Text(_facilityLookupError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
                const SizedBox(height: 16),
                ],
              ] else ...[
                // ---------------- ADMIN FACILITIES ----------------
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Facilities',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: deepTealGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (facilities.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: facilities.length,
                    itemBuilder: (context, index) {
                      final f = facilities[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: widget.isUpdating ? Colors.grey[100] : null,
                        child: ListTile(
                          title: Text(
                            f['name'] ?? '',
                            style: TextStyle(color: widget.isUpdating ? Colors.grey[600] : null),
                          ),
                          subtitle: Text(
                            'Type: ${f['type'] ?? ''} - Code: ${f['code'] ?? ''}',
                            style: TextStyle(color: widget.isUpdating ? Colors.grey[500] : null),
                          ),
                          // Facilities aren't managed from here - this
                          // screen edits personal profile info, not
                          // facility membership, so there's no delete
                          // action to accidentally trigger while
                          // updating a name or phone number.
                          trailing: widget.isUpdating
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => removeFacility(index),
                                ),
                        ),
                      );
                    },
                  ),
                if (!widget.isUpdating) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${facilities.length} of $_maxFacilities facilities added',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: facilityNameController,
                        decoration: InputDecoration(
                          labelText: 'Facility Name',
                          enabledBorder: blackBorder,
                          focusedBorder: blackBorder,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedFacilityType,
                        decoration: InputDecoration(
                          labelText: 'Type',
                          enabledBorder: blackBorder,
                          focusedBorder: blackBorder,
                        ),
                        items: kFacilityTypes
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedFacilityType = value),
                      ),
                    ),
                    IconButton(
                      icon: _isAddingFacility
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_circle),
                      tooltip: facilities.length >= _maxFacilities
                          ? 'Maximum of $_maxFacilities facilities reached'
                          : null,
                      style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.disabled)) return Colors.grey.shade400;
                          if (states.contains(WidgetState.hovered)) return deepTealGreen;
                          return warmAmber;
                        }),
                      ),
                      onPressed: (_isAddingFacility || facilities.length >= _maxFacilities) ? null : addFacility,
                    ),
                  ],
                ),
                ],
                const SizedBox(height: 16),
              ],

              // ---------------- PASSWORD ----------------
              if (!isAssistantUpdating) ...[
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    enabledBorder: blackBorder,
                    focusedBorder: blackBorder,
                    helperText: passwordController.text.isEmpty
                        ? 'At least 8 characters, with a letter and a number'
                        : (_passwordIssue(passwordController.text) ?? 'Looks good'),
                    helperStyle: TextStyle(
                      color: passwordController.text.isEmpty
                          ? Colors.grey
                          : (_passwordIssue(passwordController.text) == null ? Colors.green : Colors.redAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    enabledBorder: blackBorder,
                    focusedBorder: blackBorder,
                    suffixIcon: confirmPasswordController.text.isEmpty
                        ? null
                        : Icon(
                            passwordController.text == confirmPasswordController.text
                                ? Icons.check_circle
                                : Icons.error_outline,
                            color: passwordController.text == confirmPasswordController.text
                                ? Colors.green
                                : Colors.redAccent,
                          ),
                    helperText: confirmPasswordController.text.isEmpty
                        ? null
                        : (passwordController.text == confirmPasswordController.text
                            ? 'Passwords match'
                            : 'Passwords do not match'),
                    helperStyle: TextStyle(
                      color: passwordController.text == confirmPasswordController.text
                          ? Colors.green
                          : Colors.redAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ---------------- ERROR ----------------
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),

              const SizedBox(height: 16),

              // ---------------- SUBMIT BUTTON ----------------
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: offWhite,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ).copyWith(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.hovered)) return warmAmber;
                      return deepTealGreen;
                    }),
                  ),
                  onPressed: _submit,
                  child: Text(
                    widget.isUpdating ? 'Update Profile' : 'Register',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
 }
}
