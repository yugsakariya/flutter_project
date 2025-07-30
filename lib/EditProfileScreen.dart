import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Ruchit Kadeval');
  final _phoneController = TextEditingController(text: '9876543210');
  final _companyController = TextEditingController(text: 'RK Enterprises');
  final _addressController = TextEditingController(text: '123, MG Road, Ahmedabad');
  final _gstinController = TextEditingController(text: '24ABCDE1234F1Z5');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        titleTextStyle: TextStyle(
          fontSize: 22,
          color: Colors.white,
        ),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white), // <-- makes back arrow white
        foregroundColor: Colors.white, // also sets text/icon color to white
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 55,
                backgroundColor: Colors.blueAccent.withOpacity(0.1),
                child: const CircleAvatar(
                  radius: 50,
                  backgroundImage: AssetImage('assets/avatar.png'),
                ),
              ),
              const SizedBox(height: 20),

              _buildTextField(_nameController, "Name", Icons.person),
              _buildTextField(_phoneController, "Phone", Icons.phone,
                  prefix: "+91 ", keyboard: TextInputType.phone, maxLength: 10),
              _buildTextField(_companyController, "Company Name", Icons.business),
              _buildTextField(_addressController, "Company Address", Icons.location_on),
              _buildTextField(_gstinController, "GSTIN", Icons.qr_code),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      Fluttertoast.showToast(msg: "Profile Updated");
                      Navigator.pop(context); // return to profile screen
                    }
                  },
                  icon: const Icon(Icons.save,color: Colors.white),
                  label: const Text("Save",style: TextStyle(color: Colors.white),),
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

  Widget _buildTextField(TextEditingController controller, String label, IconData icon,
      {String? prefix, TextInputType keyboard = TextInputType.text, int? maxLength}) {
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
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Please enter $label';
          return null;
        },
      ),
    );
  }
}
