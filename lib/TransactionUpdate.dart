import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'utils.dart';
import 'party_management.dart';

class TransactionUpdate extends StatefulWidget {
  final String docRef;
  const TransactionUpdate({super.key, required this.docRef});

  @override
  State<TransactionUpdate> createState() => _TransactionUpdateState();
}

class _TransactionUpdateState extends State<TransactionUpdate> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _partyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _partyFocusNode = FocusNode();

  String _selectedType = 'Purchase';
  String _selectedStatus = 'Paid';
  bool _showPartySuggestions = false;
  bool _isLoading = true;
  bool _isSaving = false;
  
  List<Map<String, dynamic>> _products = [];
  Map<String, dynamic>? _originalData;

  final List<String> _predefinedProducts = [
    'Onion',
    'Garlic',
    'Chili',
    'Wheat grains',
    'Others'
  ];

  String get _partyLabel => _selectedType == "Purchase" ? "Supplier" : "Customer";
  String get _partyCollection => _selectedType == "Purchase" ? "suppliers" : "customers";

  @override
  void initState() {
    super.initState();
    _loadTransactionData();
    _partyFocusNode.addListener(() {
      setState(() => _showPartySuggestions = _partyFocusNode.hasFocus);
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
    _disposeProducts();
    super.dispose();
  }

  void _disposeProducts() {
    for (var product in _products) {
      (product['productController'] as TextEditingController?)?.dispose();
      (product['customProductController'] as TextEditingController?)?.dispose();
      (product['quantityController'] as TextEditingController?)?.dispose();
      (product['unitPriceController'] as TextEditingController?)?.dispose();
      (product['productFocusNode'] as FocusNode?)?.dispose();
    }
  }

  Future<void> _loadTransactionData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('transactions')
          .doc(widget.docRef)
          .get();

      if (!doc.exists) {
        AppUtils.showError("Transaction not found");
        Navigator.pop(context);
        return;
      }

      _originalData = doc.data()!;
      final data = _originalData!;

      setState(() {
        _selectedType = data['type'] ?? 'Purchase';
        _selectedStatus = data['status'] ?? 'Paid';
        _partyController.text = data['party'] ?? '';
        
        final date = data['date'];
        if (date is Timestamp) {
          _dateController.text = DateFormat('dd-MM-yyyy').format(date.toDate());
        } else if (date is DateTime) {
          _dateController.text = DateFormat('dd-MM-yyyy').format(date);
        } else {
          _dateController.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
        }

        // Load products
        final products = data['product'] as List? ?? [];
        _products.clear();
        
        for (var productData in products) {
          if (productData != null) {
            final productMap = productData as Map<String, dynamic>;
            final productName = productMap['product']?.toString() ?? '';
            final quantity = productMap['quantity']?.toString() ?? '0';
            final unitPrice = productMap['unitPrice']?.toString() ?? '0';

            final product = _createProductFromData(productName, quantity, unitPrice);
            _products.add(product);
          }
        }

        if (_products.isEmpty) {
          _products.add(_createEmptyProduct());
        }
      });

      // Try to load party details
      await _loadPartyDetails(_partyController.text);

    } catch (e) {
      AppUtils.showError("Error loading transaction: $e");
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _createProductFromData(String productName, String quantity, String unitPrice) {
    final productController = TextEditingController();
    final customProductController = TextEditingController();
    final quantityController = TextEditingController(text: quantity);
    final unitPriceController = TextEditingController(text: unitPrice);
    final productFocusNode = FocusNode();
    
    String selectedProduct = '';
    bool showCustomProductField = false;
    
    if (_predefinedProducts.contains(AppUtils.capitalize(productName))) {
      selectedProduct = AppUtils.capitalize(productName);
      productController.text = productName;
    } else {
      selectedProduct = 'Others';
      showCustomProductField = true;
      customProductController.text = productName;
    }

    productFocusNode.addListener(() {
      setState(() {});
    });

    return {
      'productController': productController,
      'customProductController': customProductController,
      'quantityController': quantityController,
      'unitPriceController': unitPriceController,
      'productFocusNode': productFocusNode,
      'selectedProduct': selectedProduct,
      'showCustomProductField': showCustomProductField,
      'showProductSuggestions': false,
      'availableStock': 0,
    };
  }

  Map<String, dynamic> _createEmptyProduct() {
    final productFocusNode = FocusNode();
    productFocusNode.addListener(() {
      setState(() {});
    });

    return {
      'productController': TextEditingController(),
      'customProductController': TextEditingController(),
      'quantityController': TextEditingController(),
      'unitPriceController': TextEditingController(),
      'productFocusNode': productFocusNode,
      'selectedProduct': '',
      'showCustomProductField': false,
      'showProductSuggestions': false,
      'availableStock': 0,
    };
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

      if (partyQuery.docs.isNotEmpty && mounted) {
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
      _products.add(_createEmptyProduct());
    });
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

  void _onProductChanged(int index, String? value) {
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
    });
  }

  Future<void> _revertStockChanges() async {
    if (_originalData == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final originalProducts = _originalData!['product'] as List? ?? [];
      final originalType = _originalData!['type']?.toString() ?? '';

      for (var product in originalProducts) {
        if (product == null) continue;
        
        final productMap = product as Map<String, dynamic>;
        final productName = productMap['product']?.toString() ?? '';
        final quantity = (productMap['quantity'] as num?)?.toInt() ?? 0;

        if (productName.isEmpty || quantity <= 0) continue;

        final stockQuery = await FirebaseFirestore.instance
            .collection('stocks')
            .where('user', isEqualTo: user.uid)
            .where('product', isEqualTo: productName)
            .limit(1)
            .get();

        if (stockQuery.docs.isNotEmpty) {
          final stockRef = stockQuery.docs.first.reference;
          final quantityChange = originalType == 'Purchase' ? -quantity : quantity;
          
          await stockRef.update({
            'quantity': FieldValue.increment(quantityChange),
            if (originalType == 'Purchase') 'purchase': FieldValue.increment(-quantity),
            if (originalType == 'Sale') 'sales': FieldValue.increment(-quantity),
          });
        }
      }
    } catch (e) {
      throw Exception('Failed to revert stock changes: $e');
    }
  }

  Future<void> _applyNewStockChanges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    for (var product in _products) {
      String productName;
      if (product['selectedProduct'] == 'Others') {
        productName = (product['customProductController'] as TextEditingController)
            .text.toLowerCase().trim();
      } else {
        productName = (product['selectedProduct'] as String).toLowerCase().trim();
      }

      if (productName.isEmpty) continue;

      final quantity = int.tryParse(
          (product['quantityController'] as TextEditingController).text) ?? 0;

      if (quantity <= 0) continue;

      await _updateStock(productName, quantity, _selectedType);
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

      if (newQuantity < 0 && type == "Sale") {
        throw Exception("Insufficient stock for $productName! Available: $currentQty");
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
      throw Exception("Cannot sell non-existent product: $productName");
    }
  }

  Future<void> _updateTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
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
      }

      // Revert original stock changes
      await _revertStockChanges();
      
      // Apply new stock changes
      await _applyNewStockChanges();

      // Create product array
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
      }

      // Update transaction
      final transactionData = {
        'type': _selectedType,
        'party': _partyController.text.trim(),
        'product': productArray,
        'product_names': productNames,
        'date': DateFormat('dd-MM-yyyy').parse(_dateController.text),
        'status': _selectedStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(widget.docRef)
          .update(transactionData);

      AppUtils.showSuccess('Transaction updated successfully!');
      Navigator.of(context).pop();

    } catch (e) {
      AppUtils.showError('Error updating transaction: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AlertDialog(
      title: const Text("Update Transaction"),
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
                  onChanged: _isSaving ? null : (value) => setState(() => _selectedType = value!),
                  decoration: const InputDecoration(
                    labelText: "Transaction Type",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Date Field
                AppTextField(
                  controller: _dateController,
                  labelText: "Date",
                  prefixIcon: Icons.calendar_today,
                  enabled: false,
                  validator: (value) => value?.isEmpty ?? true ? "Please select date" : null,
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
                  onChanged: _isSaving ? null : (value) => setState(() => _selectedStatus = value!),
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
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _updateTransaction,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text("Update"),
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
              onChanged: _isSaving ? null : (value) => _onProductChanged(index, value),
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
              validator: (value) => AppUtils.validatePositiveInteger(value, 'Quantity'),
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
          ],
        ),
      ),
    );
  }
}