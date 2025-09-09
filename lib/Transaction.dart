import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/TransactionAdd.dart';
import 'package:flutter_project/TransactionUpdate.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

class TransactionScreen extends StatefulWidget {
  final VoidCallback? goToDashboard;
  const TransactionScreen({super.key, this.goToDashboard});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Get transaction stream with optional search
  Stream<QuerySnapshot> _getTransactionStream() {
    if (user == null) return const Stream.empty();

    var query = FirebaseFirestore.instance
        .collection('transactions')
        .where('user', isEqualTo: user!.uid)
        .orderBy("timestamp", descending: true);

    if (_searchQuery.isNotEmpty) {
      query = query
          .where('party', isGreaterThanOrEqualTo: _searchQuery.toLowerCase())
          .where('party', isLessThanOrEqualTo: '${_searchQuery.toLowerCase()}\uf8ff');
    }

    return query.snapshots();
  }

  // Show update dialog
  void _updateTransaction(String docId) {
    showDialog(
      context: context,
      builder: (context) => TransactionUpdate(docRef: docId),
    );
  }

  // Show delete confirmation dialog
  void _showDeleteDialog(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Transaction"),
        content: const Text("Are you sure you want to delete this transaction?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => _deleteTransaction(docId),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Delete transaction and update stock
  Future<void> _deleteTransaction(String docId) async {
    try {
      // Get transaction document
      final transactionDoc = await FirebaseFirestore.instance
          .collection('transactions')
          .doc(docId)
          .get();

      if (!transactionDoc.exists) {
        _showToast("Transaction not found", Colors.red);
        return;
      }

      final data = transactionDoc.data();
      if (data == null) {
        _showToast("Transaction data is null", Colors.red);
        return;
      }

      final type = data['type']?.toString() ?? '';
      final product = data['product'] as List<dynamic>? ?? [];

      if (type.isEmpty) {
        _showToast("Invalid transaction type", Colors.red);
        return;
      }

      print("Deleting transaction: Type=$type, Products=${product.length}");

      // Use batch for atomic operations
      final batch = FirebaseFirestore.instance.batch();

      // Delete the transaction
      batch.delete(FirebaseFirestore.instance.collection('transactions').doc(docId));

      // Process each product for stock updates
      for (var item in product) {
        if (item == null) continue;

        final itemMap = Map<String, dynamic>.from(item as Map);

        final productName = itemMap['product']?.toString() ?? '';
        final quantity = (itemMap['quantity'] as num?)?.toInt() ?? 0;

        if (productName.isEmpty || quantity <= 0) continue;

        print("Processing product: Product=$productName, Quantity=$quantity");

        // Find corresponding stock document
        final stockQuery = await FirebaseFirestore.instance
            .collection('stocks')
            .where('user', isEqualTo: user!.uid)
            .where('product', isEqualTo: productName)
            .limit(1)
            .get();

        if (stockQuery.docs.isEmpty) {
          print("No stock document found for product: $productName");
          continue;
        }

        final stockRef = FirebaseFirestore.instance
            .collection('stocks')
            .doc(stockQuery.docs.first.id);

        // Calculate quantity change to reverse the transaction
        final quantityChange = type == 'Purchase' ? -quantity : quantity;
        print("Quantity change to apply for $productName: $quantityChange");

        // Check if this product has other transactions
        final allTransactionsQuery = await FirebaseFirestore.instance
            .collection('transactions')
            .where('user', isEqualTo: user!.uid)
            .get();

        bool hasOtherTransactions = false;
        for (var doc in allTransactionsQuery.docs) {
          if (doc.id == docId) continue; // Skip current transaction

          final docData = doc.data();
          final docProduct = docData['product'] as List<dynamic>? ?? [];

          for (var docItem in docProduct) {
            if (docItem != null) {
              final docItemMap = Map<String, dynamic>.from(docItem as Map);
              if (docItemMap['product']?.toString() == productName) {
                hasOtherTransactions = true;
                break;
              }
            }
          }
          if (hasOtherTransactions) break;
        }

        if (!hasOtherTransactions) {
          print("Deleting stock entry for $productName as this is the last transaction");
          batch.delete(stockRef);
        } else {
          // Update stock quantity and purchase/sales totals
          print("Updating stock quantity for $productName by $quantityChange");
          Map<String, dynamic> updateData = {
            'quantity': FieldValue.increment(quantityChange)
          };

          // Also update the purchase or sales total
          if (type == 'Purchase') {
            updateData['purchase'] = FieldValue.increment(-quantity);
            print("Decreasing purchase total by $quantity");
          } else {
            updateData['sales'] = FieldValue.increment(-quantity);
            print("Decreasing sales total by $quantity");
          }

          batch.update(stockRef, updateData);
        }
      }

      await batch.commit();
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      _showToast("Transaction deleted successfully", Colors.green);
    } catch (error) {
      print("Error deleting transaction: $error");
      _showToast("Failed to delete transaction: $error", Colors.red);
    }
  }

  // Show toast message
  void _showToast(String message, Color backgroundColor) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: backgroundColor,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  // Helper method to safely get the first product name from product array
  String _getFirstProductName(Map<String, dynamic> data) {
    try {
      final product = data['product'] as List<dynamic>? ?? [];

      if (product.isNotEmpty && product[0] != null) {
        final firstProduct = Map<String, dynamic>.from(product[0] as Map);
        return firstProduct['product']?.toString() ?? 'Unknown Product';
      }
      return 'No Products';
    } catch (e) {
      print("Error getting first product name: $e");
      return 'Error Loading Product';
    }
  }

  // Helper method to safely get total quantity from product array
  int _getTotalQuantity(Map<String, dynamic> data) {
    try {
      final product = data['product'] as List<dynamic>? ?? [];

      int totalQuantity = 0;
      for (var item in product) {
        if (item != null) {
          final itemMap = Map<String, dynamic>.from(item as Map);
          totalQuantity += (itemMap['quantity'] as num?)?.toInt() ?? 0;
        }
      }
      return totalQuantity;
    } catch (e) {
      print("Error getting total quantity: $e");
      return 0;
    }
  }

  // Helper method to safely get total amount from product array
  double _getTotalAmount(Map<String, dynamic> data) {
    try {
      final product = data['product'] as List<dynamic>? ?? [];

      double totalAmount = 0.0;
      for (var item in product) {
        if (item != null) {
          final itemMap = Map<String, dynamic>.from(item as Map);
          final quantity = (itemMap['quantity'] as num?)?.toInt() ?? 0;
          final unitPrice = (itemMap['unitPrice'] as num?)?.toDouble() ?? 0.0;
          totalAmount += quantity * unitPrice;
        }
      }
      return totalAmount;
    } catch (e) {
      print("Error getting total amount: $e");
      return 0.0;
    }
  }

  // Helper method to safely get products count
  int _getProductsCount(Map<String, dynamic> data) {
    try {
      final product = data['product'] as List<dynamic>? ?? [];
      return product.where((item) => item != null).length;
    } catch (e) {
      print("Error getting products count: $e");
      return 0;
    }
  }

  // Helper method to safely get date
  DateTime? _getTransactionDate(Map<String, dynamic> data) {
    try {
      final dateField = data['date'];
      if (dateField is Timestamp) {
        return dateField.toDate();
      }
      return null;
    } catch (e) {
      print("Error getting transaction date: $e");
      return null;
    }
  }

  // Build transaction card with complete null safety
  Widget _buildTransactionCard(DocumentSnapshot doc) {
    try {
      final data = doc.data();
      if (data == null) {
        return _buildErrorCard('No data available', doc.id);
      }

      final dataMap = Map<String, dynamic>.from(data as Map);

      final type = dataMap['type']?.toString() ?? 'Unknown';
      final status = dataMap['status']?.toString() ?? 'Unknown';
      final party = dataMap['party']?.toString() ?? 'Unknown Party';

      final isPurchase = type == 'Purchase';
      final isPaid = status == 'Paid';

      final productsCount = _getProductsCount(dataMap);
      final totalQuantity = _getTotalQuantity(dataMap);
      final totalAmount = _getTotalAmount(dataMap);
      final firstProductName = _getFirstProductName(dataMap);
      final transactionDate = _getTransactionDate(dataMap);

      return Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          isPurchase ? Icons.trending_up : Icons.trending_down,
                          color: isPurchase ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            productsCount > 1
                                ? "$firstProductName (+${productsCount - 1} more)"
                                : _capitalizeFirstLetter(firstProductName),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPurchase ? Colors.purple.shade100 : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isPurchase ? Colors.purple.shade700 : Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Transaction details
              _buildDetailRow(Icons.format_list_numbered, "Products: $productsCount"),
              const SizedBox(height: 4),
              _buildDetailRow(Icons.inventory_2, "Total Qty: $totalQuantity"),
              const SizedBox(height: 4),
              _buildDetailRow(Icons.attach_money, "Total: ₹${totalAmount.toStringAsFixed(2)}"),
              const SizedBox(height: 4),
              if (transactionDate != null)
                _buildDetailRow(Icons.calendar_today, "Date: ${_formatDate(transactionDate)}"),
              if (transactionDate != null) const SizedBox(height: 4),
              _buildDetailRow(
                  Icons.local_offer,
                  "${isPurchase ? 'Supplier' : 'Customer'}: $party"
              ),

              const SizedBox(height: 12),

              // Status and actions row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isPaid ? Colors.green.shade100 : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: isPaid ? Colors.green.shade700 : Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _updateTransaction(doc.id),
                        icon: const Icon(Icons.edit, size: 20),
                        tooltip: "Update Transaction",
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _showDeleteDialog(doc.id),
                        icon: const Icon(Icons.delete, size: 20),
                        color: Colors.red.shade600,
                        tooltip: "Delete Transaction",
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print("Error building transaction card: $e");
      return _buildErrorCard('Error loading transaction: $e', doc.id);
    }
  }

  // Build error card for failed transactions
  Widget _buildErrorCard(String message, String docId) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red.shade600, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error loading transaction',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade600,
                    ),
                  ),
                  Text(
                    'Doc ID: $docId',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build detail row helper
  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  // Format date helper
  String _formatDate(DateTime date) {
    try {
      return "${date.day} ${DateFormat('MMM').format(date)} ${date.year}";
    } catch (e) {
      return "Invalid Date";
    }
  }

  // Capitalize first letter helper
  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
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
          title: const Text("Transactions"),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          elevation: 1,
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.indigo,
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => Transactionadd(),
            );
          },
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Search field
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search by party name...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              // Transaction list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _getTransactionStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              "Error loading transactions",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${snapshot.error}",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, color: Colors.grey.shade400, size: 64),
                            const SizedBox(height: 16),
                            Text(
                              "No transactions found",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Add your first transaction using the + button",
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: docs.length,
                      padding: const EdgeInsets.only(bottom: 80), // Space for FAB
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        if (doc.exists) {
                          return _buildTransactionCard(doc);
                        } else {
                          return _buildErrorCard('Document does not exist', doc.id);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
