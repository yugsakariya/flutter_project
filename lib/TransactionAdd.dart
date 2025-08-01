import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

class Transactionadd extends StatefulWidget {
  const Transactionadd({super.key});

  @override
  State<Transactionadd> createState() => _TransactionaddState();
}

class _TransactionaddState extends State<Transactionadd> {
  final _productController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _dateController = TextEditingController();
  final _partyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _productFocusNode = FocusNode();
  final _partyFocusNode = FocusNode();

  String _selectedType = 'Purchase';
  String _selectedStatus = 'Paid';
  bool _showProductSuggestions = false;
  bool _showPartySuggestions = false;

  final User? user = FirebaseAuth.instance.currentUser;

  String get _partyLabel => _selectedType == "Purchase" ? "Supplier" : "Customer";
  String get _partyCollection => _selectedType == "Purchase" ? "suppliers" : "customers";

  Stream<List<String>> _getProductSuggestions(String query) {
    if (query.trim().isEmpty) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('stocks')
        .where('user', isEqualTo: user?.uid)
        .where('product', isGreaterThanOrEqualTo: query.trim().toLowerCase())
        .where('product', isLessThan: '${query.trim().toLowerCase()}\uf8ff')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => doc['product'] as String? ?? '')
        .where((product) => product.isNotEmpty)
        .toSet() // Remove duplicates
        .toList()..sort());
  }

  Stream<List<String>> _getPartySuggestions(String query) {
    if (query.trim().isEmpty) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection(_partyCollection)
        .where('user', isEqualTo: user?.uid)
        .where('name', isGreaterThanOrEqualTo: query.trim())
        .where('name', isLessThan: '${query.trim()}\uf8ff')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => doc['name'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .toSet() // Remove duplicates
        .toList()..sort());
  }

  Future<void> _updateStock(String product, int quantity, String type) async {
    if (user == null) return;

    final stockQuery = await FirebaseFirestore.instance
        .collection('stocks')
        .where('product', isEqualTo: product)
        .where('user', isEqualTo: user!.uid)
        .limit(1)
        .get();

    final quantityChange = type == "Purchase" ? quantity : -quantity;
    final purchaseChange = type == "Purchase" ? quantity : 0;
    final salesChange = type == "Sale" ? quantity : 0;

    if (stockQuery.docs.isNotEmpty) {
      await stockQuery.docs.first.reference.update({
        'quantity': FieldValue.increment(quantityChange),
        'purchase': FieldValue.increment(purchaseChange),
        'sales': FieldValue.increment(salesChange),
        'lastUpdated': DateTime.now(),
      });
    } else {
      await FirebaseFirestore.instance.collection('stocks').add({
        'product': product,
        'quantity': quantityChange,
        'purchase': purchaseChange,
        'sales': salesChange,
        'user': user!.uid,
        'createdAt': DateTime.now(),
        'lastUpdated': DateTime.now(),
      });
    }
  }

  Future<void> _ensurePartyExists(String partyName) async {
    if (user == null || partyName.trim().isEmpty) return;

    final partyQuery = await FirebaseFirestore.instance
        .collection(_partyCollection)
        .where('name', isEqualTo: partyName.trim())
        .where('user', isEqualTo: user!.uid)
        .limit(1)
        .get();

    // Only add if party doesn't exist
    if (partyQuery.docs.isEmpty) {
      await FirebaseFirestore.instance.collection(_partyCollection).add({
        'name': partyName.trim(),
        'user': user!.uid,
        'createdAt': DateTime.now(),
        'lastUpdated': DateTime.now(),
      });
    } else {
      // Update lastUpdated to show recent activity
      await partyQuery.docs.first.reference.update({
        'lastUpdated': DateTime.now(),
      });
    }
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate() || user == null) return;

    try {
      final partyName = _partyController.text.trim();

      // Ensure party exists in the appropriate collection
      await _ensurePartyExists(partyName);

      // Add the transaction
      await FirebaseFirestore.instance.collection('transactions').add({
        'product': _productController.text.toLowerCase().trim(),
        'quantity': int.parse(_quantityController.text),
        'unitPrice': double.parse(_unitPriceController.text),
        'party': partyName,
        'date': DateFormat('dd-MM-yyyy').parse(_dateController.text),
        'type': _selectedType,
        'status': _selectedStatus,
        'user': user!.uid,
        'timestamp': DateTime.now(),
      });

      // Update stock
      await _updateStock(
        _productController.text.toLowerCase().trim(),
        int.parse(_quantityController.text),
        _selectedType,
      );

      Fluttertoast.showToast(
          msg: "Transaction Added Successfully",
          backgroundColor: Colors.green
      );
      Navigator.pop(context);
    } catch (error) {
      Fluttertoast.showToast(
          msg: "Failed to add transaction: $error",
          backgroundColor: Colors.red
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd-MM-yyyy').format(DateTime.now());

    _productFocusNode.addListener(() {
      setState(() => _showProductSuggestions = _productFocusNode.hasFocus);
    });

    _partyFocusNode.addListener(() {
      setState(() => _showPartySuggestions = _partyFocusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _productController.dispose();
    _productFocusNode.dispose();
    _partyController.dispose();
    _partyFocusNode.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Widget _buildSuggestionsList({
    required Stream<List<String>> stream,
    required TextEditingController controller,
    required FocusNode focusNode,
  }) {
    return StreamBuilder<List<String>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              height: 40,
              child: Center(child: CircularProgressIndicator())
          );
        }

        final suggestions = snapshot.data ?? [];
        if (suggestions.isEmpty) return const SizedBox.shrink();

        return Container(
          constraints: const BoxConstraints(maxHeight: 150),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 4
              )
            ],
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: suggestions.length,
            itemBuilder: (context, index) => ListTile(
              dense: true,
              title: Text(suggestions[index]),
              onTap: () {
                controller.text = suggestions[index];
                focusNode.unfocus();
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Add Transaction"),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Product field with suggestions
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _productController,
                    focusNode: _productFocusNode,
                    decoration: const InputDecoration(
                      labelText: "Product",
                      hintText: "Enter Product name",
                    ),
                    validator: (value) =>
                    value?.trim().isEmpty == true ? "Please enter product name" : null,
                    onChanged: (value) => setState(() {}),
                  ),
                  if (_showProductSuggestions && _productController.text.trim().isNotEmpty)
                    _buildSuggestionsList(
                      stream: _getProductSuggestions(_productController.text),
                      controller: _productController,
                      focusNode: _productFocusNode,
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Quantity field
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: "Quantity"),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.trim().isEmpty == true) return "Please enter quantity";
                  final qty = int.tryParse(value!);
                  return qty == null || qty <= 0 ? "Quantity must be greater than 0" : null;
                },
              ),

              // Unit Price field
              TextFormField(
                controller: _unitPriceController,
                decoration: const InputDecoration(labelText: "Unit Price"),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.trim().isEmpty == true) return "Please enter unit price";
                  final price = double.tryParse(value!);
                  return price == null || price <= 0 ? "Unit price must be greater than 0" : null;
                },
              ),

              // Date field
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: "Date",
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    _dateController.text = DateFormat('dd-MM-yyyy').format(pickedDate);
                  }
                },
                validator: (value) =>
                value?.trim().isEmpty == true ? "Please select date" : null,
              ),

              // Type dropdown
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: ['Purchase', 'Sale']
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                    // Clear party field when type changes
                    _partyController.clear();
                    _partyFocusNode.unfocus();
                  });
                },
                decoration: const InputDecoration(labelText: "Type"),
                validator: (value) => value == null ? "Please select type" : null,
              ),

              // Party field with suggestions
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _partyController,
                    focusNode: _partyFocusNode,
                    decoration: InputDecoration(
                      labelText: _partyLabel,
                      hintText: "Enter $_partyLabel name",
                    ),
                    validator: (value) =>
                    value?.trim().isEmpty == true ? "Please enter $_partyLabel name" : null,
                    onChanged: (value) => setState(() {}),
                  ),
                  if (_showPartySuggestions && _partyController.text.trim().isNotEmpty)
                    _buildSuggestionsList(
                      stream: _getPartySuggestions(_partyController.text),
                      controller: _partyController,
                      focusNode: _partyFocusNode,
                    ),
                ],
              ),

              // Status dropdown
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                items: ['Paid', 'Due']
                    .map((status) => DropdownMenuItem(value: status, child: Text(status)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedStatus = value!),
                decoration: const InputDecoration(labelText: "Status"),
                validator: (value) => value == null ? "Please select status" : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
          child: const Text("Cancel", style: TextStyle(color: Colors.white)),
        ),
        ElevatedButton(
          onPressed: _submitTransaction,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          child: const Text("Submit", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}