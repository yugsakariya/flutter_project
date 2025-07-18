import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StockScreen extends StatefulWidget {
  final VoidCallback? goToDashboard;
  const StockScreen({super.key, this.goToDashboard});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  Map <String, dynamic> _processStockData(QuerySnapshot snapshots){
    Map<String, dynamic> products={};
    for(var doc in snapshots.docs) {
      var productName = doc['product'];
      if (!products.containsKey(productName)) {
        products[productName] = {
          'name': productName,
          'purchaseStock': 0,
          'saleStock': 0,
        };
      }
      if (doc['type'] == 'Purchase') {
        products[productName]['purchaseStock'] += doc['quantity'];
      } else if (doc['type'] == 'Sale') {
        products[productName]['saleStock'] += doc['quantity'];
      }
      products[productName]['totalStock'] = products[productName]['purchaseStock'] - products[productName]['saleStock'];
    }
    return products;
  }
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (widget.goToDashboard != null) {
          widget.goToDashboard!();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F6),
        appBar: AppBar(
          title: const Text("Stock Details"),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
        body: StreamBuilder(
          stream: FirebaseFirestore.instance.collection("transactions").snapshots(),
          builder: (context,snapshot){
            if(snapshot.hasError){
              return Center(
                child: Text("Error  {snapshot.error}"),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting){
              return Center(
                child: CircularProgressIndicator(),
              );
            }
            Map <String, dynamic> products = _processStockData(snapshot.data!);
            if(products.isEmpty){
              return Center(
                child:Text("No stocks available",style: TextStyle(fontSize:18,color: Colors.grey),),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                String productKey = products.keys.elementAt(index);
                var product = products[productKey];
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
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
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            product['name'],
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "Total:  ${product['totalStock']}",
                              style: const TextStyle(color: Colors.indigo, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      children: [
                        Container(
                          color: Colors.grey.shade50,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildDetailRow(Icons.shopping_cart, "Purchase Stock",
                                  "  ${product['purchaseStock']}", Colors.green),
                              const SizedBox(height: 10),
                              _buildDetailRow(Icons.sell, "Sale Stock",
                                  "  ${product['saleStock']}", Colors.red),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 16)),
          ],
        ),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}
