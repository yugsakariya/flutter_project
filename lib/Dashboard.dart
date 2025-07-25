import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/Stocks.dart';
import 'package:flutter_project/Profile.dart';
import 'package:flutter_project/LowStocks.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // Logout function
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      // AuthWrapper will automatically handle the redirect to login screen
      Navigator.pop(context);

    } catch (e) {
      print('Error logging out: $e');
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error logging out. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
              icon: Icon(Icons.account_circle, size: 28, color: Colors.white),
              tooltip: 'Profile',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Profile()),
                );
              },
            ),
            // User info and logout popup menu
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'logout') {
                  _logout();
                }
              },
              itemBuilder: (BuildContext context) {
                final user = FirebaseAuth.instance.currentUser;
                return [
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Logged in as:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          user?.email ?? 'Unknown',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Divider(),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Logout'),
                      ],
                    ),
                  ),
                ];
              },
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.more_vert, size: 24, color: Colors.white),
                  ],
                ),
              ),
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
                  _buildLowStockCard(),
                  _buildStockCard(),
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
                      "title": _capitalizeFirstLetter(doc['product'] ?? 'Unknown Product'),
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

  Widget _buildLowStockCard() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("stocks")
            .where('quantity', isLessThanOrEqualTo: 10)
            .snapshots(),
        initialData: null,
        builder: (context, snapshot) {
          int lowStockCount = 0;
          if (snapshot.hasData) {
            lowStockCount = snapshot.data!.docs.length;
          }

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LowStocks()),
              );
            },
            child: Card(
              elevation: 3,
              margin: EdgeInsets.all(8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                child: Column(
                  children: [
                    Icon(Icons.warning, color: Colors.redAccent, size: 30),
                    SizedBox(height: 10),
                    Text("Low Stock", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                    Text(
                      lowStockCount.toString(),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStockCard() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("stocks")
            .snapshots(),
        initialData: null,
        builder: (context, snapshot) {
          int totalStockCount = 0;
          if (snapshot.hasData) {
            totalStockCount = snapshot.data!.docs.length;
          }

          return GestureDetector(
            onTap: () {
              if (widget.onTabChange != null) {
                widget.onTabChange!(1); // Stocks tab index
              }
            },
            child: Card(
              elevation: 3,
              margin: EdgeInsets.all(8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                child: Column(
                  children: [
                    Icon(Icons.shopping_cart, color: Colors.indigo, size: 30),
                    SizedBox(height: 10),
                    Text("Stock", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                    Text(
                      totalStockCount.toString(),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}