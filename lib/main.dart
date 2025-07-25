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
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show splash screen while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SplashScreen();
        }

        // If user is logged in, show main app
        if (snapshot.hasData && snapshot.data != null) {
          return MyApp();
        }

        // If user is not logged in, show login screen
        return Loginscreen();
      },
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  ConnectionStatus _connectionStatus = ConnectionStatus.unknown;
  late final ConnectivityManager _connectivityManager;
  StreamSubscription<ConnectionStatus>? _connectionSubscription;
  Timer? _realTimeCheckTimer;
  Timer? _internetCheckTimer;
  bool _isRetrying = false;
  bool _initialCheckComplete = false; // Add this flag

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivityManager = ConnectivityManager();
    _initializeConnectivity();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground, check immediately
      _connectivityManager.forceCheckConnection();
      _startRealTimeChecking();
    } else if (state == AppLifecycleState.paused) {
      // App went to background, reduce frequency
      _stopRealTimeChecking();
    }
  }

  Future<void> _initializeConnectivity() async {
    await _connectivityManager.initialize();
    if (mounted) {
      _connectionSubscription = _connectivityManager.connectionStream.listen((status) {
        if (mounted) {
          setState(() {
            _connectionStatus = status;
            if (!_initialCheckComplete) {
              _initialCheckComplete = true; // Mark initial check as complete
            }
          });

          // If connection is restored, do an immediate internet check
          if (status == ConnectionStatus.connected) {
            _startRealTimeChecking();
          } else {
            _stopRealTimeChecking();
          }
        }
      });

      setState(() {
        _connectionStatus = _connectivityManager.currentStatus;
      });

      // Give a brief moment for initial connectivity check, then mark as complete
      Timer(Duration(milliseconds: 1000), () {
        if (mounted && !_initialCheckComplete) {
          setState(() {
            _initialCheckComplete = true;
          });
        }
      });

      _startRealTimeChecking();
    }
  }

  void _startRealTimeChecking() {
    _stopRealTimeChecking(); // Clear any existing timers

    // Real-time connectivity check every 2 seconds
    _realTimeCheckTimer = Timer.periodic(Duration(seconds: 2), (_) {
      if (mounted) {
        _connectivityManager.checkConnection();
      }
    });

    // More frequent internet access check every 5 seconds when connected
    _internetCheckTimer = Timer.periodic(Duration(seconds: 5), (_) async {
      if (mounted && _connectionStatus != ConnectionStatus.noConnectivity) {
        await _connectivityManager.forceInternetCheck();
      }
    });
  }

  void _stopRealTimeChecking() {
    _realTimeCheckTimer?.cancel();
    _internetCheckTimer?.cancel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectionSubscription?.cancel();
    _connectivityManager.dispose();
    _stopRealTimeChecking();
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

  Future<void> _onRetryPressed() async {
    if (_isRetrying) return; // Prevent multiple simultaneous retries

    setState(() {
      _isRetrying = true;
      _connectionStatus = ConnectionStatus.unknown;
    });

    try {
      await Future.delayed(Duration(milliseconds: 500)); // Small delay for UI stability
      await _connectivityManager.forceCheckConnection();
      _startRealTimeChecking();
    } catch (e) {
      print('Error during retry: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
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
            // Only show overlay after initial check is complete and there's actually no connection
            if (_initialCheckComplete && _connectionStatus != ConnectionStatus.connected)
              Positioned.fill(
                child: ConnectionStatusWidget(
                  status: _connectionStatus,
                  onRetry: _isRetrying ? null : _onRetryPressed,
                  isRetrying: _isRetrying,
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

// --- Real-time Connection Indicator ---
class ConnectionIndicator extends StatefulWidget {
  final ConnectionStatus status;

  const ConnectionIndicator({Key? key, required this.status}) : super(key: key);

  @override
  State<ConnectionIndicator> createState() => _ConnectionIndicatorState();
}

class _ConnectionIndicatorState extends State<ConnectionIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    if (widget.status == ConnectionStatus.connected) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ConnectionIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == ConnectionStatus.connected) {
      _animationController.repeat(reverse: true);
    } else {
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status == ConnectionStatus.connected) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Online',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor().withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.status == ConnectionStatus.unknown)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            Icon(_getStatusIcon(), color: Colors.white, size: 16),
          SizedBox(width: 4),
          Text(
            _getStatusText(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (widget.status) {
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.noConnectivity:
        return Colors.red;
      case ConnectionStatus.noInternet:
        return Colors.orange;
      case ConnectionStatus.unknown:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (widget.status) {
      case ConnectionStatus.connected:
        return Icons.wifi;
      case ConnectionStatus.noConnectivity:
        return Icons.wifi_off;
      case ConnectionStatus.noInternet:
        return Icons.cloud_off;
      case ConnectionStatus.unknown:
        return Icons.signal_wifi_statusbar_null;
    }
  }

  String _getStatusText() {
    switch (widget.status) {
      case ConnectionStatus.connected:
        return 'Online';
      case ConnectionStatus.noConnectivity:
        return 'No WiFi';
      case ConnectionStatus.noInternet:
        return 'No Internet';
      case ConnectionStatus.unknown:
        return 'Checking...';
    }
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
  final StreamController<ConnectionStatus> _connectionController =
  StreamController<ConnectionStatus>.broadcast();

  Stream<ConnectionStatus> get connectionStream => _connectionController.stream;
  ConnectionStatus _currentStatus = ConnectionStatus.unknown;
  ConnectionStatus get currentStatus => _currentStatus;

  final List<String> _testUrls = [
    '8.8.8.8',      // Google DNS - fastest
    '1.1.1.1',      // Cloudflare DNS
    'google.com',
    'cloudflare.com',
  ];

  bool _isCheckingInternet = false;

  Future<void> initialize() async {
    try {
      final initialResult = await _connectivity.checkConnectivity();
      await _updateConnectionStatus(initialResult);

      // Listen to real-time connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
            (results) async {
          await _updateConnectionStatus(results);
        },
        onError: (error) {
          print('Connectivity subscription error: $error');
          if (_currentStatus != ConnectionStatus.unknown) {
            _currentStatus = ConnectionStatus.unknown;
            _connectionController.add(ConnectionStatus.unknown);
          }
        },
      );
    } catch (e) {
      print('Error initializing connectivity: $e');
      _currentStatus = ConnectionStatus.unknown;
      _connectionController.add(ConnectionStatus.unknown);
    }
  }

  Future<bool> hasInternetAccess() async {
    if (_isCheckingInternet) return _currentStatus == ConnectionStatus.connected;
    _isCheckingInternet = true;

    try {
      // Test multiple URLs concurrently for faster response
      final futures = _testUrls.map((url) => _testSingleUrl(url));
      final results = await Future.wait(futures, eagerError: false);

      // Return true if any test succeeds
      final hasInternet = results.any((result) => result);
      return hasInternet;
    } catch (e) {
      print('Internet access check error: $e');
      return false;
    } finally {
      _isCheckingInternet = false;
    }
  }

  Future<bool> _testSingleUrl(String url) async {
    try {
      final result = await InternetAddress.lookup(url).timeout(
        Duration(seconds: 5),
      );
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> results) async {
    try {
      final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      ConnectionStatus newStatus;

      if (result == ConnectivityResult.none) {
        newStatus = ConnectionStatus.noConnectivity;
      } else {
        // Quick internet check with timeout
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
        print('Connection status changed to: $newStatus');
      }
    } catch (e) {
      print('Error updating connection status: $e');
      if (_currentStatus != ConnectionStatus.unknown) {
        _currentStatus = ConnectionStatus.unknown;
        _connectionController.add(ConnectionStatus.unknown);
      }
    }
  }

  Future<void> checkConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      await _updateConnectionStatus(result);
    } catch (e) {
      print('Error checking connection: $e');
      if (_currentStatus != ConnectionStatus.unknown) {
        _currentStatus = ConnectionStatus.unknown;
        _connectionController.add(ConnectionStatus.unknown);
      }
    }
  }

  Future<void> forceCheckConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final connectivity = result.isNotEmpty ? result.first : ConnectivityResult.none;

      ConnectionStatus newStatus;
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

      // Always update status on force check
      _currentStatus = newStatus;
      _connectionController.add(newStatus);
    } catch (e) {
      print('Error force checking connection: $e');
      _currentStatus = ConnectionStatus.unknown;
      _connectionController.add(ConnectionStatus.unknown);
    }
  }

  Future<void> forceInternetCheck() async {
    if (_currentStatus == ConnectionStatus.noConnectivity) return;

    try {
      final hasInternet = await hasInternetAccess();
      final newStatus = hasInternet ?
      ConnectionStatus.connected :
      ConnectionStatus.noInternet;

      if (_currentStatus != newStatus) {
        _currentStatus = newStatus;
        _connectionController.add(newStatus);
      }
    } catch (e) {
      print('Error in force internet check: $e');
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    if (!_connectionController.isClosed) {
      _connectionController.close();
    }
  }
}

// --- Overlay Widget ---
class ConnectionStatusWidget extends StatelessWidget {
  final ConnectionStatus status;
  final VoidCallback? onRetry;
  final bool isRetrying;

  const ConnectionStatusWidget({
    Key? key,
    required this.status,
    this.onRetry,
    this.isRetrying = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (status == ConnectionStatus.connected) {
      return SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated icon
              AnimatedSwitcher(
                duration: Duration(milliseconds: 300),
                child: Icon(
                  _getIcon(),
                  key: ValueKey(status),
                  color: _getIconColor(),
                  size: 100,
                ),
              ),
              SizedBox(height: 24),
              Text(
                _getTitle(),
                style: TextStyle(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
                textAlign: TextAlign.center,
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
              SizedBox(height: 32),
              if (onRetry != null && !isRetrying)
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: Icon(Icons.refresh),
                  label: Text('Retry Connection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    minimumSize: Size(180, 48),
                  ),
                ),
              if (isRetrying)
                Column(
                  children: [
                    CircularProgressIndicator(color: Colors.indigo),
                    SizedBox(height: 12),
                    Text(
                      'Retrying connection...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              if (status == ConnectionStatus.unknown && !isRetrying)
                Column(
                  children: [
                    CircularProgressIndicator(color: Colors.indigo),
                    SizedBox(height: 12),
                    Text(
                      'Checking connection in real-time...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
            ],
          ),
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
      case ConnectionStatus.unknown:
        return Icons.signal_wifi_statusbar_null;
      default:
        return Icons.signal_wifi_off;
    }
  }

  Color _getIconColor() {
    switch (status) {
      case ConnectionStatus.noConnectivity:
        return Colors.red[400]!;
      case ConnectionStatus.noInternet:
        return Colors.orange[400]!;
      case ConnectionStatus.unknown:
        return Colors.grey[400]!;
      default:
        return Colors.grey[400]!;
    }
  }

  String _getTitle() {
    switch (status) {
      case ConnectionStatus.noConnectivity:
        return 'No Network Connection';
      case ConnectionStatus.noInternet:
        return 'No Internet Access';
      case ConnectionStatus.unknown:
        return 'Checking Connection...';
      default:
        return 'Connection Issue';
    }
  }

  String _getDescription() {
    switch (status) {
      case ConnectionStatus.noConnectivity:
        return 'Please check your WiFi or mobile data connection and try again.';
      case ConnectionStatus.noInternet:
        return 'You are connected to a network, but internet access is not available.';
      case ConnectionStatus.unknown:
        return 'Please wait while we verify your connection status in real-time.';
      default:
        return 'Unable to connect to the internet. Please check your connection.';
    }
  }
}