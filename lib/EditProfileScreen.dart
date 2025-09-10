import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'Profile.dart';

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
  bool _newProfile = true;
  bool _isLoading = true;
  String? _existingDocId;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _addressController.dispose();
    _gstinController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('profile')
          .where('user', isEqualTo: user.uid)
          .get();

      if (querySnapshot.docs.isEmpty) {
        // No profile exists
        setState(() {
          _newProfile = true;
          _isLoading = false;
        });
      } else {
        // Profile exists
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        _existingDocId = doc.id;

        setState(() {
          _newProfile = false;
          _nameController.text = data['name'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _companyController.text = data['company'] ?? '';
          _addressController.text = data['address'] ?? '';
          _gstinController.text = data['gstin'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _newProfile = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_newProfile) {
        await FirebaseFirestore.instance.collection('profile').add({
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
        if (_existingDocId != null) {
          await FirebaseFirestore.instance
              .collection('profile')
              .doc(_existingDocId)
              .update({
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'company': _companyController.text.trim(),
            'address': _addressController.text.trim(),
            'gstin': _gstinController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      Fluttertoast.showToast(
        msg: _newProfile ? 'Profile created successfully!' : 'Profile updated successfully!',
        backgroundColor: Colors.green,
      );

      if (_newProfile) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Profile()),
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error saving profile: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_newProfile ? 'Create Profile' : 'Edit Profile'),
        titleTextStyle: const TextStyle(fontSize: 22, color: Colors.white),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: !_newProfile,
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Colors.indigo),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),

              // NAME - Always editable
              _buildTextField(_nameController, "Name", Icons.person),

              // PHONE - Always editable
              _buildTextField(
                _phoneController,
                "Phone",
                Icons.phone,
                prefix: "+91 ",
                keyboard: TextInputType.phone,
                maxLength: 10,
              ),

              // COMPANY - Always editable
              _buildTextField(
                _companyController,
                "Company Name",
                Icons.business,
              ),

              // ADDRESS - Always editable
              _buildTextField(
                _addressController,
                "Company Address",
                Icons.location_on,
              ),

              // GSTIN - Always editable
              _buildTextField(
                _gstinController,
                "GSTIN",
                Icons.qr_code,
              ),

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
                      : Icon(_newProfile ? Icons.add : Icons.save, color: Colors.white),
                  label: Text(
                    _isLoading
                        ? "Saving..."
                        : _newProfile
                        ? "Create Profile"
                        : "Update Profile",
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
          prefixIcon: Icon(icon, color: Colors.indigo),
          counterText: maxLength != null ? "" : null,
          filled: true,
          fillColor: Colors.white,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter $label';
          }
          if (label == "Phone" && value.trim().length != 10) {
            return 'Please enter a valid 10-digit phone number';
          }
          return null;
        },
      ),
    );
  }
}
