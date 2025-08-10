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
  List<Map<String, String>> items = []; // Fixed: Added proper generic type
  int quantity = 1;

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
          items = List<Map<String, String>>.from(
              (data['items'] as List?)?.map((item) => Map<String, String>.from(item)) ?? []
          );
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        Fluttertoast.showToast(
          msg: 'Bill not found',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(
        msg: 'Error loading bill: Rs.e',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
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

                    // Create a separate controller for each product
                    final TextEditingController productPriceController = TextEditingController();
                    int productQuantity = 1;

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
                                        if (productQuantity > 1) {
                                          setDialogState(() {
                                            productQuantity--;
                                          });
                                        }
                                      },
                                      icon: const Icon(Icons.remove),
                                    ),
                                    Text(productQuantity.toString()),
                                    IconButton(
                                      onPressed: () {
                                        setDialogState(() {
                                          productQuantity++;
                                        });
                                      },
                                      icon: const Icon(Icons.add),
                                    ),
                                  ],
                                ),
                                TextField(
                                  controller: productPriceController,
                                  decoration: const InputDecoration(
                                    labelText: 'Price',
                                    prefixText: '\Rs.',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    if (productPriceController.text.isNotEmpty) {
                                      setState(() {
                                        items.add({
                                          'name': data['product'] ?? 'Unknown',
                                          'quantity': productQuantity.toString(),
                                          'price': productPriceController.text,
                                        });
                                      });
                                      productPriceController.dispose();
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
    int editQuantity = int.tryParse(item['quantity'] ?? '1') ?? 1;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Rs.${item['name']}'),
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
                      prefixText: '\Rs.',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                editPriceController.dispose();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (editPriceController.text.isNotEmpty) {
                  setState(() {
                    items[index] = {
                      'name': item['name'] ?? 'Unknown',
                      'quantity': editQuantity.toString(),
                      'price': editPriceController.text,
                    };
                  });
                  editPriceController.dispose();
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
      final quantity = int.tryParse(item['quantity'] ?? '0') ?? 0;
      final price = double.tryParse(item['price'] ?? '0') ?? 0.0;
      subtotal += quantity * price;
    }
    return subtotal;
  }

  Future<void> updateBill() async {
    if (nameController.text.isEmpty || items.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please add customer name and items',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    if (billDocumentId == null) {
      Fluttertoast.showToast(
        msg: 'Bill document not found',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
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

      Fluttertoast.showToast(
        msg: 'Bill Rs.{widget.billNumber} updated successfully!',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      Navigator.of(context).pop();
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error updating bill: Rs.e',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
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
        title: Text('Edit Bill - Rs.{widget.billNumber}'),
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
                Map<String, String> item = entry.value;
                return ListTile(
                  title: Text(item['name'] ?? 'Unknown'),
                  subtitle: Text('Quantity: Rs.${item['quantity'] ?? '0'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Rs.${item['price'] ?? '0'}'),
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
                Text("Rs.${subtotal.toStringAsFixed(2)}"),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Tax (10%):"),
                Text("Rs.${tax.toStringAsFixed(2)}"),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("Rs.${total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
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
