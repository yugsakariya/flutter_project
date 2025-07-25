import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'login.dart';
import 'main.dart';

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
  String _statusMessage = 'Checking internet access...';
  Color _statusColor = Colors.orange;
  Timer? _periodicTimer;
  int _attempts = 0;
  final int _maxAttempts = 5;
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

    // Start periodic internet access check every 3 seconds
    _periodicTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkInternetConnection();
    });
    // Do an immediate check as well
    _checkInternetConnection();
  }

  Future<void> _checkInternetConnection() async {
    if (_navigated) return;
    setState(() {
      _statusMessage = 'Checking internet access...';
      _statusColor = Colors.orange;
    });
    _attempts++;
    try {
      final response = await http.get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        setState(() {
          _statusMessage = 'Internet connection available';
          _statusColor = Colors.green;
        });
        _proceedToMainApp();
        return;
      } else {
        setState(() {
          _statusMessage = 'Limited internet access';
          _statusColor = Colors.orange;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'No internet access';
        _statusColor = Colors.red;
      });
    }
    if (_attempts >= _maxAttempts) {
      _proceedToMainApp();
    }
  }

  void _proceedToMainApp() {
    if (_navigated) return;
    _navigated = true;
    _periodicTimer?.cancel();
    setState(() {
      _isCheckingConnection = false;
    });
    // Wait a bit to show the result, then proceed
    Timer(const Duration(seconds: 1), () {
      _navigateToMainApp();
    });
  }

  void _navigateToMainApp() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => Loginscreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _periodicTimer?.cancel();
    super.dispose();
  }

  IconData _getStatusIcon() {
    if (_statusColor == Colors.green) {
      return Icons.wifi;
    } else if (_statusColor == Colors.orange) {
      return Icons.wifi_off;
    } else {
      return Icons.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
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
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/logo.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Inventory Management',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Manage your stock efficiently',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 50),
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
} 