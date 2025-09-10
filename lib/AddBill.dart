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
  final TextEditingController cityController = TextEditingController();
  final TextEditingController stateController = TextEditingController();
  final TextEditingController billNumberController = TextEditingController();
  final FocusNode nameFocusNode = FocusNode();

  bool showCustomerSuggestions = false;
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> items = [];
  final user = FirebaseAuth.instance.currentUser;
  String? pendingBillNumber;
  String? linkedTransactionId;

  String formatDate(DateTime date) => DateFormat.yMMMd().format(date);

  @override
  void initState() {
    super.initState();
    _initializeBillNumber();
    nameFocusNode.addListener(() {
      setState(() => showCustomerSuggestions = nameFocusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    cityController.dispose();
    stateController.dispose();
    billNumberController.dispose();
    nameFocusNode.dispose();
    super.dispose();
  }

  // Get customer suggestions
  Stream<List<String>> _getCustomerSuggestions(String query) {
    if (query.trim().isEmpty) return Stream.value([]);
    final lowercaseQuery = query.trim().toLowerCase();
    return FirebaseFirestore.instance
        .collection('customers')
        .where('user', isEqualTo: user?.uid)
        .snapshots()
        .map((snapshot) {
      final customers = snapshot.docs
          .map((doc) => doc['name'] as String? ?? '')
          .where((name) => name.isNotEmpty &&
          name.toLowerCase().contains(lowercaseQuery))
          .toSet()
          .toList();
      customers.sort();
      return customers.take(10).toList();
    });
  }

  // Load customer details when selected
  Future<void> _loadCustomerDetails(String customerName) async {
    try {
      final customerQuery = await FirebaseFirestore.instance
          .collection('customers')
          .where('user', isEqualTo: user?.uid)
          .where('name', isEqualTo: customerName)
          .limit(1)
          .get();
      if (customerQuery.docs.isNotEmpty) {
        final customerData = customerQuery.docs.first.data();
        setState(() {
          phoneController.text = customerData['phone'] ?? '';
          cityController.text = customerData['city'] ?? '';
          stateController.text = customerData['state'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading customer details: $e');
    }
  }

  // Show add customer dialog
  void _showAddCustomerDialog() {
    final newNameController = TextEditingController(text: nameController.text);
    final newPhoneController = TextEditingController();
    final newCityController = TextEditingController();
    final newStateController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Customer'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: newNameController,
                  decoration: InputDecoration(
                    labelText: 'Customer Name*',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter name' : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: newPhoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                    prefixText: '+91 ',
                  ),
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (value) {
                    if (value?.trim().isNotEmpty == true && value!.trim().length != 10) {
                      return 'Please enter a valid 10-digit phone number';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: newCityController,
                  decoration: InputDecoration(
                    labelText: 'City',
                    prefixIcon: Icon(Icons.location_city),
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: newStateController,
                  decoration: InputDecoration(
                    labelText: 'State',
                    prefixIcon: Icon(Icons.map),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _addNewCustomer(
              newNameController.text,
              newPhoneController.text,
              newCityController.text,
              newStateController.text,
              formKey,
            ),
            child: Text('Add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Add new customer
  Future<void> _addNewCustomer(String name, String phone, String city, String state,
      GlobalKey<FormState> formKey) async {
    if (!formKey.currentState!.validate()) return;
    try {
      await FirebaseFirestore.instance.collection('customers').add({
        'name': name.trim(),
        'phone': phone.trim(),
        'city': city.trim(),
        'state': state.trim(),
        'user': user?.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context);

      // Auto-fill the form with new customer data
      setState(() {
        nameController.text = name.trim();
        phoneController.text = phone.trim();
        cityController.text = city.trim();
        stateController.text = state.trim();
      });

      Fluttertoast.showToast(
        msg: 'Customer added successfully!',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error adding customer: $e',
        backgroundColor: Colors.red,
      );
    }
  }

  // Build suggestions list widget
  Widget _buildSuggestionsList({
    required Stream<List<String>> stream,
    required TextEditingController controller,
    required FocusNode focusNode,
  }) {
    return StreamBuilder<List<String>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 50,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final suggestions = snapshot.data ?? [];
        if (suggestions.isEmpty) return const SizedBox.shrink();

        return Container(
          constraints: const BoxConstraints(maxHeight: 200),
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: suggestions.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Colors.grey.shade200,
              ),
              itemBuilder: (context, index) => InkWell(
                onTap: () {
                  controller.text = suggestions[index];
                  focusNode.unfocus();
                  _loadCustomerDetails(suggestions[index]);
                  setState(() {});
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    suggestions[index],
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
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
              // ONLY SHOW PRODUCTS WITH AVAILABLE STOCK > 0
              stream: FirebaseFirestore.instance
                  .collection('stocks')
                  .where('user', isEqualTo: user?.uid)
                  .where('quantity', isGreaterThan: 0) // Only available stocks
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

  // REMOVED STOCK UPDATE METHOD - Bills don't manage stock anymore

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
      double tax = subtotal * 0.05;
      double total = subtotal + tax;

      // REMOVED STOCK UPDATE LOOP - Bills only show available stock, don't manage it

      await FirebaseFirestore.instance.collection('bills').add({
        'user': user?.uid,
        'billNumber': finalBillNumber,
        'customerName': nameController.text,
        'customerPhone': phoneController.text,
        'customerCity': cityController.text,
        'customerState': stateController.text,
        'date': selectedDate,
        'items': items,
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'linkedTransactionId': linkedTransactionId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'billType': 'manual',
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
    double tax = subtotal * 0.05;
    double total = subtotal + tax;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Bill'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
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

            // Enhanced Name Field with Autocomplete and Add Option
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nameController,
                        focusNode: nameFocusNode,
                        decoration: InputDecoration(
                          labelText: 'Customer Name',
                          suffixIcon: IconButton(
                            icon: Icon(Icons.person_add, color: Colors.indigo),
                            onPressed: _showAddCustomerDialog,
                            tooltip: 'Add New Customer',
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
                if (showCustomerSuggestions && nameController.text.isNotEmpty)
                  _buildSuggestionsList(
                    stream: _getCustomerSuggestions(nameController.text),
                    controller: nameController,
                    focusNode: nameFocusNode,
                  ),
              ],
            ),
            const SizedBox(height: 8),

            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixText: '+91 ',
              ),
              keyboardType: TextInputType.phone,
              maxLength: 10,
            ),
            const SizedBox(height: 8),

            TextField(
              controller: cityController,
              decoration: const InputDecoration(labelText: 'City'),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: stateController,
              decoration: const InputDecoration(labelText: 'State'),
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
}

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
  late TextEditingController quantityController;
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    productPriceController = TextEditingController();
    quantityController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    productPriceController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableStock = widget.productData['quantity'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.productData['product'] ?? 'Unknown Product',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Available Stock: $availableStock kg',
                style: TextStyle(
                  color: Colors.blue.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),

              // Direct Quantity Input
              TextFormField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                  suffixText: 'kg',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter quantity';
                  final quantity = int.tryParse(value);
                  if (quantity == null || quantity <= 0) return 'Quantity must be > 0';
                  if (quantity > availableStock) return 'Max available: $availableStock kg';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Price Input
              TextFormField(
                controller: productPriceController,
                decoration: const InputDecoration(
                  labelText: 'Price',
                  prefixText: '₹',
                  border: OutlineInputBorder(),
                  suffixText: "per kg",
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter price';
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) return 'Price must be > 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final quantity = int.parse(quantityController.text);
                      widget.onItemAdded({
                        'name': widget.productData['product'] ?? 'Unknown',
                        'quantity': quantity.toString(),
                        'price': productPriceController.text,
                      });
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
      ),
    );
  }
}
