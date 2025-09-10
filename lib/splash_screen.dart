import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isCheckingConnection = true;
  String _statusMessage = 'Initializing...';
  Color _statusColor = Colors.orange;
  Timer? _connectionTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();

    // Start connection check after a brief delay
    Timer(const Duration(milliseconds: 500), () {
      _checkInternetConnection();
    });
  }

  Future<void> _checkInternetConnection() async {
    if (_navigated || !mounted) return;

    setState(() {
      _statusMessage = 'Checking internet connection...';
      _statusColor = Colors.orange;
    });

    try {
      // Check connectivity first
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult == ConnectivityResult.none) {
        setState(() {
          _statusMessage = 'No internet connection';
          _statusColor = Colors.red;
        });
        _proceedAfterDelay();
        return;
      }

      // Try to reach a server
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        setState(() {
          _statusMessage = 'Connection successful';
          _statusColor = Colors.green;
        });
      } else {
        setState(() {
          _statusMessage = 'Limited connectivity';
          _statusColor = Colors.orange;
        });
      }

    } catch (e) {
      setState(() {
        _statusMessage = 'Connection timeout';
        _statusColor = Colors.red;
      });
    }

    _proceedAfterDelay();
  }

  void _proceedAfterDelay() {
    if (_navigated || !mounted) return;

    _connectionTimer = Timer(const Duration(seconds: 2), () {
      _navigateToMainApp();
    });
  }

  void _navigateToMainApp() {
    if (_navigated || !mounted) return;

    _navigated = true;
    _connectionTimer?.cancel();

    setState(() {
      _isCheckingConnection = false;
    });

    // Navigate to AuthWrapper (which handles login state)
    Navigator.of(context).pushReplacementNamed('/auth');
  }

  @override
  void dispose() {
    _animationController.dispose();
    _connectionTimer?.cancel();
    super.dispose();
  }

  IconData _getStatusIcon() {
    switch (_statusColor) {
      case Colors.green:
        return Icons.wifi;
      case Colors.orange:
        return Icons.wifi_1_bar;
      case Colors.red:
      default:
        return Icons.wifi_off;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo Container
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback if logo doesn't exist
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.inventory_2,
                                  size: 80,
                                  color: Colors.indigo,
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // App Title
                      const Text(
                        'Inventory Management',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Subtitle
                      const Text(
                        'Manage your stock efficiently',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 50),

                      // Loading indicator
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                      ),

                      const SizedBox(height: 20),

                      // Status message
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getStatusIcon(),
                            color: _statusColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _statusMessage,
                            style: TextStyle(
                              color: _statusColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}