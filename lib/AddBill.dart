import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  int quantity = 1;
  String formatDate(DateTime date) => DateFormat.yMMMd().format(date);
  final price = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;
  String? pendingBillNumber; // Store the bill number without committing

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

                    return StatefulBuilder(
                      builder: (context, setDialogState) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['product'] ?? 'Unknown Product',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Text('Quantity: '),
                                    IconButton(
                                      onPressed: () {
                                        if (quantity > 1) {
                                          setDialogState(() {
                                            quantity--;
                                          });
                                        }
                                      },
                                      icon: const Icon(Icons.remove),
                                    ),
                                    Text(quantity.toString()),
                                    IconButton(
                                      onPressed: () {
                                        setDialogState(() {
                                          quantity++;
                                        });
                                      },
                                      icon: const Icon(Icons.add),
                                    ),
                                  ],
                                ),
                                TextField(
                                  controller: price,
                                  decoration: const InputDecoration(
                                    labelText: 'Price',
                                    prefixText: '\$',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    if (price.text.isNotEmpty) {
                                      setState(() {
                                        items.add({
                                          'name': data['product'] ?? 'Unknown',
                                          'quantity': quantity.toString(),
                                          'price': price.text,
                                        });
                                      });
                                      price.clear();
                                      quantity = 1;
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  child: const Text("Add"),
                                ),
                              ],
                            ),
                          ),
                        );
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

  // Get the next bill number WITHOUT incrementing the counter
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

  // Actually increment the bill counter when saving
  Future<String> _generateAndIncrementBillNumber() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('billcounter')
          .where('user', isEqualTo: user?.uid)
          .get();

      if (querySnapshot.docs.isEmpty) {
        // Create initial counter document
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

        // Update counter ONLY when saving
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
    final billNo = await _getNextBillNumber();
    setState(() {
      pendingBillNumber = billNo;
      billNumberController.text = billNo;
    });
  }

  double calculateSubtotal() {
    double subtotal = 0.0;
    for (var item in items) {
      final quantity = int.tryParse(item['quantity']) ?? 0;
      final price = double.tryParse(item['price']) ?? 0.0;
      subtotal += quantity * price;
    }
    return subtotal;
  }

  // Save bill function that increments the counter
  Future<void> saveBill() async {
    if (nameController.text.isEmpty || items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add customer name and items')),
      );
      return;
    }

    try {
      // Generate and increment bill number only when saving
      final finalBillNumber = await _generateAndIncrementBillNumber();

      // Calculate totals
      double subtotal = calculateSubtotal();
      double tax = subtotal * 0.1;
      double total = subtotal + tax;

      // Save bill to Firestore
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bill $finalBillNumber saved successfully!')),
      );

      // Clear form and navigate back or reset
      Navigator.of(context).pop();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving bill: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double subtotal = calculateSubtotal();
    double tax = subtotal * 0.1; // 10% tax
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
              enabled: false, // Bill number should not be editable
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
              children: items.map((item) => ListTile(
                title: Text(item['name']),
                subtitle: Text('Quantity: ${item['quantity']}'),
                trailing: Text('\$${item['price']}'),
                leading: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    setState(() {
                      items.remove(item);
                    });
                  },
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
                Text("\$${subtotal.toStringAsFixed(2)}"),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Tax (10%):"),
                Text("\$${tax.toStringAsFixed(2)}"),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("\$${total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saveBill, // Use the new saveBill function
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
    price.dispose();
    super.dispose();
  }
}
