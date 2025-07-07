import 'package:flutter/material.dart';
import 'package:flutter_project/ProductList.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        automaticallyImplyLeading: false,
        title: Text("Dashboard"),
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.account_circle, size: 28),
            tooltip: 'Profile',
            onPressed: () {
              // Add navigation or action for profile
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Profile tapped')),
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
                _buildSummaryCard("Total Product", "24", Colors.indigo, Icons.shopping_cart),
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

            // Recent Transactions
            _buildSectionTitle("Recent Transactions"),
            _buildRecentList([
              {"title": "Chilli Purchase", "amount": "- ₹2000", "date": "01 Jul 2025"},
              {"title": "Onion Sale", "amount": "+ ₹1200", "date": "30 Jun 2025"},
            ]),
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

  Widget _buildRecentList(List<Map<String, String>> items) {
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