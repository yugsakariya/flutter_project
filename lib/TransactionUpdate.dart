import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

class Transactionupdate extends StatefulWidget {
  final String docRef;
  const Transactionupdate({super.key , required this.docRef});

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
        _dateController.text = DateFormat('dd-MM-yyyy').format(docData['date'].toDate())?? '';
        _partyController.text = docData["party"] ?? '';

        // Ensure the values from database match dropdown options
        String typeFromDB = docData['type']?.toString() ?? '';
        String statusFromDB = docData['status']?.toString() ?? '';

        _type = typeFromDB;
        _status = statusFromDB;

        print('load exit');
        setState(() {}); // Trigger rebuild after loading data
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error loading transaction data: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
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
                  if(int.tryParse(value) == null){
                    return "Please enter valid Quantity";
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
                  if(double.tryParse(value) == null){
                    return "Please enter valid Unit Price";
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _partyController,
                decoration: InputDecoration(
                  label: Text("Party"),
                  hintText: "Enter Party Name",
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return "Please enter party name";
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
                        onPressed: (){
                          if(_formKey.currentState!.validate()){
                            FirebaseFirestore.instance
                                .collection('transactions')
                                .doc(widget.docRef)
                                .update({
                              "product": _productController.text,
                              "type": _type,
                              "quantity": int.parse(_quantityController.text),
                              "unitPrice": double.parse(_unitPriceController.text),
                              "date": DateFormat('dd-MM-yyyy').parse(
                                  _dateController.text),
                              "party": _partyController.text,
                              "status": _status,
                            }).then((_) {
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
                            }).catchError((error) {
                              Fluttertoast.showToast(msg: "Error:$error",
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                                timeInSecForIosWeb: 1,
                                backgroundColor: Colors.red,
                                textColor: Colors.white,
                                fontSize: 16.0,
                              );
                            });
                          }
                        },
                        child: Text("Submit")
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
}