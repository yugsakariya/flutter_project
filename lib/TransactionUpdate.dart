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

  String _type = '';
  String _status = '';
  bool _isLoading = false;

  // Original values to track changes
  String _originalProduct = '';
  int _originalQuantity = 0;
  String _originalType = '';

  final User? user = FirebaseAuth.instance.currentUser;

  String get _partyLabel => _type == "Purchase" ? "Supplier" : "Customer";

  @override
  void initState() {
    super.initState();
    _loadTransactionData();
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
    final newProduct = _productController.text.toLowerCase();
    final newQuantity = int.parse(_quantityController.text);

    // Revert original transaction impact
    await _revertOriginalStock(batch);

    // Apply new transaction impact
    await _applyNewStock(batch, newProduct, newQuantity);

    // Clean up old stock if product name changed
    if (_originalProduct != newProduct) {
      await _cleanupOldStock(batch);
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

  Future<void> _cleanupOldStock(WriteBatch batch) async {
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

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate() || user == null) return;

    setState(() => _isLoading = true);
    try {
      await _updateStocks();

      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(widget.docRef)
          .update({
        "product": _productController.text.toLowerCase(),
        "type": _type,
        "quantity": int.parse(_quantityController.text),
        "unitPrice": double.parse(_unitPriceController.text),
        "date": DateFormat('dd-MM-yyyy').parse(_dateController.text),
        "party": _partyController.text,
        "status": _status,
        "lastUpdated": DateTime.now(),
      });

      Fluttertoast.showToast(msg: "Transaction updated successfully", backgroundColor: Colors.green);
      Navigator.pop(context);
    } catch (error) {
      Fluttertoast.showToast(msg: "Error: $error", backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
              TextFormField(
                controller: _productController,
                decoration: const InputDecoration(labelText: "Product"),
                validator: (v) => v?.isEmpty == true ? "Product name required" : null,
              ),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: "Quantity"),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v?.isEmpty == true) return "Quantity required";
                  final qty = int.tryParse(v!);
                  return qty == null || qty <= 0 ? "Enter a valid quantity" : null;
                },
              ),
              TextFormField(
                controller: _unitPriceController,
                decoration: const InputDecoration(labelText: "Unit Price"),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v?.isEmpty == true) return "Unit price required";
                  final price = double.tryParse(v!);
                  return price == null || price <= 0 ? "Enter a valid price" : null;
                },
              ),
              DropdownButtonFormField<String>(
                value: _type.isEmpty ? null : _type,
                items: ['Purchase', 'Sale']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
                decoration: const InputDecoration(labelText: "Type"),
                validator: (v) => v == null ? "Type required" : null,
              ),
              TextFormField(
                controller: _partyController,
                decoration: InputDecoration(labelText: _partyLabel),
                validator: (v) => v?.isEmpty == true ? "Please enter $_partyLabel name" : null,
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
                validator: (v) => v?.isEmpty == true ? "Date required" : null,
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
    _quantityController.dispose();
    _unitPriceController.dispose();
    _dateController.dispose();
    _partyController.dispose();
    super.dispose();
  }
}