import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LowStocks extends StatefulWidget {
  const LowStocks({super.key});

  @override
  State<LowStocks> createState() => _LowStocksState();
}

class _LowStocksState extends State<LowStocks> {
  final int _lowStockThreshold = 10; // Define threshold for low stock

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: const Text("Low Stock Products"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("stocks")
            .where('quantity', isLessThanOrEqualTo: _lowStockThreshold)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text("Error: ${snapshot.error}"),
            );
          }
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.data?.docs.isEmpty ?? true) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.green,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "No Low Stock Products",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "All products have sufficient stock",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              DocumentSnapshot stockDoc = snapshot.data!.docs[index];
              Map<String, dynamic> stockData = stockDoc.data() as Map<String, dynamic>;

              String productName = stockData['product'] ?? 'Unknown Product';
              int quantity = stockData['quantity'] ?? 0;
              int purchase = stockData['purchase'] ?? 0;
              int sales = stockData['sales'] ?? 0;

              // Determine severity level
              Color severityColor;
              IconData severityIcon;
              String severityText;
              
              if (quantity <= 0) {
                severityColor = Colors.red;
                severityIcon = Icons.error;
                severityText = "Out of Stock";
              } else if (quantity <= 5) {
                severityColor = Colors.orange;
                severityIcon = Icons.warning;
                severityText = "Critical";
              } else {
                severityColor = Colors.yellow.shade700;
                severityIcon = Icons.info;
                severityText = "Low";
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: severityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      severityIcon,
                      color: severityColor,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    _capitalizeFirstLetter(productName),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: severityColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              severityText,
                              style: TextStyle(
                                color: severityColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Stock: $quantity",
                            style: TextStyle(
                              color: severityColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Purchase: $purchase | Sales: $sales",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey.shade400,
                    size: 16,
                  ),
                  onTap: () {
                    // You can add navigation to product details here
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Product: ${_capitalizeFirstLetter(productName)}'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
} 