import 'package:flutter/material.dart';
import 'package:flutter_project/Dashboard.dart';
import 'package:flutter_project/Stocks.dart';
import 'package:flutter_project/Transaction.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class Appstart extends StatefulWidget {
  const Appstart({super.key});

  @override
  State<Appstart> createState() => _AppstartState();
}

class _AppstartState extends State<Appstart> {
  bool isConnected = false;
  String connectionType = 'None';
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  int _selectedIndex = 0;

  final List<Widget> pages = [
    Dashboard(),
    StockScreen(),
    TransactionScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _listenToConnectivityChanges();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      _updateConnectionStatus(connectivityResults);
    } catch (e) {
      print('Error checking connectivity: $e');
      setState(() {
        isConnected = false;
        connectionType = 'Error';
      });
    }
  }

  void _listenToConnectivityChanges() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
          (List<ConnectivityResult> results) {
        _updateConnectionStatus(results);
      },
      onError: (error) {
        print('Connectivity stream error: $error');
      },
    );
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    setState(() {
      // Check if any connection is available
      if (results.contains(ConnectivityResult.none) && results.length == 1) {
        isConnected = false;
        connectionType = 'No Connection';
      } else {
        isConnected = true;
        // Prioritize connection types (WiFi > Mobile > Others)
        if (results.contains(ConnectivityResult.wifi)) {
          connectionType = 'WiFi';
        } else if (results.contains(ConnectivityResult.mobile)) {
          connectionType = 'Mobile Data';
        } else if (results.contains(ConnectivityResult.ethernet)) {
          connectionType = 'Ethernet';
        } else if (results.contains(ConnectivityResult.vpn)) {
          connectionType = 'VPN';
        } else if (results.contains(ConnectivityResult.bluetooth)) {
          connectionType = 'Bluetooth';
        } else if (results.contains(ConnectivityResult.other)) {
          connectionType = 'Other';
        } else {
          connectionType = 'Multiple Connections';
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('My App'),
            Row(
              children: [
                Icon(
                  isConnected ? Icons.wifi : Icons.wifi_off,
                  color: isConnected ? Colors.green : Colors.red,
                ),
                SizedBox(width: 8),
                Text(
                  connectionType,
                  style: TextStyle(
                    fontSize: 12,
                    color: isConnected ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Connection status banner
          if (!isConnected)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(8),
              color: Colors.red,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'No Internet Connection',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          Expanded(child: pages[_selectedIndex]),
        ],
      ),
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