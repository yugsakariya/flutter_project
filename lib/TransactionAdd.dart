import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'utils.dart';
import 'party_management.dart';

class Transactionadd extends StatefulWidget {
  const Transactionadd({super.key});

  @override
  State<Transactionadd> createState() => _TransactionaddState();
}

class _TransactionaddState extends State<Transactionadd> {
  final _dateController = TextEditingController();
  final _partyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _partyFocusNode = FocusNode();

  String _selectedType = 'Purchase';
  String _selectedStatus = 'Paid';
  bool _showPartySuggestions = false;
  bool _isLoading = false;

  List<Map<String, dynamic>> _products = [
    _createEmptyProduct(),
  ];

  final List<String> _predefinedProducts = [
    'Onion',
    'Garlic',
    'Chili',
    'Wheat grains',
    'Others'
  ];

  static Map<String, dynamic> _createEmptyProduct() {
    return {
      'productController': TextEditingController(),
      'customProductController': TextEditingController(),
      'quantityController': TextEditingController(),
      'unitPriceController': TextEditingController(),
      'productFocusNode': FocusNode(),
      'selectedProduct': '',
      'showCustomProductField': false,
      'showProductSuggestions': false,
      'availableStock': 0,
    };
  }

  String get _partyLabel => _selectedType == "Purchase" ? "Supplier" : "Customer";
  String get _partyCollection => _selectedType == "Purchase" ? "suppliers" : "customers";

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
    _partyFocusNode.addListener(() {
      setState(() => _showPartySuggestions = _partyFocusNode.hasFocus);
    });

    (_products[0]['productFocusNode'] as FocusNode).addListener(() {
      setState(() => _products[0]['showProductSuggestions'] =
          (_products[0]['productFocusNode'] as FocusNode).hasFocus);
    });
  }

  @override
  void dispose() {
    _dateController.dispose();
    _partyController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _partyFocusNode.dispose();
    
    for (var product in _products) {
      (product['productController'] as TextEditingController).dispose();
      (product['customProductController'] as TextEditingController).dispose();
      (product['quantityController'] as TextEditingController).dispose();
      (product['unitPriceController'] as TextEditingController).dispose();
      (product['productFocusNode'] as FocusNode).dispose();
    }
    super.dispose();
  }

  Future<void> _getAvailableStock(int productIndex, String productName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || productName.isEmpty || productIndex >= _products.length) {
      if (productIndex < _products.length) {
        setState(() => _products[productIndex]['availableStock'] = 0);
      }
      return;
    }

    try {
      final stockQuery = await FirebaseFirestore.instance
          .collection('stocks')
          .where('product', isEqualTo: productName.toLowerCase().trim())
          .where('user', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (stockQuery.docs.isNotEmpty) {
        setState(() => _products[productIndex]['availableStock'] = 
            stockQuery.docs.first['quantity'] ?? 0);
      } else {
        setState(() => _products[productIndex]['availableStock'] = 0);
      }
    } catch (e) {
      setState(() => _products[productIndex]['availableStock'] = 0);
    }
  }

  Future<void> _loadPartyDetails(String partyName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final partyQuery = await FirebaseFirestore.instance
          .collection(_partyCollection)
          .where('user', isEqualTo: user?.uid)
          .where('name', isEqualTo: partyName)
          .limit(1)
          .get();

      if (partyQuery.docs.isNotEmpty) {
        final partyData = partyQuery.docs.first.data();
        setState(() {
          _phoneController.text = partyData['phone'] ?? '';
          _cityController.text = partyData['city'] ?? '';
          _stateController.text = partyData['state'] ?? '';
        });
      }
    } catch (e) {
      AppUtils.showError('Error loading party details: $e');
    }
  }

  void _showAddPartyDialog() {
    showDialog(
      context: context,
      builder: (context) => PartyDialog(
        partyType: _selectedType == "Purchase" ? PartyType.supplier : PartyType.customer,
        initialName: _partyController.text,
        onPartyAdded: (partyData) {
          setState(() {
            _partyController.text = partyData['name'] ?? '';
            _phoneController.text = partyData['phone'] ?? '';
            _cityController.text = partyData['city'] ?? '';
            _stateController.text = partyData['state'] ?? '';
          });
        },
      ),
    );
  }

  void _addNewProduct() {
    setState(() {
      final newProduct = _createEmptyProduct();
      (newProduct['productFocusNode'] as FocusNode).addListener(() {
        setState(() => newProduct['showProductSuggestions'] =
            (newProduct['productFocusNode'] as FocusNode).hasFocus);
      });
      _products.add(newProduct);
    });
  }
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateController.text.isNotEmpty
          ? DateFormat('dd-MM-yyyy').parse(_dateController.text)
          : DateTime.now(),
      firstDate: DateTime(2000), // Adjust as needed
      lastDate: DateTime.now(), // Maximum date is today
      helpText: 'Select Transaction Date',
      cancelText: 'Cancel',
      confirmText: 'OK',
    );

    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('dd-MM-yyyy').format(picked);
      });
    }
  }


  void _removeProduct(int index) {
    if (_products.length > 1) {
      setState(() {
        ((_products[index]['productController']) as TextEditingController).dispose();
        ((_products[index]['customProductController']) as TextEditingController).dispose();
        ((_products[index]['quantityController']) as TextEditingController).dispose();
        ((_products[index]['unitPriceController']) as TextEditingController).dispose();
        ((_products[index]['productFocusNode']) as FocusNode).dispose();
        _products.removeAt(index);
      });
    }
  }

  void _onProductChanged(int index, String? value) async {
    setState(() {
      _products[index]['selectedProduct'] = value ?? '';
      _products[index]['showCustomProductField'] = value == 'Others';
      if (value != 'Others') {
        (_products[index]['productController'] as TextEditingController).text =
            value?.toLowerCase() ?? '';
        (_products[index]['customProductController'] as TextEditingController).clear();
      } else {
        (_products[index]['productController'] as TextEditingController).clear();
      }
      _products[index]['availableStock'] = 0;
    });

    if (_selectedType == 'Sale' && value != 'Others' && value != null) {
      await _getAvailableStock(index, value.toLowerCase());
    }
  }

  Future<void> _updateStock(String productName, int quantity, String type) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final stockQuery = await FirebaseFirestore.instance
        .collection('stocks')
        .where('product', isEqualTo: productName)
        .where('user', isEqualTo: user.uid)
        .limit(1)
        .get();

    final quantityChange = type == "Purchase" ? quantity : -quantity;

    if (stockQuery.docs.isNotEmpty) {
      final currentStock = stockQuery.docs.first.data();
      final currentQty = currentStock['quantity'] ?? 0;
      final newQuantity = currentQty + quantityChange;

      if (newQuantity < 0) {
        AppUtils.showError("Insufficient stock! Available: $currentQty");
        throw Exception("Stock cannot be negative");
      }

      await stockQuery.docs.first.reference.update({
        'quantity': newQuantity,
        'purchase': FieldValue.increment(type == "Purchase" ? quantity : 0),
        'sales': FieldValue.increment(type == "Sale" ? quantity : 0),
        'lastUpdated': DateTime.now(),
      });
    } else if (type == "Purchase") {
      await FirebaseFirestore.instance.collection('stocks').add({
        'product': productName,
        'quantity': quantity,
        'purchase': quantity,
        'sales': 0,
        'user': user.uid,
        'createdAt': DateTime.now(),
        'lastUpdated': DateTime.now(),
      });
    } else {
      AppUtils.showError("Cannot sell non-existent product!");
      throw Exception("Product not in stock");
    }
  }

  Future<void> _ensurePartyExists(String partyName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || partyName.trim().isEmpty) return;

    final exists = await FirestoreHelper.documentExists(
        _partyCollection, 'name', partyName.trim());

    if (!exists) {
      await FirestoreHelper.addDocument(_partyCollection, {
        'name': partyName.trim(),
        'phone': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
      });
    }
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final partyName = _partyController.text.trim();

      // Validate all products
      for (int i = 0; i < _products.length; i++) {
        final product = _products[i];
        String productName;
        if (product['selectedProduct'] == 'Others') {
          productName = (product['customProductController'] as TextEditingController)
              .text.toLowerCase().trim();
        } else {
          productName = (product['selectedProduct'] as String).toLowerCase().trim();
        }

        if (productName.isEmpty) {
          throw Exception("Product ${i + 1}: Please select or enter a product name");
        }

        final quantity = int.tryParse(
            (product['quantityController'] as TextEditingController).text) ?? 0;
        if (quantity <= 0) {
          throw Exception("Product ${i + 1}: Quantity must be greater than 0");
        }

        // Check stock for sales
        if (_selectedType == 'Sale') {
          final availableStock = product['availableStock'] as int;
          if (quantity > availableStock) {
            throw Exception(
                "Product ${i + 1}: Only $availableStock units available in stock");
          }
        }
      }

      await _ensurePartyExists(partyName);

      // Create product array and update stock
      List<Map<String, dynamic>> productArray = [];
      List<String> productNames = [];

      for (var product in _products) {
        String productName;
        if (product['selectedProduct'] == 'Others') {
          productName = (product['customProductController'] as TextEditingController)
              .text.toLowerCase().trim();
        } else {
          productName = (product['selectedProduct'] as String).toLowerCase().trim();
        }

        final quantity = int.parse(
            (product['quantityController'] as TextEditingController).text);
        final unitPrice = double.parse(
            (product['unitPriceController'] as TextEditingController).text);

        productArray.add({
          'product': productName,
          'quantity': quantity,
          'unitPrice': unitPrice,
        });

        productNames.add(productName);
        await _updateStock(productName, quantity, _selectedType);
      }

      // Add transaction first
      final transactionData = {
        'user': user.uid,
        'type': _selectedType,
        'party': partyName,
        'product': productArray,
        'product_names': productNames,
        'date': DateFormat('dd-MM-yyyy').parse(_dateController.text),
        'timestamp': DateTime.now(),
        'status': _selectedStatus,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final transactionDoc = await FirebaseFirestore.instance
          .collection('transactions')
          .add(transactionData);

      // Create bill if it's a Sale transaction
      String? billId;
      if (_selectedType == 'Sale') {
        billId = await _createBillFromTransaction(transactionDoc.id);

        // Update transaction with bill reference
        if (billId != null) {
          await transactionDoc.update({'billId': billId});
          AppUtils.showSuccess('Sale transaction and bill created successfully!');
        } else {
          AppUtils.showSuccess('Sale transaction added successfully!');
        }
      } else {
        AppUtils.showSuccess('Purchase transaction added successfully!');
      }

      Navigator.of(context).pop();

    } catch (e) {
      AppUtils.showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

// Method to generate bill number
  Future<String> _generateBillNumber() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final querySnapshot = await FirebaseFirestore.instance
          .collection('billcounter')
          .where('user', isEqualTo: user?.uid)
          .get();

      int newCounter;
      if (querySnapshot.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('billcounter').add({
          'user': user?.uid,
          'counter': 1,
        });
        newCounter = 1;
      } else {
        final doc = querySnapshot.docs.first;
        final currentCounter = doc.data()['counter'] ?? 0;
        newCounter = currentCounter + 1;
        await doc.reference.update({'counter': newCounter});
      }

      return "INV-$newCounter";
    } catch (e) {
      return "INV-${DateTime.now().millisecondsSinceEpoch}";
    }
  }

// Method to create bill from sale transaction
  Future<String?> _createBillFromTransaction(String transactionId) async {
    if (_selectedType != 'Sale') return null; // Only for Sale transactions

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // Convert transaction products to bill items format
      List<Map<String, dynamic>> billItems = [];
      double subtotal = 0.0;

      for (var product in _products) {
        String productName;
        if (product['selectedProduct'] == 'Others') {
          productName = (product['customProductController'] as TextEditingController)
              .text.trim();
        } else {
          productName = (product['selectedProduct'] as String);
        }

        final quantity = int.parse(
            (product['quantityController'] as TextEditingController).text);
        final unitPrice = double.parse(
            (product['unitPriceController'] as TextEditingController).text);

        billItems.add({
          'name': productName,
          'quantity': quantity.toString(),
          'price': unitPrice.toString(),
        });

        subtotal += quantity * unitPrice;
      }

      final tax = subtotal * 0.05; // 5% tax
      final total = subtotal + tax;
      final billNumber = await _generateBillNumber();

      final billData = {
        'user': user.uid,
        'transactionId': transactionId, // Link to transaction
        'billNumber': billNumber,
        'customerName': _partyController.text.trim(),
        'customerPhone': _phoneController.text.trim(),
        'customerCity': _cityController.text.trim(),
        'customerState': _stateController.text.trim(),
        'date': DateFormat('dd-MM-yyyy').parse(_dateController.text),
        'items': billItems,
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'billType': 'auto', // Mark as auto-generated
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final billDoc = await FirebaseFirestore.instance.collection('bills').add(billData);
      return billDoc.id;

    } catch (e) {
      print('Error creating bill from transaction: $e');
      return null;
    }
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Add Transaction"),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Transaction Type
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  items: ['Purchase', 'Sale']
                      .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: _isLoading ? null : (value) => setState(() => _selectedType = value!),
                  decoration: const InputDecoration(
                    labelText: "Transaction Type",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Date Field
                GestureDetector(
                  onTap: _isLoading ? null : () => _selectDate(context),
                  child: AbsorbPointer(
                    child: AppTextField(
                      controller: _dateController,
                      labelText: "Date",
                      prefixIcon: Icons.calendar_today,
                      validator: (value) => value?.isEmpty ?? true ? "Please select date" : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Party Field with suggestions
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _partyController,
                        focusNode: _partyFocusNode,
                        labelText: _partyLabel,
                        prefixIcon: _selectedType == 'Purchase' ? Icons.business : Icons.person,
                        validator: (value) => AppUtils.validateRequired(value, _partyLabel.toLowerCase()),
                        onChanged: (value) => setState(() {}),
                      ),
                    ),
                    IconButton(
                      onPressed: _showAddPartyDialog,
                      icon: const Icon(Icons.add_circle_outline, color: Colors.indigo),
                      tooltip: "Add $_partyLabel",
                    ),
                  ],
                ),
                if (_showPartySuggestions && _partyController.text.isNotEmpty)
                  SuggestionsList(
                    stream: FirestoreHelper.getSuggestions(_partyCollection, 'name', _partyController.text),
                    controller: _partyController,
                    focusNode: _partyFocusNode,
                    onSelected: _loadPartyDetails,
                  ),
                const SizedBox(height: 16),

                // Phone, City, State
                AppTextField(
                  controller: _phoneController,
                  labelText: "Phone",
                  prefixIcon: Icons.phone,
                  prefixText: '+91 ',
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: AppUtils.validatePhone,
                ),
                const SizedBox(height: 16),
                
                AppTextField(
                  controller: _cityController,
                  labelText: "City",
                  prefixIcon: Icons.location_city,
                ),
                const SizedBox(height: 16),
                
                AppTextField(
                  controller: _stateController,
                  labelText: "State",
                  prefixIcon: Icons.map,
                ),
                const SizedBox(height: 20),

                // Products section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Products",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    IconButton(
                      onPressed: _addNewProduct,
                      icon: const Icon(Icons.add_circle_outline, color: Colors.indigo),
                      tooltip: "Add Product",
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Products list
                ...List.generate(_products.length, (index) => _buildProductCard(index)),
                const SizedBox(height: 16),

                // Status dropdown
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  items: ['Paid', 'Unpaid']
                      .map((status) => DropdownMenuItem(value: status, child: Text(status)))
                      .toList(),
                  onChanged: _isLoading ? null : (value) => setState(() => _selectedStatus = value!),
                  decoration: const InputDecoration(
                    labelText: "Status",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitTransaction,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text("Submit"),
        ),
      ],
    );
  }

  Widget _buildProductCard(int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Product ${index + 1}",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (_products.length > 1)
                  IconButton(
                    onPressed: () => _removeProduct(index),
                    icon: const Icon(Icons.remove_circle_outline),
                    color: Colors.red,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Product dropdown
            DropdownButtonFormField<String>(
              value: (_products[index]['selectedProduct'] as String).isEmpty
                  ? null
                  : _products[index]['selectedProduct'] as String,
              items: _predefinedProducts.map((product) {
                return DropdownMenuItem(value: product, child: Text(product));
              }).toList(),
              onChanged: _isLoading ? null : (value) => _onProductChanged(index, value),
              decoration: const InputDecoration(
                labelText: "Product",
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null ? "Please select a product" : null,
            ),

            // Custom product field
            if (_products[index]['showCustomProductField'] as bool) ...[
              const SizedBox(height: 12),
              AppTextField(
                controller: _products[index]['customProductController'] as TextEditingController,
                labelText: "Product Name",
                validator: (value) {
                  if (_products[index]['selectedProduct'] == 'Others' && 
                      (value?.trim().isEmpty ?? true)) {
                    return "Please enter product name";
                  }
                  return null;
                },
              ),
            ],

            const SizedBox(height: 12),

            // Quantity field
            AppTextField(
              controller: _products[index]['quantityController'] as TextEditingController,
              labelText: "Quantity",
              suffixText: "kg",
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.isEmpty ?? true) return "Enter quantity";
                final qty = int.tryParse(value!) ?? 0;
                if (qty <= 0) return "Quantity must be > 0";
                
                if (_selectedType == 'Sale') {
                  final availableStock = _products[index]['availableStock'] as int;
                  if (qty > availableStock) {
                    return "Max: $availableStock";
                  }
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            // Unit price field
            AppTextField(
              controller: _products[index]['unitPriceController'] as TextEditingController,
              labelText: "Unit Price",
              prefixText: "₹ ",
              suffixText: "per kg",
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) => AppUtils.validatePositiveNumber(value, 'Unit Price'),
            ),

            // Available stock indicator
            if (_selectedType == 'Sale' && _products[index]['selectedProduct'] != 'Others') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  "Available Stock: ${_products[index]['availableStock']}",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}