import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ProductAdd extends StatefulWidget {
  const ProductAdd({super.key});

  @override
  State<ProductAdd> createState() => _ProductAddState();
}

class _ProductAddState extends State<ProductAdd> {
  final _formKey = GlobalKey<FormState>();
  final _productController = TextEditingController();
  final _categoryController = TextEditingController();
  final _stockController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _supplierController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text("Add Product"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Center(
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5)),
              ],
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextFormField(
                       controller: _productController,
                        decoration: const InputDecoration(
                          labelText: "Product Name",
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value!.isEmpty) {
                            return 'Please enter product name';
                          }
                          return null;
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextFormField(
                        controller: _categoryController,
                        decoration: const InputDecoration(
                          labelText: "Category",
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value!.isEmpty) {
                            return 'Please enter category';
                          }
                          return null;
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextFormField(
                        controller: _stockController,
                        decoration: const InputDecoration(
                          labelText: "Stock",
                          border: OutlineInputBorder(),
                          suffixText: "kg",
                        ),
                        validator: (value) {
                          if (value!.isEmpty) {
                            return 'Please enter stock';
                          }
                          else if(!RegExp(r'^[0-9]+$').hasMatch(value)) {
                            return 'Please enter a valid stock number';
                          }
                          return null;
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: "Price",
                          border: OutlineInputBorder(),
                          prefixText: "₹ ",
                          suffixText: "per kg",
                        ),
                        validator: (value) {
                          if (value!.isEmpty) {
                            return 'Please enter price';
                          }
                          else if(!RegExp(r'^[0-9]+$').hasMatch(value)) {
                            return 'Please enter a valid price';
                          }
                          return null;
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: "Description",
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value!.isEmpty) {
                            return 'Please enter description';
                          }
                          return null;
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextFormField(
                        controller: _supplierController,
                        decoration: const InputDecoration(
                          labelText: "Supplier",
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value!.isEmpty) {
                            return 'Please enter supplier name';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // just go back
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300]),
                          child: const Text("Cancel", style: TextStyle(color: Colors.black)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                                Fluttertoast.showToast(
                                  msg: "Product Saved",
                                  toastLength: Toast.LENGTH_SHORT,
                                  gravity: ToastGravity.BOTTOM,
                                  backgroundColor: Colors.black,
                                  textColor: Colors.white,
                                  fontSize: 16.0
                                );
                                FirebaseFirestore.instance.collection('products').add({
                                  'productName': _productController.text,
                                  'category': _categoryController.text,
                                  'stock': int.parse(_stockController.text),
                                  'price': double.parse(_priceController.text),
                                  'description': _descriptionController.text,
                                  'supplier': _supplierController.text,
                                }).then((value) {
                                  Navigator.pop(context); // go back after saving
                                }).catchError((error) {
                                  Fluttertoast.showToast(
                                    msg: "Failed to save product: $error",
                                    toastLength: Toast.LENGTH_SHORT,
                                    gravity: ToastGravity.BOTTOM,
                                    backgroundColor: Colors.red,
                                    textColor: Colors.white,
                                    fontSize: 16.0
                                  );
                                });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: Text("Save Product", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
    );
  }
  }