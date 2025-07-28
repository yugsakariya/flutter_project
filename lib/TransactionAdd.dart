import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Use nullable String variables instead of TextEditingControllers for dropdowns
  String? _selectedType;
  String? _selectedStatus;
  
  // For product suggestions
  final TextEditingController _productSearchController = TextEditingController();
  final FocusNode _productFocusNode = FocusNode();
  bool _showSuggestions = false;

  Future<bool> isProductinCollection(String product) async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('stocks')
        .where('product', isEqualTo: product)
        .get();

    return querySnapshot.docs.isNotEmpty;
  }

  Stream<List<String>> _getProductSuggestions(String query) {
    if (query.trim().isEmpty) {
      return Stream.value([]);
    }
    
    return FirebaseFirestore.instance
        .collection('stocks')
        .where('product', isGreaterThanOrEqualTo: query.trim().toLowerCase())
        .where('product', isLessThan: query.trim().toLowerCase() + '\uf8ff')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => (doc.data() as Map<String, dynamic>)['product'] as String? ?? '')
              .where((product) => product.isNotEmpty)
              .toList();
        });
  }

  Future<void> updateStockQuantity(String product, int quantity, String type) async {
    try {
      QuerySnapshot docs = await FirebaseFirestore.instance
          .collection('stocks')
          .where('product', isEqualTo: product)
          .limit(1)
          .get();

      if (docs.docs.isNotEmpty) {
        // Product exists in stocks, update quantity and purchase/sales fields
        DocumentSnapshot stockDoc = docs.docs.first;
        Map<String, dynamic> stockData = stockDoc.data() as Map<String, dynamic>;

        int currentQuantity = stockData['quantity'] ?? 0;
        int currentPurchase = stockData['purchase'] ?? 0;
        int currentSales = stockData['sales'] ?? 0;

        int newQuantity;
        int newPurchase = currentPurchase;
        int newSales = currentSales;

        if (type == "Purchase") {
          // Increase stock and purchase count for purchases
          newQuantity = currentQuantity + quantity;
          newPurchase = currentPurchase + quantity;
        } else {
          // Decrease stock and increase sales count for sales
          newQuantity = currentQuantity - quantity;
          newSales = currentSales + quantity;
        }

        // Update the existing stock document
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
        // Product doesn't exist in stocks, create new document
        int initialQuantity;
        int initialPurchase = 0;
        int initialSales = 0;

        if (type == "Purchase") {
          initialQuantity = quantity;
          initialPurchase = quantity;
        } else {
          // For sales of non-existing products, start with negative quantity
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
    } catch (error) {
      print("Error updating stock: $error");
      // You might want to show an error toast here
    }
  }

  @override
  void initState() {
    super.initState();
    // Set initial date to today
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
 String? lable = '';
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
                      label: Text("Product"),
                      hintText: "Enter Product name",
                    ),
                    validator: (value) {
                      if (value!.isEmpty) {
                        return "Please enter product name";
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                  if (_showSuggestions && _productController.text.trim().isNotEmpty)
                    StreamBuilder<List<String>>(
                      stream: _getProductSuggestions(_productController.text),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Container(
                            height: 40,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        
                        if (snapshot.hasError) {
                          return Container(
                            height: 40,
                            child: Center(
                              child: Text(
                                'Error loading suggestions',
                                style: TextStyle(color: Colors.red, fontSize: 12),
                              ),
                            ),
                          );
                        }
                        
                        List<String> suggestions = snapshot.data ?? [];
                        
                        if (suggestions.isEmpty) {
                          return SizedBox.shrink();
                        }
                        
                        return Container(
                          constraints: BoxConstraints(maxHeight: 150),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.3),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: suggestions.length,
                            itemBuilder: (context, index) {
                              String suggestion = suggestions[index];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  suggestion,
                                  style: TextStyle(fontSize: 14),
                                ),
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
                decoration: InputDecoration(
                  label: Text("Quantity"),
                  hintText: "Enter Quantity",
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return "Please enter quantity";
                  }
                  if (int.tryParse(value) == null) {
                    return "Please enter correct quantity";
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
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return "Please enter unit price";
                  }
                  if (double.tryParse(value) == null) {
                    return "Please enter correct unit price";
                  }
                  if (double.parse(value) <= 0) {
                    return "Unit price must be greater than 0";
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
                value: _selectedType,
                items: ['Purchase', 'Sale'].map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState((){
                    _selectedType = value;
                    if(value=="Purchase"){
                      lable = "Supplier";
                    }
                    if(value == 'Sale'){
                      lable = "Customer" ;
                    }
                  });
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
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                items: ['Paid', 'Due'].map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedStatus = value);
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
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    ),
                    child: Text("Cancel", style: TextStyle(color: Colors.white)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        try {
                          // Add transaction to Firestore
                          await FirebaseFirestore.instance
                              .collection('transactions')
                              .add({
                            'product': _productController.text.toLowerCase(),
                            'quantity': int.parse(_quantityController.text),
                            'unitPrice': double.parse(_unitPriceController.text),
                            'party': _partyController.text,
                            'date': DateFormat('dd-MM-yyyy').parse(_dateController.text),
                            'type': _selectedType,
                            'status': _selectedStatus,
                            'timestamp': DateTime.now(),
                          });

                          // Update stock quantity with purchase/sales tracking
                          await updateStockQuantity(
                            _productController.text.toLowerCase(),
                            int.parse(_quantityController.text),
                            _selectedType!,
                          );

                          Fluttertoast.showToast(
                            msg: "Transaction Added Successfully",
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                            backgroundColor: Colors.green,
                            textColor: Colors.white,
                            fontSize: 16.0,
                          );

                          Navigator.pop(context);
                        } catch (error) {
                          Fluttertoast.showToast(
                            msg: "Failed to add transaction: $error",
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                            backgroundColor: Colors.red,
                            textColor: Colors.white,
                            fontSize: 16.0,
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    ),
                    child: Text("Submit", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}