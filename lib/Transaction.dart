import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/TransactionUpdate.dart';
import 'package:flutter_project/Dashboard.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'TransactionAdd.dart';


class TransactionScreen extends StatefulWidget {
  final VoidCallback? goToDashboard;
  const TransactionScreen({super.key, this.goToDashboard});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}
class _TransactionScreenState extends State<TransactionScreen> {
  @override
  void initState() {
    super.initState();
    _typeController.text = 'Purchase'; // Default value
    _statusController.text = 'Paid'; // Default value
  }
  final _productController = TextEditingController();
  final _typeController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  // final _totalController = TextEditingController();
  final _dateController = TextEditingController();
  final _partyController = TextEditingController();
  final _statusController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  void _updateTransaction(String docId){
    showDialog(context: context, builder: (context) {
      return Transactionupdate(docRef: docId);
    });
  }
  void _deleteTransaction(String docId) {
    FirebaseFirestore.instance.collection('transactions').doc(docId).delete().then((_)=> Navigator.pop(context)).catchError((error) {
      Fluttertoast.showToast(
          msg: "Failed to delete transaction: $error",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0
      );
    });
  }
  void _showDeleteDialog(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Transaction"),
        content: Text("Are you sure you want to delete this transaction?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          TextButton(onPressed:() {
            _deleteTransaction(docId);
          },
              child: Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  // void _openFilterSheet() {
  //   showModalBottomSheet(
  //     context: context,
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
  //     builder: (context) {
  //       return Padding(
  //         padding: const EdgeInsets.all(16),
  //         child: SingleChildScrollView(
  //           child: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               Text("Filter Transactions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
  //               SizedBox(height: 16),
  //               DropdownButtonFormField<String>(
  //                 value: selectedType,
  //                 items: ['All', 'Purchase', 'Sale']
  //                     .map((e) => DropdownMenuItem(value: e, child: Text(e)))
  //                     .toList(),
  //                 onChanged: (value) => setState(() => selectedType = value!),
  //                 decoration: InputDecoration(labelText: 'Type'),
  //               ),
  //               SizedBox(height: 10),
  //               DropdownButtonFormField<String>(
  //                 value: selectedStatus,
  //                 items: ['All', 'Paid', 'Due']
  //                     .map((e) => DropdownMenuItem(value: e, child: Text(e)))
  //                     .toList(),
  //                 onChanged: (value) => setState(() => selectedStatus = value!),
  //                 decoration: InputDecoration(labelText: 'Status'),
  //               ),
  //               SizedBox(height: 10),
  //               Row(
  //                 children: [
  //                   Expanded(
  //                     child: InkWell(
  //                       onTap: () => _pickDate(isFrom: true),
  //                       child: InputDecorator(
  //                         decoration: InputDecoration(labelText: 'From Date'),
  //                         child: Text(fromDate == null
  //                             ? 'Select'
  //                             : DateFormat('yyyy-MM-dd').format(fromDate!)),
  //                       ),
  //                     ),
  //                   ),
  //                   SizedBox(width: 10),
  //                   Expanded(
  //                     child: InkWell(
  //                       onTap: () => _pickDate(isFrom: false),
  //                       child: InputDecorator(
  //                         decoration: InputDecoration(labelText: 'To Date'),
  //                         child: Text(toDate == null
  //                             ? 'Select'
  //                             : DateFormat('yyyy-MM-dd').format(toDate!)),
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //               SizedBox(height: 20),
  //               ElevatedButton(
  //                 onPressed: () {
  //                   Navigator.pop(context);
  //                   _applyFilters();
  //                 },
  //                 child: Text("Apply Filter"),
  //               ),
  //             ],
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }
  final _searchController = TextEditingController();
  String _searchQuery='';
  Stream<QuerySnapshot> _getTransactionStream(){
    if(_searchQuery.isEmpty){
      return FirebaseFirestore.instance.collection('transactions').snapshots();
    }
    else{
      return FirebaseFirestore.instance
          .collection('transactions')
          .where('product',isGreaterThanOrEqualTo: _searchQuery)
          .where('product', isLessThanOrEqualTo: '$_searchQuery\uf8ff')
          .snapshots();
    }
  }
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (widget.goToDashboard != null) {
          widget.goToDashboard!();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Color(0xFFF6F6F6),
        appBar: AppBar(
          title: Text("Transactions"),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          // Remove custom leading button
        ),
        floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.indigo,
            child: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              showDialog(context: context, builder: (context) {
                return AlertDialog(
                  title: Text("Add Transaction"),
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
                            ),
                            validator: (value) {
                              if (value!.isEmpty) {
                                return "Please enter quantity";
                              }
                              if (int.tryParse(value) == null){
                                return "Please enter correct quantity";
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
                              if (double.tryParse(value) == null){
                                return "Please enter correct unit price";
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
                                        'unitPrice': double.parse(
                                            _unitPriceController.text),
                                        'party': _partyController.text,
                                        'date': DateFormat('dd-MM-yyyy').parse(
                                            _dateController.text),
                                        'type': _typeController.text,
                                        'status': _statusController.text,
                                        'timestamp': DateTime.now(),
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
                  ),
                );
              });
            }
        ),
        body:  Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [

              SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search transactions...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value){
                  setState(() {
                    _searchQuery = value;
                  });
                  print(_searchQuery);
                },
              ),
              SizedBox(height: 16),
              Expanded(
                  child: StreamBuilder<QuerySnapshot>(stream: _getTransactionStream(),
                    builder: (context,snapshot){
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      else if (snapshot.hasError) {
                        return Center(child: Text("Error: ${snapshot.error}"));
                      }
                      else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(child: Text("No transactions found"));
                      }
                      else{
                        return ListView.builder(
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            final doc = snapshot.data!.docs[index];
                            return Card(
                              elevation: 1,
                              margin: EdgeInsets.only(bottom: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment
                                          .spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              doc['type'] == 'Purchase'
                                                  ? Icons.trending_up
                                                  : Icons.trending_down,
                                              color: doc['type'] == 'Purchase'
                                                  ? Colors
                                                  .green
                                                  : Colors.red,
                                            ),
                                            SizedBox(height: 12),
                                            SizedBox(width: 6),
                                            Text(doc['product'],
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16)),
                                          ],
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color:
                                            doc['type'] == 'Purchase'
                                                ? Colors.purple.shade100
                                                : Colors.orange.shade100,
                                            borderRadius: BorderRadius.circular(
                                                12),
                                          ),
                                          child: Text(doc['type'],
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: doc['type'] == 'Purchase'
                                                      ? Colors.purple
                                                      : Colors.orange)),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Row(children: [
                                      Icon(Icons.format_list_numbered, size: 18),
                                      SizedBox(width: 5),
                                      Text("Qty: ${doc['quantity']}")
                                    ]),
                                    Row(children: [
                                      Icon(Icons.attach_money, size: 18),
                                      SizedBox(width: 5),
                                      Text("Unit Price: \₹${doc['unitPrice']}")
                                    ]),
                                    // Row(children: [
                                    //   Icon(Icons.money, size: 18),
                                    //   SizedBox(width: 5),
                                    //   Text("Total: \₹${doc['total']}")
                                    // ]),
                                    Row(children: [
                                      Icon(Icons.calendar_today, size: 18),
                                      SizedBox(width: 5),
                                      Text("Date: ${doc['date'].toDate().day} ${DateFormat('MMM').format(doc['date'].toDate())}.to ${doc['date'].toDate().year}")
                                    ]),
                                    Row(children: [
                                      Icon(Icons.local_offer, size: 18),
                                      SizedBox(width: 5),
                                      Text("Supplier: ${doc['party']}")
                                    ]),
                                    SizedBox(height: 6),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: doc['status'] == 'Paid'
                                            ? Colors.green.shade100
                                            : Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(doc['status'],
                                          style: TextStyle(
                                              color: doc['status'] == 'Paid'
                                                  ? Colors.green
                                                  : Colors.orange,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(onPressed: () {
                                          _updateTransaction(doc.id);
                                        },
                                          icon: Icon(Icons.edit),
                                          tooltip: "Update Transaction",
                                        ),
                                        IconButton(onPressed: () {
                                          _showDeleteDialog(doc.id);
                                        },
                                          icon: Icon(Icons.delete),
                                          tooltip: "Delete Transaction",
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }
                    },
                  )
              ),
            ],
          ),
        ),
      ),
    );
  }
}