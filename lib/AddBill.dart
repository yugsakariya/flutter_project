import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';

class NewBillScreen extends StatefulWidget {
  const NewBillScreen({super.key});

  @override
  State<NewBillScreen> createState() => _NewBillScreenState();
}

class _NewBillScreenState extends State<NewBillScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController billNumberController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> items = [];
  final user = FirebaseAuth.instance.currentUser;
  String? pendingBillNumber;

  String formatDate(DateTime date) => DateFormat.yMMMd().format(date);

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

  // COMPLETELY FIXED: Single item addition (simple approach)
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

  Future<String> _getNextBillNumber() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('billcounter')
          .where('user', isEqualTo: user?.uid)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return "INV-1";
      } else {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        final currentCounter = data['counter'] ?? 0;
        return "INV-${currentCounter + 1}";
      }
    } catch (e) {
      return "INV-${DateTime.now().millisecondsSinceEpoch}";
    }
  }

  Future<String> _generateAndIncrementBillNumber() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('billcounter')
          .where('user', isEqualTo: user?.uid)
          .get();

      if (querySnapshot.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('billcounter').add({
          'user': user?.uid,
          'counter': 1,
        });
        return "INV-1";
      } else {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        final currentCounter = data['counter'] ?? 0;
        final newCounter = currentCounter + 1;

        await doc.reference.update({'counter': newCounter});
        return "INV-$newCounter";
      }
    } catch (e) {
      return "INV-${DateTime.now().millisecondsSinceEpoch}";
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeBillNumber();
  }

  void _initializeBillNumber() async {
    try {
      final billNo = await _getNextBillNumber();
      if (mounted) {
        setState(() {
          pendingBillNumber = billNo;
          billNumberController.text = billNo;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          pendingBillNumber = "INV-1";
          billNumberController.text = "INV-1";
        });
      }
    }
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

  Future<void> saveBill() async {
    if (nameController.text.isEmpty || items.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please add customer name and items',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    try {
      final finalBillNumber = await _generateAndIncrementBillNumber();

      double subtotal = calculateSubtotal();
      double tax = subtotal * 0.1;
      double total = subtotal + tax;

      await FirebaseFirestore.instance.collection('bills').add({
        'user': user?.uid,
        'billNumber': finalBillNumber,
        'customerName': nameController.text,
        'customerPhone': phoneController.text,
        'date': selectedDate,
        'items': items,
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'createdAt': FieldValue.serverTimestamp(),
      });

      Fluttertoast.showToast(
        msg: 'Bill $finalBillNumber saved successfully!',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error saving bill: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double subtotal = calculateSubtotal();
    double tax = subtotal * 0.1;
    double total = subtotal + tax;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Bill'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                const Text("Date Today's:"),
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
              children: items.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(item['name'] ?? 'Unknown'),
                  subtitle: Text('Quantity: ${item['quantity'] ?? '0'}'),
                  trailing: Text('₹${item['price'] ?? '0'}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  leading: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        items.remove(item);
                      });
                    },
                  ),
                ),
              )).toList(),
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
              onPressed: saveBill,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Save Bill', style: TextStyle(fontSize: 16)),
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

// FIXED: Separate StatefulWidget for Product Selection Card
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

            // Quantity controls
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
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Price input
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

            // Add button
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
