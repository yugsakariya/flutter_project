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
  final _customProductController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _dateController = TextEditingController();
  final _partyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _productFocusNode = FocusNode();
  final _partyFocusNode = FocusNode();

  String _selectedType = 'Purchase';
  String _selectedStatus = 'Paid';
  String _selectedProduct = '';
  bool _showCustomProductField = false;
  bool _showProductSuggestions = false;
  bool _showPartySuggestions = false;
  bool _isLoading = false;
  int _availableStock = 0;

  final User? user = FirebaseAuth.instance.currentUser;

  // Add predefined products list
  final List<String> _predefinedProducts = [
    'Onion',
    'Garlic',
    'Chili',
    'Wheat grains',
    'Others'
  ];

  String get _partyLabel => _selectedType == "Purchase" ? "Supplier" : "Customer";
  String get _partyCollection => _selectedType == "Purchase" ? "suppliers" : "customers";

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
        setState(() => _availableStock = stockQuery.docs.first['quantity'] ?? 0);
      } else {
        setState(() => _availableStock = 0);
      }
    } catch (e) {
      setState(() => _availableStock = 0);
    }
  }

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
      return products.take(10).toList();
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
      return parties.take(10).toList();
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

    int quantityChange = type == "Purchase" ? quantity : -quantity;
    int newQuantity = 0;

    if (stockQuery.docs.isNotEmpty) {
      final currentStock = stockQuery.docs.first.data();
      final currentQty = currentStock['quantity'] ?? 0;
      newQuantity = currentQty + quantityChange;

      // PREVENT NEGATIVE STOCK
      if (newQuantity < 0) {
        Fluttertoast.showToast(
            msg: "Insufficient stock! Available: $currentQty",
            backgroundColor: Colors.red
        );
        throw Exception("Stock cannot be negative");
      }

      await stockQuery.docs.first.reference.update({
        'quantity': newQuantity,
        'purchase': FieldValue.increment(type == "Purchase" ? quantity : 0),
        'sales': FieldValue.increment(type == "Sale" ? quantity : 0),
        'lastUpdated': DateTime.now(),
      });
    } else if (type == "Purchase") {
      // Purchase can add new stock
      await FirebaseFirestore.instance.collection('stocks').add({
        'product': product,
        'quantity': quantity,
        'purchase': quantity,
        'sales': 0,
        'user': user!.uid,
        'createdAt': DateTime.now(),
        'lastUpdated': DateTime.now(),
      });
    } else {
      // Trying to sell something not in stock
      Fluttertoast.showToast(
          msg: "Cannot sell non-existent product!",
          backgroundColor: Colors.red
      );
      throw Exception("Product not in stock");
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

  // Generate bill number (same logic as in AddBill.dart)
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

  // Auto-generate bill for Sale transactions
  Future<void> _generateBillForSale(String customerName, String productName, int quantity, double unitPrice) async {
    try {
      final billNumber = await _generateBillNumber();
      final subtotal = quantity * unitPrice;
      final tax = subtotal * 0.05; // 5% GST
      final total = subtotal + tax;

      final items = [{
        'name': productName,
        'quantity': quantity.toString(),
        'price': unitPrice.toString(),
      }];

      await FirebaseFirestore.instance.collection('bills').add({
        'user': user!.uid,
        'billNumber': billNumber,
        'customerName': customerName,
        'customerPhone': '',
        'date': DateFormat('dd-MM-yyyy').parse(_dateController.text),
        'items': items,
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'createdAt': FieldValue.serverTimestamp(),
        'autoGenerated': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Bill $billNumber auto-generated for sale transaction');
    } catch (e) {
      print('Error auto-generating bill: $e');
    }
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate() || user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final partyName = _partyController.text.trim();

      // Get the correct product name based on selection
      String productName;
      if (_selectedProduct == 'Others') {
        productName = _customProductController.text.toLowerCase().trim();
      } else {
        productName = _selectedProduct.toLowerCase().trim();
      }

      final quantity = int.parse(_quantityController.text);
      final unitPrice = double.parse(_unitPriceController.text);

      // Check stock availability BEFORE processing sale
      if (_selectedType == 'Sale') {
        final stockQuery = await FirebaseFirestore.instance
            .collection('stocks')
            .where('product', isEqualTo: productName)
            .where('user', isEqualTo: user!.uid)
            .limit(1)
            .get();

        int availableStock = 0;
        if (stockQuery.docs.isNotEmpty) {
          availableStock = stockQuery.docs.first['quantity'] ?? 0;
        }

        if (quantity > availableStock) {
          Fluttertoast.showToast(
              msg: "Insufficient stock. Available: $availableStock",
              backgroundColor: Colors.red
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      // Ensure party exists
      await _ensurePartyExists(partyName);

      // Add the transaction
      await FirebaseFirestore.instance.collection('transactions').add({
        'product': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'party': partyName,
        'date': DateFormat('dd-MM-yyyy').parse(_dateController.text),
        'type': _selectedType,
        'status': _selectedStatus,
        'user': user!.uid,
        'timestamp': DateTime.now(),
      });

      // Update stock (with negative stock prevention)
      await _updateStock(productName, quantity, _selectedType);

      // Auto-generate bill for Sale transactions
      if (_selectedType == 'Sale') {
        await _generateBillForSale(partyName, productName, quantity, unitPrice);
      }

      Fluttertoast.showToast(
          msg: _selectedType == 'Sale'
              ? "Sale transaction added and bill generated successfully"
              : "Transaction Added Successfully",
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
        _isLoading = false;
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
    _customProductController.dispose();
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
                setState(() {});
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
              // Type dropdown - MOVED TO TOP
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: ['Purchase', 'Sale']
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: _isLoading ? null : (value) {
                  setState(() {
                    _selectedType = value!;
                    _partyController.clear();
                    _partyFocusNode.unfocus();
                    _availableStock = 0; // Reset stock when type changes
                  });
                },
                decoration: const InputDecoration(
                  labelText: "Type",
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null ? "Please select type" : null,
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
                      if (_selectedType == 'Sale' && value != 'Others' && value != null) {
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
                            if (_selectedType == 'Sale' && value.trim().isNotEmpty) {
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
                  hintText: _selectedType == 'Sale' && (_selectedProduct.isNotEmpty && _selectedProduct != 'Others' || _customProductController.text.isNotEmpty)
                      ? "Available stock: $_availableStock"
                      : "Enter quantity",
                  border: const OutlineInputBorder(),
                  // Add helper text for better visibility
                  helperText: _selectedType == 'Sale' && (_selectedProduct.isNotEmpty && _selectedProduct != 'Others' || _customProductController.text.isNotEmpty)
                      ? "Available: $_availableStock"
                      : null,
                  helperStyle: TextStyle(
                    color: _availableStock > 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.trim().isEmpty == true) return "Please enter quantity";
                  final qty = int.tryParse(value!);
                  if (qty == null || qty <= 0) return "Quantity must be greater than 0";

                  // Additional validation for Sale transactions
                  if (_selectedType == 'Sale' && qty > _availableStock) {
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
                enabled: !_isLoading,
                decoration: const InputDecoration(
                  labelText: "Date",
                  suffixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                onTap: _isLoading ? null : () async {
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
                onChanged: _isLoading ? null : (value) => setState(() => _selectedStatus = value!),
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
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
          child: const Text("Cancel", style: TextStyle(color: Colors.white)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitTransaction,
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
