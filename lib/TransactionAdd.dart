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
  final User? user = FirebaseAuth.instance.currentUser;

  // Multiple products list
  List<Map<String, dynamic>> _products = [
    {
      'productController': TextEditingController(),
      'customProductController': TextEditingController(),
      'quantityController': TextEditingController(),
      'unitPriceController': TextEditingController(),
      'productFocusNode': FocusNode(),
      'selectedProduct': '',
      'showCustomProductField': false,
      'showProductSuggestions': false,
      'availableStock': 0,
    }
  ];

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

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
    _partyFocusNode.addListener(() {
      setState(() => _showPartySuggestions = _partyFocusNode.hasFocus);
    });

    // Initialize focus listeners for first product
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
    // Dispose all product controllers
    for (var product in _products) {
      (product['productController'] as TextEditingController).dispose();
      (product['customProductController'] as TextEditingController).dispose();
      (product['quantityController'] as TextEditingController).dispose();
      (product['unitPriceController'] as TextEditingController).dispose();
      (product['productFocusNode'] as FocusNode).dispose();
    }
    super.dispose();
  }

  // Get available stock for specific product
  Future<void> _getAvailableStock(int productIndex, String productName) async {
    if (user == null || productName.isEmpty) {
      setState(() => _products[productIndex]['availableStock'] = 0);
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
        setState(() => _products[productIndex]['availableStock'] =
            stockQuery.docs.first['quantity'] ?? 0);
      } else {
        setState(() => _products[productIndex]['availableStock'] = 0);
      }
    } catch (e) {
      setState(() => _products[productIndex]['availableStock'] = 0);
    }
  }

  // Load party details when selected
  Future<void> _loadPartyDetails(String partyName) async {
    try {
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
      print('Error loading party details: e');
    }
  }

  // Show add party dialog
  void _showAddPartyDialog() {
    final newNameController = TextEditingController(text: _partyController.text);
    final newPhoneController = TextEditingController();
    final newCityController = TextEditingController();
    final newStateController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New $_partyLabel'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: newNameController,
                  decoration: InputDecoration(
                    labelText: '$_partyLabel Name*',
                    prefixIcon: Icon(_selectedType == 'Purchase' ?
                    Icons.business : Icons.person),
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
                    if (value?.trim().isNotEmpty == true &&
                        value!.trim().length != 10) {
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
            onPressed: () => _addNewParty(
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

  // Add new party
  Future<void> _addNewParty(String name, String phone, String city, String state,
      GlobalKey<FormState> formKey) async {
    if (!formKey.currentState!.validate()) return;

    try {
      await FirebaseFirestore.instance.collection(_partyCollection).add({
        'name': name.trim(),
        'phone': phone.trim(),
        'city': city.trim(),
        'state': state.trim(),
        'user': user?.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context);
      // Auto-fill the form with new party data
      setState(() {
        _partyController.text = name.trim();
        _phoneController.text = phone.trim();
        _cityController.text = city.trim();
        _stateController.text = state.trim();
      });

      Fluttertoast.showToast(
        msg: '$_partyLabel added successfully!',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error adding $_partyLabel: e',
        backgroundColor: Colors.red,
      );
    }
  }

  // Get available stock products for sales
  Stream<List<Map<String, dynamic>>> _getAvailableStockProducts() {
    if (user == null || _selectedType != 'Sale') return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('stocks')
        .where('user', isEqualTo: user!.uid)
        .where('quantity', isGreaterThan: 0)
        .snapshots()
        .map((snapshot) {
      final products = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'product': data['product'] as String,
          'quantity': data['quantity'] as int,
        };
      }).where((product) => (product['quantity'] as int) > 0).toList();
      return products;
    });
  }

  Stream<List<String>> _getProductSuggestions(String query) {
    if (query.trim().isEmpty) return Stream.value([]);
    final lowercaseQuery = query.trim().toLowerCase();

    if (_selectedType == 'Sale') {
      // For sales, only show products with available stock
      return FirebaseFirestore.instance
          .collection('stocks')
          .where('user', isEqualTo: user?.uid)
          .where('quantity', isGreaterThan: 0)
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
    } else {
      // For purchases, show all products
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

  Future<void> _updateStock(String productName, int quantity, String type) async {
    if (user == null) return;

    final stockQuery = await FirebaseFirestore.instance
        .collection('stocks')
        .where('product', isEqualTo: productName)
        .where('user', isEqualTo: user!.uid)
        .limit(1)
        .get();

    int quantityChange = type == "Purchase" ? quantity : -quantity;

    if (stockQuery.docs.isNotEmpty) {
      final currentStock = stockQuery.docs.first.data();
      final currentQty = currentStock['quantity'] ?? 0;
      int newQuantity = currentQty + quantityChange;

      // PREVENT NEGATIVE STOCK
      if (newQuantity < 0) {
        Fluttertoast.showToast(
            msg: "Insufficient stock! Available: currentQty",
            backgroundColor: Colors.red);
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
        'product': productName,
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
          backgroundColor: Colors.red);
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
        'phone': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'user': user!.uid,
        'createdAt': DateTime.now(),
        'lastUpdated': DateTime.now(),
      });
    } else {
      // Update existing party with new details
      await partyQuery.docs.first.reference.update({
        'phone': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'lastUpdated': DateTime.now(),
      });
    }
  }

  // Generate bill number
  // Generate bill number with atomic counter increment
  Future<String> _generateBillNumber() async {
    try {
      // Use a fixed document ID for the counter to avoid multiple counter documents
      final counterRef = FirebaseFirestore.instance
          .collection('billcounter')
          .doc(user!.uid); // Use user ID as document ID

      // Use Firestore transaction for atomic counter increment
      final newCounter = await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(counterRef);

        int currentCounter;
        if (snapshot.exists) {
          currentCounter = snapshot.data()?['counter'] ?? 0;
        } else {
          currentCounter = 0;
        }

        final newCounter = currentCounter + 1;

        // Update or create the counter document atomically
        transaction.set(counterRef, {
          'counter': newCounter,
          'user': user!.uid,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return newCounter;
      });

      return "INV-$newCounter";
    } catch (e) {
      print('Error generating bill number: $e');
      // Fallback to timestamp-based bill number
      return "INV-${DateTime.now().millisecondsSinceEpoch}";
    }
  }


  // Auto-generate bill for Sale transactions with proper linking
  // Auto-generate bill for Sale transactions with proper linking
  Future<String?> _generateLinkedBill(String customerName, String transactionId) async {
    if (_selectedType != 'Sale') return null;

    try {
      final billNumber = await _generateBillNumber(); // This will now work correctly
      double subtotal = 0.0;
      List<Map<String, dynamic>> billItems = [];

      // Process all products
      for (var product in _products) {
        String productName;
        if (product['selectedProduct'] == 'Others') {
          productName = (product['customProductController'] as TextEditingController)
              .text.toLowerCase().trim();
        } else {
          productName = (product['selectedProduct'] as String).toLowerCase().trim();
        }

        final quantity = int.parse((product['quantityController'] as TextEditingController).text);
        final unitPrice = double.parse((product['unitPriceController'] as TextEditingController).text);

        billItems.add({
          'name': productName,
          'quantity': quantity.toString(),
          'price': unitPrice.toString(),
        });
        subtotal += quantity * unitPrice;
      }

      final tax = subtotal * 0.05; // 5% GST
      final total = subtotal + tax;

      // Create linked bill
      await FirebaseFirestore.instance.collection('bills').add({
        'user': user!.uid,
        'billNumber': billNumber,
        'customerName': customerName,
        'customerPhone': _phoneController.text,
        'customerCity': _cityController.text,
        'customerState': _stateController.text,
        'date': DateFormat('dd-MM-yyyy').parse(_dateController.text),
        'items': billItems,
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'linkedTransactionId': transactionId, // Link to transaction
        'billType': 'auto-generated', // Mark as auto-generated
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Bill $billNumber auto-generated and linked to transaction $transactionId');
      return billNumber;
    } catch (e) {
      print('Error auto-generating bill: $e');
      return null;
    }
  }


  // Add new product to the list
  void _addNewProduct() {
    setState(() {
      final newProduct = {
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

      // Add focus listener for new product
      (newProduct['productFocusNode'] as FocusNode).addListener(() {
        setState(() => newProduct['showProductSuggestions'] =
            (newProduct['productFocusNode'] as FocusNode).hasFocus);
      });

      _products.add(newProduct);
    });
  }

  // Remove product from the list
  void _removeProduct(int index) {
    if (_products.length > 1) {
      setState(() {
        // Dispose controllers before removing
        (_products[index]['productController'] as TextEditingController).dispose();
        (_products[index]['customProductController'] as TextEditingController).dispose();
        (_products[index]['quantityController'] as TextEditingController).dispose();
        (_products[index]['unitPriceController'] as TextEditingController).dispose();
        (_products[index]['productFocusNode'] as FocusNode).dispose();

        _products.removeAt(index);
      });
    }
  }

  // Handle product selection change
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

      // Reset available stock when changing products
      _products[index]['availableStock'] = 0;
    });

    // Get stock for selected product if it's a sale
    if (_selectedType == 'Sale' && value != 'Others' && value != null) {
      await _getAvailableStock(index, value.toLowerCase());
    }
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate() || user == null) return;

    setState(() => _isLoading = true);

    try {
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

        if ((product['quantityController'] as TextEditingController).text.trim().isEmpty) {
          throw Exception("Product ${i + 1}: Please enter quantity");
        }

        if ((product['unitPriceController'] as TextEditingController).text.trim().isEmpty) {
          throw Exception("Product ${i + 1}: Please enter unit price");
        }

        final quantity = int.tryParse((product['quantityController'] as TextEditingController).text) ?? 0;
        if (quantity <= 0) {
          throw Exception("Product ${i + 1}: Quantity must be greater than 0");
        }

        // Check stock availability for sales
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
            throw Exception("Product ${i + 1}: Insufficient stock. Available: $availableStock");
          }
        }
      }

      // Ensure party exists
      await _ensurePartyExists(partyName);

      // Prepare products array for single transaction document
      List<Map<String, dynamic>> productsArray = [];
      List<String> productNames = []; // NEW: Build product names array
      double totalAmount = 0.0;

      for (var product in _products) {
        String productName;
        if (product['selectedProduct'] == 'Others') {
          productName = (product['customProductController'] as TextEditingController)
              .text.toLowerCase().trim();
        } else {
          productName = (product['selectedProduct'] as String).toLowerCase().trim();
        }

        final quantity = int.parse((product['quantityController'] as TextEditingController).text);
        final unitPrice = double.parse((product['unitPriceController'] as TextEditingController).text);

        productsArray.add({
          'product': productName,
          'quantity': quantity,
          'unitPrice': unitPrice,
        });

        // NEW: Add to product names array
        productNames.add(productName);

        totalAmount += quantity * unitPrice;

        // Update stock for each product
        await _updateStock(productName, quantity, _selectedType);
      }

      // Create transaction with proper bill linking
      final transactionRef = await FirebaseFirestore.instance.collection('transactions').add({
        'product': productsArray,
        'product_names': productNames, // NEW: Add product names array
        'party': partyName,
        'date': DateFormat('dd-MM-yyyy').parse(_dateController.text),
        'type': _selectedType,
        'status': _selectedStatus,
        'totalAmount': totalAmount,
        'user': user!.uid,
        'linkedBillNumber': null, // Will be updated after bill creation
        'timestamp': DateTime.now(),
        'lastUpdated': DateTime.now(),
      });

      // Auto-generate bill for Sale transactions with proper linking
      String? linkedBillNumber;
      if (_selectedType == 'Sale') {
        linkedBillNumber = await _generateLinkedBill(partyName, transactionRef.id);

        // Update transaction with linked bill number
        if (linkedBillNumber != null) {
          await transactionRef.update({
            'linkedBillNumber': linkedBillNumber,
          });
        }
      }

      String successMessage = _selectedType == 'Sale'
          ? "Sale with ${_products.length} products added successfully${linkedBillNumber != null ? ' and bill $linkedBillNumber created' : ''}!"
          : "Purchase with ${_products.length} products added successfully!";

      Fluttertoast.showToast(
        msg: successMessage,
        backgroundColor: Colors.green,
      );

      Navigator.pop(context);
    } catch (error) {
      Fluttertoast.showToast(
        msg: "Failed to add transaction: $error",
        backgroundColor: Colors.red,
      );
    } finally {
      setState(() => _isLoading = false);
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
                  _loadPartyDetails(suggestions[index]); // Auto-load details
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Add Transaction"),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SizedBox(
          width: double.maxFinite,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Type dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    items: ['Purchase', 'Sale']
                        .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: _isLoading ? null : (value) {
                      setState(() {
                        _selectedType = value!;
                        _partyController.clear();
                        _phoneController.clear();
                        _cityController.clear();
                        _stateController.clear();
                        _partyFocusNode.unfocus();
                        // Reset all products' available stock when type changes
                        for (var product in _products) {
                          product['availableStock'] = 0;
                        }
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: "Transaction Type",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Party name field with suggestions
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _partyController,
                              focusNode: _partyFocusNode,
                              decoration: InputDecoration(
                                labelText: _partyLabel,
                                border: OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.add, color: Colors.indigo),
                                  onPressed: _showAddPartyDialog,
                                  tooltip: 'Add New _partyLabel',
                                ),
                              ),
                              validator: (value) =>
                              value?.isEmpty ?? true ? "Please enter _partyLabel name" : null,
                              onChanged: (value) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      if (_showPartySuggestions && _partyController.text.isNotEmpty)
                        _buildSuggestionsList(
                          stream: _getPartySuggestions(_partyController.text),
                          controller: _partyController,
                          focusNode: _partyFocusNode,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Phone field
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: "Phone Number",
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
                  const SizedBox(height: 16),
                  // City field
                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: "City",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // State field
                  TextFormField(
                    controller: _stateController,
                    decoration: const InputDecoration(
                      labelText: "State",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Date field
                  TextFormField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      labelText: "Date",
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        _dateController.text = DateFormat('dd-MM-yyyy').format(picked);
                      }
                    },
                    validator: (value) => value?.isEmpty ?? true ? "Please select date" : null,
                  ),
                  const SizedBox(height: 20),
                  // Products section header
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
                        icon: Icon(Icons.add_circle_outline, color: Colors.indigo),
                        tooltip: "Add Product",
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Products list
                  ...List.generate(_products.length, (index) =>
                      _buildProductCard(index)),
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
            // Product header with remove button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Product ${index + 1}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
                return DropdownMenuItem(
                  value: product,
                  child: Text(product),
                );
              }).toList(),
              onChanged: _isLoading ? null : (value) => _onProductChanged(index, value),
              decoration: const InputDecoration(
                labelText: "Product",
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null ? "Please select a product" : null,
            ),

            // Custom product field (shown only when "Others" is selected)
            if (_products[index]['showCustomProductField'] as bool) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _products[index]['customProductController'] as TextEditingController,
                decoration: const InputDecoration(
                  labelText: "Product Name",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (_products[index]['selectedProduct'] == 'Others' && (value?.trim().isEmpty ?? true)) {
                    return "Please enter product name";
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 12),

            // Quantity field (full width)
            TextFormField(
              controller: _products[index]['quantityController'] as TextEditingController,
              decoration: const InputDecoration(
                labelText: "Quantity",
                border: OutlineInputBorder(),
                suffixText: "kg",
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.isEmpty ?? true) return "Enter quantity";
                final qty = int.tryParse(value!) ?? 0;
                if (qty <= 0) return "Quantity must be > 0";
                // Check stock for sales
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

            // Unit price field (full width)
            TextFormField(
              controller: _products[index]['unitPriceController'] as TextEditingController,
              decoration: const InputDecoration(
                labelText: "Unit Price",
                border: OutlineInputBorder(),
                prefixText: "₹ ",
                suffixText: "per kg",
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value?.isEmpty ?? true) return "Enter price";
                final price = double.tryParse(value!) ?? 0;
                if (price <= 0) return "Price must be > 0";
                return null;
              },
            ),

            // Available stock indicator for sales
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