import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

import 'AddBill.dart';
import 'EditBill.dart';
import 'pdf_generator.dart';

class BillsScreen extends StatefulWidget {
  final VoidCallback? goToDashboard;

  const BillsScreen({super.key, this.goToDashboard});

  @override
  _BillsScreenState createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (widget.goToDashboard != null) {
          widget.goToDashboard!();
          return false; // Prevent default back navigation
        }
        return true; // Allow default back navigation
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Billing'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('bills').where('user', isEqualTo: user?.uid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(color: Colors.red),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No bills found',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                DocumentSnapshot bill = snapshot.data!.docs[index];
                Map<String, dynamic> data = bill.data() as Map<String, dynamic>;

                return Card(
                  elevation: 4,
                  margin: EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.receipt, color: Colors.white),
                    ),
                    title: Text(
                      data['billNumber'] ?? 'Untitled Bill',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4),
                        Text('Customer: ${data['customerName'] ?? 'Unknown'}'),
                        Text('Total: ₹${data['total']?.toStringAsFixed(2) ?? '0.00'}'),
                        if (data['date'] != null)
                          Text(
                            'Date: ${_formatDate(data['date'])}',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.more_vert),
                      onPressed: () => _showBillActions(context, bill),
                    ),
                    onTap: () => _showBillDetails(context, data),
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NewBillScreen())
          ),
          backgroundColor: Colors.indigo,
          child: Icon(Icons.add,color: Colors.white,),
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    if (date is Timestamp) {
      DateTime dateTime = date.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
    return date.toString();
  }

  void _showBillDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['billNumber'] ?? 'Bill Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: ${data['customerName'] ?? 'Unknown'}'),
              if (data['customerPhone'] != null) ...[
                SizedBox(height: 8),
                Text('Phone: ${data['customerPhone']}'),
              ],
              SizedBox(height: 8),
              Text('Subtotal: ₹${data['subtotal']?.toStringAsFixed(2) ?? '0.00'}'),
              Text('Tax: ₹${data['tax']?.toStringAsFixed(2) ?? '0.00'}'),
              Text('Total: ₹${data['total']?.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              if (data['date'] != null) ...[
                SizedBox(height: 8),
                Text('Date: ${_formatDate(data['date'])}'),
              ],
              if (data['items'] != null) ...[
                SizedBox(height: 12),
                Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...((data['items'] as List).map((item) => Padding(
                  padding: EdgeInsets.only(left: 8, top: 4),
                  child: Text('${item['name']} - Qty: ${item['quantity']} - ₹${item['price']}'),
                ))),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBillActions(BuildContext context, DocumentSnapshot bill) {
    final data = bill.data() as Map<String, dynamic>;
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.picture_as_pdf, color: Colors.red),
              title: Text('Generate PDF'),
              onTap: () async {
                Navigator.pop(context);
                await _generatePDF(data);
              },
            ),
            ListTile(
              leading: Icon(Icons.edit),
              title: Text('Edit Bill'),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => EditBillScreen(billNumber: data['billNumber'])));
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete Bill', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteBill(context, bill);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Check and request storage permission
  Future<bool> _checkAndRequestStoragePermission() async {
    // For different Android versions, we need to handle permissions differently
    Permission permission;
    if (Platform.isAndroid) {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      if (deviceInfo.version.sdkInt >= 30) {
        // Android 11 and above
        permission = Permission.manageExternalStorage;
      } else {
        // Android 10 and below
        permission = Permission.storage;
      }
    } else {
      permission = Permission.storage;
    }

    PermissionStatus status = await permission.status;
    print('Current permission status: $status'); // Debug print

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied || status.isLimited) {
      // Request permission
      PermissionStatus result = await permission.request();
      print('Permission request result: $result'); // Debug print
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      // Show dialog to open app settings
      _showPermissionDialog();
      return false;
    }

    // If status is restricted or other
    PermissionStatus result = await permission.request();
    return result.isGranted;
  }

  // Show dialog when permission is permanently denied
  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) => AlertDialog(
        title: Text('Storage Permission Required'),
        content: Text(
          'This app needs storage permission to save PDF files. Please grant the permission in app settings to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
              // Check permission again after returning from settings
              Future.delayed(Duration(milliseconds: 500), () async {
                bool hasPermission = await _checkAndRequestStoragePermission();
                if (hasPermission) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Permission granted! You can now generate PDFs.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              });
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePDF(Map<String, dynamic> billData) async {
    try {
      // Check storage permission first
      bool hasPermission = await _checkAndRequestStoragePermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Storage permission is required to save PDF files'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      // Generate PDF and get result with file path
      final pdfResult = await PDFGenerator.generateGSTVoucher(billData: billData);
      Navigator.pop(context); // Close loading dialog

      if (pdfResult['success']) {
        // Show brief success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved to Downloads folder'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Directly open the PDF without dialog
        await _openPDFDirectly(pdfResult['localPath']);
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(pdfResult['error'] ?? 'Unknown error occurred'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Updated method to directly open PDF
  Future<void> _openPDFDirectly(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        // If opening failed, show user a brief message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved to Downloads folder. Please open manually.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error opening PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saved to Downloads folder'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Add this method to handle PDF opening
  Future<void> _openPDF(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        // If opening failed, show user a message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open PDF. Please check Downloads folder manually.'),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      print('Error opening PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please check Downloads folder for your PDF file'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _deleteBill(BuildContext context, DocumentSnapshot bill) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Bill'),
        content: Text('Are you sure you want to delete this bill?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await bill.reference.delete();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Bill deleted successfully')),
                );
              } catch (e) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting bill: $e')),
                );
              }
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
