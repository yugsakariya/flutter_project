import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: TransactionScreen(),
  ));
}

class TransactionScreen extends StatelessWidget {
  final List<Map<String, dynamic>> transactions = [
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
    {
      'product': 'Bluetooth Mouse',
      'qty': 25,
      'unitPrice': 20.00,
      'total': 500.00,
      'date': '2024-06-18',
      'party': 'Tech Innovations Inc.',
      'type': 'Purchase',
      'status': 'Paid',
    },
    {
      'product': 'USB-C Multiport Adapter',
      'qty': 15,
      'unitPrice': 30.00,
      'total': 450.00,
      'date': '2024-06-17',
      'party': 'Alice Brown (Customer)',
      'type': 'Sale',
      'status': 'Paid',
    },
    {
      'product': 'Portable SSD 1TB',
      'qty': 8,
      'unitPrice': 90.00,
      'total': 720.00,
      'date': '2024-06-16',
      'party': 'Local Parts Ltd.',
      'type': 'Purchase',
      'status': 'Due',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF6F6F6),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Add your transaction form logic here
        },
        label: Icon(Icons.add),
        //icon: Icon(Icons.add),
        backgroundColor: Colors.deepPurple,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Transactions',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search transactions...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    return Card(
                      elevation: 1,
                      margin: EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Row (Product Name & Type)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      tx['type'] == 'Purchase'
                                          ? Icons.trending_up
                                          : Icons.trending_down,
                                      color: tx['type'] == 'Purchase'
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      tx['product'],
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: tx['type'] == 'Purchase'
                                        ? Colors.purple.shade100
                                        : Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    tx['type'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: tx['type'] == 'Purchase'
                                          ? Colors.purple
                                          : Colors.orange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),

                            // Details
                            Row(
                              children: [
                                Icon(Icons.format_list_numbered, size: 18),
                                SizedBox(width: 5),
                                Text("Qty: ${tx['qty']}"),
                              ],
                            ),
                            Row(
                              children: [
                                Icon(Icons.attach_money, size: 18),
                                SizedBox(width: 5),
                                Text("Unit Price: \$${tx['unitPrice']}"),
                              ],
                            ),
                            Row(
                              children: [
                                Icon(Icons.money, size: 18),
                                SizedBox(width: 5),
                                Text("Total: \$${tx['total']}"),
                              ],
                            ),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 18),
                                SizedBox(width: 5),
                                Text("Date: ${tx['date']}"),
                              ],
                            ),
                            Row(
                              children: [
                                Icon(Icons.local_offer, size: 18),
                                SizedBox(width: 5),
                                Text("Party: ${tx['party']}"),
                              ],
                            ),

                            SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: tx['status'] == 'Paid'
                                      ? Colors.green.shade100
                                      : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  tx['status'],
                                  style: TextStyle(
                                    color: tx['status'] == 'Paid'
                                        ? Colors.green
                                        : Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                          ],
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
