import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NewBillScreen extends StatefulWidget {
  const NewBillScreen({super.key, required void Function() goToDashboard});

  @override
  State<NewBillScreen> createState() => _NewBillScreenState();
}

class _NewBillScreenState extends State<NewBillScreen> {
  final TextEditingController nameController = TextEditingController(text: 'Amit Bhai');
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController billNumberController = TextEditingController(text: 'INV-2023-001');
  DateTime selectedDate = DateTime.now();
  List<String> items = [];

  String formatDate(DateTime date) => DateFormat.yMMMd().format(date);

  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  void addItem() {
    setState(() {
      items.add("Item ${items.length + 1}");
    });
  }

  @override
  Widget build(BuildContext context) {
    double subtotal = 0.0;
    double tax = 0.0;
    double total = subtotal + tax;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anmol Trading'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/logo.png'), // Replace with your logo
        ),
        // actions: [
        //   IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
        // ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Bill', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('CUSTOMER DETAILS', style: TextStyle(fontWeight:     FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            const Text('BILL INFO', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: billNumberController,
              decoration: const InputDecoration(labelText: 'Bill Number'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text("Date Today's:"),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: pickDate,
                  child: Text(DateFormat.yMMMd().format(selectedDate)),
                ),
                const Spacer(),
                const Text("Due Date"), // Placeholder
              ],
            ),
            const SizedBox(height: 16),
            const Text('ITEMS', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: addItem,
              icon: const Icon(Icons.add),
              label: const Text("Add Item"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            items.isEmpty
                ? const Text("No items added yet")
                : Column(
              children: items.map((item) => ListTile(title: Text(item))).toList(),
            ),
            const SizedBox(height: 16),
            const Text('SUMMARY', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Subtotal:"),
                Text("\$${subtotal.toStringAsFixed(2)}"),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Tax:"),
                Text("\$${tax.toStringAsFixed(2)}"),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("\$${total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Save and Print logic
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Save & Print Bill', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
