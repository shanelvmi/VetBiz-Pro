import 'dart:typed_data';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/facility_provider.dart';
import '../utils/facility_activation.dart';
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

  // Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController assistantFacilityNameController = TextEditingController();
  final TextEditingController assistantFacilityCodeController = TextEditingController();

  // Live lookup as the code is typed - shows the real facility name and
  // type looked up from Firestore, instead of also asking for the name
  // as separate free text (which could be typed wrong, or made up
  // entirely, while the code alone is already enough to identify the
  // facility uniquely).
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
        final query = await FirebaseFirestore.instance
            .collection('facilities')
            .where('code', isEqualTo: code)
            .limit(1)
            .get();

        if (!mounted) return;
        setState(() {
          _isLookingUpFacility = false;
          if (query.docs.isEmpty) {
            _foundFacility = null;
            _facilityLookupError = 'No facility found with this code';
          } else {
            final doc = query.docs.first;
            _foundFacility = {
              'facilityId': doc.id,
              'name': doc.data()['name'] ?? '',
              'type': doc.data()['type'] ?? '',
              'code': code,
            };
            _facilityLookupError = null;
          }
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
  // Free text here previously meant every admin typed their own variant
  // ("Vet Shop", "Veterinary Store", "agrovet"...), making the field
  // useless for anything beyond display. A fixed set keeps it
  // meaningful and consistent, with "Other" as an honest fallback for
  // anything genuinely outside these.
  static const List<String> kFacilityTypes = [
    'Agrovet',
    'Vet Clinic',
    'Vet Hospital',
    'Ambulatory Vet',
    'Other',
  ];
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

  String _randomCode({int length = 8}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  /// Generates a facility code and verifies it's not already in use
  /// before returning it - the random generator alone (2.8 trillion
  /// possible 8-character codes) makes a collision extremely unlikely,
  /// but "extremely unlikely" isn't "never." This makes it actually
  /// guaranteed rather than just statistically safe, at the cost of one
  /// quick query per attempt.
  Future<String> generateUniqueFacilityCode({int length = 8, int maxAttempts = 5}) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final candidate = _randomCode(length: length);
      final existing = await FirebaseFirestore.instance
          .collection('facilities')
          .where('code', isEqualTo: candidate)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) return candidate;
      // Collision (astronomically rare) - loop and try a fresh one.
    }
    // maxAttempts exhausted (should never realistically happen) - fall
    // back to a longer code, which shrinks the collision odds further
    // still rather than silently reusing something.
    return _randomCode(length: length + 4);
  }

  @override
  void dispose() {
    _facilityLookupDebounce?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
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

  Future<void> addFacility() async {
    final name = facilityNameController.text.trim();
    final type = _selectedFacilityType;
    if (name.isEmpty || type == null || _isAddingFacility) return;

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
        setState(() => error = "Enter a valid facility code");
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

      // Add facilities to Firestore
      for (var f in facilities) {
        final docRef = await FirebaseFirestore.instance.collection('facilities').add({
          'name': f['name'],
          'type': f['type'],
          'code': f['code'],
          'createdBy': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // FIXED: Ensure facilityId is set correctly
        facilitiesWithId.add({...f, 'facilityId': docRef.id});
        facilityIds.add(docRef.id);
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
      // _foundFacility was already verified via the live lookup as the
      // code was typed - no need to query again, and this can no
      // longer crash on an empty result the way the old query-then-
      // .first approach could if the facility somehow wasn't found by
      // this point.
      if (_foundFacility == null) {
        setState(() => error = 'Enter a valid facility code first');
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
                onChanged: isAssistantUpdating
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
                  color: isAssistantUpdating ? Colors.grey : Colors.black,
                ),
              ),
              const SizedBox(height: 16),

              // ---------------- ASSISTANT FIELDS ----------------
              if (selectedRole == 'Assistant') ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Ask your facility Admin for the Facility Name and Code to join their team.",
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
                    labelText: 'Facility Code',
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
                        child: ListTile(
                          title: Text(f['name'] ?? ''),
                          subtitle: Text(
                              'Type: ${f['type'] ?? ''} - Code: ${f['code'] ?? ''}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => removeFacility(index),
                          ),
                        ),
                      );
                    },
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
                      style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.hovered)) return deepTealGreen;
                          return warmAmber;
                        }),
                      ),
                      onPressed: _isAddingFacility ? null : addFacility,
                    ),
                  ],
                ),
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
