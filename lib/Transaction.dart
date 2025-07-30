import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/TransactionAdd.dart';
import 'package:flutter_project/TransactionUpdate.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';


class TransactionScreen extends StatefulWidget {
  final VoidCallback? goToDashboard;
  const TransactionScreen({super.key, this.goToDashboard});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}
class _TransactionScreenState extends State<TransactionScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
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

  void _updateTransaction(String docId){
    showDialog(context: context, builder: (context) {
      return Transactionupdate(docRef: docId);
    });
  }
  void _deleteTransaction(String docId) async {
    try {
      // First, get the transaction document to access its data
      DocumentSnapshot transactionDoc = await FirebaseFirestore.instance
          .collection('transactions')
          .doc(docId)
          .get();

      if (!transactionDoc.exists) {
        Fluttertoast.showToast(
            msg: "Transaction not found",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0
        );
        return;
      }

      // Get transaction data
      final transactionData = transactionDoc.data() as Map<String, dynamic>;
      final String product = transactionData['product'];
      final String type = transactionData['type'];
      final int quantity = transactionData['quantity'];

      // Query the stocks collection to find the document with matching product name
      QuerySnapshot stockQuery = await FirebaseFirestore.instance
          .collection('stocks')
          .where('user', isEqualTo: user!.uid)
          .where('product', isEqualTo: product) // Assuming the field name is 'product'
          .limit(1)
          .get();

      if (stockQuery.docs.isEmpty) {
        Fluttertoast.showToast(
            msg: "Stock record not found for product: $product",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.orange,
            textColor: Colors.white,
            fontSize: 16.0
        );
        // Still delete the transaction even if stock is not found
        await FirebaseFirestore.instance.collection('transactions').doc(docId).delete();
        Navigator.of(context, rootNavigator: true).pop();
        return;
      }

      // Get the stock document reference
      DocumentSnapshot stockDoc = stockQuery.docs.first;
      String stockDocId = stockDoc.id;

      // Use a batch to ensure both operations succeed or fail together
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // Delete the transaction
      batch.delete(FirebaseFirestore.instance.collection('transactions').doc(docId));

      // Update stock based on transaction type
      DocumentReference stockRef = FirebaseFirestore.instance
          .collection('stocks')
          .doc(stockDocId);

      if (type == 'Purchase') {
        // If it was a purchase, we need to subtract the quantity from stock
        // (reversing the original addition)
        batch.update(stockRef, {
          'quantity': FieldValue.increment(-quantity),
        });
      } else if (type == 'Sale') {
        // If it was a sale, we need to add the quantity back to stock
        // (reversing the original subtraction)
        batch.update(stockRef, {
          'quantity': FieldValue.increment(quantity),
        });
      }

      // Execute the batch
      await batch.commit();

      // Check if there are any remaining transactions for this product
      QuerySnapshot remainingTransactions = await FirebaseFirestore.instance
          .collection('transactions')
          .where('product', isEqualTo: product)
          .get();

      if (remainingTransactions.docs.isEmpty) {
        // No transactions left for this product, delete the stock document
        await FirebaseFirestore.instance.collection('stocks').doc(stockDocId).delete();
      }

      Navigator.of(context, rootNavigator: true).pop();

      Fluttertoast.showToast(
          msg: "Transaction deleted and stock updated successfully",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0
      );

    } catch (error) {
      Fluttertoast.showToast(
          msg: "Failed to delete transaction: $error",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0
      );
    }
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

  final _searchController = TextEditingController();
  String _searchQuery='';
  Stream<QuerySnapshot> _getTransactionStream(){
    if(_searchQuery.isEmpty){
      return FirebaseFirestore.instance.collection('transactions').where('user',isEqualTo: user!.uid).snapshots();
    }
    else{
      return FirebaseFirestore.instance
          .collection('transactions').where('user',isEqualTo: user!.uid)
          .where('product',isGreaterThanOrEqualTo: _searchQuery.toLowerCase())
          .where('product', isLessThanOrEqualTo: '$_searchQuery\uf8ff'.toLowerCase())
          .snapshots();
    }
  }
  @override
  void dispose(){
    _productController.dispose();
    _typeController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _dateController.dispose();
    _partyController.dispose();
    _statusController.dispose();
    super.dispose();
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
                return Transactionadd();
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
                                            Text(_capitalizeFirstLetter(doc['product']),
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
                                      Text("Date: ${doc['date'].toDate().day} ${DateFormat('MMM').format(doc['date'].toDate())} ${doc['date'].toDate().year}")
                                    ]),
                                    Row(children: [
                                      Icon(Icons.local_offer, size: 18),
                                      SizedBox(width: 5),
                                      Text("${_checktype(doc['type'])}: ${doc['party']}")
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
 String? _checktype(String type){
    if (type == "Purchase"){
      return "Supplier";
    }
    else if (type == "Sale"){
      return "Customer";
    }
    return null;
 }
  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}