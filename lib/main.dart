import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_project/Dashboard.dart';
import 'package:flutter_project/Transaction.dart';
import 'package:flutter_project/Stocks.dart';
import 'package:flutter_project/firebase_options.dart';
import 'package:flutter_project/login.dart';
import 'package:flutter_project/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AuthWrapper(),
  ));
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SplashScreen();
        }
        if (snapshot.hasData && snapshot.data != null) {
          return MyApp();
        }
        return Loginscreen();
      },
    );
  }
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;
  bool _isConnected = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _startConnectivityListener();
  }

  void _checkConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      final hasConnection = result.first != ConnectivityResult.none;

      if (hasConnection) {
        // Simple internet check
        final hasInternet = await _hasInternetConnection();
        setState(() => _isConnected = hasInternet);
      } else {
        setState(() => _isConnected = false);
      }
    } catch (e) {
      setState(() => _isConnected = false);
    }
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _startConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final hasConnection = result.first != ConnectivityResult.none;
      if (hasConnection) {
        _hasInternetConnection().then((hasInternet) {
          setState(() => _isConnected = hasInternet);
        });
      } else {
        setState(() => _isConnected = false);
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _goToDashboard() {
    setState(() => _selectedIndex = 0);
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _retryConnection() {
    _checkConnectivity();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      Dashboard(onTabChange: (int idx) => setState(() => _selectedIndex = idx)),
      StockScreen(goToDashboard: _goToDashboard),
      TransactionScreen(goToDashboard: _goToDashboard),
    ];

    return Scaffold(
      body: _isConnected
          ? _pages[_selectedIndex]
          : _buildNoConnectionScreen(),
      bottomNavigationBar: _isConnected ? _buildBottomNavBar() : null,
    );
  }

  Widget _buildNoConnectionScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off,
                color: Colors.red[400],
                size: 80,
              ),
              SizedBox(height: 24),
              Text(
                'No Internet Connection',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'Please check your connection and try again',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _retryConnection,
                icon: Icon(Icons.refresh),
                label: Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      elevation: 8,
      currentIndex: _selectedIndex,
      selectedItemColor: Colors.indigo,
      unselectedItemColor: Colors.grey[600],
      onTap: _onItemTapped,
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2),
          label: 'Stocks',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.swap_horiz),
          label: 'Transactions',
        ),
      ],
    );
  }
}