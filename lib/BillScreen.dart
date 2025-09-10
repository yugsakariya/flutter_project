import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/EditBill.dart';
import 'package:intl/intl.dart';
import 'utils.dart';
import 'AddBill.dart';

class BillsScreen extends StatefulWidget {
  final VoidCallback? goToDashboard;
  const BillsScreen({super.key, this.goToDashboard});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _getBillsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('bills')
        .where('user', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  List<DocumentSnapshot> _filterBills(List<DocumentSnapshot> docs) {
    if (_searchQuery.isEmpty) return docs;

    final searchLower = _searchQuery.toLowerCase().trim();
    return docs.where((doc) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final customerName = data['customerName']?.toString().toLowerCase() ?? '';
        final billNumber = data['billNumber']?.toString().toLowerCase() ?? '';
        
        return customerName.contains(searchLower) || billNumber.contains(searchLower);
      } catch (e) {
        return false;
      }
    }).toList();
  }

  void _showBillDetails(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    showDialog(
      context: context,
      builder: (context) => BillDetailsDialog(billData: data),
    );
  }

  void _deleteBill(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Bill"),
        content: const Text("Are you sure you want to delete this bill?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('bills').doc(docId).delete();
                Navigator.pop(context);
                AppUtils.showSuccess("Bill deleted successfully");
              } catch (e) {
                Navigator.pop(context);
                AppUtils.showError("Error deleting bill: $e");
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
          title: const Text("Bills"),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.indigo,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewBillScreen()),
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
                  hintText: 'Search by customer name or bill number...',
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
                  stream: _getBillsStream(),
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
                            const Text("Error loading bills"),
                            Text("${snapshot.error}"),
                          ],
                        ),
                      );
                    }

                    final allDocs = snapshot.data?.docs ?? [];
                    final filteredDocs = _filterBills(allDocs);

                    if (filteredDocs.isEmpty && _searchQuery.isNotEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, color: Colors.grey[400], size: 64),
                            const SizedBox(height: 16),
                            Text(
                              "No bills found for '$_searchQuery'",
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
                              "No bills found",
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Create your first bill using the + button",
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
                        return _buildBillCard(doc);
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

  Widget _buildBillCard(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final billNumber = data['billNumber']?.toString() ?? 'Unknown';
      final customerName = data['customerName']?.toString() ?? 'Unknown Customer';
      final total = (data['total'] as num?)?.toDouble() ?? 0.0;
      final items = data['items'] as List? ?? [];

      String dateString = "No Date";
      try {
        final date = data['date'];
        if (date is Timestamp) {
          dateString = DateFormat('dd-MM-yyyy').format(date.toDate());
        } else if (date is DateTime) {
          dateString = DateFormat('dd-MM-yyyy').format(date);
        }
      } catch (e) {
        // Keep default "No Date"
      }

      return Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => _showBillDetails(doc),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            billNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.indigo,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            customerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton(
                      onSelected: (value) {
                        if (value == 'edit') {
                          Navigator.push(context, MaterialPageRoute(builder: (_)=>EditBillScreen(billNumber: billNumber)));
                        }
                        if (value == 'delete') {
                          _deleteBill(doc.id);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                _buildDetailRow(Icons.shopping_bag, "Items: ${items.length}"),
                const SizedBox(height: 4),
                _buildDetailRow(Icons.calendar_today, "Date: $dateString"),
                const SizedBox(height: 4),
                _buildDetailRow(Icons.attach_money, "Total: ₹${total.toStringAsFixed(2)}"),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Completed',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
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
                      'Error loading bill',
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

class BillDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> billData;

  const BillDetailsDialog({super.key, required this.billData});

  @override
  Widget build(BuildContext context) {
    final billNumber = billData['billNumber']?.toString() ?? 'Unknown';
    final customerName = billData['customerName']?.toString() ?? 'Unknown';
    final customerPhone = billData['customerPhone']?.toString() ?? '';
    final customerCity = billData['customerCity']?.toString() ?? '';
    final customerState = billData['customerState']?.toString() ?? '';
    final items = billData['items'] as List? ?? [];
    final subtotal = (billData['subtotal'] as num?)?.toDouble() ?? 0.0;
    final tax = (billData['tax'] as num?)?.toDouble() ?? 0.0;
    final total = (billData['total'] as num?)?.toDouble() ?? 0.0;

    String dateString = "No Date";
    try {
      final date = billData['date'];
      if (date is Timestamp) {
        dateString = DateFormat('dd-MM-yyyy').format(date.toDate());
      } else if (date is DateTime) {
        dateString = DateFormat('dd-MM-yyyy').format(date);
      }
    } catch (e) {
      // Keep default "No Date"
    }

    return AlertDialog(
      title: Text(billNumber),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoSection('Customer Details', [
              'Name: $customerName',
              if (customerPhone.isNotEmpty) 'Phone: +91 $customerPhone',
              if (customerCity.isNotEmpty || customerState.isNotEmpty)
                'Address: ${[customerCity, customerState].where((s) => s.isNotEmpty).join(', ')}',
            ]),
            const SizedBox(height: 16),
            
            _buildInfoSection('Bill Details', [
              'Date: $dateString',
              'Items: ${items.length}',
            ]),
            const SizedBox(height: 16),
            
            if (items.isNotEmpty) ...[
              const Text(
                'Items:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 150,
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index] as Map<String, dynamic>;
                    final name = item['name']?.toString() ?? 'Unknown';
                    final quantity = item['quantity']?.toString() ?? '0';
                    final price = item['price']?.toString() ?? '0';
                    final amount = (int.tryParse(quantity) ?? 0) * (double.tryParse(price) ?? 0);
                    
                    return Card(
                      child: ListTile(
                        title: Text(name),
                        subtitle: Text('Qty: $quantity kg @ ₹$price per kg'),
                        trailing: Text('₹${amount.toStringAsFixed(2)}'),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            _buildInfoSection('Bill Summary', [
              'Subtotal: ₹${subtotal.toStringAsFixed(2)}',
              'Tax (5%): ₹${tax.toStringAsFixed(2)}',
              'Total: ₹${total.toStringAsFixed(2)}',
            ]),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildInfoSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(item),
        )),
      ],
    );
  }
}