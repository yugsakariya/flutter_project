import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'utils.dart';
import 'TransactionAdd.dart';
import 'TransactionUpdate.dart';

class TransactionScreen extends StatefulWidget {
  final VoidCallback? goToDashboard;
  const TransactionScreen({super.key, this.goToDashboard});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _getTransactionsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('transactions')
        .where('user', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  List<DocumentSnapshot> _filterTransactions(List<DocumentSnapshot> docs) {
    if (_searchQuery.isEmpty) return docs;

    final searchLower = _searchQuery.toLowerCase().trim();
    return docs.where((doc) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final products = data['product'] as List? ?? [];
        
        return products.any((product) {
          if (product is Map) {
            final productName = product['product']?.toString().toLowerCase() ?? '';
            return productName.contains(searchLower);
          }
          return false;
        });
      } catch (e) {
        return false;
      }
    }).toList();
  }

  void _showUpdateDialog(String docId) {
    showDialog(
      context: context,
      builder: (context) => TransactionUpdate(docRef: docId),
    );
  }

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

  Future<void> _deleteTransaction(String docId) async {
    LoadingDialog.show(context, "Deleting transaction...");

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final transactionDoc = await FirebaseFirestore.instance
          .collection('transactions')
          .doc(docId)
          .get();

      if (!transactionDoc.exists) {
        LoadingDialog.hide(context);
        AppUtils.showError("Transaction not found");
        return;
      }

      final data = transactionDoc.data()!;
      final type = data['type']?.toString() ?? '';
      final products = data['product'] as List? ?? [];

      final batch = FirebaseFirestore.instance.batch();
      
      batch.delete(FirebaseFirestore.instance.collection('transactions').doc(docId));

      for (var product in products) {
        if (product == null) continue;
        
        final productMap = product as Map<String, dynamic>;
        final productName = productMap['product']?.toString() ?? '';
        final quantity = (productMap['quantity'] as num?)?.toInt() ?? 0;

        if (productName.isEmpty || quantity <= 0) continue;

        final stockQuery = await FirebaseFirestore.instance
            .collection('stocks')
            .where('user', isEqualTo: user.uid)
            .where('product', isEqualTo: productName)
            .limit(1)
            .get();

        if (stockQuery.docs.isNotEmpty) {
          final stockRef = stockQuery.docs.first.reference;
          final quantityChange = type == 'Purchase' ? -quantity : quantity;
          
          batch.update(stockRef, {
            'quantity': FieldValue.increment(quantityChange),
            if (type == 'Purchase') 'purchase': FieldValue.increment(-quantity),
            if (type == 'Sale') 'sales': FieldValue.increment(-quantity),
          });
        }
      }

      await batch.commit();
      LoadingDialog.hide(context);
      Navigator.pop(context);
      AppUtils.showSuccess("Transaction deleted successfully");

    } catch (e) {
      LoadingDialog.hide(context);
      AppUtils.showError("Failed to delete transaction: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        widget.goToDashboard?.call();
        return false;
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
          onPressed: () => showDialog(
            context: context,
            builder: (context) => const Transactionadd(),
          ),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search by product name...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
              const SizedBox(height: 16),
              
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _getTransactionsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error, color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            const Text("Error loading transactions"),
                            Text("${snapshot.error}"),
                          ],
                        ),
                      );
                    }

                    final allDocs = snapshot.data?.docs ?? [];
                    final filteredDocs = _filterTransactions(allDocs);

                    if (filteredDocs.isEmpty && _searchQuery.isNotEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, color: Colors.grey[400], size: 64),
                            const SizedBox(height: 16),
                            Text(
                              "No transactions found for '$_searchQuery'",
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    }

                    if (filteredDocs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, color: Colors.grey[400], size: 64),
                            const SizedBox(height: 16),
                            Text(
                              "No transactions found",
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Add your first transaction using the + button",
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: filteredDocs.length,
                      padding: const EdgeInsets.only(bottom: 80),
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        return _buildTransactionCard(doc);
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

  Widget _buildTransactionCard(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final type = data['type']?.toString() ?? 'Unknown';
      final status = data['status']?.toString() ?? 'Unknown';
      final party = data['party']?.toString() ?? 'Unknown Party';
      final products = data['product'] as List? ?? [];

      final isPurchase = type == 'Purchase';
      final isPaid = status == 'Paid';

      String productName = 'No Products';
      int totalQuantity = 0;
      double totalAmount = 0.0;

      if (products.isNotEmpty && products[0] != null) {
        final firstProduct = products[0] as Map<String, dynamic>;
        productName = firstProduct['product']?.toString() ?? 'Unknown Product';

        for (var product in products) {
          if (product != null) {
            final productMap = product as Map<String, dynamic>;
            final quantity = (productMap['quantity'] as num?)?.toInt() ?? 0;
            final unitPrice = (productMap['unitPrice'] as num?)?.toDouble() ?? 0.0;
            totalQuantity += quantity;
            totalAmount += quantity * unitPrice;
          }
        }

        if (products.length > 1) {
          productName = "$productName (+${products.length - 1} more)";
        }
      }

      String dateString = "No Date";
      try {
        final timestamp = data['timestamp'];
        if (timestamp is Timestamp) {
          dateString = DateFormat('dd-MM-yyyy').format(timestamp.toDate());
        }
      } catch (e) {
        // Keep default "No Date"
      }

      return Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                            AppUtils.capitalize(productName),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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

              _buildDetailRow(Icons.format_list_numbered, "Products: ${products.length}"),
              const SizedBox(height: 4),
              _buildDetailRow(Icons.inventory_2, "Total Qty: $totalQuantity"),
              const SizedBox(height: 4),
              _buildDetailRow(Icons.attach_money, "Total: ₹${totalAmount.toStringAsFixed(2)}"),
              const SizedBox(height: 4),
              _buildDetailRow(Icons.calendar_today, "Date: $dateString"),
              const SizedBox(height: 4),
              _buildDetailRow(
                Icons.local_offer,
                "${isPurchase ? 'Supplier' : 'Customer'}: $party",
              ),
              const SizedBox(height: 12),

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
                        onPressed: () => _showUpdateDialog(doc.id),
                        icon: const Icon(Icons.edit, size: 20),
                        tooltip: "Update Transaction",
                      ),
                      IconButton(
                        onPressed: () => _showDeleteDialog(doc.id),
                        icon: const Icon(Icons.delete, size: 20),
                        color: Colors.red.shade600,
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
    } catch (e) {
      return Card(
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
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red.shade700),
                    ),
                    Text(
                      'Error: $e',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }
}