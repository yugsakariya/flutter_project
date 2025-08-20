import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/Customers.dart';
import 'package:flutter_project/Stocks.dart';
import 'package:flutter_project/Profile.dart';
import 'package:flutter_project/LowStocks.dart';
import 'package:flutter_project/login.dart';
import 'package:flutter_project/main.dart';
import 'package:flutter_project/pdf_generator.dart';
import 'package:flutter_project/report_generator.dart';
import 'package:flutter_project/supplier.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'Transaction.dart';

class Dashboard extends StatefulWidget {
  final void Function(int)? onTabChange;
  const Dashboard({super.key, this.onTabChange});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final user = FirebaseAuth.instance.currentUser!;

  Future<bool> _showExitDialog() async {
    return await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
      ),
    ) ?? false;
  }

  Future<bool> _checkAndRequestStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        // Get Android version
        final deviceInfo = await DeviceInfoPlugin().androidInfo;
        final sdkInt = deviceInfo.version.sdkInt;
        print("Android SDK version: $sdkInt");

        Permission permission;

        if (sdkInt >= 30) {
          // Android 11 and above - use MANAGE_EXTERNAL_STORAGE
          permission = Permission.manageExternalStorage;
        } else {
          // Android 10 and below - use WRITE_EXTERNAL_STORAGE
          permission = Permission.storage;
        }

        // Check current status
        PermissionStatus status = await permission.status;
        print("Current permission status: $status");

        if (status.isGranted) {
          return true;
        }

        if (status.isDenied) {
          // Show explanation before requesting
          bool shouldRequest = await _showPermissionExplanationDialog();
          if (!shouldRequest) return false;

          // Request permission
          status = await permission.request();
          print("Permission request result: $status");

          if (status.isGranted) {
            _showPermissionGrantedMessage();
            return true;
          } else if (status.isPermanentlyDenied) {
            _showPermissionPermanentlyDeniedDialog();
            return false;
          } else {
            _showPermissionDeniedDialog();
            return false;
          }
        }

        if (status.isPermanentlyDenied) {
          _showPermissionPermanentlyDeniedDialog();
          return false;
        }

        // For any other status, try requesting
        status = await permission.request();
        return status.isGranted;
      } else {
        // For iOS, storage permission is usually not required
        return true;
      }
    } catch (e) {
      print("Permission error: $e");
      _showPermissionErrorDialog(e.toString());
      return false;
    }
  }

  Future<bool> _showPermissionExplanationDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Storage Permission Needed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This app needs storage permission to:'),
            SizedBox(height: 8),
            Text('• Save PDF reports to your device'),
            Text('• Allow you to access generated reports'),
            SizedBox(height: 12),
            Text('Please allow storage access in the next dialog.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Continue'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showPermissionGrantedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Storage permission granted! You can now generate PDF reports.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Permission Denied'),
        content: Text(
          'Storage permission was denied. PDF reports cannot be saved without this permission.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Try requesting permission again
              await _checkAndRequestStoragePermission();
            },
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showPermissionPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Permission Required'),
        content: Text(
          'Storage permission has been permanently denied. Please enable it manually in app settings to generate PDF reports.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();

              // Check permission again after user returns from settings
              Future.delayed(Duration(seconds: 1), () async {
                final hasPermission = await _checkAndRequestStoragePermission();
                if (hasPermission) {
                  _showPermissionGrantedMessage();
                }
              });
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showPermissionErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permission Error'),
        content: Text('An error occurred while requesting storage permission:\n$error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
  void _showReportFilterDialog(BuildContext context) async {
    DateTime? fromDate;
    DateTime? toDate;
    String type = "Both";
    List<String> products = [];
    List<String> selectedProducts = [];
    bool allProductsSelected = true;

    try {
      // Fetch all product names for the checkbox list
      final stockSnapshot = await FirebaseFirestore.instance
          .collection("stocks")
          .where("user", isEqualTo: user.uid)
          .get();
      products = stockSnapshot.docs.map((doc) => doc['product'].toString()).toList();
      // Initially select all products
      selectedProducts = List.from(products);
      print("Found ${products.length} products");
    } catch (e) {
      print("Error fetching products: $e");
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Generate PDF Report"),
          content: StatefulBuilder(
            builder: (context, setState) => Container(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.6, // 60% of screen height
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // From Date Picker
                    ListTile(
                      title: Text(fromDate == null
                          ? "Select From Date"
                          : "From: ${fromDate!.day}/${fromDate!.month}/${fromDate!.year}"),
                      trailing: Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => fromDate = picked);
                      },
                    ),

                    // To Date Picker
                    ListTile(
                      title: Text(toDate == null
                          ? "Select To Date"
                          : "To: ${toDate!.day}/${toDate!.month}/${toDate!.year}"),
                      trailing: Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => toDate = picked);
                      },
                    ),

                    SizedBox(height: 16),

                    // Product Selection Section
                    Text(
                      'Select Products:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),

                    // All Products Checkbox
                    CheckboxListTile(
                      title: Text(
                        'All Products',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      value: allProductsSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          allProductsSelected = value ?? false;
                          if (allProductsSelected) {
                            selectedProducts = List.from(products);
                          } else {
                            selectedProducts.clear();
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),

                    Divider(),

                    // Individual Product Checkboxes (Scrollable)
                    Container(
                      height: 200, // Fixed height for scrollable area
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: products.isEmpty
                          ? Center(
                        child: Text(
                          'No products found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                          : ListView.builder(
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return CheckboxListTile(
                            title: Text(product),
                            value: selectedProducts.contains(product),
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  if (!selectedProducts.contains(product)) {
                                    selectedProducts.add(product);
                                  }
                                } else {
                                  selectedProducts.remove(product);
                                }

                                // Update "All Products" checkbox state
                                allProductsSelected = selectedProducts.length == products.length;
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          );
                        },
                      ),
                    ),

                    SizedBox(height: 16),

                    // Selected count display
                    Text(
                      'Selected: ${selectedProducts.length} of ${products.length} products',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),

                    SizedBox(height: 16),

                    // Type dropdown
                    Row(
                      children: [
                        Text("Transaction Type: "),
                        SizedBox(width: 16),
                        Expanded(
                          child: DropdownButton<String>(
                            value: type,
                            isExpanded: true,
                            items: [
                              DropdownMenuItem(value: "Purchase", child: Text("Purchase")),
                              DropdownMenuItem(value: "Sale", child: Text("Sale")),
                              DropdownMenuItem(value: "Both", child: Text("Both")),
                            ],
                            onChanged: (val) {
                              setState(() {
                                if (val != null) type = val;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (fromDate == null || toDate == null) {
                  Fluttertoast.showToast(
                      msg: "Please select From and To dates",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      timeInSecForIosWeb: 2,
                      backgroundColor: Colors.red,        // Or your preferred color
                      textColor: Colors.white,
                      fontSize: 16.0
                  );

                  return;
                }

                if (selectedProducts.isEmpty) {
                  Fluttertoast.showToast(
                      msg: "Please select at least one product",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      timeInSecForIosWeb: 2,
                      backgroundColor: Colors.red,        // Or your preferred color
                      textColor: Colors.white,
                      fontSize: 16.0
                  );

                  return;
                }

                Navigator.of(context).pop();
                _generateReportPDF(
                  from: fromDate!,
                  to: toDate!,
                  type: type,
                  selectedProducts: selectedProducts,
                );
              },
              child: Text("Generate"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _generateReportPDF({
    required DateTime from,
    required DateTime to,
    required String type,
    List<String>? selectedProducts,
  }) async {
    print("Starting PDF generation process with from: $from, to: $to type: $type products: $selectedProducts");

    // 1. Check permission FIRST
    bool hasPermission = await _checkAndRequestStoragePermission();
    if (!hasPermission) {
      Fluttertoast.showToast(
          msg: "Storage permission is required for PDF export.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 2,
          backgroundColor: Colors.red,        // Or your preferred color
          textColor: Colors.white,
          fontSize: 16.0
      );

      return;
    }

    // 2. Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Generating PDF report..."),
          ],
        ),
      ),
    );

    try {
      // 3. Run Firestore query on 'timestamp' field
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection("transactions")
          .where("user", isEqualTo: user.uid)
          .where("timestamp", isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where("timestamp", isLessThanOrEqualTo: Timestamp.fromDate(to))
          .get();

      print("Fetched ${snapshot.docs.length} documents from Firestore.");

      if (snapshot.docs.isEmpty) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        Fluttertoast.showToast(
            msg: "No transactions found in selected range.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 2,
            backgroundColor: Colors.red,        // Or your preferred color
            textColor: Colors.white,
            fontSize: 16.0
        );

        return;
      }

      // 4. Filter results as needed
      final filtered = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;

        // Filter by selected products (if not all products selected)
        if (selectedProducts != null && selectedProducts.isNotEmpty) {
          if (!selectedProducts.contains(data['product'])) return false;
        }

        // Filter by transaction type
        if (type != "Both" && data['type'] != type) return false;

        return true;
      }).toList();

      print("After filter: ${filtered.length} records remain.");

      if (filtered.isEmpty) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        Fluttertoast.showToast(
            msg: "No matching transactions after filter.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 2,
            backgroundColor: Colors.red,        // Or your preferred color
            textColor: Colors.white,
            fontSize: 16.0
        );

        return;
      }

      // 5. Sum totals robustly
      double totalPurchase = 0;
      double totalSales = 0;
      for (var doc in filtered) {
        final data = doc.data() as Map<String, dynamic>;
        final qty = (data['quantity'] as int?) ?? 0;
        final price = (data['unitPrice'] as num?)?.toDouble() ?? 0.0;
        final amount = qty * price;
        if (data['type'] == "Purchase") totalPurchase += amount;
        if (data['type'] == "Sale") totalSales += amount;
      }

      if (kDebugMode) {
        print("TotalPurchase: $totalPurchase, TotalSales: $totalSales");
      }

      String productFilter = "All Products";
      if (selectedProducts != null && selectedProducts.isNotEmpty) {
        if (selectedProducts.length == 1) {
          productFilter = selectedProducts.first;
        } else {
          productFilter = "${selectedProducts.length} selected products";
        }
      }


      final reportData = {
        "from": from,
        "to": to,
        "product": productFilter,
        "transactions": filtered.map((doc) => doc.data()).toList(),
        "totalPurchase": totalPurchase,
        "totalSales": totalSales,
        "type": type,
      };

      // 6. Generate PDF (await!)
      final pdfPath = await ReportGenerator.generateReport(reportData);
      print("PDF file generated at $pdfPath");

      if (Navigator.canPop(context)) Navigator.pop(context); // close dialog

      final openResult = await OpenFile.open(pdfPath);
      print("OpenFile.open result: ${openResult.type}");


    } catch (e, stack) {
      print("Error in PDF export: $e $stack");
      if (Navigator.canPop(context)) Navigator.pop(context);
      Fluttertoast.showToast(
          msg: "Failed: $e",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 2,
          backgroundColor: Colors.red,        // Or your preferred color
          textColor: Colors.white,
          fontSize: 16.0
      );

    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      Fluttertoast.showToast(
          msg: "Error logging out. Please try again.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 2,
          backgroundColor: Colors.red,        // Or your preferred color
          textColor: Colors.white,
          fontSize: 16.0
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
          titleTextStyle: TextStyle(fontSize: 22, color: Colors.white),
          actions: [
            IconButton(
              icon: Icon(Icons.report, color: Colors.white),
              tooltip: "Generate Report",
              onPressed: () {
                _showReportFilterDialog(context);
              },
            ),
            IconButton(
              icon: Icon(Icons.account_circle, size: 28, color: Colors.white),
              tooltip: 'Profile',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Profile()),
              ),
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
                      Text('Logged in as:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      Text(user.email ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                      Divider(),
                    ],
                  ),
                ),
                PopupMenuItem(
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
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.more_vert, size: 24, color: Colors.white),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [_buildLowStockCard(), _buildStockCard()],
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [_buildsuppliersCard(), _buildcustomerCard()],
              ),
              SizedBox(height: 30),
              Row(
                children: [
                  _buildSectionTitle("Recent Transactions"),
                  Spacer(),
                  TextButton(
                    onPressed: () => widget.onTabChange?.call(2),
                    child: Text("View More "),
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
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No transactions found'));
        }

        final transactions = snapshot.data!.docs.map((doc) => {
          "title": _capitalizeFirstLetter(doc['product'] ?? 'Unknown Product'),
          "amount": "₹${doc['unitPrice'] ?? '0'}",
          "timestamp": (doc['timestamp'] != null && doc['timestamp'] is Timestamp)
              ? DateFormat('dd-MM-yyyy').format(doc['timestamp'].toDate())
              : 'No Date'
        }).toList();

        return _buildRecentList(transactions);
      },
    );
  }

  Widget _buildLowStockCard() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("stocks")
            .where('quantity', isLessThanOrEqualTo: 10)
            .where("user", isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final lowStockCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LowStocks()),
            ),
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
                    Text(lowStockCount.toString(),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildsuppliersCard() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("suppliers")
            .where("user", isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final supplierCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SupplierScreen()),
            ),
            child: Card(
              elevation: 3,
              margin: EdgeInsets.all(8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                child: Column(
                  children: [
                    Icon(Icons.local_shipping, color: Colors.orange, size: 30),
                    SizedBox(height: 10),
                    Text("Suppliers", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                    Text(supplierCount.toString(),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildcustomerCard() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("customers")
            .where("user", isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final customerCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CustomerScreen()),
            ),
            child: Card(
              elevation: 3,
              margin: EdgeInsets.all(8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                child: Column(
                  children: [
                    Icon(Icons.account_circle, color: Colors.green, size: 30),
                    SizedBox(height: 10),
                    Text("Customer", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                    Text(customerCount.toString(),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
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
        stream: FirebaseFirestore.instance.collection("stocks").where("user", isEqualTo: user.uid).snapshots(),
        builder: (context, snapshot) {
          final totalStockCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
          return GestureDetector(
            onTap: () => widget.onTabChange?.call(1),
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
                    Text(totalStockCount.toString(),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
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
      child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildRecentList(List<Map<String, String>> items) {
    return Column(
      children: items.map((item) => Card(
        margin: EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          title: Text(item['title'] ?? ""),
          subtitle: Text(item['timestamp'] ?? ""),
          trailing: Text(item['amount'] ?? "", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      )).toList(),
    );
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}
