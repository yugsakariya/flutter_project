import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppUtils {
  static final user = FirebaseAuth.instance.currentUser;
  
  // Toast utilities
  static void showToast(String message, {Color? backgroundColor}) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: backgroundColor ?? Colors.green,
      textColor: Colors.white,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 2,
      fontSize: 16.0,
    );
  }
  
  static void showSuccess(String message) => showToast(message, backgroundColor: Colors.green);
  static void showError(String message) => showToast(message, backgroundColor: Colors.red);
  static void showWarning(String message) => showToast(message, backgroundColor: Colors.orange);
  
  // String utilities
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
  
  // Validation utilities
  static String? validatePhone(String? value) {
    if (value?.trim().isNotEmpty == true && value!.trim().length != 10) {
      return 'Please enter a valid 10-digit phone number';
    }
    return null;
  }
  
  static String? validateRequired(String? value, String fieldName) {
    if (value?.trim().isEmpty ?? true) {
      return 'Please enter $fieldName';
    }
    return null;
  }
  
  static String? validatePositiveNumber(String? value, String fieldName) {
    if (value?.isEmpty ?? true) return 'Enter $fieldName';
    final number = double.tryParse(value!);
    if (number == null || number <= 0) return '$fieldName must be > 0';
    return null;
  }
  
  static String? validatePositiveInteger(String? value, String fieldName) {
    if (value?.isEmpty ?? true) return 'Enter $fieldName';
    final number = int.tryParse(value!);
    if (number == null || number <= 0) return '$fieldName must be > 0';
    return null;
  }
}

// Reusable Form Field Widget
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData? prefixIcon;
  final String? prefixText;
  final String? suffixText;
  final TextInputType? keyboardType;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool enabled;
  final FocusNode? focusNode;

  const AppTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.prefixIcon,
    this.prefixText,
    this.suffixText,
    this.keyboardType,
    this.maxLength,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      enabled: enabled,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        prefixText: prefixText,
        suffixText: suffixText,
        border: const OutlineInputBorder(),
        counterText: maxLength != null ? "" : null,
      ),
      validator: validator,
    );
  }
}

// Reusable Suggestion List Widget
class SuggestionsList extends StatelessWidget {
  final Stream<List<String>> stream;
  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(String)? onSelected;

  const SuggestionsList({
    super.key,
    required this.stream,
    required this.controller,
    required this.focusNode,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 50,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final suggestions = snapshot.data ?? [];
        if (suggestions.isEmpty) return const SizedBox.shrink();

        return Container(
          constraints: const BoxConstraints(maxHeight: 200),
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: suggestions.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Colors.grey.shade200,
              ),
              itemBuilder: (context, index) => InkWell(
                onTap: () {
                  controller.text = suggestions[index];
                  focusNode.unfocus();
                  onSelected?.call(suggestions[index]);
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    suggestions[index],
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Loading Dialog
class LoadingDialog {
  static void show(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message),
          ],
        ),
      ),
    );
  }
  
  static void hide(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }
}

// Firestore Helper
class FirestoreHelper {
  static final _firestore = FirebaseFirestore.instance;
  static final _user = FirebaseAuth.instance.currentUser;
  
  // Get suggestions for autocomplete
  static Stream<List<String>> getSuggestions(String collection, String field, String query) {
    if (query.trim().isEmpty || _user == null) return Stream.value([]);
    
    final lowercaseQuery = query.trim().toLowerCase();
    return _firestore
        .collection(collection)
        .where('user', isEqualTo: _user!.uid)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => doc[field] as String? ?? '')
          .where((item) => item.isNotEmpty && item.toLowerCase().contains(lowercaseQuery))
          .toSet()
          .toList();
      items.sort();
      return items.take(10).toList();
    });
  }
  
  // Add document with user ID
  static Future<DocumentReference> addDocument(String collection, Map<String, dynamic> data) {
    data['user'] = _user?.uid;
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    return _firestore.collection(collection).add(data);
  }
  
  // Update document
  static Future<void> updateDocument(String collection, String docId, Map<String, dynamic> data) {
    data['updatedAt'] = FieldValue.serverTimestamp();
    return _firestore.collection(collection).doc(docId).update(data);
  }
  
  // Get user documents stream
  static Stream<QuerySnapshot> getUserDocuments(String collection) {
    if (_user == null) return const Stream.empty();
    return _firestore
        .collection(collection)
        .where('user', isEqualTo: _user!.uid)
        .snapshots();
  }
  
  // Check if document exists
  static Future<bool> documentExists(String collection, String field, String value) async {
    if (_user == null) return false;
    
    final query = await _firestore
        .collection(collection)
        .where('user', isEqualTo: _user!.uid)
        .where(field, isEqualTo: value)
        .limit(1)
        .get();
    
    return query.docs.isNotEmpty;
  }
}

// Reusable Stats Card Widget
class StatsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Stream<QuerySnapshot> stream;
  final VoidCallback? onTap;

  const StatsCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.stream,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return GestureDetector(
          onTap: onTap,
          child: Card(
            elevation: 3,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              child: Column(
                children: [
                  Icon(icon, color: color, size: 30),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}