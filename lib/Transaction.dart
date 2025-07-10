import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'TransactionAdd.dart';

class TransactionScreen extends StatefulWidget {
  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  List<Map<String, dynamic>> transactions = [
    {
      'product': 'Gaming Laptop Z5',
      'qty': 10,
      'unitPrice': 1200.00,
      'total': 12000.00,
      'date': '2024-06-20',
      'party': 'Global Supply Co.',
      'type': 'Purchase',
      'status': 'Paid',
    },
    {
      'product': 'Ergonomic Keyboard',
      'qty': 5,
      'unitPrice': 75.00,
      'total': 375.00,
      'date': '2024-06-19',
      'party': 'John Doe (Customer)',
      'type': 'Sale',
      'status': 'Due',
    },
  ];

  List<Map<String, dynamic>> filteredTransactions = [];
  TextEditingController searchController = TextEditingController();

  String selectedType = 'All';
  String selectedStatus = 'All';
  DateTime? fromDate;
  DateTime? toDate;

  @override
  void initState() {
    super.initState();
    filteredTransactions = List.from(transactions);
    searchController.addListener(_applyFilters);
  }

  void _applyFilters() {
    String query = searchController.text.toLowerCase();

    setState(() {
      filteredTransactions = transactions.where((tx) {
        bool matchesQuery = tx['product'].toLowerCase().contains(query) ||
            tx['party'].toLowerCase().contains(query) ||
            tx['type'].toLowerCase().contains(query) ||
            tx['status'].toLowerCase().contains(query) ||
            tx['date'].toLowerCase().contains(query);

        bool matchesType = selectedType == 'All' || tx['type'] == selectedType;
        bool matchesStatus = selectedStatus == 'All' || tx['status'] == selectedStatus;

        DateTime txDate = DateTime.tryParse(tx['date']) ?? DateTime(2000);
        bool matchesFromDate = fromDate == null || txDate.isAfter(fromDate!.subtract(Duration(days: 1)));
        bool matchesToDate = toDate == null || txDate.isBefore(toDate!.add(Duration(days: 1)));

        return matchesQuery && matchesType && matchesStatus && matchesFromDate && matchesToDate;
      }).toList();
    });
  }

  void _navigateToAdd() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TransactionAdd()),
    );
    if (result != null) {
      setState(() {
        transactions.insert(0, result);
        _applyFilters();
      });
    }
  }

  void _navigateToUpdate(int index) async {
    final tx = filteredTransactions[index];
    final realIndex = transactions.indexOf(tx);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionAdd(transaction: tx),
      ),
    );
    if (result != null) {
      setState(() {
        transactions[realIndex] = result;
        _applyFilters();
      });
    }
  }

  void _deleteTransaction(int index) {
    final tx = filteredTransactions[index];
    final realIndex = transactions.indexOf(tx);
    setState(() {
      transactions.removeAt(realIndex);
      _applyFilters();
    });
  }

  void _showDeleteDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Transaction"),
        content: Text("Are you sure you want to delete this transaction?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteTransaction(index);
              },
              child: Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Filter Transactions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  items: ['All', 'Purchase', 'Sale']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (value) => setState(() => selectedType = value!),
                  decoration: InputDecoration(labelText: 'Type'),
                ),
                SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  items: ['All', 'Paid', 'Due']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (value) => setState(() => selectedStatus = value!),
                  decoration: InputDecoration(labelText: 'Status'),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(isFrom: true),
                        child: InputDecorator(
                          decoration: InputDecoration(labelText: 'From Date'),
                          child: Text(fromDate == null
                              ? 'Select'
                              : DateFormat('yyyy-MM-dd').format(fromDate!)),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(isFrom: false),
                        child: InputDecorator(
                          decoration: InputDecoration(labelText: 'To Date'),
                          child: Text(toDate == null
                              ? 'Select'
                              : DateFormat('yyyy-MM-dd').format(toDate!)),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _applyFilters();
                  },
                  child: Text("Apply Filter"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDate({required bool isFrom}) async {
    DateTime initial = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          fromDate = picked;
        } else {
          toDate = picked;
        }
      });
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF6F6F6),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAdd,
        label: Icon(Icons.add),
        backgroundColor: Colors.deepPurple,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Transactions',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: Icon(Icons.filter_alt_outlined),
                    onPressed: _openFilterSheet,
                  )
                ],
              ),
              SizedBox(height: 16),
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search transactions...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              SizedBox(height: 16),
              Expanded(
                child: filteredTransactions.isEmpty
                    ? Center(child: Text("No transactions found."))
                    : ListView.builder(
                  itemCount: filteredTransactions.length,
                  itemBuilder: (context, index) {
                    final tx = filteredTransactions[index];
                    return GestureDetector(
                      onTap: () => _navigateToUpdate(index),
                      onLongPress: () => _showDeleteDialog(index),
                      child: Card(
                        elevation: 1,
                        margin: EdgeInsets.only(bottom: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        tx['type'] == 'Purchase'
                                            ? Icons.trending_up
                                            : Icons.trending_down,
                                        color: tx['type'] == 'Purchase' ? Colors.green : Colors.red,
                                      ),
                                      SizedBox(width: 6),
                                      Text(tx['product'],
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 16)),
                                    ],
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: tx['type'] == 'Purchase'
                                          ? Colors.purple.shade100
                                          : Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(tx['type'],
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: tx['type'] == 'Purchase'
                                                ? Colors.purple
                                                : Colors.orange)),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(children: [
                                Icon(Icons.format_list_numbered, size: 18),
                                SizedBox(width: 5),
                                Text("Qty: ${tx['qty']}")
                              ]),
                              Row(children: [
                                Icon(Icons.attach_money, size: 18),
                                SizedBox(width: 5),
                                Text("Unit Price: \$${tx['unitPrice']}")
                              ]),
                              Row(children: [
                                Icon(Icons.money, size: 18),
                                SizedBox(width: 5),
                                Text("Total: \$${tx['total']}")
                              ]),
                              Row(children: [
                                Icon(Icons.calendar_today, size: 18),
                                SizedBox(width: 5),
                                Text("Date: ${tx['date']}")
                              ]),
                              Row(children: [
                                Icon(Icons.local_offer, size: 18),
                                SizedBox(width: 5),
                                Text("Party: ${tx['party']}")
                              ]),
                              SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: tx['status'] == 'Paid'
                                        ? Colors.green.shade100
                                        : Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(tx['status'],
                                      style: TextStyle(
                                          color: tx['status'] == 'Paid'
                                              ? Colors.green
                                              : Colors.orange,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


