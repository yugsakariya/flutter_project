import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';

import 'utils.dart';
import 'report_generator.dart';
import 'Profile.dart';
import 'party_management.dart';
import 'Stocks.dart';
import 'LowStocks.dart';

class Dashboard extends StatefulWidget {
  final void Function(int)? onTabChange;
  const Dashboard({super.key, this.onTabChange});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final user = FirebaseAuth.instance.currentUser!;

  Future<bool> _checkStoragePermission() async {
    if (Platform.isAndroid) {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      final permission = deviceInfo.version.sdkInt >= 30 
          ? Permission.manageExternalStorage 
          : Permission.storage;
      
      if (await permission.isGranted) return true;
      
      final status = await permission.request();
      if (!status.isGranted) {
        _showPermissionDialog();
        return false;
      }
    }
    return true;
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Permission Required'),
        content: const Text('Please grant storage permission to save PDF reports.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    DateTime? fromDate;
    DateTime? toDate;
    String type = "Both";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Generate PDF Report"),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ListTile(
                    title: Text(fromDate == null 
                        ? "Select From Date" 
                        : "From: ${DateFormat('dd/MM/yyyy').format(fromDate!)}"),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => fromDate = picked);
                    },
                  ),
                  ListTile(
                    title: Text(toDate == null 
                        ? "Select To Date" 
                        : "To: ${DateFormat('dd/MM/yyyy').format(toDate!)}"),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => toDate = picked);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(
                      labelText: "Transaction Type",
                      border: OutlineInputBorder(),
                    ),
                    items: ["Purchase", "Sale", "Both"]
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (value) => setState(() => type = value ?? "Both"),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (fromDate == null || toDate == null) {
                  AppUtils.showWarning("Please select both dates");
                  return;
                }
                Navigator.pop(context);
                _generateReport(fromDate!, toDate!, type);
              },
              child: const Text("Generate"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateReport(DateTime from, DateTime to, String type) async {
    if (!await _checkStoragePermission()) return;

    LoadingDialog.show(context, "Generating PDF report...");

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("transactions")
          .where("user", isEqualTo: user.uid)
          .where("timestamp", isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where("timestamp", isLessThanOrEqualTo: Timestamp.fromDate(to))
          .get();

      if (snapshot.docs.isEmpty) {
        LoadingDialog.hide(context);
        AppUtils.showWarning("No transactions found in selected range");
        return;
      }

      final filtered = snapshot.docs.where((doc) {
        final data = doc.data();
        return type == "Both" || data['type'] == type;
      }).toList();

      if (filtered.isEmpty) {
        LoadingDialog.hide(context);
        AppUtils.showWarning("No matching transactions found");
        return;
      }

      // Calculate totals
      double totalPurchase = 0;
      double totalSales = 0;

      for (var doc in filtered) {
        final data = doc.data();
        final products = data['product'] as List? ?? [];
        for (var product in products) {
          if (product is Map) {
            final qty = (product['quantity'] as num?)?.toInt() ?? 0;
            final price = (product['unitPrice'] as num?)?.toDouble() ?? 0.0;
            final amount = qty * price;
            
            if (data['type'] == "Purchase") totalPurchase += amount;
            if (data['type'] == "Sale") totalSales += amount;
          }
        }
      }

      final reportData = {
        "from": from,
        "to": to,
        "product": "All Products",
        "transactions": filtered.map((doc) => doc.data()).toList(),
        "totalPurchase": totalPurchase,
        "totalSales": totalSales,
        "type": type,
      };

      final pdfPath = await ReportGenerator.generateReport(reportData);
      LoadingDialog.hide(context);
      
      await OpenFile.open(pdfPath);
      AppUtils.showSuccess("Report generated successfully");

    } catch (e) {
      LoadingDialog.hide(context);
      AppUtils.showError("Failed to generate report: $e");
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      AppUtils.showError("Error logging out. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App'),
            content: const Text('Are you sure you want to exit?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        ) ?? false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: _buildAppBar(),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildLowStockCard()),
                  Expanded(child: _buildStockCard()),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildSuppliersCard()),
                  Expanded(child: _buildCustomersCard()),
                ],
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  const Text(
                    "Recent Transactions",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => widget.onTabChange?.call(2),
                    child: const Text("View More"),
                  ),
                ],
              ),
              _buildRecentTransactions(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.indigo,
      automaticallyImplyLeading: false,
      title: const Text("Dashboard"),
      titleTextStyle: const TextStyle(fontSize: 22, color: Colors.white),
      actions: [
        IconButton(
          icon: const Icon(Icons.description, color: Colors.white),
          onPressed: _showReportDialog,
          tooltip: "Generate Report",
        ),
        IconButton(
          icon: const Icon(Icons.account_circle, color: Colors.white),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Profile()),
          ),
          tooltip: 'Profile',
        ),
        PopupMenuButton(
          onSelected: (value) {
            if (value == 'logout') _logout();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Logged in as:',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    user.email ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Logout'),
                ],
              ),
            ),
          ],
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.more_vert, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildLowStockCard() {
    return StatsCard(
      title: "Low Stock",
      icon: Icons.warning,
      color: Colors.redAccent,
      stream: FirebaseFirestore.instance
          .collection("stocks")
          .where('quantity', isLessThanOrEqualTo: 10)
          .where("user", isEqualTo: user.uid)
          .snapshots(),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LowStocks()),
      ),
    );
  }

  Widget _buildStockCard() {
    return StatsCard(
      title: "Stock",
      icon: Icons.shopping_cart,
      color: Colors.indigo,
      stream: FirebaseFirestore.instance
          .collection("stocks")
          .where("user", isEqualTo: user.uid)
          .snapshots(),
      onTap: () => widget.onTabChange?.call(1),
    );
  }

  Widget _buildSuppliersCard() {
    return StatsCard(
      title: "Suppliers",
      icon: Icons.local_shipping,
      color: Colors.orange,
      stream: FirebaseFirestore.instance
          .collection("suppliers")
          .where("user", isEqualTo: user.uid)
          .snapshots(),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PartyScreen(partyType: PartyType.supplier)),
      ),
    );
  }

  Widget _buildCustomersCard() {
    return StatsCard(
      title: "Customers",
      icon: Icons.account_circle,
      color: Colors.green,
      stream: FirebaseFirestore.instance
          .collection("customers")
          .where("user", isEqualTo: user.uid)
          .snapshots(),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PartyScreen(partyType: PartyType.customer)),
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("transactions")
          .orderBy("timestamp", descending: true)
          .where("user", isEqualTo: user.uid)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              children: [
                Icon(Icons.receipt_long, color: Colors.grey, size: 48),
                SizedBox(height: 8),
                Text('No recent transactions found'),
              ],
            ),
          );
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _buildTransactionCard(data);
          }).toList(),
        );
      },
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> data) {
    try {
      final type = data['type']?.toString() ?? 'Unknown';
      final party = data['party']?.toString() ?? 'Unknown';
      final products = data['product'] as List? ?? [];
      
      String productName = 'No Products';
      double totalAmount = 0.0;
      
      if (products.isNotEmpty && products[0] != null) {
        final firstProduct = products[0] as Map<String, dynamic>;
        productName = firstProduct['product']?.toString() ?? 'Unknown Product';
        
        for (var product in products) {
          if (product != null) {
            final productMap = product as Map<String, dynamic>;
            final quantity = (productMap['quantity'] as num?)?.toInt() ?? 0;
            final unitPrice = (productMap['unitPrice'] as num?)?.toDouble() ?? 0.0;
            totalAmount += quantity * unitPrice;
          }
        }
        
        if (products.length > 1) {
          productName = "$productName (+${products.length - 1} more)";
        }
      }

      final timestamp = data['timestamp'];
      String dateString = "No Date";
      if (timestamp is Timestamp) {
        dateString = DateFormat('dd-MM-yyyy').format(timestamp.toDate());
      }

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: type == 'Purchase' ? Colors.green : Colors.red,
            child: Icon(
              type == 'Purchase' ? Icons.trending_up : Icons.trending_down,
              color: Colors.white,
            ),
          ),
          title: Text(AppUtils.capitalize(productName)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${type == 'Purchase' ? 'Supplier' : 'Customer'}: $party'),
              Text('Date: $dateString'),
            ],
          ),
          trailing: Text(
            '₹${totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    } catch (e) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: const Icon(Icons.error, color: Colors.red),
          title: const Text('Error loading transaction'),
          subtitle: Text('Error: $e'),
        ),
      );
    }
  }
}