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

import 'BillScreen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyMainApp());
}

class MyMainApp extends StatelessWidget {
  const MyMainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Inventory Management',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // Set splash screen as initial route
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/auth': (context) => const AuthWrapper(),
        '/login': (context) => const Loginscreen(),
        '/main': (context) => const MyApp(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const MyApp();
        }
        return const Loginscreen();
      },
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

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
          .timeout(const Duration(seconds: 3));
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
          if (mounted) {
            setState(() => _isConnected = hasInternet);
          }
        });
      } else {
        if (mounted) {
          setState(() => _isConnected = false);
        }
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
    final List<Widget> pages = [
      Dashboard(onTabChange: (int idx) => setState(() => _selectedIndex = idx)),
      StockScreen(goToDashboard: _goToDashboard),
      TransactionScreen(goToDashboard: _goToDashboard),
      BillsScreen(goToDashboard: _goToDashboard),
    ];

    return Scaffold(
      body: _isConnected
          ? pages[_selectedIndex]
          : _buildNoConnectionScreen(),
      bottomNavigationBar: _isConnected ? _buildBottomNavBar() : null,
    );
  }

  Widget _buildNoConnectionScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off,
                color: Colors.red[400],
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                'No Internet Connection',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Please check your connection and try again',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _retryConnection,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
      items: const [
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
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long),
          label: 'Billing',
        ),
      ],
    );
  }
}