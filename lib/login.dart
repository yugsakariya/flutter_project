// import 'package:Project/ProductList.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/Dashboard.dart';
import 'package:flutter_project/appstart.dart';
import 'package:flutter_project/main.dart';
import 'ProductList.dart';

class Loginscreen extends StatefulWidget {
  Loginscreen({super.key});

  @override
  State<Loginscreen> createState() => _FormDesignState();
}

class _FormDesignState extends State<Loginscreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController numberController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  bool passwordControlle =true;

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
                       child: Image.asset("assets/logo.jpg"),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(height: 20),
                  Text(
                    'Welcome Back!',
                    style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 40),
                  // Name Field
                  TextFormField(
                    controller: numberController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter Your Number';
                      }
                      if(value.length<10 )
                      {
                        return "Please Enter 10 Digit";
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                        labelText: 'Number',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.cyan, width: 2.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        prefixIcon: Icon(Icons.person)
                    ),
                  ),
              
                  const SizedBox(height: 20),
              
              
              
                  TextFormField(
                    controller: passwordController,
                    obscureText: passwordControlle,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter Your Password';
                      }
                      if(value.length<6 )
                      {
                        return "Please Enter more than 6";
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.cyan, width: 2.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        prefixIcon: Icon(Icons.password),
                        suffixIcon: IconButton(
                            onPressed: ()
                            {
                              setState(() {
                                passwordControlle=!passwordControlle;
                              });
                            },
                            icon: Icon(passwordControlle?Icons.visibility_off:Icons.visibility))
                    ),
                  ),
                  const SizedBox(height: 20),
              
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final number = numberController.value;
                        final password = passwordController.value;
                        // ScaffoldMessenger.of(context).showSnackBar(
                        //   SnackBar(content: Text('')),
                        // );
                        Navigator.push(context, MaterialPageRoute(builder: (_)=>Appstart()),);
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
