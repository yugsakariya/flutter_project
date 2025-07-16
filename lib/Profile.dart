// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
//
// class Profile extends StatefulWidget {
//   const Profile({super.key});
//
//   @override
//   State<Profile> createState() => _ProfileState();
// }
//
// class _ProfileState extends State<Profile> {
//   @override
//   initState() {
//     super.initState();
//     _loadInitialProfileData(); // Call a new async method
//   }
//  var docId = '';
//   void _loadInitialProfileData() async {
//     try {
//       // Use .get() to fetch data once
//       QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection("profile").get();
//       if (querySnapshot.docs.isNotEmpty) {
//         // Assuming you want to load the first profile document found
//         _loadUserData(querySnapshot.docs[0].id);
//         // You might also want to populate your _nameController here
//         // if the profile document contains the name
//         Map<String, dynamic>? data = querySnapshot.docs[0].data() as Map<String, dynamic>?;
//         if (data != null && data.containsKey('name')) {
//           _nameController.text = data['name'];
//         }
//       }
//       else {
//       }
//
//   }
//   catch (e) {
//       // Optionally, you can show an error message to the user
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to load profile data')),
//       );
//   }
//   }
//
//   void _loadUserData(String docId) async {
//     try {
//       DocumentSnapshot docData = await FirebaseFirestore.instance.collection("profile").doc(docId).get();
//       docId = docData.id;
//       if (docData.exists) {
//         _nameController.text = docData["name"] ?? '';
//       }
//     } catch (e) {
//       print("Error loading user data for docId $docId: $e");
//     }
//   }
//   final _formKey =GlobalKey<FormState>();
//   final _nameController = TextEditingController();
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//         appBar: AppBar(
//           title: Text("Profile"),
//           backgroundColor: Colors.indigo,
//           foregroundColor: Colors.white,
//         ),
//       body: Padding(
//         padding: const EdgeInsets.all(30.0),
//         child: Center(
//           child: Form(
//             child: Column(
//               children: [
//                 CircleAvatar(
//                   radius: 45,
//                 ),
//                 SizedBox(height: 20),
//                 TextFormField(
//                   controller: _nameController,
//                   decoration: InputDecoration(
//                     labelText: "Name",
//                     border: OutlineInputBorder(),
//                   ),
//                   validator: (value) {
//                     if (value!.isEmpty) {
//                       return 'Please enter your name';
//                     }
//                     return null;
//                   },
//                 ),
//                 SizedBox(height: 10),
//                 ElevatedButton(onPressed: (){
//                   if (_formKey.currentState!.validate()) {
//                     FirebaseFirestore.instance.collection("profile").doc(docId).set({
//                       'name': _nameController.text,
//                     }).then((_) {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(content: Text('Profile updated successfully')),
//                       );
//                     }).catchError((error) {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(content: Text('Failed to update profile: $error')),
//                       );
//                     });
//                   }
//                 }, child: Text("Update Profile")),
//                 ]
//             ),
//           ),
//         ),
//       )
//     );
//   }
// }
