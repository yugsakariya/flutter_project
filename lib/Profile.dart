import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'EditProfileScreen.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          Navigator.push(context,MaterialPageRoute(builder: (_)=>EditProfileScreen()));
        }

        // Fix: Correct way to access document data
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
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 55,
                  backgroundColor: Colors.indigo.withOpacity(0.1),
                  child: const CircleAvatar(
                    radius: 50,
                    backgroundImage: AssetImage('assets/images/default_avatar.png'), // Fix: Add proper asset path
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  data["name"] ?? 'No Name', // Fix: Handle null values
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  data["designation"] ?? 'Flutter Developer', // Fix: Make designation dynamic
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),

                _buildInfoCard(
                  title: 'Personal Information',
                  items: [
                    {
                      'icon': Icons.email,
                      'label': 'Email',
                      'value': data["email"] ?? user.email ?? 'No Email' // Fix: Use dynamic data
                    },
                    {
                      'icon': Icons.phone,
                      'label': 'Phone',
                      'value': data["phone"] ?? 'No Phone' // Fix: Use dynamic data
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
                      'value': data["company_name"] ?? 'No Company' // Fix: Use dynamic data
                    },
                    {
                      'icon': Icons.location_on,
                      'label': 'Address',
                      'value': data["address"] ?? 'No Address' // Fix: Use dynamic data
                    },
                    {
                      'icon': Icons.qr_code,
                      'label': 'GSTIN',
                      'value': data["gstin"] ?? 'No GSTIN' // Fix: Use dynamic data
                    },
                  ],
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfileScreen(),
                        ),
                      );
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
          )
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