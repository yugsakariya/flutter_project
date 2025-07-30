import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  String? _originalProduct;
  int? _originalQuantity;
  String? _originalType;

  final User? user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTransactionData();
  }

  void _loadTransactionData() async {
    setState(() => _isLoading = true);
    try {
      DocumentSnapshot docData = await FirebaseFirestore.instance
          .collection('transactions')
          .doc(widget.docRef)
          .get();

      if (docData.exists) {
        final data = docData.data() as Map<String, dynamic>;
        _productController.text = data["product"] ?? '';
        _quantityController.text = data["quantity"]?.toString() ?? '';
        _unitPriceController.text = data["unitPrice"]?.toString() ?? '';
        _dateController.text = DateFormat('dd-MM-yyyy').format(data['date'].toDate());
        _partyController.text = data["party"] ?? '';
        _type = data['type'];
        _status = data['status'];
        lable = (_type == "Purchase") ? "Supplier" : "Customer";

        _originalProduct = data['product'];
        _originalQuantity = data['quantity'];
        _originalType = data['type'];
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error loading transaction data: $e", backgroundColor: Colors.red);
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStock({required String product, required int quantity, required String type, bool isReverting = false}) async {
    if(user == null) return;

    final stockQuery = await FirebaseFirestore.instance
        .collection('stocks')
        .where('user', isEqualTo: user!.uid)
        .where('product', isEqualTo: product)
        .limit(1)
        .get();

    int quantityChange = (type == 'Purchase') ? quantity : -quantity;
    if (isReverting) quantityChange = -quantityChange;

    if (stockQuery.docs.isNotEmpty) {
      await stockQuery.docs.first.reference.update({'quantity': FieldValue.increment(quantityChange)});
    } else if (!isReverting) {
      await FirebaseFirestore.instance.collection('stocks').add({
        'product': product, 'quantity': quantityChange, 'user': user!.uid,
        'purchase': 0, 'sales': 0, 'createdAt': DateTime.now()
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Update Transaction"),
      content: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(
                controller: _productController,
                decoration: InputDecoration(labelText: "Product"),
                validator: (v) => v!.isEmpty ? "Product name required" : null,
              ),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(labelText: "Quantity"),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v!.isEmpty) return "Quantity required";
                  if (int.tryParse(v) == null || int.parse(v) <= 0) return "Enter a valid quantity";
                  return null;
                },
              ),
              TextFormField(
                controller: _unitPriceController,
                decoration: InputDecoration(labelText: "Unit Price"),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v!.isEmpty) return "Unit price required";
                  if (double.tryParse(v) == null || double.parse(v) <= 0) return "Enter a valid price";
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                value: _type,
                items: ['Purchase', 'Sale'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() {
                  _type = v;
                  lable = (v == "Purchase") ? "Supplier" : "Customer";
                }),
                decoration: InputDecoration(labelText: "Type"),
                validator: (v) => v == null ? "Type required" : null,
              ),
              TextFormField(
                controller: _partyController,
                decoration: InputDecoration(labelText: lable),
                validator: (v) => v!.isEmpty ? "Please enter $lable name" : null,
              ),
              TextFormField(
                controller: _dateController,
                decoration: InputDecoration(labelText: "Date", suffixIcon: Icon(Icons.calendar_today)),
                readOnly: true,
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context, initialDate: DateTime.now(),
                    firstDate: DateTime(2000), lastDate: DateTime(2100),
                  );
                  if (picked != null) _dateController.text = DateFormat('dd-MM-yyyy').format(picked);
                },
                validator: (v) => v!.isEmpty ? "Date required" : null,
              ),
              DropdownButtonFormField<String>(
                value: _status,
                items: ['Paid', 'Due'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _status = v),
                decoration: InputDecoration(labelText: "Status"),
                validator: (v) => v == null ? "Status required" : null,
              ),
            ],
          ),
        ),
      ),
      actions: _isLoading ? [] : [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
        ElevatedButton(
          child: Text("Submit"),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              if(user == null || _originalProduct == null) {
                Fluttertoast.showToast(msg: "Error: User or original data missing.", backgroundColor: Colors.red);
                return;
              }
              setState(() => _isLoading = true);

              try {
                await _updateStock(product: _originalProduct!, quantity: _originalQuantity!, type: _originalType!, isReverting: true);
                await _updateStock(product: _productController.text.toLowerCase(), quantity: int.parse(_quantityController.text), type: _type!);

                await FirebaseFirestore.instance.collection('transactions').doc(widget.docRef).update({
                  "product": _productController.text.toLowerCase(),
                  "type": _type,
                  "quantity": int.parse(_quantityController.text),
                  "unitPrice": double.parse(_unitPriceController.text),
                  "date": DateFormat('dd-MM-yyyy').parse(_dateController.text),
                  "party": _partyController.text,
                  "status": _status,
                  "lastUpdated": DateTime.now(),
                });

                Fluttertoast.showToast(msg: "Transaction updated successfully", backgroundColor: Colors.green);
                Navigator.pop(context);

              } catch (error) {
                Fluttertoast.showToast(msg: "Error: $error", backgroundColor: Colors.red);
              } finally {
                if(mounted) setState(() => _isLoading = false);
              }
            }
          },
        ),
      ],
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