import 'package:cloud_firestore/cloud_firestore.dart';
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
  String? _type;
  String? _status;
  String? lable = "";
  // Store original transaction data for stock reversal
  String? _originalProduct;
  int? _originalQuantity;
  String? _originalType;

  @override
  void initState() {
    super.initState();
    _loadTransactionData();
  }

  void _loadTransactionData() async {
    try {
      DocumentSnapshot docData = await FirebaseFirestore.instance
          .collection('transactions')
          .doc(widget.docRef)
          .get();
      print("Before load");
      if (docData.exists) {
        print("In load data");
        _productController.text = docData["product"] ?? '';
        _quantityController.text = docData["quantity"]?.toString() ?? '';
        _unitPriceController.text = docData["unitPrice"]?.toString() ?? '';
        _dateController.text = DateFormat('dd-MM-yyyy').format(docData['date'].toDate());
        _partyController.text = docData["party"] ?? '';

        // Ensure the values from database match dropdown options
        String typeFromDB = docData['type']?.toString() ?? '';
        String statusFromDB = docData['status']?.toString() ?? '';

        _type = typeFromDB;
        _status = statusFromDB;

        // Store original values for stock management
        _originalProduct = docData['product'];
        _originalQuantity = docData['quantity'];
        _originalType = docData['type'];

        print('load exit');
        setState(() {}); // Trigger rebuild after loading data
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error loading transaction data: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Future<void> updateStockForTransaction({
    required String oldProduct,
    required int oldQuantity,
    required String oldType,
    required String newProduct,
    required int newQuantity,
    required String newType,
  }) async {
    try {
      // Step 1: Revert the old transaction's effect on stock
      await _revertStockChange(oldProduct, oldQuantity, oldType);

      // Step 2: Apply the new transaction's effect on stock
      await _applyStockChange(newProduct, newQuantity, newType);

    } catch (error) {
      print("Error updating stock: $error");
      throw error; // Re-throw to handle in calling function
    }
  }

  Future<void> _revertStockChange(String product, int quantity, String type) async {
    QuerySnapshot docs = await FirebaseFirestore.instance
        .collection('stocks')
        .where('product', isEqualTo: product)
        .limit(1)
        .get();

    if (docs.docs.isNotEmpty) {
      DocumentSnapshot stockDoc = docs.docs.first;
      Map<String, dynamic> stockData = stockDoc.data() as Map<String, dynamic>;

      int currentQuantity = stockData['quantity'] ?? 0;
      int currentPurchase = stockData['purchase'] ?? 0;
      int currentSales = stockData['sales'] ?? 0;

      int revertedQuantity;
      int revertedPurchase = currentPurchase;
      int revertedSales = currentSales;

      if (type == "Purchase") {
        // If original was purchase, subtract from both quantity and purchase
        revertedQuantity = currentQuantity - quantity;
        revertedPurchase = currentPurchase - quantity;
      } else {
        // If original was sale, add to quantity and subtract from sales
        revertedQuantity = currentQuantity + quantity;
        revertedSales = currentSales - quantity;
      }

      await FirebaseFirestore.instance
          .collection('stocks')
          .doc(stockDoc.id)
          .update({
        'quantity': revertedQuantity,
        'purchase': revertedPurchase,
        'sales': revertedSales,
        'lastUpdated': DateTime.now(),
      });
    }
  }

  Future<void> _applyStockChange(String product, int quantity, String type) async {
    QuerySnapshot docs = await FirebaseFirestore.instance
        .collection('stocks')
        .where('product', isEqualTo: product)
        .limit(1)
        .get();

    if (docs.docs.isNotEmpty) {
      // Product exists, update quantity and purchase/sales fields
      DocumentSnapshot stockDoc = docs.docs.first;
      Map<String, dynamic> stockData = stockDoc.data() as Map<String, dynamic>;

      int currentQuantity = stockData['quantity'] ?? 0;
      int currentPurchase = stockData['purchase'] ?? 0;
      int currentSales = stockData['sales'] ?? 0;

      int newQuantity;
      int newPurchase = currentPurchase;
      int newSales = currentSales;

      if (type == "Purchase") {
        newQuantity = currentQuantity + quantity;
        newPurchase = currentPurchase + quantity;
      } else {
        newQuantity = currentQuantity - quantity;
        newSales = currentSales + quantity;
      }

      await FirebaseFirestore.instance
          .collection('stocks')
          .doc(stockDoc.id)
          .update({
        'quantity': newQuantity,
        'purchase': newPurchase,
        'sales': newSales,
        'lastUpdated': DateTime.now(),
      });
    } else {
      // Product doesn't exist, create new stock document
      int initialQuantity;
      int initialPurchase = 0;
      int initialSales = 0;

      if (type == "Purchase") {
        initialQuantity = quantity;
        initialPurchase = quantity;
      } else {
        initialQuantity = -quantity;
        initialSales = quantity;
      }

      await FirebaseFirestore.instance.collection('stocks').add({
        'product': product,
        'quantity': initialQuantity,
        'purchase': initialPurchase,
        'sales': initialSales,
        'createdAt': DateTime.now(),
        'lastUpdated': DateTime.now(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Update Transaction"),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(
                controller: _productController,
                decoration: InputDecoration(
                  label: Text("Product"),
                  hintText: "Enter Product name",
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return "Please enter product name";
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  label: Text("Quantity"),
                  hintText: "Enter Quantity",
                  suffixText: "Kg",
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return "Please enter quantity";
                  }
                  if (int.tryParse(value) == null) {
                    return "Please enter valid Quantity";
                  }
                  if (int.parse(value) <= 0) {
                    return "Quantity must be greater than 0";
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _unitPriceController,
                decoration: InputDecoration(
                  label: Text("Unit Price"),
                  hintText: "Enter Unit Price",
                  suffixText: "per Kg",
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return "Please enter unit price";
                  }
                  if (double.tryParse(value) == null) {
                    return "Please enter valid Unit Price";
                  }
                  if (double.parse(value) <= 0) {
                    return "Unit price must be greater than 0";
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                value: _type,
                items: ['Purchase', 'Sale'].map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _type = value);
                },
                decoration: InputDecoration(
                  labelText: "Type",
                  hintText: "Select Type",
                ),
                validator: (value) {
                  if (value == null) {
                    return "Please select type";
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _partyController,
                decoration: InputDecoration(
                  label: Text(lable!),
                  hintText: "Enter $lable Name",
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return "Please enter $lable name";
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _dateController,
                decoration: InputDecoration(
                  labelText: "Date",
                  hintText: "Select Date",
                  suffixIcon: IconButton(
                    icon: Icon(Icons.calendar_today),
                    onPressed: () {
                      showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      ).then((pickedDate) {
                        if (pickedDate != null) {
                          _dateController.text =
                              DateFormat('dd-MM-yyyy').format(pickedDate);
                        }
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return "Please select date";
                  }
                  return null;
                },
              ),

              DropdownButtonFormField<String>(
                value: _status,
                items: ['Paid', 'Due'].map((status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _status = value);
                },
                decoration: InputDecoration(
                  labelText: "Status",
                  hintText: "Select Status",
                ),
                validator: (value) {
                  if (value == null) {
                    return "Please select status";
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text("Cancel", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          try {
                            // Update stock based on transaction changes
                            if (_originalProduct != null &&
                                _originalQuantity != null &&
                                _originalType != null) {
                              await updateStockForTransaction(
                                oldProduct: _originalProduct!,
                                oldQuantity: _originalQuantity!,
                                oldType: _originalType!,
                                newProduct: _productController.text.toLowerCase(),
                                newQuantity: int.parse(_quantityController.text),
                                newType: _type!,
                              );
                            }

                            // Update transaction in Firestore
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

                            // If product name changed, update in stocks as well
                            if (_originalProduct != null &&
                                _originalProduct != _productController.text.toLowerCase()) {
                              QuerySnapshot stockDocs = await FirebaseFirestore.instance
                                  .collection('stocks')
                                  .where('product', isEqualTo: _originalProduct)
                                  .limit(1)
                                  .get();
                              if (stockDocs.docs.isNotEmpty) {
                                await FirebaseFirestore.instance
                                    .collection('stocks')
                                    .doc(stockDocs.docs.first.id)
                                    .update({
                                  'product': _productController.text.toLowerCase(),
                                  'lastUpdated': DateTime.now(),
                                });
                              }
                            }

                            Fluttertoast.showToast(
                              msg: "Transaction updated successfully",
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                              timeInSecForIosWeb: 1,
                              backgroundColor: Colors.green,
                              textColor: Colors.white,
                              fontSize: 16.0,
                            );
                            Navigator.pop(context);

                          } catch (error) {
                            Fluttertoast.showToast(
                              msg: "Error: $error",
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                              timeInSecForIosWeb: 1,
                              backgroundColor: Colors.red,
                              textColor: Colors.white,
                              fontSize: 16.0,
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text("Submit", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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