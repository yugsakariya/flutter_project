import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

class TransactionUpdate extends StatefulWidget {
  final String docRef;
  const TransactionUpdate({super.key, required this.docRef});

  @override
  State<TransactionUpdate> createState() => _TransactionUpdateState();
}

class _TransactionUpdateState extends State<TransactionUpdate> {
  final _dateController = TextEditingController();
  final _partyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _partyFocusNode = FocusNode();

  String _type = '';
  String _status = '';
  bool _isLoading = false;
  bool _showPartySuggestions = false;

  // Multiple products list - will be populated from existing transaction
  List<Map<String, dynamic>> _products = [];

  // Original values to track changes
  String _originalParty = '';
  String _originalType = '';
  List<Map<String, dynamic>> _originalProducts = [];
  String? _linkedBillNumber; // Track linked bill

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
    // Dispose all product controllers
    for (var product in _products) {
      (product['productController'] as TextEditingController?)?.dispose();
      (product['customProductController'] as TextEditingController?)?.dispose();
      (product['quantityController'] as TextEditingController?)?.dispose();
      (product['unitPriceController'] as TextEditingController?)?.dispose();
      (product['productFocusNode'] as FocusNode?)?.dispose();
    }
    super.dispose();
  }

  // Check if party exists in the database
  Future<bool> _checkPartyExists(String partyName) async {
    if (user == null || partyName.trim().isEmpty) return false;

    try {
      final partyQuery = await FirebaseFirestore.instance
          .collection(_partyCollection)
          .where('name', isEqualTo: partyName.trim())
          .where('user', isEqualTo: user!.uid)
          .limit(1)
          .get();

      return partyQuery.docs.isNotEmpty;
    } catch (e) {
      print('Error checking party existence: $e');
      return false;
    }
  }

  // Get available stock for specific product
  Future _getAvailableStock(int productIndex, String productName) async {
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
          .where('user', isEqualTo: user!.uid)
          .limit(1)
          .get();
      if (stockQuery.docs.isNotEmpty) {
        int currentStock = stockQuery.docs.first['quantity'] ?? 0;
        // Add back original quantity if it was a sale of the same product
        final originalProduct = _originalProducts.firstWhere(
              (original) => original['product'] == productName.toLowerCase().trim(),
          orElse: () => {},
        );
        if (_originalType == 'Sale' && originalProduct.isNotEmpty) {
          currentStock += (originalProduct['quantity'] as num? ?? 0).toInt();
        }

        setState(() => _products[productIndex]['availableStock'] = currentStock);
      } else {
        setState(() => _products[productIndex]['availableStock'] = 0);
      }
    } catch (e) {
      setState(() => _products[productIndex]['availableStock'] = 0);
    }
  }

  Future _loadTransactionData() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('transactions')
          .doc(widget.docRef)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        final party = data["party"] ?? '';
        final type = data['type'] ?? '';
        final date = data['date'];

        // Set basic transaction info
        _partyController.text = party;
        _dateController.text = DateFormat('dd-MM-yyyy').format(date.toDate());
        _type = type;
        _status = data['status'] ?? '';
        _originalParty = party;
        _originalType = type;
        _linkedBillNumber = data['linkedBillNumber']; // Load linked bill

        // Load party details
        await _loadPartyDetails(party);

        // Load products from the product array in the transaction document
        _products.clear();
        _originalProducts.clear();
        final productsArray = data['product'] as List? ?? [];

        for (var productData in productsArray) {
          final originalProductName = productData["product"] ?? '';

          // Store original product data
          _originalProducts.add({
            'product': originalProductName,
            'quantity': productData['quantity'] ?? 0,
            'unitPrice': productData['unitPrice'] ?? 0.0,
          });

          // Create product map
          final product = {
            'productController': TextEditingController(text: originalProductName),
            'customProductController': TextEditingController(),
            'quantityController': TextEditingController(text: productData["quantity"]?.toString() ?? ''),
            'unitPriceController': TextEditingController(text: productData["unitPrice"]?.toString() ?? ''),
            'productFocusNode': FocusNode(),
            'selectedProduct': '',
            'showCustomProductField': false,
            'showProductSuggestions': false,
            'availableStock': 0,
          };

          // Set dropdown selection based on original product
          if (_predefinedProducts.contains(_capitalizeFirstLetter(originalProductName))) {
            product['selectedProduct'] = _capitalizeFirstLetter(originalProductName);
            product['showCustomProductField'] = false;
          } else {
            product['selectedProduct'] = 'Others';
            product['showCustomProductField'] = true;
            (product['customProductController'] as TextEditingController).text = originalProductName;
          }

          // Add focus listener
          (product['productFocusNode'] as FocusNode).addListener(() {
            setState(() => product['showProductSuggestions'] = (product['productFocusNode'] as FocusNode).hasFocus);
          });

          _products.add(product);

          // Get available stock if it's a sale transaction
          if (_type == 'Sale') {
            await _getAvailableStock(_products.length - 1, originalProductName);
          }
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

  // Load party details when selected
  Future _loadPartyDetails(String partyName) async {
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
      print('Error loading party details: $e');
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
                    prefixIcon: Icon(_type == 'Purchase' ? Icons.business : Icons.person),
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
  Future _addNewParty(String name, String phone, String city, String state,
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
        msg: 'Error adding $_partyLabel: $e',
        backgroundColor: Colors.red,
      );
    }
  }

  // Get available stock products for sales
  Stream<List<Map<String, dynamic>>> _getAvailableStockProducts() {
    if (user == null || _type != 'Sale') return Stream.value([]);
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
    final lowerQuery = query.trim().toLowerCase();
    if (_type == 'Sale') {
      return FirebaseFirestore.instance
          .collection('stocks')
          .where('user', isEqualTo: user?.uid)
          .where('quantity', isGreaterThan: 0)
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
        return products.take(10).toList();
      });
    } else {
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
        return products.take(10).toList();
      });
    }
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
      return parties.take(10).toList();
    });
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
        setState(() => newProduct['showProductSuggestions'] = (newProduct['productFocusNode'] as FocusNode).hasFocus);
      });

      _products.add(newProduct);
    });
  }

  // Remove product from the list
  void _removeProduct(int index) {
    if (_products.length > 1) {
      setState(() {
        // Dispose controllers before removing
        (_products[index]['productController'] as TextEditingController?)?.dispose();
        (_products[index]['customProductController'] as TextEditingController?)?.dispose();
        (_products[index]['quantityController'] as TextEditingController?)?.dispose();
        (_products[index]['unitPriceController'] as TextEditingController?)?.dispose();
        (_products[index]['productFocusNode'] as FocusNode?)?.dispose();
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
        (_products[index]['productController'] as TextEditingController).text = value?.toLowerCase() ?? '';
        (_products[index]['customProductController'] as TextEditingController).clear();
      } else {
        (_products[index]['productController'] as TextEditingController).clear();
      }

      // Reset available stock when changing products
      _products[index]['availableStock'] = 0;
    });

    // Get stock for selected product if it's a sale
    if (_type == 'Sale' && value != 'Others' && value != null) {
      await _getAvailableStock(index, value.toLowerCase());
    }
  }

  Future _revertStockChange(String productName, int quantity, String type) async {
    final stockQuery = await FirebaseFirestore.instance
        .collection('stocks')
        .where('user', isEqualTo: user!.uid)
        .where('product', isEqualTo: productName)
        .limit(1)
        .get();
    if (stockQuery.docs.isNotEmpty) {
      final revertQty = type == 'Purchase' ? -quantity : quantity;
      await stockQuery.docs.first.reference.update({
        'quantity': FieldValue.increment(revertQty),
        'purchase': FieldValue.increment(type == 'Purchase' ? -quantity : 0),
        'sales': FieldValue.increment(type == 'Sale' ? -quantity : 0),
        'lastUpdated': DateTime.now(),
      });
    }
  }

  Future _applyStockChange(String productName, int quantity, String type) async {
    final stockQuery = await FirebaseFirestore.instance
        .collection('stocks')
        .where('user', isEqualTo: user!.uid)
        .where('product', isEqualTo: productName)
        .limit(1)
        .get();
    final qty = type == 'Purchase' ? quantity : -quantity;
    if (stockQuery.docs.isNotEmpty) {
      final stockData = stockQuery.docs.first.data();
      final futureStock = (stockData['quantity'] ?? 0) + qty;
      // PREVENT NEGATIVE STOCK
      if (futureStock < 0) {
        final currentStock = stockData['quantity'] ?? 0;
        Fluttertoast.showToast(
            msg: "Insufficient stock! Available: $currentStock",
            backgroundColor: Colors.red);
        throw Exception("Stock cannot be negative");
      }

      await stockQuery.docs.first.reference.update({
        'quantity': futureStock,
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
        'user': user!.uid,
        'createdAt': DateTime.now(),
        'lastUpdated': DateTime.now(),
      });
    } else {
      Fluttertoast.showToast(
          msg: "Cannot sell non-existent product!",
          backgroundColor: Colors.red);
      throw Exception("Product not in stock");
    }
  }

  Future _ensurePartyExists(String partyName) async {
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
      await partyQuery.docs.first.reference.update({
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


  // Update or create linked bill with proper synchronization
  Future _updateLinkedBill(String customerName) async {
    if (_type != 'Sale') return;

    try {
      double subtotal = 0.0;
      List<Map<String, dynamic>> billItems = [];

      // Process all current products
      for (var product in _products) {
        String productName;
        if (product['selectedProduct'] == 'Others') {
          productName = (product['customProductController'] as TextEditingController).text.toLowerCase().trim();
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

      if (_linkedBillNumber != null) {
        // Update existing linked bill
        final billQuery = await FirebaseFirestore.instance
            .collection('bills')
            .where('billNumber', isEqualTo: _linkedBillNumber)
            .where('user', isEqualTo: user!.uid)
            .limit(1)
            .get();

        if (billQuery.docs.isNotEmpty) {
          await billQuery.docs.first.reference.update({
            'customerName': customerName,
            'customerPhone': _phoneController.text,
            'customerCity': _cityController.text,
            'customerState': _stateController.text,
            'items': billItems,
            'subtotal': subtotal,
            'tax': tax,
            'total': total,
            'date': DateFormat('dd-MM-yyyy').parse(_dateController.text),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('Updated linked bill $_linkedBillNumber with ${billItems.length} products');
        } else {
          print('Linked bill $_linkedBillNumber not found, will create new one');
          _linkedBillNumber = null; // Clear invalid link
        }
      }

      // Create new bill if no valid linked bill exists
      if (_linkedBillNumber == null) {
        final newBillNumber = await _generateBillNumber();
        await FirebaseFirestore.instance.collection('bills').add({
          'user': user!.uid,
          'billNumber': newBillNumber,
          'customerName': customerName,
          'customerPhone': _phoneController.text,
          'customerCity': _cityController.text,
          'customerState': _stateController.text,
          'date': DateFormat('dd-MM-yyyy').parse(_dateController.text),
          'items': billItems,
          'subtotal': subtotal,
          'tax': tax,
          'total': total,
          'linkedTransactionId': widget.docRef, // Link back to transaction
          'billType': 'auto-generated', // Mark as auto-generated
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update transaction with new bill number
        await FirebaseFirestore.instance
            .collection('transactions')
            .doc(widget.docRef)
            .update({
          'linkedBillNumber': newBillNumber,
        });

        _linkedBillNumber = newBillNumber;
        print('Created new linked bill $newBillNumber with ${billItems.length} products');
      }
    } catch (e) {
      print('Error updating/creating linked bill: $e');
    }
  }

  Future<void> _submitUpdate() async {
    // Hide keyboard immediately when update is pressed
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate() || user == null) return;

    setState(() => _isLoading = true);

    try {
      final newPartyName = _partyController.text.trim();

      // Check if party exists first
      final partyExists = await _checkPartyExists(newPartyName);
      if (!partyExists) {
        throw Exception("Please add $_partyLabel '$newPartyName' first before updating the transaction");
      }

      // Validate all products
      for (int i = 0; i < _products.length; i++) {
        final product = _products[i];
        String productName;
        if (product['selectedProduct'] == 'Others') {
          productName = (product['customProductController'] as TextEditingController).text.toLowerCase().trim();
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
        if (_type == 'Sale' && quantity > (product['availableStock'] as int)) {
          throw Exception("Product ${i + 1}: Insufficient stock. Available: ${product['availableStock']}");
        }
      }

      // Ensure new party exists
      await _ensurePartyExists(newPartyName);

      // Revert original stock changes
      for (var originalProduct in _originalProducts) {
        await _revertStockChange(
          originalProduct['product'].toString(),
          (originalProduct['quantity'] as num).toInt(),
          _originalType,
        );
      }

      // Prepare products array for single transaction document
      List<Map<String, dynamic>> productsArray = [];
      List<String> productNames = []; // NEW: Build product names array
      double totalAmount = 0.0;

      for (var product in _products) {
        String productName;
        if (product['selectedProduct'] == 'Others') {
          productName = (product['customProductController'] as TextEditingController).text.toLowerCase().trim();
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

        // Apply new stock changes
        await _applyStockChange(productName, quantity, _type);
      }

      // Update the single transaction document
      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(widget.docRef)
          .update({
        'product': productsArray,
        'product_names': productNames, // NEW: Add product names array
        'party': newPartyName,
        'date': DateFormat('dd-MM-yyyy').parse(_dateController.text),
        'type': _type,
        'status': _status,
        'totalAmount': totalAmount,
        'lastUpdated': DateTime.now(),
      });

      // Update linked bill for Sale transactions
      if (_type == 'Sale') {
        await _updateLinkedBill(newPartyName);
      }

      String successMessage = _type == 'Sale'
          ? "Sale with ${_products.length} products updated and bill synchronized successfully!"
          : "Purchase with ${_products.length} products updated successfully!";

      Fluttertoast.showToast(
        msg: successMessage,
        backgroundColor: Colors.green,
      );

      Navigator.pop(context);
    } catch (error) {
      Fluttertoast.showToast(
        msg: "$error",
        backgroundColor: Colors.red,
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

        if (snapshot.hasError) {
          print("Suggestion error: ${snapshot.error}");
          return const SizedBox.shrink();
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
                  // Load party details if it's party suggestions
                  if (controller == _partyController) {
                    _loadPartyDetails(suggestions[index]);
                  }
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
            _buildStockAwareDropdown(index),

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
                  if (_products[index]['selectedProduct'] == 'Others' &&
                      (value?.trim().isEmpty ?? true)) {
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
                if (_type == 'Sale') {
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
            if (_type == 'Sale' && _products[index]['selectedProduct'] != 'Others') ...[
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

  // Build dropdown with available stock products
  Widget _buildStockAwareDropdown(int index) {
    if (_type != 'Sale') {
      return DropdownButtonFormField<String>(
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
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getAvailableStockProducts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return DropdownButtonFormField<String>(
            items: const [],
            onChanged: null,
            decoration: const InputDecoration(
              labelText: "Loading products...",
              border: OutlineInputBorder(),
            ),
          );
        }

        final stockProducts = snapshot.data ?? [];
        final List<DropdownMenuItem<String>> products = [];

        // Add stock products
        for (final product in stockProducts) {
          final productName = _capitalizeFirstLetter(product['product'].toString());
          products.add(
            DropdownMenuItem(
              value: productName,
              child: Text(productName),
            ),
          );
        }

        // Add Others option
        products.add(const DropdownMenuItem(
          value: 'Others',
          child: Text('Others'),
        ));

        final currentValue = (_products[index]['selectedProduct'] as String);
        final validValues = products.map((product) => product.value).toList();
        final isValidSelection = currentValue.isEmpty || validValues.contains(currentValue);

        return DropdownButtonFormField<String>(
          value: isValidSelection ? (currentValue.isEmpty ? null : currentValue) : null,
          items: products,
          onChanged: _isLoading ? null : (value) => _onProductChanged(index, value),
          decoration: const InputDecoration(
            labelText: "Product",
            border: OutlineInputBorder(),
          ),
          validator: (value) => value == null ? "Please select a product" : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return AlertDialog(
        title: const Text("Update Transaction"),
        content: Container(
          height: 100,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return AlertDialog(
      title: const Text("Update Transaction"),
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
                  // Type dropdown (readonly for update)
                  DropdownButtonFormField<String>(
                    value: _type.isEmpty ? null : _type,
                    items: ['Purchase', 'Sale']
                        .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: null, // Disabled for update
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
                                  tooltip: 'Add New $_partyLabel',
                                ),
                              ),
                              validator: (value) =>
                              value?.isEmpty ?? true ? "Please enter $_partyLabel name" : null,
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
                        initialDate: DateFormat('dd-MM-yyyy').parse(_dateController.text),
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
                  ...List.generate(_products.length, (index) => _buildProductCard(index)),
                  const SizedBox(height: 16),

                  // Status dropdown
                  DropdownButtonFormField<String>(
                    value: _status,
                    items: ['Paid', 'Unpaid']
                        .map((status) => DropdownMenuItem(value: status, child: Text(status)))
                        .toList(),
                    onChanged: _isLoading ? null : (value) => setState(() => _status = value!),
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
          onPressed: _isLoading ? null : _submitUpdate,
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
              : const Text("Update"),
        ),
      ],
    );
  }
}
