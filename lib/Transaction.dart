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
    var query = FirebaseFirestore.instance
        .collection('transactions')
        .where('user', isEqualTo: user!.uid).orderBy("timestamp",descending: true);

    if (_searchQuery.isNotEmpty) {
      query = query
          .where('product', isGreaterThanOrEqualTo: _searchQuery.toLowerCase())
          .where('product', isLessThanOrEqualTo: '${_searchQuery}\uf8ff'.toLowerCase());
    }

    return query.snapshots();
  }

  // Show update dialog
  void _updateTransaction(String docId) {
    showDialog(
      context: context,
      builder: (context) => Transactionupdate(docRef: docId),
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
  // Delete transaction and update stock
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

      final data = transactionDoc.data() as Map<String, dynamic>;
      final product = data['product'] as String;
      final type = data['type'] as String;
      final quantity = data['quantity'] as int;

      print("Deleting transaction: Product=$product, Type=$type, Quantity=$quantity");

      // Find corresponding stock document
      final stockQuery = await FirebaseFirestore.instance
          .collection('stocks')
          .where('user', isEqualTo: user!.uid)
          .where('product', isEqualTo: product)
          .limit(1)
          .get();

      if (stockQuery.docs.isEmpty) {
        print("No stock document found for product: $product");
        // Just delete the transaction if no stock found
        await FirebaseFirestore.instance.collection('transactions').doc(docId).delete();
        Navigator.of(context, rootNavigator: true).pop();
        _showToast("Transaction deleted (no stock found)", Colors.orange);
        return;
      }

      // Get current stock data for debugging
      final currentStock = stockQuery.docs.first.data();
      final currentQuantity = currentStock['quantity'] as int;
      final currentPurchase = currentStock['purchase'] as int;
      final currentSales = currentStock['sales'] as int;

      print("Current stock - Quantity: $currentQuantity, Purchase: $currentPurchase, Sales: $currentSales");

      // Use batch for atomic operations
      final batch = FirebaseFirestore.instance.batch();

      // Delete the transaction
      batch.delete(FirebaseFirestore.instance.collection('transactions').doc(docId));

      final stockRef = FirebaseFirestore.instance
          .collection('stocks')
          .doc(stockQuery.docs.first.id);

      // Calculate quantity change to reverse the transaction
      // Purchase increases stock, so deleting should decrease it
      // Sale decreases stock, so deleting should increase it
      final quantityChange = type == 'Purchase' ? -quantity : quantity;
      print("Quantity change to apply: $quantityChange");

      // Check remaining transactions BEFORE deleting current one
      final allTransactionsQuery = await FirebaseFirestore.instance
          .collection('transactions')
          .where('user', isEqualTo: user!.uid)
          .where('product', isEqualTo: product)
          .get();

      print("Total transactions for this product: ${allTransactionsQuery.docs.length}");

      // If this is the last transaction for this product, delete stock entry
      if (allTransactionsQuery.docs.length <= 1) {
        print("Deleting stock entry as this is the last transaction");
        batch.delete(stockRef);
      } else {
        // Update stock quantity and purchase/sales totals
        print("Updating stock quantity by $quantityChange");

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

      await batch.commit();
      Navigator.of(context, rootNavigator: true).pop();
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

  // Build transaction card
  Widget _buildTransactionCard(DocumentSnapshot doc) {
    final isPurchase = doc['type'] == 'Purchase';
    final isPaid = doc['status'] == 'Paid';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isPurchase ? Icons.trending_up : Icons.trending_down,
                      color: isPurchase ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _capitalizeFirstLetter(doc['product']),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPurchase ? Colors.purple.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    doc['type'],
                    style: TextStyle(
                      fontSize: 12,
                      color: isPurchase ? Colors.purple : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Transaction details
            _buildDetailRow(Icons.format_list_numbered, "Qty: ${doc['quantity']}"),
            _buildDetailRow(Icons.attach_money, "Unit Price: ₹${doc['unitPrice']}"),
            _buildDetailRow(Icons.calendar_today,
                "Date: ${_formatDate(doc['date'].toDate())}"),
            _buildDetailRow(Icons.local_offer,
                "${isPurchase ? 'Supplier' : 'Customer'}: ${doc['party']}"),

            const SizedBox(height: 6),

            // Status and actions row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPaid ? Colors.green.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    doc['status'],
                    style: TextStyle(
                      color: isPaid ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _updateTransaction(doc.id),
                      icon: const Icon(Icons.edit),
                      tooltip: "Update Transaction",
                    ),
                    IconButton(
                      onPressed: () => _showDeleteDialog(doc.id),
                      icon: const Icon(Icons.delete),
                      tooltip: "Delete Transaction",
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Build detail row helper
  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 5),
          Text(text),
        ],
      ),
    );
  }

  // Format date helper
  String _formatDate(DateTime date) {
    return "${date.day} ${DateFormat('MMM').format(date)} ${date.year}";
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
              const SizedBox(height: 16),

              // Search field
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search transactions...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
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
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("No transactions found"));
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        return _buildTransactionCard(snapshot.data!.docs[index]);
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