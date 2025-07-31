import 'package:flutter/material.dart';
import 'package:flutter_project/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_project/Dashboard.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
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
                  // Remove the Welcome Back! text
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
                                  'FirebaseAuthException: code= [38;5;9m${e.code} [0m, message=${e.message}',
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
      ),
    );
  }
}
