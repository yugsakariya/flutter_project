import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SupplierScreen extends StatelessWidget {
  const SupplierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user= FirebaseAuth.instance.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Suppliers"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('suppliers').where('user',isEqualTo: user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error loading suppliers"));
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());

          final suppliers = snapshot.data!.docs;

          if (suppliers.isEmpty) return Center(child: Text("No suppliers found"));

          return ListView.builder(
            itemCount: suppliers.length,
            itemBuilder: (context, index) {
              final data = suppliers[index].data() as Map<String, dynamic>;
              final name = data['name'] ?? 'No Name';

              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(Icons.store, color: Colors.orange),
                    title: Text(name),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
