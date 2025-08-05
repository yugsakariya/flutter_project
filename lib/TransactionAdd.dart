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
  bool _isLoading = false; // Added loading state

  final User? user = FirebaseAuth.instance.currentUser;

  String get _partyLabel => _selectedType == "Purchase" ? "Supplier" : "Customer";
  String get _partyCollection => _selectedType == "Purchase" ? "suppliers" : "customers";

  Stream<List<String>> _getProductSuggestions(String query) {
    if (query.trim().isEmpty) return Stream.value([]);

    final lowercaseQuery = query.trim().toLowerCase();

    return FirebaseFirestore.instance
        .collection('stocks')
        .where('user', isEqualTo: user?.uid)
        .snapshots()
        .map((snapshot) {
      final products = snapshot.docs
          .map((doc) => doc['product'] as String? ?? '')
          .where((product) => product.isNotEmpty &&
          product.toLowerCase().contains(lowercaseQuery))
          .toSet()
          .toList();

      products.sort();
      return products.take(10).toList(); // Limit to 10 suggestions
    });
  }

  Stream<List<String>> _getPartySuggestions(String query) {
    if (query.trim().isEmpty) return Stream.value([]);

    final lowercaseQuery = query.trim().toLowerCase();

    return FirebaseFirestore.instance
        .collection(_partyCollection)
        .where('user', isEqualTo: user?.uid)
        .snapshots()
        .map((snapshot) {
      final parties = snapshot.docs
          .map((doc) => doc['name'] as String? ?? '')
          .where((name) => name.isNotEmpty &&
          name.toLowerCase().contains(lowercaseQuery))
          .toSet()
          .toList();

      parties.sort();
      return parties.take(10).toList(); // Limit to 10 suggestions
    });
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

    setState(() {
      _isLoading = true; // Start loading
    });

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
    } finally {
      setState(() {
        _isLoading = false; // Stop loading
      });
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
          return Container(
            height: 40,
            margin: const EdgeInsets.only(top: 4),
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
            child: const Center(child: CircularProgressIndicator()),
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
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2)
              )
            ],
          ),
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
                setState(() {}); // Refresh to hide suggestions
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  suggestions[index],
                  style: const TextStyle(fontSize: 14),
                ),
              ),
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
                    enabled: !_isLoading, // Disable when loading
                    decoration: const InputDecoration(
                      labelText: "Product",
                      hintText: "Enter Product name",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                    value?.trim().isEmpty == true ? "Please enter product name" : null,
                    onChanged: (value) => setState(() {}),
                  ),
                  if (_showProductSuggestions &&
                      _productController.text.trim().isNotEmpty &&
                      !_isLoading)
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
                enabled: !_isLoading, // Disable when loading
                decoration: const InputDecoration(
                  labelText: "Quantity",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.trim().isEmpty == true) return "Please enter quantity";
                  final qty = int.tryParse(value!);
                  return qty == null || qty <= 0 ? "Quantity must be greater than 0" : null;
                },
              ),

              const SizedBox(height: 16),

              // Unit Price field
              TextFormField(
                controller: _unitPriceController,
                enabled: !_isLoading, // Disable when loading
                decoration: const InputDecoration(
                  labelText: "Unit Price",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.trim().isEmpty == true) return "Please enter unit price";
                  final price = double.tryParse(value!);
                  return price == null || price <= 0 ? "Unit price must be greater than 0" : null;
                },
              ),

              const SizedBox(height: 16),

              // Date field
              TextFormField(
                controller: _dateController,
                enabled: !_isLoading, // Disable when loading
                decoration: const InputDecoration(
                  labelText: "Date",
                  suffixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                onTap: _isLoading ? null : () async { // Disable tap when loading
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

              const SizedBox(height: 16),

              // Type dropdown
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: ['Purchase', 'Sale']
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: _isLoading ? null : (value) { // Disable when loading
                  setState(() {
                    _selectedType = value!;
                    // Clear party field when type changes
                    _partyController.clear();
                    _partyFocusNode.unfocus();
                  });
                },
                decoration: const InputDecoration(
                  labelText: "Type",
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null ? "Please select type" : null,
              ),

              const SizedBox(height: 16),

              // Party field with suggestions
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _partyController,
                    focusNode: _partyFocusNode,
                    enabled: !_isLoading, // Disable when loading
                    decoration: InputDecoration(
                      labelText: _partyLabel,
                      hintText: "Enter $_partyLabel name",
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) =>
                    value?.trim().isEmpty == true ? "Please enter $_partyLabel name" : null,
                    onChanged: (value) => setState(() {}),
                  ),
                  if (_showPartySuggestions &&
                      _partyController.text.trim().isNotEmpty &&
                      !_isLoading)
                    _buildSuggestionsList(
                      stream: _getPartySuggestions(_partyController.text),
                      controller: _partyController,
                      focusNode: _partyFocusNode,
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Status dropdown
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                items: ['Paid', 'Due']
                    .map((status) => DropdownMenuItem(value: status, child: Text(status)))
                    .toList(),
                onChanged: _isLoading ? null : (value) => setState(() => _selectedStatus = value!), // Disable when loading
                decoration: const InputDecoration(
                  labelText: "Status",
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null ? "Please select status" : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context), // Disable when loading
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
          child: const Text("Cancel", style: TextStyle(color: Colors.white)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitTransaction, // Disable when loading
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          child: _isLoading
              ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : const Text("Submit", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}