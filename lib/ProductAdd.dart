// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
//
// class StockScreen extends StatefulWidget {
//   const StockScreen({super.key});
//
//   @override
//   State<StockScreen> createState() => _StockScreenState();
// }
//
// class _StockScreenState extends State<StockScreen> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF6F6F6),
//       appBar: AppBar(
//         title: const Text("Stock Details"),
//         backgroundColor: Colors.indigo,
//         foregroundColor: Colors.white,
//       ),
//       body: StreamBuilder<QuerySnapshot>(
//         stream: FirebaseFirestore.instance.collection('products').snapshots(),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }
//           if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//             return const Center(child: Text("No products available"));
//           }
//
//           final products = snapshot.data!.docs;
//
//           return ListView.builder(
//             padding: const EdgeInsets.all(16),
//             itemCount: products.length,
//             itemBuilder: (context, index) {
//               var product = products[index];
//               return Container(
//                 margin: const EdgeInsets.only(bottom: 12),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(12),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.grey.withOpacity(0.1),
//                       spreadRadius: 1,
//                       blurRadius: 4,
//                       offset: const Offset(0, 3),
//                     )
//                   ],
//                 ),
//                 child: ExpansionTile(
//                   title: Text(
//                     "${product['name']} (${product['code']})",
//                     style: const TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   children: [
//                     Container(
//                       color: Colors.grey.shade100,
//                       padding: const EdgeInsets.all(12),
//                       child: Column(
//                         children: [
//                           _buildRow("Stock", "${product['stock']} units"),
//                           _buildRow("Unit Price", "₹${product['price']}"),
//                           if (product['category'] != null)
//                             _buildRow("Category", product['category']),
//                           _buildRow(
//                               "Last Updated",
//                               DateFormat('dd MMM yyyy').format(
//                                   (product['updatedAt'] as Timestamp).toDate())),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
//
//   Widget _buildRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
//           Text(value, style: const TextStyle(color: Colors.black87)),
//         ],
//       ),
//     );
//   }
// }
