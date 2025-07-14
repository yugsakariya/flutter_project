import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

class TransactionAdd extends StatefulWidget {
  const TransactionAdd({super.key});

  @override
  State<TransactionAdd> createState() => _TransactionAddState();
}

class _TransactionAddState extends State<TransactionAdd> {
  final _productController = TextEditingController();
  final _typeController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  // final _totalController = TextEditingController();
  final _dateController = TextEditingController();
  final _partyController = TextEditingController();
  final _statusController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  void initState() {
    super.initState();
    _typeController.text = 'Purchase'; // Default value
    _statusController.text = 'Paid'; // Default value
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Add Transaction"),
      content: Form(
        key: _formKey,
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
              ),
              validator: (value) {
                if (value!.isEmpty) {
                  return "Please enter quantity";
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
              value: _typeController.text,
              items: ['Purchase', 'Sale'].map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _typeController.text = value!);
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
              value: _statusController.text,
              items: ['Paid', 'Due'].map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _statusController.text = value!);
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
              children: [
                ElevatedButton(onPressed: () {
                  Navigator.pop(context);
                },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                      "Cancel", style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton(onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    FirebaseFirestore.instance
                        .collection('transactions')
                        .add(
                          {
                            'product': _productController.text,
                            'quantity': int.parse(_quantityController.text),
                            'unitPrice': double.parse(_unitPriceController.text),
                            'party': _partyController.text,
                            'date': DateFormat('dd-MM-yyyy').parse(_dateController.text),
                            'type': _typeController.text,
                            'status': _statusController.text,
                          }
                        ).then((value) {
                         Fluttertoast.showToast(msg: "Transaction Added",
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM,
                          backgroundColor: Colors.black,
                          textColor: Colors.white,
                          fontSize: 16.0
                         );
                          Navigator.pop(context);
                        }).catchError((error) {
                          Fluttertoast.showToast(
                            msg: "Failed to add transaction: $error",
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                            backgroundColor: Colors.red,
                            textColor: Colors.white,
                            fontSize: 16.0
                          );
                        }
                    );
                  }
                }, child: Text("Submit"))
              ],
            ),
          ],
        ),
      ),
    );
  }
}