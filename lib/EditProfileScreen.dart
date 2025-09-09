import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'Profile.dart'; // Import Profile screen

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstinController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser!;
  bool _newProfile = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    // Clean up controllers to prevent memory leaks
    _nameController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _addressController.dispose();
    _gstinController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('profile')
          .where('user', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (doc.docs.isEmpty) {
        _newProfile = true;
      } else {
        final data = doc.docs.first.data();
        setState(() {
          _nameController.text = data['name'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _companyController.text = data['company'] ?? '';
          _addressController.text = data['address'] ?? '';
          _gstinController.text = data['gstin'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading profile data: $e');
      if (mounted) {
        Fluttertoast.showToast(msg: "Error loading profile data");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_newProfile) {
        // Add new profile
        await FirebaseFirestore.instance.collection("profile").add({
          'user': user.uid,
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'company': _companyController.text.trim(),
          'address': _addressController.text.trim(),
          'gstin': _gstinController.text.trim(),
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Update existing profile
        final docs = await FirebaseFirestore.instance
            .collection('profile')
            .where('user', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (docs.docs.isNotEmpty) {
          await docs.docs.first.reference.update({
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'company': _companyController.text.trim(),
            'address': _addressController.text.trim(),
            'gstin': _gstinController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (mounted) {
        Fluttertoast.showToast(msg: "Profile updated successfully");

        if (_newProfile) {
          // For new profile, replace current screen with Profile screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Profile()),
          );
        } else {
          // For existing profile update, go back with success indicator
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      print('Error saving profile: $e');
      if (mounted) {
        Fluttertoast.showToast(msg: "Error saving profile: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_newProfile ? 'Create Profile' : 'Edit Profile'), // Dynamic title
        titleTextStyle: const TextStyle(
          fontSize: 22,
          color: Colors.white,
        ),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
        foregroundColor: Colors.white,
        // Hide back button for new profile creation
        automaticallyImplyLeading: !_newProfile,
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),
              _buildTextField(_nameController, "Name", Icons.person, canChange: true,),
              _buildTextField(
                  _phoneController,
                  "Phone",
                  Icons.phone,
                  prefix: "+91 ",
                  keyboard: TextInputType.phone,
                  maxLength: 10,
                  canChange: true
              ),
              _buildTextField(_companyController, "Company Name", Icons.business,canChange: false),
              _buildTextField(_addressController, "Company Address", Icons.location_on,canChange: false),
              _buildTextField(_gstinController, "GSTIN", Icons.qr_code,canChange: false),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveProfile,
                  icon: _isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(Icons.save, color: Colors.white),
                  label: Text(
                    _isLoading ? "Saving..." : "Save",
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String label,
      IconData icon, {
        String? prefix,
        TextInputType keyboard = TextInputType.text,
        int? maxLength,
        required bool canChange,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefix,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
          counterText: maxLength != null ? "" : null, // Hide counter for phone field
        ),
        enabled: canChange,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter $label';
          }

          // Additional validation for phone number
          if (label == "Phone" && value.trim().length != 10) {
            return 'Please enter a valid 10-digit phone number';
          }

          return null;
        },
      ),
    );
  }
}