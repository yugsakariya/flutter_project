import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/Stocks.dart';
import 'package:flutter_project/Profile.dart';
import 'package:intl/intl.dart';

import 'Transaction.dart';

class Dashboard extends StatefulWidget {
  final void Function(int)? onTabChange;
  const Dashboard({super.key, this.onTabChange});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {

  Future<bool> _showExitDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must tap button to dismiss
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Exit App'),
          content: Text('Are you sure you want to exit?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Yes'),
            ),
          ],
        );
      },
    ) ?? false; // Return false if dialog is dismissed
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _showExitDialog,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: Colors.indigo,
          automaticallyImplyLeading: false,
          title: Text("Dashboard"),
          titleTextStyle: TextStyle(
            fontSize: 22,
            color: Colors.white,
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.account_circle, size: 28,color: Colors.white,),
              tooltip: 'Profile',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Profile()),
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding:EdgeInsets.all(16),
          child: Column(
            children: [
              // Summary Cards
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryCard("Low Stock", "5", Colors.redAccent, Icons.warning),
                  _buildSummaryCard("Stock", "24", Colors.indigo, Icons.shopping_cart),
                ],
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryCard("Total Category", "6", Colors.green, Icons.category),
                  _buildSummaryCard("Suppliers", "10", Colors.orange, Icons.store),
                ],
              ),

              SizedBox(height: 30),
              Row(
                children: [
                  _buildSectionTitle("Recent Transactions"),
                  Spacer(flex: 1),
                  TextButton(
                    onPressed: () {
                      if (widget.onTabChange != null) {
                        widget.onTabChange!(2); // Transactions tab index
                      }
                    },
                    child: Text("View More ")
                  )
                ],
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("transactions")
                    .orderBy("timestamp", descending: true)
                    .limit(3)
                    .snapshots(),
                builder: (context, snapshot) {
                  // Handle loading state
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('No transactions found'));
                  }
                  if (snapshot.hasData){
                    print(snapshot.data!.docs.map((doc)=>doc.data()).toList());
                  }
                  List<Map<String, dynamic>> transactions = [];
                  for (var doc in snapshot.data!.docs) {
                    transactions.add({
                      "title": doc['product'] ?? 'Unknown Product',
                      "amount": "₹${doc['unitPrice'] ?? '0'}",
                      "date": (doc['date'] != null && doc['date'] is Timestamp)
                          ? DateFormat('dd-MM-yyyy').format(doc['date'].toDate())
                          : 'No Date'
                    });
                  }

                  return _buildRecentList(transactions);
                },
              ),

              SizedBox(height: 24),

              // Recent Billing
              _buildSectionTitle("Recent Billing"),
              _buildRecentList([
                {"title": "Invoice #4523", "amount": "₹1200", "date": "30 Jun 2025"},
                {"title": "Invoice #4522", "amount": "₹800", "date": "29 Jun 2025"},
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String count, Color color, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 3,
        margin: EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 30),
              SizedBox(height: 10),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              SizedBox(height: 6),
              Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildRecentList(List<Map<String, dynamic>> items) {
    return Column(
      children: items.map((item) {
        return Card(
          margin: EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            title: Text(item['title'] ?? ""),
            subtitle: Text(item['date'] ?? ""),
            trailing: Text(
              item['amount'] ?? "",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }).toList(),
    );
  }
}