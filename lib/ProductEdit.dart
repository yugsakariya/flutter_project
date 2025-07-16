// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
//
// class ProductEdit extends StatefulWidget {
//   final String? docRef;
//   const ProductEdit({super.key, this.docRef});
//   @override
//   State<ProductEdit> createState() => _ProductEditState();
// }
//
// class _ProductEditState extends State<ProductEdit> {
//   final _formKey = GlobalKey<FormState>();
//   final _productNameController = TextEditingController();
//   final _categoryController = TextEditingController();
//   final _stockController = TextEditingController();
//   final _priceController = TextEditingController();
//   final _descriptionController = TextEditingController();
//   final _supplierController = TextEditingController();
//
//   bool _isLoading = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadProductData();
//   }
//   Future<void> _loadProductData() async {
//     try {
//       DocumentSnapshot docData = await FirebaseFirestore.instance
//           .collection('products')
//           .doc(widget.docRef)
//           .get();
//
//       if (docData.exists) {
//         _productNameController.text = docData["productName"] ?? '';
//         _categoryController.text = docData["category"] ?? '';
//         _stockController.text = docData["stock"]?.toString() ?? '';
//         _priceController.text = docData["price"]?.toString() ?? '';
//         _descriptionController.text = docData["description"] ?? '';
//         _supplierController.text = docData["supplier"] ?? '';
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error loading product data: $e')),
//       );
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
//   @override
//   void dispose() {
//     _productNameController.dispose();
//     _categoryController.dispose();
//     _stockController.dispose();
//     _priceController.dispose();
//     _descriptionController.dispose();
//     _supplierController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return Scaffold(
//         appBar: AppBar(
//           title: Text("Edit Product"),
//           backgroundColor: Colors.indigo,
//           foregroundColor: Colors.white,
//         ),
//         body: Center(child: CircularProgressIndicator()),
//       );
//     }
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Edit Product"),
//         backgroundColor: Colors.indigo,
//         foregroundColor: Colors.white,
//       ),
//       body: Center(
//         child: Container(
//           width: 380,
//           padding: const EdgeInsets.all(20),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: const [
//               BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5)),
//             ],
//           ),
//           child: SingleChildScrollView(
//             child: Form(
//               key: _formKey,
//               child: Column(
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.all(8.0),
//                     child: TextFormField(
//                       controller: _productNameController,
//                       decoration: const InputDecoration(
//                         labelText: "Product Name",
//                         border: OutlineInputBorder(),
//                       ),
//                       validator: (value) {
//                         if (value == null || value.isEmpty) {
//                           return 'Please enter product name';
//                         }
//                         return null;
//                       },
//                     ),
//                   ),
//                   Padding(
//                     padding: const EdgeInsets.all(8.0),
//                     child: TextFormField(
//                       controller: _categoryController,
//                       decoration: const InputDecoration(
//                         labelText: "Category",
//                         border: OutlineInputBorder(),
//                       ),
//                       validator: (value) {
//                         if (value == null || value.isEmpty) {
//                           return 'Please enter category';
//                         }
//                         return null;
//                       },
//                     ),
//                   ),
//                   Padding(
//                     padding: const EdgeInsets.all(8.0),
//                     child: TextFormField(
//                       controller: _stockController,
//                       keyboardType: TextInputType.number,
//                       decoration: const InputDecoration(
//                         labelText: "Stock",
//                         border: OutlineInputBorder(),
//                       ),
//                       validator: (value) {
//                         if (value == null || value.isEmpty) {
//                           return 'Please enter stock';
//                         }
//                         if (int.tryParse(value) == null) {
//                           return 'Please enter a valid number';
//                         }
//                         return null;
//                       },
//                     ),
//                   ),
//                   Padding(
//                     padding: const EdgeInsets.all(8.0),
//                     child: TextFormField(
//                       controller: _priceController,
//                       keyboardType: TextInputType.numberWithOptions(decimal: true),
//                       decoration: const InputDecoration(
//                         labelText: "Price",
//                         prefixText: "\$ ",
//                         border: OutlineInputBorder(),
//                       ),
//                       validator: (value) {
//                         if (value == null || value.isEmpty) {
//                           return 'Please enter price';
//                         }
//                         if (double.tryParse(value) == null) {
//                           return 'Please enter a valid price';
//                         }
//                         return null;
//                       },
//                     ),
//                   ),
//                   Padding(
//                     padding: const EdgeInsets.all(8.0),
//                     child: TextFormField(
//                       controller: _descriptionController,
//                       maxLines: 3,
//                       decoration: const InputDecoration(
//                         labelText: "Description",
//                         border: OutlineInputBorder(),
//                       ),
//                       validator: (value) {
//                         if (value == null || value.isEmpty) {
//                           return 'Please enter description';
//                         }
//                         return null;
//                       },
//                     ),
//                   ),
//                   Padding(
//                     padding: const EdgeInsets.all(8.0),
//                     child: TextFormField(
//                       controller: _supplierController,
//                       decoration: const InputDecoration(
//                         labelText: "Supplier",
//                         border: OutlineInputBorder(),
//                       ),
//                       validator: (value) {
//                         if (value == null || value.isEmpty) {
//                           return 'Please enter supplier';
//                         }
//                         return null;
//                       },
//                     ),
//                   ),
//                   SizedBox(height: 20),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.end,
//                     children: [
//                       ElevatedButton.icon(
//                         onPressed: () => Navigator.pop(context),
//                         icon: Icon(Icons.cancel, color: Colors.black),
//                         label: Text("Cancel", style: TextStyle(color: Colors.black)),
//                         style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300]),
//                       ),
//                       SizedBox(width: 10),
//                       ElevatedButton.icon(
//                         onPressed: () async {
//                           if (_formKey.currentState!.validate()) {
//                             try {
//                               await FirebaseFirestore.instance
//                                   .collection('products')
//                                   .doc(widget.docRef)
//                                   .update({
//                                 'productName': _productNameController.text,
//                                 'category': _categoryController.text,
//                                 'stock': int.parse(_stockController.text),
//                                 'price': double.parse(_priceController.text),
//                                 'description': _descriptionController.text,
//                                 'supplier': _supplierController.text,
//                               });
//                               ScaffoldMessenger.of(context).showSnackBar(
//                                 SnackBar(content: Text('Product updated successfully')),
//                               );
//                               Navigator.pop(context);
//                             } catch (e) {
//                               ScaffoldMessenger.of(context).showSnackBar(
//                                 SnackBar(content: Text('Error updating product: $e')),
//                               );
//                             }
//                           }
//                         },
//                         icon: const Icon(Icons.save),
//                         label: const Text("Save Changes"),
//                         style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
//                       ),
//                     ],
//                   )
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }