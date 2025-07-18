import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_project/Dashboard.dart';
import 'package:flutter_project/Transaction.dart';
import 'package:flutter_project/Stocks.dart';
import 'package:flutter_project/firebase_options.dart';
import 'package:flutter_project/login.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;
  ConnectionStatus _connectionStatus = ConnectionStatus.unknown;
  late final ConnectivityManager _connectivityManager;
  StreamSubscription<ConnectionStatus>? _connectionSubscription;
  Timer? _autoCheckTimer;

  @override
  void initState() {
    super.initState();
    _connectivityManager = ConnectivityManager();
    _connectivityManager.initialize();
    _connectionSubscription = _connectivityManager.connectionStream.listen((status) {
      if (mounted) {
        setState(() {
          _connectionStatus = status;
        });
      }
    });
    _connectionStatus = _connectivityManager.currentStatus;
    // Auto check every 100ms
    _autoCheckTimer = Timer.periodic(Duration(milliseconds: 100), (_) {
      _connectivityManager.forceCheckConnection();
    });
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _connectivityManager.dispose();
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  void _goToDashboard() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = <Widget>[
      Dashboard(onTabChange: (int idx) => setState(() => _selectedIndex = idx)),
      StockScreen(goToDashboard: _goToDashboard),
      TransactionScreen(goToDashboard: _goToDashboard),
    ];
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Stack(
          children: [
            _pages[_selectedIndex],
            if (_connectionStatus != ConnectionStatus.connected)
              Positioned.fill(
                child: ConnectionStatusWidget(
                  status: _connectionStatus,
                  onRetry: _connectivityManager.checkConnection,
                ),
              ),
          ],
        ),
        bottomNavigationBar: _connectionStatus == ConnectionStatus.connected
            ? BottomNavigationBar(
                items: const <BottomNavigationBarItem>[
                  BottomNavigationBarItem(
                    icon: Icon(Icons.dashboard),
                    label: 'Dashboard',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.inventory),
                    label: 'Stocks',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.swap_horiz),
                    label: 'Transactions',
                  ),
                ],
                currentIndex: _selectedIndex,
                selectedItemColor: Colors.indigo,
                onTap: _onItemTapped,
              )
            : null,
      ),
    );
  }
}

// --- Connectivity Manager ---
enum ConnectionStatus {
  unknown,
  connected,
  noConnectivity,
  noInternet,
}

class ConnectivityManager {
  static final ConnectivityManager _instance = ConnectivityManager._internal();
  factory ConnectivityManager() => _instance;
  ConnectivityManager._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _internetCheckTimer;
  final StreamController<ConnectionStatus> _connectionController =
      StreamController<ConnectionStatus>.broadcast();

  Stream<ConnectionStatus> get connectionStream => _connectionController.stream;
  ConnectionStatus _currentStatus = ConnectionStatus.unknown;
  ConnectionStatus get currentStatus => _currentStatus;

  final String _testUrl = 'google.com';

  Future<void> initialize() async {
    final initialResult = await _connectivity.checkConnectivity();
    await _updateConnectionStatus(initialResult);
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<bool> hasInternetAccess() async {
    try {
      final result = await InternetAddress.lookup(_testUrl);
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> results) async {
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    ConnectionStatus newStatus;
    if (result == ConnectivityResult.none) {
      newStatus = ConnectionStatus.noConnectivity;
    } else {
      final hasInternet = await hasInternetAccess();
      if (hasInternet) {
        newStatus = ConnectionStatus.connected;
      } else {
        newStatus = ConnectionStatus.noInternet;
      }
    }
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      _connectionController.add(newStatus);
    }
  }

  Future<void> checkConnection() async {
    final result = await _connectivity.checkConnectivity();
    await _updateConnectionStatus(result);
  }

  Future<void> forceCheckConnection() async {
    final result = await _connectivity.checkConnectivity();
    ConnectionStatus newStatus;
    final connectivity = result.isNotEmpty ? result.first : ConnectivityResult.none;
    if (connectivity == ConnectivityResult.none) {
      newStatus = ConnectionStatus.noConnectivity;
    } else {
      final hasInternet = await hasInternetAccess();
      if (hasInternet) {
        newStatus = ConnectionStatus.connected;
      } else {
        newStatus = ConnectionStatus.noInternet;
      }
    }
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      _connectionController.add(newStatus);
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionController.close();
  }
}

// --- Overlay Widget ---
class ConnectionStatusWidget extends StatelessWidget {
  final ConnectionStatus status;
  final VoidCallback? onRetry;
  const ConnectionStatusWidget({Key? key, required this.status, this.onRetry}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (status == ConnectionStatus.connected) {
      return SizedBox.shrink();
    }
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getIcon(), color: Colors.grey, size: 100),
            SizedBox(height: 24),
            Text(
              _getTitle(),
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            SizedBox(height: 12),
            Text(
              _getDescription(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRetry,
                child: Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (status) {
      case ConnectionStatus.noConnectivity:
        return Icons.wifi_off;
      case ConnectionStatus.noInternet:
        return Icons.cloud_off;
      default:
        return Icons.signal_wifi_off;
    }
  }

  String _getTitle() {
    switch (status) {
      case ConnectionStatus.noConnectivity:
        return 'Check your network';
      case ConnectionStatus.noInternet:
        return 'No internet access';
      default:
        return 'Connection issue';
    }
  }

  String _getDescription() {
    switch (status) {
      case ConnectionStatus.noConnectivity:
        return 'No connection available.';
      case ConnectionStatus.noInternet:
        return 'You are connected to a network, but there is no internet.';
      default:
        return 'Unable to connect to the internet.';  
    }
  }
}