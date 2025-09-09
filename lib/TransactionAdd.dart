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
      setState(() => _products[0]['showProductSuggestions'] = (_products[0]['productFocusNode'] as FocusNode).hasFocus);
    });
  }

  @override
  void dispose() {
    _dateController.dispose();
    _partyController.dispose();
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
        setState(() => _products[productIndex]['availableStock'] = stockQuery.docs.first['quantity'] ?? 0);
      } else {
        setState(() => _products[productIndex]['availableStock'] = 0);
      }
    } catch (e) {
      setState(() => _products[productIndex]['availableStock'] = 0);
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
            msg: "Insufficient stock! Available: $currentQty",
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

  // FIXED: Auto-generate bill for Sale transactions with proper linking
  Future<String?> _generateLinkedBill(String customerName, String transactionId) async {
    if (_selectedType != 'Sale') return null;

    try {
      final billNumber = await _generateBillNumber();
      double subtotal = 0.0;
      List<Map<String, dynamic>> billItems = [];

      // Process all products
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

      // FIXED: Create linked bill
      await FirebaseFirestore.instance.collection('bills').add({
        'user': user!.uid,
        'billNumber': billNumber,
        'customerName': customerName,
        'customerPhone': '',
        'date': DateFormat('dd-MM-yyyy').parse(_dateController.text),
        'items': billItems,
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'linkedTransactionId': transactionId, // NEW: Link to transaction
        'billType': 'auto-generated', // NEW: Mark as auto-generated
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
        (_products[index]['productController'] as TextEditingController).text = value?.toLowerCase() ?? '';
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

        totalAmount += quantity * unitPrice;

        // Update stock for each product (moved to happen before transaction creation)
        await _updateStock(productName, quantity, _selectedType);
      }

      // FIXED: Create transaction with proper bill linking
      final transactionRef = await FirebaseFirestore.instance.collection('transactions').add({
        'product': productsArray,
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

      // FIXED: Auto-generate bill for Sale transactions with proper linking
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
    final product = _products[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product header with remove button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    "Product ${index + 1}",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                if (_products.length > 1)
                  IconButton(
                    onPressed: () => _removeProduct(index),
                    icon: const Icon(Icons.remove_circle_outline),
                    color: Colors.red.shade600,
                    tooltip: "Remove Product",
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Product dropdown - full width
            _buildStockAwareDropdown(index),

            // Custom product field (shown only when "Others" is selected)
            if (_products[index]['showCustomProductField'] as bool) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _products[index]['customProductController'] as TextEditingController,
                focusNode: _products[index]['productFocusNode'] as FocusNode,
                enabled: !_isLoading,
                decoration: const InputDecoration(
                  labelText: "Custom Product Name",
                  hintText: "Enter custom product name",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
                validator: (value) {
                  if (_products[index]['selectedProduct'] == 'Others' && (value?.trim().isEmpty == true)) {
                    return "Please enter custom product name";
                  }
                  return null;
                },
                onChanged: (value) async {
                  final normalizedProductName = value.toLowerCase().trim();
                  (_products[index]['productController'] as TextEditingController).text = normalizedProductName;
                  setState(() {});
                  if (_selectedType == 'Sale' && value.trim().isNotEmpty) {
                    await _getAvailableStock(index, normalizedProductName);
                  }
                },
              ),
              if ((_products[index]['showProductSuggestions'] as bool) &&
                  (_products[index]['customProductController'] as TextEditingController).text.trim().isNotEmpty &&
                  !_isLoading)
                _buildSuggestionsList(
                  stream: _getProductSuggestions(
                      (_products[index]['customProductController'] as TextEditingController).text),
                  controller: _products[index]['customProductController'] as TextEditingController,
                  focusNode: _products[index]['productFocusNode'] as FocusNode,
                ),
            ],
            const SizedBox(height: 16),

            // Quantity field - full width
            TextFormField(
              controller: _products[index]['quantityController'] as TextEditingController,
              enabled: !_isLoading,
              decoration: InputDecoration(
                labelText: "Quantity",
                hintText: "Enter quantity",
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.inventory_2_outlined),
                helperText: _selectedType == 'Sale' &&
                    (((_products[index]['selectedProduct'] as String).isNotEmpty &&
                        _products[index]['selectedProduct'] != 'Others') ||
                        (_products[index]['customProductController'] as TextEditingController)
                            .text
                            .isNotEmpty)
                    ? "Available stock: ${_products[index]['availableStock']}"
                    : null,
                helperStyle: TextStyle(
                  color: (_products[index]['availableStock'] as int) > 0
                      ? Colors.green.shade600
                      : Colors.red.shade600,
                  fontWeight: FontWeight.w500,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.trim().isEmpty == true) return "Please enter quantity";
                final qty = int.tryParse(value!);
                if (qty == null || qty <= 0) return "Quantity must be greater than 0";
                if (_selectedType == 'Sale' && qty > (_products[index]['availableStock'] as int)) {
                  return "Insufficient stock. Available: ${_products[index]['availableStock']}";
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Unit Price field - full width
            TextFormField(
              controller: _products[index]['unitPriceController'] as TextEditingController,
              enabled: !_isLoading,
              decoration: const InputDecoration(
                labelText: "Unit Price",
                hintText: "Enter unit price",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value?.trim().isEmpty == true) return "Please enter unit price";
                final price = double.tryParse(value!);
                return price == null || price <= 0 ? "Unit price must be greater than 0" : null;
              },
            ),
          ],
        ),
      ),
    );
  }

  // Build dropdown with available stock products - FIXED DUPLICATE VALUES ISSUE
  Widget _buildStockAwareDropdown(int index) {
    if (_selectedType != 'Sale') {
      return DropdownButtonFormField<String>(
        value: (_products[index]['selectedProduct'] as String).isEmpty
            ? null
            : _products[index]['selectedProduct'] as String,
        items: _predefinedProducts.map((product) {
          return DropdownMenuItem<String>(
            value: product,
            child: Text(product),
          );
        }).toList(),
        onChanged: _isLoading ? null : (value) => _onProductChanged(index, value),
        decoration: const InputDecoration(
          labelText: "Product",
          hintText: "Select a product",
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        validator: (value) => value == null ? "Please select a product" : null,
        isExpanded: true,
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
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
          );
        }

        final stockProducts = snapshot.data ?? [];

        // FIXED: Remove duplicates by using a Map with product name as key
        final Map<String, Map<String, dynamic>> uniqueProductsMap = {};
        for (final product in stockProducts) {
          final productName = product['product'].toString();
          // Keep the one with highest quantity if duplicates exist
          if (!uniqueProductsMap.containsKey(productName) ||
              (uniqueProductsMap[productName]!['quantity'] as int) < (product['quantity'] as int)) {
            uniqueProductsMap[productName] = product;
          }
        }

        final List<DropdownMenuItem<String>> products = [];

        // Add stock products with better formatting
        uniqueProductsMap.values.forEach((product) {
          products.add(
            DropdownMenuItem<String>(
              value: product['product'].toString(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        product['product'].toString(),
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          );
        });

        if (!uniqueProductsMap.containsKey('Others')) {
          products.add(const DropdownMenuItem<String>(
            value: 'Others',
            child: Text('Others'),
          ));
        }

        final currentValue = (_products[index]['selectedProduct'] as String);
        final validValues = products.map((product) => product.value).toList();
        final isValidSelection = currentValue.isEmpty || validValues.contains(currentValue);

        return DropdownButtonFormField<String>(
          value: isValidSelection ? (currentValue.isEmpty ? null : currentValue) : null,
          items: products,
          onChanged: _isLoading ? null : (value) => _onProductChanged(index, value),
          decoration: const InputDecoration(
            labelText: "Product",
            hintText: "Select a product",
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          validator: (value) => value == null ? "Please select a product" : null,
          isExpanded: true,
          menuMaxHeight: 250,
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
                        .map((type) => DropdownMenuItem<String>(value: type, child: Text(type)))
                        .toList(),
                    onChanged: _isLoading ? null : (value) {
                      setState(() {
                        _selectedType = value!;
                        _partyController.clear();
                        _partyFocusNode.unfocus();
                        // Reset all products' available stock when type changes
                        for (var product in _products) {
                          product['availableStock'] = 0;
                        }
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: "Type",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    validator: (value) => value == null ? "Please select type" : null,
                    isExpanded: true,
                  ),
                  const SizedBox(height: 16),

                  // Products section with add button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Products",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: _isLoading ? null : _addNewProduct,
                        icon: const Icon(Icons.add_circle, color: Colors.green),
                        tooltip: "Add Product",
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Dynamic list of products
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _products.length,
                    itemBuilder: (context, index) => _buildProductCard(index),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _dateController,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: "Date",
                      suffixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
                          prefixIcon: const Icon(Icons.person),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
                        .map((status) => DropdownMenuItem<String>(value: status, child: Text(status)))
                        .toList(),
                    onChanged: _isLoading ? null : (value) => setState(() => _selectedStatus = value!),
                    decoration: const InputDecoration(
                      labelText: "Status",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    validator: (value) => value == null ? "Please select status" : null,
                    isExpanded: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text("Cancel"),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitTransaction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text("Submit"),
            ),
          ],
        ),
      ],
    );
  }
}