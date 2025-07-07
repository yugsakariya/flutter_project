import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TransactionAdd extends StatefulWidget {
  final Map<String, dynamic>? transaction;

  const TransactionAdd({super.key, this.transaction});

  @override
  State<TransactionAdd> createState() => _TransactionAddState();
}

class _TransactionAddState extends State<TransactionAdd> {
  final _formKey = GlobalKey<FormState>();
  final productController = TextEditingController();
  final qtyController = TextEditingController();
  final unitPriceController = TextEditingController();
  final partyController = TextEditingController();
  final dateController = TextEditingController();

  String type = 'Sale';
  String status = 'Paid';

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      final t = widget.transaction!;
      productController.text = t['product'];
      qtyController.text = t['qty'].toString();
      unitPriceController.text = t['unitPrice'].toString();
      partyController.text = t['party'];
      dateController.text = t['date'];
      type = t['type'];
      status = t['status'];
    } else {
      dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final qty = int.parse(qtyController.text);
      final unitPrice = double.parse(unitPriceController.text);
      final total = qty * unitPrice;

      final newTransaction = {
        'product': productController.text,
        'qty': qty,
        'unitPrice': unitPrice,
        'total': total,
        'date': dateController.text,
        'party': partyController.text,
        'type': type,
        'status': status,
      };

      Navigator.pop(context, newTransaction);
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(dateController.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUpdating = widget.transaction != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isUpdating ? "Update Transaction" : "Add Transaction"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: productController,
                decoration: InputDecoration(labelText: "Product Name"),
                validator: (value) => value!.isEmpty ? 'Enter product name' : null,
              ),
              TextFormField(
                controller: qtyController,
                decoration: InputDecoration(labelText: "Quantity"),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Enter quantity' : null,
              ),
              TextFormField(
                controller: unitPriceController,
                decoration: InputDecoration(labelText: "Unit Price"),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Enter unit price' : null,
              ),
              TextFormField(
                controller: partyController,
                decoration: InputDecoration(labelText: "Party Name"),
                validator: (value) => value!.isEmpty ? 'Enter party name' : null,
              ),
              TextFormField(
                controller: dateController,
                readOnly: true,
                onTap: () => _pickDate(context),
                decoration: InputDecoration(
                  labelText: "Date",
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                validator: (value) => value!.isEmpty ? 'Pick a date' : null,
              ),
              DropdownButtonFormField<String>(
                value: type,
                decoration: InputDecoration(labelText: "Transaction Type"),
                items: ['Sale', 'Purchase']
                    .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                    .toList(),
                onChanged: (value) => setState(() => type = value!),
              ),
              DropdownButtonFormField<String>(
                value: status,
                decoration: InputDecoration(labelText: "Payment Status"),
                items: ['Paid', 'Due']
                    .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                    .toList(),
                onChanged: (value) => setState(() => status = value!),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitForm,
                child: Text(isUpdating ? "Update Transaction" : "Add Transaction",style: TextStyle(color: Colors.black,fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
