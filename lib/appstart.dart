import 'package:flutter/material.dart';
import 'package:flutter_project/Dashboard.dart';
import 'package:flutter_project/ProductList.dart';
import 'package:flutter_project/Transaction.dart';

class Appstart extends StatefulWidget {
  const Appstart({super.key});

  @override
  State<Appstart> createState() => _AppstartState();
}

class _AppstartState extends State<Appstart> {
  int _selectedIndex = 0;
  final List<Widget>pages = [
    Dashboard(),
    ProductList(),
    TransactionScreen(),
    // Center(child: Text('Billing Page')),
    // Center(child: Text('Suppliers Page')),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        fixedColor: Colors.indigo,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          // BottomNavigationBarItem(
          //   icon: Icon(Icons.payment),
          //   label: 'Billing',
          // ),
          // BottomNavigationBarItem(
          //   icon: Icon(Icons.people),
          //   label: 'Suppliers',
          // ),
        ],
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
