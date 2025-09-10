import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'utils.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final user = FirebaseAuth.instance.currentUser!;

  Future<QuerySnapshot> _getdata() {
    return FirebaseFirestore.instance
        .collection('profile')
        .where('user', isEqualTo: user.uid)
        .limit(1)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: _getdata(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const EditProfileScreen();
        }

        final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('Profile'),
            titleTextStyle: const TextStyle(
              fontSize: 22,
              color: Colors.white,
            ),
            centerTitle: true,
            backgroundColor: Colors.indigo,
            iconTheme: const IconThemeData(color: Colors.white),
            foregroundColor: Colors.white,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildInfoCard(
                  title: 'Personal Information',
                  items: [
                    {
                      'icon': Icons.person,
                      'label': 'Name',
                      'value': data["name"] ?? 'No Name'
                    },
                    {
                      'icon': Icons.email,
                      'label': 'Email',
                      'value': data["email"] ?? user.email ?? 'No Email'
                    },
                    {
                      'icon': Icons.phone,
                      'label': 'Phone',
                      'value': data["phone"] ?? 'No Phone'
                    },
                  ],
                ),
                const SizedBox(height: 20),
                _buildInfoCard(
                  title: 'Company Details',
                  items: [
                    {
                      'icon': Icons.business,
                      'label': 'Company Name',
                      'value': data["company"] ?? 'No Company'
                    },
                    {
                      'icon': Icons.location_on,
                      'label': 'Address',
                      'value': data["address"] ?? 'No Address'
                    },
                    {
                      'icon': Icons.qr_code,
                      'label': 'GSTIN',
                      'value': data["gstin"] ?? 'No GSTIN'
                    },
                  ],
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfileScreen(),
                        ),
                      );
                      if (result == true && mounted) {
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.edit, color: Colors.white),
                    label: const Text(
                      'Edit Profile',
                      style: TextStyle(color: Colors.white),
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
        );
      },
    );
  }

  Widget _buildInfoCard({
    required String title,
    required List<Map<String, dynamic>> items,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map((item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(item['icon'], color: Colors.indigo),
                title: Text(
                  item['label'],
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(item['value']),
              )),
        ],
      ),
    );
  }
}

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
        setState(() {
          _newProfile = true;
        });

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
      AppUtils.showError("Error loading profile data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_newProfile) {
        await FirestoreHelper.addDocument("profile", {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'company': _companyController.text.trim(),
          'address': _addressController.text.trim(),
          'gstin': _gstinController.text.trim(),
          'email': user.email,
        });
      } else {
        final docs = await FirebaseFirestore.instance
            .collection('profile')
            .where('user', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (docs.docs.isNotEmpty) {
          await FirestoreHelper.updateDocument('profile', docs.docs.first.id, {
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'company': _companyController.text.trim(),
            'address': _addressController.text.trim(),
            'gstin': _gstinController.text.trim(),
          });
        }
      }

      AppUtils.showSuccess("Profile updated successfully");
      
      if (_newProfile) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Profile()),
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      AppUtils.showError("Error saving profile: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const SizedBox(height: 20),
                    _buildTextField(
                      _nameController,
                      "Name",
                      Icons.person,
                      canChange: true,
                    ),
                    _buildTextField(
                      _phoneController,
                      "Phone",
                      Icons.phone,
                      prefix: "+91 ",
                      keyboard: TextInputType.phone,
                      maxLength: 10,
                      canChange: true,
                    ),
                    _buildTextField(
                      _companyController,
                      "Company Name",
                      Icons.business,
                      canChange: _newProfile?true:false,
                    ),
                    _buildTextField(
                      _addressController,
                      "Company Address",
                      Icons.location_on,
                      canChange: _newProfile?true:false,
                    ),
                    _buildTextField(
                      _gstinController,
                      "GSTIN",
                      Icons.qr_code,
                      canChange: _newProfile?true:false,
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
      child: AppTextField(
        controller: controller,
        labelText: label,
        prefixIcon: icon,
        prefixText: prefix,
        keyboardType: keyboard,
        maxLength: maxLength,
        enabled: canChange,
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