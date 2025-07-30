import 'package:flutter/material.dart';

import 'EditProfileScreen.dart';

class Profile extends StatelessWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile'),
        titleTextStyle: TextStyle(
          fontSize: 22,
          color: Colors.white,
        ),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white), // <-- makes back arrow white
        foregroundColor: Colors.white, // also sets text/icon color to white
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
                backgroundImage: AssetImage('assets/avatar.png'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ruchit Kadeval',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Flutter Developer',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),

            _buildInfoCard(
              title: 'Personal Information',
              items: const [
                {'icon': Icons.email, 'label': 'Email', 'value': 'ruchit@example.com'},
                {'icon': Icons.phone, 'label': 'Phone', 'value': '+91 98765 43210'},
              ],
            ),

            const SizedBox(height: 20),

            _buildInfoCard(
              title: 'Company Details',
              items: const [
                {'icon': Icons.business, 'label': 'Company Name', 'value': 'RK Enterprises'},
                {'icon': Icons.location_on, 'label': 'Address', 'value': '123, MG Road, Ahmedabad'},
                {'icon': Icons.qr_code, 'label': 'GSTIN', 'value': '24ABCDE1234F1Z5'},
              ],
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                  );
                },
                icon: const Icon(Icons.edit,color: Colors.white,),
                label: const Text('Edit Profile',style: TextStyle(color: Colors.white),),
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
            style:
            const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
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
