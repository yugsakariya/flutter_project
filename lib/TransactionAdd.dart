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
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _dateController = TextEditingController();
  final _partyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _selectedType = 'Purchase';
  String? _selectedStatus = 'Paid';
  String? lable = 'Supplier';

  final User? user = FirebaseAuth.instance.currentUser;

  final TextEditingController _productSearchController = TextEditingController();
  final FocusNode _productFocusNode = FocusNode();
  bool _showSuggestions = false;

  Future<bool> isProductinCollection(String product) async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('stocks')
        .where('product', isEqualTo: product)
        .where('user', isEqualTo: user?.uid)
        .get();

    return querySnapshot.docs.isNotEmpty;
  }

  Stream<List<String>> _getProductSuggestions(String query) {
    if (query.trim().isEmpty) {
      return Stream.value([]);
    }

    return FirebaseFirestore.instance
        .collection('stocks')
        .where('user', isEqualTo: user?.uid)
        .where('product', isGreaterThanOrEqualTo: query.trim().toLowerCase())
        .where('product', isLessThan: query.trim().toLowerCase() + '\uf8ff')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => (doc.data())['product'] as String? ?? '')
          .where((product) => product.isNotEmpty)
          .toList();
    });
  }

  Future<void> updateStockQuantity(String product, int quantity, String type) async {
    if (user == null) {
      Fluttertoast.showToast(msg: "Action failed: User not logged in.", backgroundColor: Colors.red);
      return;
    }

    QuerySnapshot docs = await FirebaseFirestore.instance
        .collection('stocks')
        .where('product', isEqualTo: product)
        .where('user', isEqualTo: user!.uid)
        .limit(1)
        .get();

    if (docs.docs.isNotEmpty) {
      DocumentReference stockRef = docs.docs.first.reference;
      await stockRef.update({
        'quantity': FieldValue.increment(type == "Purchase" ? quantity : -quantity),
        'purchase': FieldValue.increment(type == "Purchase" ? quantity : 0),
        'sales': FieldValue.increment(type == "Sale" ? quantity : 0),
        'lastUpdated': DateTime.now(),
      });
    } else {
      await FirebaseFirestore.instance.collection('stocks').add({
        'product': product,
        'quantity': type == "Purchase" ? quantity : -quantity,
        'purchase': type == "Purchase" ? quantity : 0,
        'sales': type == "Sale" ? quantity : 0,
        'user': user!.uid,
        'createdAt': DateTime.now(),
        'lastUpdated': DateTime.now(),
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
    _productFocusNode.addListener(() {
      setState(() {
        _showSuggestions = _productFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _productController.dispose();
    _productSearchController.dispose();
    _productFocusNode.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _dateController.dispose();
    _partyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Add Transaction"),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _productController,
                    focusNode: _productFocusNode,
                    decoration: InputDecoration(
                      labelText: "Product",
                      hintText: "Enter Product name",
                    ),
                    validator: (value) => value!.isEmpty ? "Please enter product name" : null,
                    onChanged: (value) => setState(() {}),
                  ),
                  if (_showSuggestions && _productController.text.trim().isNotEmpty)
                    StreamBuilder<List<String>>(
                      stream: _getProductSuggestions(_productController.text),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Container(height: 40, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
                        }
                        if (snapshot.hasError) {
                          return Container(height: 40, child: Center(child: Text('Error', style: TextStyle(color: Colors.red, fontSize: 12))));
                        }
                        List<String> suggestions = snapshot.data ?? [];
                        if (suggestions.isEmpty) return SizedBox.shrink();

                        return Container(
                          constraints: BoxConstraints(maxHeight: 150),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 4, offset: Offset(0, 2))],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: suggestions.length,
                            itemBuilder: (context, index) {
                              String suggestion = suggestions[index];
                              return ListTile(
                                dense: true,
                                title: Text(suggestion, style: TextStyle(fontSize: 14)),
                                onTap: () {
                                  _productController.text = suggestion;
                                  _productFocusNode.unfocus();
                                  setState(() {});
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(labelText: "Quantity", hintText: "Enter Quantity"),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) return "Please enter quantity";
                  if (int.tryParse(value) == null || int.parse(value) <= 0) return "Quantity must be greater than 0";
                  return null;
                },
              ),
              TextFormField(
                controller: _unitPriceController,
                decoration: InputDecoration(labelText: "Unit Price", hintText: "Enter Unit Price"),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) return "Please enter unit price";
                  if (double.tryParse(value) == null || double.parse(value) <= 0) return "Unit price must be greater than 0";
                  return null;
                },
              ),
              TextFormField(
                controller: _dateController,
                decoration: InputDecoration(
                  labelText: "Date",
                  hintText: "Select Date",
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context, initialDate: DateTime.now(),
                    firstDate: DateTime(2000), lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) _dateController.text = DateFormat('dd-MM-yyyy').format(pickedDate);
                },
                validator: (value) => value!.isEmpty ? "Please select date" : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: ['Purchase', 'Sale'].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (value) => setState((){
                  _selectedType = value;
                  lable = (value == "Purchase") ? "Supplier" : "Customer";
                }),
                decoration: InputDecoration(labelText: "Type", hintText: "Select Type"),
                validator: (value) => value == null ? "Please select type" : null,
              ),
              TextFormField(
                controller: _partyController,
                decoration: InputDecoration(labelText: lable, hintText: "Enter $lable Name"),
                validator: (value) => value!.isEmpty ? "Please enter $lable name" : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                items: ['Paid', 'Due'].map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
                onChanged: (value) => setState(() => _selectedStatus = value),
                decoration: InputDecoration(labelText: "Status", hintText: "Select Status"),
                validator: (value) => value == null ? "Please select status" : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
          child: Text("Cancel", style: TextStyle(color: Colors.white)),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              if (user == null) {
                Fluttertoast.showToast(msg: "Action failed: User not logged in.", backgroundColor: Colors.red);
                return;
              }
              try {
                await FirebaseFirestore.instance.collection('transactions').add({
                  'product': _productController.text.toLowerCase(),
                  'quantity': int.parse(_quantityController.text),
                  'unitPrice': double.parse(_unitPriceController.text),
                  'party': _partyController.text,
                  'date': DateFormat('dd-MM-yyyy').parse(_dateController.text),
                  'type': _selectedType,
                  'status': _selectedStatus,
                  'user': user!.uid,
                  'timestamp': DateTime.now(),
                });

                await updateStockQuantity(
                  _productController.text.toLowerCase(),
                  int.parse(_quantityController.text),
                  _selectedType!,
                );

                Fluttertoast.showToast(msg: "Transaction Added Successfully", backgroundColor: Colors.green);
                Navigator.pop(context);

              } catch (error) {
                Fluttertoast.showToast(msg: "Failed to add transaction: $error", backgroundColor: Colors.red);
              }
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          child: Text("Submit", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}