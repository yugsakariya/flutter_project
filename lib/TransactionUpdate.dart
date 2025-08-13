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
  final _customProductController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _dateController = TextEditingController();
  final _partyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _productFocusNode = FocusNode();
  final _partyFocusNode = FocusNode();

  String _type = '';
  String _status = '';
  String _selectedProduct = '';
  bool _showCustomProductField = false;
  bool _isLoading = false;
  bool _showProductSuggestions = false;
  bool _showPartySuggestions = false;
  int _availableStock = 0;

  // Original values to track changes
  String _originalProduct = '';
  int _originalQuantity = 0;
  String _originalType = '';
  String _originalParty = '';

  final User? user = FirebaseAuth.instance.currentUser;

  // Add predefined products list
  final List<String> _predefinedProducts = [
    'Onion',
    'Garlic',
    'Chili',
    'Wheat grains',
    'Others'
  ];

  String get _partyLabel => _type == "Purchase" ? "Supplier" : "Customer";
  String get _partyCollection => _type == "Purchase" ? "suppliers" : "customers";
  String get _originalPartyCollection => _originalType == "Purchase" ? "suppliers" : "customers";

  // Add method to get available stock
  Future<void> _getAvailableStock(String productName) async {
    if (user == null || productName.isEmpty) {
      setState(() => _availableStock = 0);
      return;
    }

    try {
      final stockQuery = await FirebaseFirestore.instance
          .collection('stocks')
          .where('product', isEqualTo: productName.toLowerCase().trim())
          .where('user', isEqualTo: user!.uid)
          .limit(1)
          .get();

      if (stockQuery.docs.isNotEmpty) {
        int currentStock = stockQuery.docs.first['quantity'] ?? 0;
        // Add back original quantity if it was a sale of the same product
        if (_originalType == 'Sale' && _originalProduct == productName.toLowerCase().trim()) {
          currentStock += _originalQuantity;
        }
        setState(() => _availableStock = currentStock);
      } else {
        setState(() => _availableStock = 0);
      }
    } catch (e) {
      setState(() => _availableStock = 0);
    }
  }

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
    final lowerQuery = query.trim().toLowerCase();
    return FirebaseFirestore.instance
        .collection('stocks')
        .where('user', isEqualTo: user?.uid)
        .snapshots()
        .map((snapshot) {
      final products = snapshot.docs
          .map((doc) => doc['product'] as String? ?? '')
          .where((product) =>
      product.isNotEmpty &&
          product.toLowerCase().contains(lowerQuery))
          .toSet()
          .toList();
      products.sort();
      return products;
    });
  }

  Stream<List<String>> _getPartySuggestions(String query) {
    if (query.trim().isEmpty || _type.isEmpty) return Stream.value([]);
    final lowerQuery = query.trim().toLowerCase();
    return FirebaseFirestore.instance
        .collection(_partyCollection)
        .where('user', isEqualTo: user?.uid)
        .snapshots()
        .map((snapshot) {
      final parties = snapshot.docs
          .map((doc) => doc['name'] as String? ?? '')
          .where((name) =>
      name.isNotEmpty &&
          name.toLowerCase().contains(lowerQuery))
          .toSet()
          .toList();
      parties.sort();
      return parties;
    });
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

        // Load original product data
        final originalProduct = data["product"] ?? '';
        _productController.text = originalProduct;

        // Set dropdown selection based on original product
        if (_predefinedProducts.contains(_capitalizeFirstLetter(originalProduct))) {
          _selectedProduct = _capitalizeFirstLetter(originalProduct);
          _showCustomProductField = false;
        } else {
          _selectedProduct = 'Others';
          _showCustomProductField = true;
          _customProductController.text = originalProduct;
        }

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

        // Get available stock if it's a sale transaction
        if (_type == 'Sale') {
          await _getAvailableStock(originalProduct);
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error loading data: $e", backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  // Check if a bill exists for this transaction
  Future<DocumentSnapshot?> _findCorrespondingBill() async {
    if (_originalType != 'Sale') return null;
    try {
      final billQuery = await FirebaseFirestore.instance
          .collection('bills')
          .where('user', isEqualTo: user!.uid)
          .where('customerName', isEqualTo: _originalParty)
          .get();

      for (final billDoc in billQuery.docs) {
        final billData = billDoc.data();
        final items = billData['items'] as List? ?? [];
        for (final item in items) {
          if (item['name']?.toString().toLowerCase() == _originalProduct.toLowerCase()) {
            return billDoc;
          }
        }
      }
      return null;
    } catch (e) {
      print('Error finding corresponding bill: $e');
      return null;
    }
  }

  // Update the corresponding bill
  Future<void> _updateCorrespondingBill() async {
    if (_type != 'Sale') return;
    final billDoc = await _findCorrespondingBill();
    if (billDoc == null) return;

    try {
      final billData = billDoc.data() as Map<String, dynamic>;
      final items = List<Map<String, dynamic>>.from(billData['items'] ?? []);
      bool itemUpdated = false;

      for (int i = 0; i < items.length; i++) {
        if (items[i]['name']?.toString().toLowerCase() == _originalProduct.toLowerCase()) {
          // Get the correct product name based on selection
          String productName;
          if (_selectedProduct == 'Others') {
            productName = _customProductController.text.toLowerCase().trim();
          } else {
            productName = _selectedProduct.toLowerCase().trim();
          }

          items[i] = {
            'name': productName,
            'quantity': _quantityController.text,
            'price': _unitPriceController.text,
          };
          itemUpdated = true;
          break;
        }
      }

      if (!itemUpdated) return;

      double subtotal = 0.0;
      for (var item in items) {
        final quantity = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
        final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
        subtotal += quantity * price;
      }

      final tax = subtotal * 0.05; // 5% GST
      final total = subtotal + tax;

      await billDoc.reference.update({
        'customerName': _partyController.text.trim(),
        'items': items,
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'date': DateFormat('dd-MM-yyyy').parse(_dateController.text),
        'updatedAt': FieldValue.serverTimestamp(),
        'autoUpdated': true,
      });

      print('Bill ${billData['billNumber']} updated automatically');
    } catch (e) {
      print('Error updating corresponding bill: $e');
    }
  }

  // Generate bill number
  Future<String> _generateBillNumber() async {
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

  // Create a new bill if transaction type changed from Purchase to Sale
  Future<void> _createBillForNewSale() async {
    if (_originalType == 'Sale' || _type != 'Sale') return;

    try {
      final billNumber = await _generateBillNumber();
      final quantity = int.parse(_quantityController.text);
      final unitPrice = double.parse(_unitPriceController.text);
      final subtotal = quantity * unitPrice;
      final tax = subtotal * 0.05; // 5% GST
      final total = subtotal + tax;

      // Get the correct product name based on selection
      String productName;
      if (_selectedProduct == 'Others') {
        productName = _customProductController.text.toLowerCase().trim();
      } else {
        productName = _selectedProduct.toLowerCase().trim();
      }

      final items = [{
        'name': productName,
        'quantity': _quantityController.text,
        'price': _unitPriceController.text,
      }];

      await FirebaseFirestore.instance.collection('bills').add({
        'user': user!.uid,
        'billNumber': billNumber,
        'customerName': _partyController.text.trim(),
        'customerPhone': '',
        'date': DateFormat('dd-MM-yyyy').parse(_dateController.text),
        'items': items,
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'createdAt': FieldValue.serverTimestamp(),
        'autoGenerated': true,
        'autoUpdated': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Bill $billNumber auto-generated for updated sale transaction');
    } catch (e) {
      print('Error auto-generating bill: $e');
    }
  }

  // Delete corresponding bill if transaction type changed from Sale to Purchase
  Future<void> _deleteBillForRemovedSale() async {
    if (_originalType != 'Sale' || _type == 'Sale') return;
    final billDoc = await _findCorrespondingBill();
    if (billDoc == null) return;

    try {
      final billData = billDoc.data() as Map<String, dynamic>;
      final items = billData['items'] as List? ?? [];

      if (items.length == 1 &&
          items[0]['name']?.toString().toLowerCase() == _originalProduct.toLowerCase()) {
        await billDoc.reference.delete();
        print('Bill ${billData['billNumber']} deleted as transaction type changed from Sale to Purchase');
      } else {
        final updatedItems = items.where((item) =>
        item['name']?.toString().toLowerCase() != _originalProduct.toLowerCase()).toList();

        if (updatedItems.isNotEmpty) {
          double subtotal = 0.0;
          for (var item in updatedItems) {
            final quantity = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
            final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
            subtotal += quantity * price;
          }

          final tax = subtotal * 0.05;
          final total = subtotal + tax;

          await billDoc.reference.update({
            'items': updatedItems,
            'subtotal': subtotal,
            'tax': tax,
            'total': total,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          await billDoc.reference.delete();
        }
      }
    } catch (e) {
      print('Error handling bill for removed sale: $e');
    }
  }

  Future<void> _updateStocks() async {
    if (user == null) return;
    final batch = FirebaseFirestore.instance.batch();

    // Get the correct product name based on selection
    String newProduct;
    if (_selectedProduct == 'Others') {
      newProduct = _customProductController.text.toLowerCase().trim();
    } else {
      newProduct = _selectedProduct.toLowerCase().trim();
    }

    final newQuantity = int.parse(_quantityController.text);

    // Revert original transaction impact
    await _revertOriginalStock(batch);

    // Apply new transaction impact (with negative stock check)
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
    int futureStock = 0;

    if (stockQuery.docs.isNotEmpty) {
      final stockData = stockQuery.docs.first.data();
      futureStock = (stockData['quantity'] ?? 0) + qty;

      // PREVENT NEGATIVE STOCK
      if (futureStock < 0) {
        final currentStock = stockData['quantity'] ?? 0;
        Fluttertoast.showToast(
            msg: "Insufficient stock! Available: $currentStock",
            backgroundColor: Colors.red
        );
        throw Exception("Stock cannot be negative");
      }

      batch.update(stockQuery.docs.first.reference, {
        'quantity': futureStock,
        'purchase': FieldValue.increment(_type == "Purchase" ? newQuantity : 0),
        'sales': FieldValue.increment(_type == "Sale" ? newQuantity : 0),
        'lastUpdated': DateTime.now(),
      });
    } else if (_type == "Purchase") {
      final newStockRef = FirebaseFirestore.instance.collection('stocks').doc();
      batch.set(newStockRef, {
        'product': newProduct,
        'quantity': newQuantity,
        'purchase': newQuantity,
        'sales': 0,
        'user': user!.uid,
        'createdAt': DateTime.now(),
        'lastUpdated': DateTime.now(),
      });
    } else {
      Fluttertoast.showToast(
          msg: "Cannot sell non-existent product!",
          backgroundColor: Colors.red
      );
      throw Exception("Product not in stock");
    }
  }

  Future<void> _cleanupOldStockIfUnused(WriteBatch batch) async {
    final otherTransactions = await FirebaseFirestore.instance
        .collection('transactions')
        .where('user', isEqualTo: user!.uid)
        .where('product', isEqualTo: _originalProduct)
        .get();

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

    if (partyQuery.docs.isEmpty) {
      await FirebaseFirestore.instance.collection(_partyCollection).add({
        'name': partyName.trim(),
        'user': user!.uid,
        'createdAt': DateTime.now(),
        'lastUpdated': DateTime.now(),
      });
    } else {
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

    return otherTransactions.docs.length > 1;
  }

  Future<void> _cleanupOldPartyIfUnused() async {
    if (user == null || _originalParty.trim().isEmpty) return;
    if (_originalParty.trim() == _partyController.text.trim() &&
        _originalType == _type) return;

    final isUsed = await _isPartyUsedByOtherTransactions(_originalParty, _originalPartyCollection);
    if (!isUsed) {
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

      // Get the correct product name based on selection
      String productName;
      if (_selectedProduct == 'Others') {
        productName = _customProductController.text.toLowerCase().trim();
      } else {
        productName = _selectedProduct.toLowerCase().trim();
      }

      // Check stock availability BEFORE processing sale
      if (_type == 'Sale') {
        final stockQuery = await FirebaseFirestore.instance
            .collection('stocks')
            .where('product', isEqualTo: productName)
            .where('user', isEqualTo: user!.uid)
            .limit(1)
            .get();

        int availableStock = 0;
        if (stockQuery.docs.isNotEmpty) {
          availableStock = stockQuery.docs.first['quantity'] ?? 0;
          // Add back the original quantity if it was a sale
          if (_originalType == 'Sale' && _originalProduct == productName) {
            availableStock += _originalQuantity;
          }
        }

        final newQuantity = int.parse(_quantityController.text);
        if (newQuantity > availableStock) {
          Fluttertoast.showToast(
              msg: "Insufficient stock. Available: $availableStock",
              backgroundColor: Colors.red
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      // Update stocks first
      await _updateStocks();

      // Ensure new party exists
      await _ensurePartyExists(newPartyName);

      // Handle bill updates based on transaction type changes
      if (_originalType == 'Sale' && _type == 'Sale') {
        // Update existing bill
        await _updateCorrespondingBill();
      } else if (_originalType != 'Sale' && _type == 'Sale') {
        // Create new bill for new sale
        await _createBillForNewSale();
      } else if (_originalType == 'Sale' && _type != 'Sale') {
        // Delete or update bill for removed sale
        await _deleteBillForRemovedSale();
      }

      // Update the transaction
      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(widget.docRef)
          .update({
        "product": productName,
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

      String successMessage = "Transaction updated successfully";
      if (_type == 'Sale') {
        successMessage += " and bill updated";
      }

      Fluttertoast.showToast(
          msg: successMessage,
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

        if (snapshot.hasError) {
          print("Suggestion error: ${snapshot.error}");
          return const SizedBox.shrink();
        }

        final suggestions = snapshot.data ?? [];
        if (suggestions.isEmpty) return const SizedBox.shrink();

        return Container(
          constraints: const BoxConstraints(maxHeight: 150),
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
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: suggestions.length,
            itemBuilder: (context, index) => ListTile(
              dense: true,
              title: Text(
                suggestions[index],
                style: const TextStyle(fontSize: 14),
              ),
              onTap: () {
                controller.text = suggestions[index];
                focusNode.unfocus();
                setState(() {
                  if (controller == _customProductController) {
                    _showProductSuggestions = false;
                  } else {
                    _showPartySuggestions = false;
                  }
                });
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
            mainAxisSize: MainAxisSize.min,
            children: [
              // Type dropdown - MOVED TO TOP
              DropdownButtonFormField<String>(
                value: _type.isEmpty ? null : _type,
                items: ['Purchase', 'Sale']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: _isLoading ? null : (v) {
                  setState(() {
                    _type = v!;
                    _partyController.clear();
                    _partyFocusNode.unfocus();
                    _showPartySuggestions = false;
                    _availableStock = 0; // Reset stock when type changes
                  });
                },
                decoration: const InputDecoration(
                  labelText: "Type",
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null ? "Type required" : null,
              ),
              const SizedBox(height: 16),

              // Product dropdown with custom field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedProduct.isEmpty ? null : _selectedProduct,
                    items: _predefinedProducts.map((product) {
                      return DropdownMenuItem<String>(
                        value: product,
                        child: Text(product),
                      );
                    }).toList(),
                    onChanged: _isLoading ? null : (String? value) async {
                      setState(() {
                        _selectedProduct = value ?? '';
                        _showCustomProductField = value == 'Others';

                        if (value != 'Others') {
                          _productController.text = value?.toLowerCase() ?? '';
                          _customProductController.clear();
                        } else {
                          _productController.clear();
                        }
                      });

                      // Get stock for selected product if it's a sale
                      if (_type == 'Sale' && value != 'Others' && value != null) {
                        await _getAvailableStock(value.toLowerCase());
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: "Product",
                      hintText: "Select a product",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null ? "Please select a product" : null,
                  ),

                  // Custom product field (shown only when "Others" is selected)
                  if (_showCustomProductField) ...[
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _customProductController,
                          focusNode: _productFocusNode,
                          enabled: !_isLoading,
                          decoration: const InputDecoration(
                            labelText: "Custom Product Name",
                            hintText: "Enter custom product name",
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (_selectedProduct == 'Others' && (value?.trim().isEmpty == true)) {
                              return "Please enter custom product name";
                            }
                            return null;
                          },
                          onChanged: (value) async {
                            // Normalize the product name to lowercase for storage
                            final normalizedProductName = value.toLowerCase().trim();
                            _productController.text = normalizedProductName;
                            setState(() {});

                            // Get stock for custom product if it's a sale
                            if (_type == 'Sale' && value.trim().isNotEmpty) {
                              await _getAvailableStock(normalizedProductName);
                            }
                          },
                        ),
                        if (_showProductSuggestions &&
                            _customProductController.text.trim().isNotEmpty &&
                            !_isLoading)
                          _buildSuggestionsList(
                            stream: _getProductSuggestions(_customProductController.text),
                            controller: _customProductController,
                            focusNode: _productFocusNode,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Quantity field with stock hint for Sale
              TextFormField(
                controller: _quantityController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: "Quantity",
                  // Show available stock hint for Sale transactions
                  hintText: _type == 'Sale' && (_selectedProduct.isNotEmpty && _selectedProduct != 'Others' || _customProductController.text.isNotEmpty)
                      ? "Available stock: $_availableStock"
                      : "Enter quantity",
                  border: const OutlineInputBorder(),
                  // Add helper text for better visibility
                  helperText: _type == 'Sale' && (_selectedProduct.isNotEmpty && _selectedProduct != 'Others' || _customProductController.text.isNotEmpty)
                      ? "Available: $_availableStock"
                      : null,
                  helperStyle: TextStyle(
                    color: _availableStock > 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v?.trim().isEmpty == true) return "Quantity required";
                  final qty = int.tryParse(v!);
                  if (qty == null || qty <= 0) return "Enter a valid quantity";

                  // Additional validation for Sale transactions
                  if (_type == 'Sale' && qty > _availableStock) {
                    return "Insufficient stock. Available: $_availableStock";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Unit Price field
              TextFormField(
                controller: _unitPriceController,
                enabled: !_isLoading,
                decoration: const InputDecoration(
                  labelText: "Unit Price",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v?.trim().isEmpty == true) return "Unit price required";
                  final price = double.tryParse(v!);
                  return price == null || price <= 0 ? "Enter a valid price" : null;
                },
              ),
              const SizedBox(height: 16),

              // Date field
              TextFormField(
                controller: _dateController,
                enabled: !_isLoading,
                decoration: const InputDecoration(
                  labelText: "Date",
                  suffixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                onTap: _isLoading ? null : () async {
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
              const SizedBox(height: 16),

              // Party field with suggestions
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _partyController,
                    focusNode: _partyFocusNode,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      labelText: _partyLabel,
                      hintText: "Enter $_partyLabel name",
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => v?.trim().isEmpty == true ? "Please enter $_partyLabel name" : null,
                    onChanged: (value) => setState(() {}),
                  ),
                  if (_showPartySuggestions &&
                      _partyController.text.trim().isNotEmpty &&
                      _type.isNotEmpty &&
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
                value: _status.isEmpty ? null : _status,
                items: ['Paid', 'Due']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: _isLoading ? null : (v) => setState(() => _status = v!),
                decoration: const InputDecoration(
                  labelText: "Status",
                  border: OutlineInputBorder(),
                ),
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
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          child: const Text("Update", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _productController.dispose();
    _customProductController.dispose();
    _productFocusNode.dispose();
    _partyController.dispose();
    _partyFocusNode.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _dateController.dispose();
    super.dispose();
  }
}
