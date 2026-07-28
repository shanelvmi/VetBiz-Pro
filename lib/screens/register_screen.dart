import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import '../providers/facility_provider.dart';

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
  final TextEditingController facilityNameController = TextEditingController();
  final TextEditingController facilityTypeController = TextEditingController();

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

  String generateFacilityCode({int length = 8}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
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

  void addFacility() {
    final name = facilityNameController.text.trim();
    final type = facilityTypeController.text.trim();
    if (name.isNotEmpty && type.isNotEmpty) {
      setState(() {
        facilities.add({'name': name, 'type': type, 'code': generateFacilityCode(), 'facilityId': ''});
        facilityNameController.clear();
        facilityTypeController.clear();
      });
    }
  }

  void removeFacility(int index) => setState(() => facilities.removeAt(index));

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
    if (!widget.isUpdating && password != confirmPassword) {
      setState(() => error = "Passwords do not match");
      return;
    }

    if (selectedRole == 'Admin' && facilities.isEmpty) {
      setState(() => error = "Please add at least one facility");
      return;
    }

    if (selectedRole == 'Assistant') {
      final enteredName = assistantFacilityNameController.text.trim();
      final enteredCode = assistantFacilityCodeController.text.trim();
      if (enteredName.isEmpty || enteredCode.isEmpty) {
        setState(() => error = "Please enter Facility Name and Facility Code");
        return;
      }
      final query = await FirebaseFirestore.instance
          .collection('facilities')
          .where('name', isEqualTo: enteredName)
          .where('code', isEqualTo: enteredCode)
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        setState(() => error = "Invalid Facility Name or Code");
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
          const SnackBar(content: Text("Account registered successfully!")),
        );

        if (facilitiesWithId.length == 1) {
          final selected = facilitiesWithId.first;
          Provider.of<FacilityProvider>(context, listen: false).setFacility(
            id: selected['facilityId'],
            name: selected['name'],
            type: selected['type'],
          );
          Navigator.pushReplacementNamed(context, '/dashboard');
        } else {
          final facilityList = facilitiesWithId.map((f) {
            return {
              'facilityId': f['facilityId'],
              'facilityName': f['name'],
              'facilityType': f['type']
            };
          }).toList();
          Navigator.pushReplacementNamed(
            context,
            '/selectFacility',
            arguments: {'role': 'admin', 'facilities': facilityList},
          );
        }
      }
    } else {
      // ---------------- Assistant Registration ----------------
      final enteredName = assistantFacilityNameController.text.trim();
      final enteredCode = assistantFacilityCodeController.text.trim();
      final query = await FirebaseFirestore.instance
          .collection('facilities')
          .where('name', isEqualTo: enteredName)
          .where('code', isEqualTo: enteredCode)
          .limit(1)
          .get();
      final facilityDoc = query.docs.first;

      await _authService.registerAssistantSilently(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        facilities: [
          {
            'facilityId': facilityDoc.id,
            'name': enteredName,
            'type': facilityDoc['type'] ?? '',
            'code': enteredCode,
          }
        ],
        avatarBytes: _imageBytes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  "Assistant registered successfully! Waiting for admin approval.")),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
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
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
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
                  controller: assistantFacilityNameController,
                  decoration: InputDecoration(
                    labelText: 'Facility Name',
                    enabledBorder: blackBorder,
                    focusedBorder: blackBorder,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: assistantFacilityCodeController,
                  decoration: InputDecoration(
                    labelText: 'Facility Code',
                    enabledBorder: blackBorder,
                    focusedBorder: blackBorder,
                  ),
                ),
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
                      child: TextField(
                        controller: facilityTypeController,
                        decoration: InputDecoration(
                          labelText: 'Type',
                          enabledBorder: blackBorder,
                          focusedBorder: blackBorder,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle, color: warmAmber),
                      onPressed: addFacility,
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
                  decoration: InputDecoration(
                    labelText: 'Password',
                    enabledBorder: blackBorder,
                    focusedBorder: blackBorder,
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    enabledBorder: blackBorder,
                    focusedBorder: blackBorder,
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
                    backgroundColor: deepTealGreen,
                    foregroundColor: offWhite,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ).copyWith(
                    overlayColor: WidgetStateProperty.all(
                      Colors.teal.shade700,
                    ),
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
