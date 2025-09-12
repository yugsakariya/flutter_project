import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'utils.dart';
import 'party_management.dart';

class NewBillScreen extends StatefulWidget {
  const NewBillScreen({super.key});

  @override
  State<NewBillScreen> createState() => _NewBillScreenState();
}

class _NewBillScreenState extends State<NewBillScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _billNumberController = TextEditingController();
  final _nameFocusNode = FocusNode();

  DateTime _selectedDate = DateTime.now();
  List<Map<String, String>> _items = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _initializeBillNumber();
    _nameFocusNode.addListener(() {
      setState(() => _showSuggestions = _nameFocusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _billNumberController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeBillNumber() async {
    final billNo = await _getNextBillNumber();
    _billNumberController.text = billNo;
  }

  Future<String> _getNextBillNumber() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final querySnapshot = await FirebaseFirestore.instance
          .collection('billcounter')
          .where('user', isEqualTo: user?.uid)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return "INV-1";
      }

      final doc = querySnapshot.docs.first;
      final currentCounter = doc.data()['counter'] ?? 0;
      return "INV-${currentCounter + 1}";
    } catch (e) {
      return "INV-${DateTime.now().millisecondsSinceEpoch}";
    }
  }

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

  void _loadCustomerDetails(String customerName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final customerQuery = await FirebaseFirestore.instance
          .collection('customers')
          .where('user', isEqualTo: user?.uid)
          .where('name', isEqualTo: customerName)
          .limit(1)
          .get();

      if (customerQuery.docs.isNotEmpty) {
        final customerData = customerQuery.docs.first.data();
        setState(() {
          _phoneController.text = customerData['phone'] ?? '';
          _cityController.text = customerData['city'] ?? '';
          _stateController.text = customerData['state'] ?? '';
        });
      }
    } catch (e) {
      AppUtils.showError('Error loading customer details: $e');
    }
  }

  void _showAddCustomerDialog() {
    showDialog(
      context: context,
      builder: (context) => PartyDialog(
        partyType: PartyType.customer,
        initialName: _nameController.text,
        onPartyAdded: (customerData) {
          setState(() {
            _nameController.text = customerData['name'] ?? '';
            _phoneController.text = customerData['phone'] ?? '';
            _cityController.text = customerData['city'] ?? '';
            _stateController.text = customerData['state'] ?? '';
          });
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Item'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: _buildProductList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stocks')
          .where('user', isEqualTo: user?.uid)
          .where('quantity', isGreaterThan: 0)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No stocks available'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return ProductSelectionCard(
              productData: data,
              onItemAdded: (item) {
                setState(() => _items.add(item));
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  double _calculateSubtotal() {
    return _items.fold(0.0, (sum, item) {
      final quantity = int.tryParse(item['quantity'] ?? '0') ?? 0;
      final price = double.tryParse(item['price'] ?? '0') ?? 0.0;
      return sum + (quantity * price);
    });
  }
  Future<bool> _customerExists(String customerName) async {
    if (customerName.trim().isEmpty) return false;

    try {
      final user = FirebaseAuth.instance.currentUser;
      final customerQuery = await FirebaseFirestore.instance
          .collection('customers')
          .where('user', isEqualTo: user?.uid)
          .where('name', isEqualTo: customerName.trim())
          .limit(1)
          .get();

      return customerQuery.docs.isNotEmpty;
    } catch (e) {
      print('Error checking customer existence: $e');
      return false;
    }
  }

  Future<void> _saveBill() async {
    if (_nameController.text.isEmpty || _items.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please add customer name and items',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    // Check if customer exists
    final customerExists = await _customerExists(_nameController.text);
    if (!customerExists) {
      Fluttertoast.showToast(
        msg: 'Customer "${_nameController.text}" not found. Please add customer first.',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );

      // Optionally show the add customer dialog
      _showAddCustomerDialog();
      return;
    }

    LoadingDialog.show(context, 'Saving bill...');
    try {
      final user = FirebaseAuth.instance.currentUser;
      final billNumber = await _generateBillNumber();
      final subtotal = _calculateSubtotal();
      final tax = subtotal * 0.05;
      final total = subtotal + tax;

      // Save bill first
      final billDoc = await FirebaseFirestore.instance.collection('bills').add({
        'user': user?.uid,
        'billNumber': billNumber,
        'customerName': _nameController.text,
        'customerPhone': _phoneController.text,
        'customerCity': _cityController.text,
        'customerState': _stateController.text,
        'date': _selectedDate,
        'items': _items,
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'billType': 'manual',
      });

      // Create corresponding sale transaction
      final transactionId = await _createTransactionFromBill(billDoc.id);

      // Update bill with transaction reference
      if (transactionId != null) {
        await billDoc.update({'transactionId': transactionId});
      }

      LoadingDialog.hide(context);
      Fluttertoast.showToast(
        msg: 'Bill $billNumber saved successfully!',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      Navigator.pop(context);
    } catch (e) {
      LoadingDialog.hide(context);
      Fluttertoast.showToast(
        msg: 'Error saving bill: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }
  Future<String?> _createTransactionFromBill(String billId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // Convert bill items to transaction products format
      List<Map<String, dynamic>> productArray = [];
      List<String> productNames = [];

      for (var item in _items) {
        final productName = item['name']?.toLowerCase() ?? '';
        final quantity = int.tryParse(item['quantity'] ?? '0') ?? 0;
        final unitPrice = double.tryParse(item['price'] ?? '0') ?? 0.0;

        if (productName.isNotEmpty && quantity > 0 && unitPrice > 0) {
          productArray.add({
            'product': productName,
            'quantity': quantity,
            'unitPrice': unitPrice,
          });
          productNames.add(productName);
        }
      }

      if (productArray.isEmpty) return null;

      // Create transaction data
      final transactionData = {
        'user': user.uid,
        'type': 'Sale', // Bills always correspond to Sale transactions
        'party': _nameController.text.trim(),
        'product': productArray,
        'product_names': productNames,
        'date': _selectedDate,
        'timestamp': DateTime.now(),
        'status': 'Paid', // Default status for manual bills
        'billId': billId, // Link to bill
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add transaction
      final transactionDoc = await FirebaseFirestore.instance
          .collection('transactions')
          .add(transactionData);

      // Update stock for each product (reduce quantity for sales)
      for (var product in productArray) {
        await _updateStockForProduct(
            product['product'],
            product['quantity'],
            'Sale'
        );
      }

      return transactionDoc.id;

    } catch (e) {
      print('Error creating transaction from bill: $e');
      return null;
    }
  }

// Helper method to update stock
  Future<void> _updateStockForProduct(String productName, int quantity, String type) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
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

        // Only update if there's enough stock or if it's a purchase
        if (newQuantity >= 0 || type == "Purchase") {
          await stockQuery.docs.first.reference.update({
            'quantity': newQuantity,
            'purchase': FieldValue.increment(type == "Purchase" ? quantity : 0),
            'sales': FieldValue.increment(type == "Sale" ? quantity : 0),
            'lastUpdated': DateTime.now(),
          });
        }
      } else if (type == "Purchase") {
        // Create new stock entry for purchase
        await FirebaseFirestore.instance.collection('stocks').add({
          'product': productName,
          'quantity': quantity,
          'purchase': quantity,
          'sales': 0,
          'user': user.uid,
          'createdAt': DateTime.now(),
          'lastUpdated': DateTime.now(),
        });
      }
    } catch (e) {
      print('Error updating stock for product $productName: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = _calculateSubtotal();
    final tax = subtotal * 0.05;
    final total = subtotal + tax;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Bill'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('CUSTOMER DETAILS'),
            _buildCustomerForm(),

            _buildSectionHeader('BILL INFO'),
            _buildBillInfo(),

            _buildSectionHeader('ITEMS'),
            _buildItemsSection(),

            _buildSectionHeader('SUMMARY'),
            _buildSummary(subtotal, tax, total),

            const SizedBox(height: 20),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCustomerForm() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                labelText: 'Customer Name',
                onChanged: (value) => setState(() {}),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.person_add, color: Colors.indigo),
              onPressed: _showAddCustomerDialog,
              tooltip: 'Add New Customer',
            ),
          ],
        ),
        if (_showSuggestions && _nameController.text.isNotEmpty)
          SuggestionsList(
            stream: FirestoreHelper.getSuggestions('customers', 'name', _nameController.text),
            controller: _nameController,
            focusNode: _nameFocusNode,
            onSelected: _loadCustomerDetails,
          ),
        const SizedBox(height: 8),
        AppTextField(
          controller: _phoneController,
          labelText: 'Phone Number',
          prefixText: '+91 ',
          keyboardType: TextInputType.phone,
          maxLength: 10,
        ),
        const SizedBox(height: 8),
        AppTextField(
          controller: _cityController,
          labelText: 'City',
        ),
        const SizedBox(height: 8),
        AppTextField(
          controller: _stateController,
          labelText: 'State',
        ),
      ],
    );
  }

  Widget _buildBillInfo() {
    return Column(
      children: [
        AppTextField(
          controller: _billNumberController,
          labelText: 'Bill Number',
          enabled: false,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text("Date: "),
            TextButton(
              onPressed: _pickDate,
              child: Text(DateFormat.yMMMd().format(_selectedDate)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildItemsSection() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _addItem,
          icon: const Icon(Icons.add),
          label: const Text("Add Item"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        if (_items.isEmpty)
          const Text("No items added yet")
        else
          ..._items.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(item['name'] ?? 'Unknown'),
                  subtitle: Text('Quantity: ${item['quantity'] ?? '0'}'),
                  trailing: Text(
                    '₹${item['price'] ?? '0'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => setState(() => _items.remove(item)),
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildSummary(double subtotal, double tax, double total) {
    return Column(
      children: [
        _buildSummaryRow("Subtotal:", "₹${subtotal.toStringAsFixed(2)}"),
        _buildSummaryRow("Tax (5%):", "₹${tax.toStringAsFixed(2)}"),
        _buildSummaryRow(
          "Total:",
          "₹${total.toStringAsFixed(2)}",
          isBold: true,
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
        ),
        Text(
          value,
          style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveBill,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          minimumSize: const Size(double.infinity, 50),
        ),
        child: const Text('Save Bill', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}

class ProductSelectionCard extends StatefulWidget {
  final Map<String, dynamic> productData;
  final Function(Map<String, String>) onItemAdded;

  const ProductSelectionCard({
    super.key,
    required this.productData,
    required this.onItemAdded,
  });

  @override
  State<ProductSelectionCard> createState() => _ProductSelectionCardState();
}

class _ProductSelectionCardState extends State<ProductSelectionCard> {
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _addToBill() {
    if (_formKey.currentState!.validate()) {
      widget.onItemAdded({
        'name': widget.productData['product'] ?? 'Unknown',
        'quantity': _quantityController.text,
        'price': _priceController.text,
      });
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableStock = widget.productData['quantity'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.productData['product'] ?? 'Unknown Product',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                'Available Stock: $availableStock kg',
                style: TextStyle(color: Colors.blue.shade600, fontSize: 12),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _quantityController,
                labelText: 'Quantity',
                suffixText: 'kg',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Enter quantity';
                  final quantity = int.tryParse(value!) ?? 0;
                  if (quantity <= 0) return 'Quantity must be > 0';
                  if (quantity > availableStock) return 'Max available: $availableStock kg';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _priceController,
                labelText: 'Price per kg',
                prefixText: '₹',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) => AppUtils.validatePositiveNumber(value, 'Price'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _addToBill,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Add to Bill"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}