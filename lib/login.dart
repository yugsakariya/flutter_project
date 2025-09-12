import 'package:flutter/material.dart';
import 'package:flutter_project/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_project/Dashboard.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:io';

class Loginscreen extends StatefulWidget {
  const Loginscreen({super.key});

  @override
  State<Loginscreen> createState() => _FormDesignState();
}

class _FormDesignState extends State<Loginscreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool passwordControlle = true;
  bool _isLoading = false;
  String? _loginError;
  bool _isConnected = true;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _startConnectivityListener();
  }

  void _checkConnectivity() async {
    try {
      final ConnectivityResult result = await Connectivity().checkConnectivity();
      final hasConnection = result != ConnectivityResult.none;
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
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      final hasConnection = result != ConnectivityResult.none;
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

  void _retryConnection() {
    _checkConnectivity();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isConnected ? _buildLoginForm() : _buildNoConnectionScreen(),
    );
  }

  Widget _buildNoConnectionScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                color: Colors.transparent,
              ),
              width: 200,
              height: 200,
              child: Image.asset("assets/logo.png"),
            ),
            const SizedBox(height: 24),
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
    );
  }

  Widget _buildLoginForm() {
    return Center(
      child: Container(
        width: 1000,
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    color: Colors.transparent,
                  ),
                  width: 200,
                  height: 200,
                  child: Image.asset("assets/logo.png"),
                ),
                const SizedBox(height: 10),
                SizedBox(height: 20),
                // Email Field
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter your email';
                    }
                    if (!RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+',
                    ).hasMatch(value)) {
                      return 'Enter a valid email';
                    }
                    if (_loginError != null) {
                      return _loginError;
                    }
                    return null;
                  },
                  onChanged: (value) {
                    if (_loginError != null) {
                      setState(() {
                        _loginError = null;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: Colors.cyan,
                        width: 2.5,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: passwordController,
                  obscureText: passwordControlle,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    if (_loginError != null) {
                      return _loginError;
                    }
                    return null;
                  },
                  onChanged: (value) {
                    if (_loginError != null) {
                      setState(() {
                        _loginError = null;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: Colors.cyan,
                        width: 2.5,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    prefixIcon: Icon(Icons.password),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          passwordControlle = !passwordControlle;
                        });
                      },
                      icon: Icon(
                        passwordControlle
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _isLoading
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: () async {
                    // Check connectivity before attempting login
                    if (!_isConnected) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('No internet connection. Please check your network.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    setState(() {
                      _loginError = null;
                    });
                    if (_formKey.currentState!.validate()) {
                      setState(() {
                        _isLoading = true;
                      });
                      final email = emailController.text.trim();
                      final password = passwordController.text.trim();
                      try {
                        await FirebaseAuth.instance
                            .signInWithEmailAndPassword(
                          email: email,
                          password: password,
                        );
                        // Navigate to main app
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => MyApp()),
                        );
                      } on FirebaseAuthException catch (e) {
                        print(
                          'FirebaseAuthException: code=${e.code}, message=${e.message}',
                        );
                        setState(() {
                          _loginError = 'Invalid email or password';
                        });
                        _formKey.currentState!.validate();
                      } catch (e) {
                        print('Unknown login error: $e');
                        setState(() {
                          _loginError =
                          'Login failed. Please try again.';
                        });
                        _formKey.currentState!.validate();
                      } finally {
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 50),
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Login"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
