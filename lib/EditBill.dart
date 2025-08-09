import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  int quantity = 1;
  final price = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  bool isLoading = true;
  String? billDocumentId;

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

        setState(() {
          nameController.text = data['customerName'] ?? '';
          phoneController.text = data['customerPhone'] ?? '';
          billNumberController.text = data['billNumber'] ?? '';
          selectedDate = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
          items = List<Map<String, dynamic>>.from(data['items'] ?? []);
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill not found')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading bill: $e')),
      );
      Navigator.pop(context);
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

  void editItem(int index) {
    final item = items[index];
    final editPriceController = TextEditingController(text: item['price']);
    int editQuantity = int.tryParse(item['quantity']) ?? 1;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit ${item['name']}'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('Quantity: '),
                      IconButton(
                        onPressed: () {
                          if (editQuantity > 1) {
                            setDialogState(() {
                              editQuantity--;
                            });
                          }
                        },
                        icon: const Icon(Icons.remove),
                      ),
                      Text(editQuantity.toString()),
                      IconButton(
                        onPressed: () {
                          setDialogState(() {
                            editQuantity++;
                          });
                        },
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  TextField(
                    controller: editPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      prefixText: '\$',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (editPriceController.text.isNotEmpty) {
                  setState(() {
                    items[index] = {
                      'name': item['name'],
                      'quantity': editQuantity.toString(),
                      'price': editPriceController.text,
                    };
                  });
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
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

  Future<void> updateBill() async {
    if (nameController.text.isEmpty || items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add customer name and items')),
      );
      return;
    }

    if (billDocumentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill document not found')),
      );
      return;
    }

    try {
      // Calculate totals
      double subtotal = calculateSubtotal();
      double tax = subtotal * 0.1;
      double total = subtotal + tax;

      // Update bill in Firestore
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bill ${widget.billNumber} updated successfully!')),
      );

      Navigator.of(context).pop();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating bill: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Bill'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    double subtotal = calculateSubtotal();
    double tax = subtotal * 0.1;
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
                return ListTile(
                  title: Text(item['name']),
                  subtitle: Text('Quantity: ${item['quantity']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('\$${item['price']}'),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => editItem(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            items.removeAt(index);
                          });
                        },
                      ),
                    ],
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
    price.dispose();
    super.dispose();
  }
}
