import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';

class EditBillScreen extends StatefulWidget {
  final String billNumber;
  const EditBillScreen({super.key, required this.billNumber});

  @override
  State<EditBillScreen> createState() => _EditBillScreenState();
}

class _EditBillScreenState extends State<EditBillScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController billNumberController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> items = [];
  final user = FirebaseAuth.instance.currentUser;
  bool isLoading = true;
  String? billDocumentId;
  String? originalCustomerName;
  String? linkedTransactionId; // NEW: For transaction linking
  List<Map<String, dynamic>> originalItems = []; // Track original items for stock reversal

  @override
  void initState() {
    super.initState();
    _loadBillData();
  }

  Future<void> _loadBillData() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('bills')
          .where('billNumber', isEqualTo: widget.billNumber)
          .where('user', isEqualTo: user?.uid)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        billDocumentId = doc.id;
        originalCustomerName = data['customerName'] ?? '';
        linkedTransactionId = data['linkedTransactionId']; // NEW: Load linked transaction

        if (mounted) {
          setState(() {
            nameController.text = data['customerName'] ?? '';
            phoneController.text = data['customerPhone'] ?? '';
            billNumberController.text = data['billNumber'] ?? '';
            selectedDate = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
            items = List<Map<String, dynamic>>.from(
                (data['items'] as List?)?.map((item) => Map<String, dynamic>.from(item)) ?? []
            );
            // Store original items for stock management
            originalItems = List<Map<String, dynamic>>.from(items);
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
          Fluttertoast.showToast(
            msg: 'Bill not found',
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        Fluttertoast.showToast(
          msg: 'Error loading bill: $e',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  void addItem() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Item'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('stocks')
                  .where('user', isEqualTo: user?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No stocks available'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _ProductSelectionCard(
                      productData: data,
                      onItemAdded: (item) {
                        setState(() {
                          items.add(item);
                        });
                        Navigator.of(context).pop();
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void editItem(int index) {
    final item = items[index];
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit ${item['name']}'),
          content: _EditItemDialog(
            initialItem: item,
            onItemUpdated: (updatedItem) {
              setState(() {
                items[index] = updatedItem;
              });
              Navigator.of(context).pop();
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  double calculateSubtotal() {
    double subtotal = 0.0;
    for (var item in items) {
      final quantity = int.tryParse(item['quantity'] ?? '0') ?? 0;
      final price = double.tryParse(item['price'] ?? '0') ?? 0.0;
      subtotal += quantity * price;
    }
    return subtotal;
  }

  // FIXED: Centralized stock management
  Future<void> _revertStockChange(String product, int quantity) async {
    final stockQuery = await FirebaseFirestore.instance
        .collection('stocks')
        .where('user', isEqualTo: user!.uid)
        .where('product', isEqualTo: product.toLowerCase().trim())
        .limit(1)
        .get();

    if (stockQuery.docs.isNotEmpty) {
      // Add back the quantity (reverse the sale)
      await stockQuery.docs.first.reference.update({
        'quantity': FieldValue.increment(quantity),
        'sales': FieldValue.increment(-quantity),
        'lastUpdated': DateTime.now(),
      });
    }
  }

  Future<void> _applyStockChange(String product, int quantity) async {
    final stockQuery = await FirebaseFirestore.instance
        .collection('stocks')
        .where('user', isEqualTo: user!.uid)
        .where('product', isEqualTo: product.toLowerCase().trim())
        .limit(1)
        .get();

    if (stockQuery.docs.isNotEmpty) {
      final stockData = stockQuery.docs.first.data();
      final currentStock = stockData['quantity'] ?? 0;

      if (currentStock < quantity) {
        throw Exception("Insufficient stock! Available: $currentStock for $product");
      }

      // Subtract the quantity (apply the sale)
      await stockQuery.docs.first.reference.update({
        'quantity': FieldValue.increment(-quantity),
        'sales': FieldValue.increment(quantity),
        'lastUpdated': DateTime.now(),
      });
    } else {
      throw Exception("Product not found in stock: $product");
    }
  }

  // FIXED: Comprehensive transaction sync
  Future<void> _updateLinkedTransaction() async {
    if (linkedTransactionId == null) return;

    try {
      final transactionDoc = await FirebaseFirestore.instance
          .collection('transactions')
          .doc(linkedTransactionId)
          .get();

      if (!transactionDoc.exists) {
        print('Linked transaction not found, removing link');
        linkedTransactionId = null;
        return;
      }

      // Convert bill items to transaction format
      final List<Map<String, dynamic>> transactionProducts = [];
      double totalAmount = 0.0;

      for (var item in items) {
        final quantity = int.tryParse(item['quantity'] ?? '0') ?? 0;
        final price = double.tryParse(item['price'] ?? '0') ?? 0.0;

        transactionProducts.add({
          'product': item['name']?.toString().toLowerCase().trim() ?? '',
          'quantity': quantity,
          'unitPrice': price,
        });

        totalAmount += quantity * price;
      }

      // Update the linked transaction
      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(linkedTransactionId)
          .update({
        'product': transactionProducts,
        'party': nameController.text.trim(),
        'date': selectedDate,
        'totalAmount': totalAmount,
        'lastUpdated': DateTime.now(),
      });

      print('Successfully updated linked transaction: $linkedTransactionId');
    } catch (e) {
      print('Error updating linked transaction: $e');
      // Don't throw error - bill update should still succeed
    }
  }

  Future<void> updateBill() async {
    if (nameController.text.isEmpty || items.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please add customer name and items',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    if (billDocumentId == null) {
      Fluttertoast.showToast(
        msg: 'Bill document not found',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    try {
      // FIXED: Revert original stock changes
      for (var originalItem in originalItems) {
        final productName = originalItem['name']?.toString().toLowerCase().trim() ?? '';
        final quantity = int.tryParse(originalItem['quantity'] ?? '0') ?? 0;

        if (productName.isNotEmpty && quantity > 0) {
          await _revertStockChange(productName, quantity);
        }
      }

      // Apply new stock changes
      for (var item in items) {
        final productName = item['name']?.toString().toLowerCase().trim() ?? '';
        final quantity = int.tryParse(item['quantity'] ?? '0') ?? 0;

        if (productName.isNotEmpty && quantity > 0) {
          await _applyStockChange(productName, quantity);
        }
      }

      double subtotal = calculateSubtotal();
      double tax = subtotal * 0.05;
      double total = subtotal + tax;

      // Update the bill
      await FirebaseFirestore.instance
          .collection('bills')
          .doc(billDocumentId)
          .update({
        'customerName': nameController.text,
        'customerPhone': phoneController.text,
        'date': selectedDate,
        'items': items,
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // FIXED: Update linked transaction if exists
      await _updateLinkedTransaction();

      Fluttertoast.showToast(
        msg: 'Bill ${widget.billNumber} updated successfully!',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error updating bill: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Bill'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          elevation: 1,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    double subtotal = calculateSubtotal();
    double tax = subtotal * 0.05;
    double total = subtotal + tax;

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Bill - ${widget.billNumber}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // NEW: Show transaction link status
            if (linkedTransactionId != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link, color: Colors.blue.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This bill is linked to a transaction',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const Text('CUSTOMER DETAILS', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            const Text('BILL INFO', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: billNumberController,
              decoration: const InputDecoration(labelText: 'Bill Number'),
              enabled: false,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text("Date:"),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: pickDate,
                  child: Text(DateFormat.yMMMd().format(selectedDate)),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 16),
            const Text('ITEMS', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: addItem,
              icon: const Icon(Icons.add),
              label: const Text("Add Item"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            items.isEmpty
                ? const Text("No items added yet")
                : Column(
              children: items.asMap().entries.map((entry) {
                int index = entry.key;
                Map<String, dynamic> item = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(item['name'] ?? 'Unknown'),
                    subtitle: Text('Quantity: ${item['quantity'] ?? '0'}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₹${item['price'] ?? '0'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => editItem(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              items.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('SUMMARY', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Subtotal:"),
                Text("₹${subtotal.toStringAsFixed(2)}"),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Tax (5%):"),
                Text("₹${tax.toStringAsFixed(2)}"),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("₹${total.toStringAsFixed(2)}",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: updateBill,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Update Bill', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    billNumberController.dispose();
    super.dispose();
  }
}

// Product Selection Card and Edit Item Dialog remain the same as before...
class _ProductSelectionCard extends StatefulWidget {
  final Map<String, dynamic> productData;
  final Function(Map<String, dynamic>) onItemAdded;

  const _ProductSelectionCard({
    required this.productData,
    required this.onItemAdded,
  });

  @override
  _ProductSelectionCardState createState() => _ProductSelectionCardState();
}

class _ProductSelectionCardState extends State<_ProductSelectionCard> {
  late TextEditingController productPriceController;
  int productQuantity = 1;

  @override
  void initState() {
    super.initState();
    productPriceController = TextEditingController();
  }

  @override
  void dispose() {
    productPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.productData['product'] ?? 'Unknown Product',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Quantity: ', style: TextStyle(fontWeight: FontWeight.w500)),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (productQuantity > 1) {
                            setState(() {
                              productQuantity--;
                            });
                          }
                        },
                        icon: const Icon(Icons.remove, size: 16),
                        constraints: const BoxConstraints(minWidth: 35, minHeight: 35),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          productQuantity.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            productQuantity++;
                          });
                        },
                        icon: const Icon(Icons.add, size: 16),
                        constraints: const BoxConstraints(minWidth: 35, minHeight: 35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: productPriceController,
              decoration: const InputDecoration(
                labelText: 'Price',
                prefixText: '₹',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (productPriceController.text.isNotEmpty) {
                    widget.onItemAdded({
                      'name': widget.productData['product'] ?? 'Unknown',
                      'quantity': productQuantity.toString(),
                      'price': productPriceController.text,
                    });
                  } else {
                    Fluttertoast.showToast(
                      msg: 'Please enter a price',
                      backgroundColor: Colors.orange,
                      textColor: Colors.white,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text("Add to Bill"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditItemDialog extends StatefulWidget {
  final Map<String, dynamic> initialItem;
  final Function(Map<String, dynamic>) onItemUpdated;

  const _EditItemDialog({
    required this.initialItem,
    required this.onItemUpdated,
  });

  @override
  _EditItemDialogState createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<_EditItemDialog> {
  late TextEditingController editPriceController;
  late int editQuantity;

  @override
  void initState() {
    super.initState();
    editPriceController = TextEditingController(text: widget.initialItem['price']);
    editQuantity = int.tryParse(widget.initialItem['quantity'] ?? '1') ?? 1;
  }

  @override
  void dispose() {
    editPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Text('Quantity: ', style: TextStyle(fontWeight: FontWeight.w500)),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      if (editQuantity > 1) {
                        setState(() {
                          editQuantity--;
                        });
                      }
                    },
                    icon: const Icon(Icons.remove, size: 18),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      editQuantity.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        editQuantity++;
                      });
                    },
                    icon: const Icon(Icons.add, size: 18),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: editPriceController,
          decoration: const InputDecoration(
            labelText: 'Price',
            prefixText: '₹',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              if (editPriceController.text.isNotEmpty) {
                widget.onItemUpdated({
                  'name': widget.initialItem['name'] ?? 'Unknown',
                  'quantity': editQuantity.toString(),
                  'price': editPriceController.text,
                });
              } else {
                Fluttertoast.showToast(
                  msg: 'Please enter a price',
                  backgroundColor: Colors.orange,
                  textColor: Colors.white,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Update Item'),
          ),
        ),
      ],
    );
  }
}