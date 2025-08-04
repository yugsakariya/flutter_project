import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

class Transactionupdate extends StatefulWidget {
  final String docRef;
  const Transactionupdate({super.key, required this.docRef});

  @override
  State<Transactionupdate> createState() => _TransactionupdateState();
}

class _TransactionupdateState extends State<Transactionupdate> {
  final _productController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _dateController = TextEditingController();
  final _partyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _productFocusNode = FocusNode();
  final _partyFocusNode = FocusNode();

  String _type = '';
  String _status = '';
  bool _isLoading = false;
  bool _showProductSuggestions = false;
  bool _showPartySuggestions = false;

  // Original values to track changes
  String _originalProduct = '';
  int _originalQuantity = 0;
  String _originalType = '';
  String _originalParty = '';

  final User? user = FirebaseAuth.instance.currentUser;

  String get _partyLabel => _type == "Purchase" ? "Supplier" : "Customer";
  String get _partyCollection => _type == "Purchase" ? "suppliers" : "customers";
  String get _originalPartyCollection => _originalType == "Purchase" ? "suppliers" : "customers";

  @override
  void initState() {
    super.initState();
    _loadTransactionData();

    _productFocusNode.addListener(() {
      setState(() => _showProductSuggestions = _productFocusNode.hasFocus);
    });

    _partyFocusNode.addListener(() {
      setState(() => _showPartySuggestions = _partyFocusNode.hasFocus);
    });
  }

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
        .toSet()
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
        .toSet()
        .toList()..sort());
  }

  Future<void> _loadTransactionData() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('transactions')
          .doc(widget.docRef)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _productController.text = data["product"] ?? '';
        _quantityController.text = data["quantity"]?.toString() ?? '';
        _unitPriceController.text = data["unitPrice"]?.toString() ?? '';
        _dateController.text = DateFormat('dd-MM-yyyy').format(data['date'].toDate());
        _partyController.text = data["party"] ?? '';
        _type = data['type'] ?? '';
        _status = data['status'] ?? '';

        // Store original values
        _originalProduct = data['product'] ?? '';
        _originalQuantity = data['quantity'] ?? 0;
        _originalType = data['type'] ?? '';
        _originalParty = data['party'] ?? '';
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error loading data: $e", backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  Future<void> _updateStocks() async {
    if (user == null) return;

    final batch = FirebaseFirestore.instance.batch();
    final newProduct = _productController.text.toLowerCase().trim();
    final newQuantity = int.parse(_quantityController.text);

    // Revert original transaction impact
    await _revertOriginalStock(batch);

    // Apply new transaction impact
    await _applyNewStock(batch, newProduct, newQuantity);

    // Clean up old stock if product name changed and no other transactions use it
    if (_originalProduct != newProduct) {
      await _cleanupOldStockIfUnused(batch);
    }

    await batch.commit();
  }

  Future<void> _revertOriginalStock(WriteBatch batch) async {
    final stockQuery = await FirebaseFirestore.instance
        .collection('stocks')
        .where('user', isEqualTo: user!.uid)
        .where('product', isEqualTo: _originalProduct)
        .limit(1)
        .get();

    if (stockQuery.docs.isNotEmpty) {
      final stockRef = stockQuery.docs.first.reference;
      final revertQty = _originalType == 'Purchase' ? -_originalQuantity : _originalQuantity;
      final revertPurchase = _originalType == 'Purchase' ? -_originalQuantity : 0;
      final revertSales = _originalType == 'Sale' ? -_originalQuantity : 0;

      batch.update(stockRef, {
        'quantity': FieldValue.increment(revertQty),
        'purchase': FieldValue.increment(revertPurchase),
        'sales': FieldValue.increment(revertSales),
        'lastUpdated': DateTime.now(),
      });
    }
  }

  Future<void> _applyNewStock(WriteBatch batch, String newProduct, int newQuantity) async {
    final stockQuery = await FirebaseFirestore.instance
        .collection('stocks')
        .where('user', isEqualTo: user!.uid)
        .where('product', isEqualTo: newProduct)
        .limit(1)
        .get();

    final qty = _type == 'Purchase' ? newQuantity : -newQuantity;
    final purchase = _type == 'Purchase' ? newQuantity : 0;
    final sales = _type == 'Sale' ? newQuantity : 0;

    if (stockQuery.docs.isNotEmpty) {
      batch.update(stockQuery.docs.first.reference, {
        'quantity': FieldValue.increment(qty),
        'purchase': FieldValue.increment(purchase),
        'sales': FieldValue.increment(sales),
        'lastUpdated': DateTime.now(),
      });
    } else {
      final newStockRef = FirebaseFirestore.instance.collection('stocks').doc();
      batch.set(newStockRef, {
        'product': newProduct,
        'quantity': qty,
        'purchase': purchase,
        'sales': sales,
        'user': user!.uid,
        'createdAt': DateTime.now(),
        'lastUpdated': DateTime.now(),
      });
    }
  }

  Future<void> _cleanupOldStockIfUnused(WriteBatch batch) async {
    // Check if other transactions exist for the old product
    final otherTransactions = await FirebaseFirestore.instance
        .collection('transactions')
        .where('user', isEqualTo: user!.uid)
        .where('product', isEqualTo: _originalProduct)
        .get();

    // If this was the only transaction, delete the stock
    if (otherTransactions.docs.length == 1) {
      final stockQuery = await FirebaseFirestore.instance
          .collection('stocks')
          .where('user', isEqualTo: user!.uid)
          .where('product', isEqualTo: _originalProduct)
          .limit(1)
          .get();

      if (stockQuery.docs.isNotEmpty) {
        batch.delete(stockQuery.docs.first.reference);
      }
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

  Future<bool> _isPartyUsedByOtherTransactions(String partyName, String collection) async {
    if (user == null || partyName.trim().isEmpty) return false;

    final otherTransactions = await FirebaseFirestore.instance
        .collection('transactions')
        .where('user', isEqualTo: user!.uid)
        .where('party', isEqualTo: partyName.trim())
        .get();

    // Check if there are other transactions (excluding current one)
    return otherTransactions.docs.length > 1;
  }

  Future<void> _cleanupOldPartyIfUnused() async {
    if (user == null || _originalParty.trim().isEmpty) return;

    // Only cleanup if party name or type has changed
    if (_originalParty.trim() == _partyController.text.trim() &&
        _originalType == _type) return;

    // Check if the original party is used by other transactions
    final isUsed = await _isPartyUsedByOtherTransactions(_originalParty, _originalPartyCollection);

    if (!isUsed) {
      // Safe to delete the old party record
      final partyQuery = await FirebaseFirestore.instance
          .collection(_originalPartyCollection)
          .where('name', isEqualTo: _originalParty.trim())
          .where('user', isEqualTo: user!.uid)
          .limit(1)
          .get();

      if (partyQuery.docs.isNotEmpty) {
        await partyQuery.docs.first.reference.delete();
      }
    }
  }

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate() || user == null) return;

    setState(() => _isLoading = true);
    try {
      final newPartyName = _partyController.text.trim();

      // Update stocks first
      await _updateStocks();

      // Ensure new party exists
      await _ensurePartyExists(newPartyName);

      // Update the transaction
      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(widget.docRef)
          .update({
        "product": _productController.text.toLowerCase().trim(),
        "type": _type,
        "quantity": int.parse(_quantityController.text),
        "unitPrice": double.parse(_unitPriceController.text),
        "date": DateFormat('dd-MM-yyyy').parse(_dateController.text),
        "party": newPartyName,
        "status": _status,
        "lastUpdated": DateTime.now(),
      });

      // Cleanup old party if it's no longer used
      await _cleanupOldPartyIfUnused();

      Fluttertoast.showToast(
          msg: "Transaction updated successfully",
          backgroundColor: Colors.green
      );
      Navigator.pop(context);
    } catch (error) {
      Fluttertoast.showToast(
          msg: "Error: $error",
          backgroundColor: Colors.red
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      title: const Text("Update Transaction"),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
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
                    validator: (v) => v?.trim().isEmpty == true ? "Product name required" : null,
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

              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: "Quantity"),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v?.trim().isEmpty == true) return "Quantity required";
                  final qty = int.tryParse(v!);
                  return qty == null || qty <= 0 ? "Enter a valid quantity" : null;
                },
              ),

              TextFormField(
                controller: _unitPriceController,
                decoration: const InputDecoration(labelText: "Unit Price"),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v?.trim().isEmpty == true) return "Unit price required";
                  final price = double.tryParse(v!);
                  return price == null || price <= 0 ? "Enter a valid price" : null;
                },
              ),

              DropdownButtonFormField<String>(
                value: _type.isEmpty ? null : _type,
                items: ['Purchase', 'Sale']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _type = v!;
                    // Clear party field when type changes
                    _partyController.clear();
                    _partyFocusNode.unfocus();
                  });
                },
                decoration: const InputDecoration(labelText: "Type"),
                validator: (v) => v == null ? "Type required" : null,
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
                    validator: (v) => v?.trim().isEmpty == true ? "Please enter $_partyLabel name" : null,
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

              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: "Date",
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    _dateController.text = DateFormat('dd-MM-yyyy').format(picked);
                  }
                },
                validator: (v) => v?.trim().isEmpty == true ? "Date required" : null,
              ),

              DropdownButtonFormField<String>(
                value: _status.isEmpty ? null : _status,
                items: ['Paid', 'Due']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
                decoration: const InputDecoration(labelText: "Status"),
                validator: (v) => v == null ? "Status required" : null,
              ),
            ],
          ),
        ),
      ),
      actions: _isLoading
          ? []
          : [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _submitUpdate,
          child: const Text("Submit"),
        ),
      ],
    );
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
}