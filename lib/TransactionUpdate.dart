import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Transactionupdate extends StatefulWidget {
  String? docRef;
  const Transactionupdate({super.key , required` this.docRef});

  @override
  State<Transactionupdate> createState() => _TransactionupdateState();
}
class _TransactionupdateState extends State<Transactionupdate> {
  bool _isLoading = true;
  final _productController = TextEditingController();
  final _typeController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  // final _totalController = TextEditingController();
  final _dateController = TextEditingController();
  final _partyController = TextEditingController();
  final _statusController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  @override
 void initState() {
    super.initState();
    _loadTransactionData();
  }
  Future<void> _loadTransactionData() async {
    try {
      DocumentSnapshot docData = await FirebaseFirestore.instance
          .collection('transactions')
          .doc(widget.docRef)
          .get();

      if (docData.exists) {
        _productController.text = docData["product"] ?? '';
        _typeController.text = docData["type"] ?? '';
        _quantityController.text = docData["quantity"]?.toString() ?? '';
        _unitPriceController.text = docData["price"]?.toString() ?? '';
        _dateController.text = docData["description"] ?? '';
        _partyController.text = docData["supplier"] ?? '';
        _statusController.text = docData["status"] ?? '';
        
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading product data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Update Transaction"),
      content: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _productController,
              decoration:InputDecoration(
                label: Text("Product"),
                hintText: "Enter Product name",
              ),
              validator:(value){
                if(value!.isEmpty){
                  return "Please enter product name";
                }
                return null;
              },
            ),
            TextFormField(
              controller: _quantityController,
              decoration:InputDecoration(
                label: Text("Quantity"),
                hintText: "Enter Quantity",
              ),
              validator:(value){
                if(value!.isEmpty){
                  return "Please enter quantity";
                }
                return null;
              },
            ),
            TextFormField(
              controller: _unitPriceController,
              decoration:InputDecoration(
                label: Text("Unit Price"),
                hintText: "Enter Unit Price",
              ),
              validator:(value){
                if(value!.isEmpty){
                  return "Please enter unit price";
                }
                return null;
              },
            ),
            TextFormField(
              controller: _partyController,
              decoration:InputDecoration(
                label: Text("Party"),
                hintText: "Enter Party Name",
              ),
              validator:(value){
                if(value!.isEmpty){
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
                        _dateController.text = DateFormat('dd-MM-yyyy').format(pickedDate);
                      }
                    });
                  },
                ),
              ),
              validator:(value){
                if(value!.isEmpty){
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
                setState(() =>_typeController.text = value!);
              },
              decoration: InputDecoration(
                labelText: "Type",
                hintText: "Select Type",
              ),
              validator:(value){
                if(value==null){
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
              validator:(value){
                if(value==null){
                  return "Please select status";
                }
                return null;
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(onPressed: (){

            },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                padding: EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text("Cancel", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
