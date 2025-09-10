import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'utils.dart';

enum PartyType { customer, supplier }

class PartyDialog extends StatefulWidget {
  final PartyType partyType;
  final String? initialName;
  final Function(Map<String, String>)? onPartyAdded;

  const PartyDialog({
    super.key,
    required this.partyType,
    this.initialName,
    this.onPartyAdded,
  });

  @override
  State<PartyDialog> createState() => _PartyDialogState();
}

class _PartyDialogState extends State<PartyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  
  bool _isLoading = false;

  String get _partyTitle => widget.partyType == PartyType.customer ? 'Customer' : 'Supplier';
  String get _collection => widget.partyType == PartyType.customer ? 'customers' : 'suppliers';
  IconData get _icon => widget.partyType == PartyType.customer ? Icons.person : Icons.business;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _saveParty() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Check if party already exists
      final exists = await FirestoreHelper.documentExists(
        _collection, 
        'name', 
        _nameController.text.trim()
      );

      if (exists) {
        AppUtils.showWarning('$_partyTitle with this name already exists');
        return;
      }

      // Add new party
      await FirestoreHelper.addDocument(_collection, {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
      });

      final partyData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
      };

      widget.onPartyAdded?.call(partyData);
      AppUtils.showSuccess('$_partyTitle added successfully!');
      Navigator.of(context).pop(partyData);

    } catch (e) {
      AppUtils.showError('Error adding $_partyTitle: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add New $_partyTitle'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: _nameController,
                  labelText: '$_partyTitle Name*',
                  prefixIcon: _icon,
                  validator: (value) => AppUtils.validateRequired(value, '${_partyTitle.toLowerCase()} name'),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _phoneController,
                  labelText: 'Phone Number',
                  prefixIcon: Icons.phone,
                  prefixText: '+91 ',
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: AppUtils.validatePhone,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _cityController,
                  labelText: 'City',
                  prefixIcon: Icons.location_city,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _stateController,
                  labelText: 'State',
                  prefixIcon: Icons.map,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveParty,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : Text('Add $_partyTitle'),
        ),
      ],
    );
  }
}

// Unified Party Screen for both Customers and Suppliers
class PartyScreen extends StatefulWidget {
  final PartyType partyType;
  
  const PartyScreen({super.key, required this.partyType});

  @override
  State<PartyScreen> createState() => _PartyScreenState();
}

class _PartyScreenState extends State<PartyScreen> {
  final user = FirebaseAuth.instance.currentUser!;

  String get _title => widget.partyType == PartyType.customer ? 'Customers' : 'Suppliers';
  String get _collection => widget.partyType == PartyType.customer ? 'customers' : 'suppliers';
  IconData get _icon => widget.partyType == PartyType.customer ? Icons.people : Icons.local_shipping;
  Color get _color => widget.partyType == PartyType.customer ? Colors.green : Colors.orange;

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => PartyDialog(partyType: widget.partyType),
    );
  }

  void _showEditDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    showDialog(
      context: context,
      builder: (context) => _EditPartyDialog(
        partyType: widget.partyType,
        docId: doc.id,
        initialData: data,
      ),
    );
  }

  void _deleteParty(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${_title.substring(0, _title.length - 1)}'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await doc.reference.delete();
                Navigator.pop(context);
                AppUtils.showSuccess('${_title.substring(0, _title.length - 1)} deleted successfully!');
              } catch (e) {
                Navigator.pop(context);
                AppUtils.showError('Error deleting: $e');
              }
            },
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreHelper.getUserDocuments(_collection),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error loading $_title"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_icon, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text("No $_title found"),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add),
                    label: Text("Add ${_title.substring(0, _title.length - 1)}"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final name = data['name'] ?? 'No Name';
              final phone = data['phone'] ?? '';
              final city = data['city'] ?? '';
              final state = data['state'] ?? '';

              String addressDisplay = '';
              if (city.isNotEmpty && state.isNotEmpty) {
                addressDisplay = '$city, $state';
              } else if (city.isNotEmpty) {
                addressDisplay = city;
              } else if (state.isNotEmpty) {
                addressDisplay = state;
              }

              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _color,
                      child: Icon(_icon, color: Colors.white),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (phone.isNotEmpty)
                          Text('📞 +91 $phone', style: const TextStyle(fontSize: 12)),
                        if (addressDisplay.isNotEmpty)
                          Text('📍 $addressDisplay',
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditDialog(docs[index]);
                        } else if (value == 'delete') {
                          _deleteParty(docs[index]);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: addressDisplay.isNotEmpty,
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// Edit Party Dialog
class _EditPartyDialog extends StatefulWidget {
  final PartyType partyType;
  final String docId;
  final Map<String, dynamic> initialData;

  const _EditPartyDialog({
    required this.partyType,
    required this.docId,
    required this.initialData,
  });

  @override
  State<_EditPartyDialog> createState() => _EditPartyDialogState();
}

class _EditPartyDialogState extends State<_EditPartyDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  
  bool _isLoading = false;

  String get _partyTitle => widget.partyType == PartyType.customer ? 'Customer' : 'Supplier';
  String get _collection => widget.partyType == PartyType.customer ? 'customers' : 'suppliers';
  IconData get _icon => widget.partyType == PartyType.customer ? Icons.person : Icons.business;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData['name'] ?? '');
    _phoneController = TextEditingController(text: widget.initialData['phone'] ?? '');
    _cityController = TextEditingController(text: widget.initialData['city'] ?? '');
    _stateController = TextEditingController(text: widget.initialData['state'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _updateParty() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirestoreHelper.updateDocument(_collection, widget.docId, {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
      });

      AppUtils.showSuccess('$_partyTitle updated successfully!');
      Navigator.of(context).pop();
    } catch (e) {
      AppUtils.showError('Error updating $_partyTitle: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit $_partyTitle'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: _nameController,
                  labelText: '$_partyTitle Name*',
                  prefixIcon: _icon,
                  validator: (value) => AppUtils.validateRequired(value, '${_partyTitle.toLowerCase()} name'),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _phoneController,
                  labelText: 'Phone Number',
                  prefixIcon: Icons.phone,
                  prefixText: '+91 ',
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: AppUtils.validatePhone,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _cityController,
                  labelText: 'City',
                  prefixIcon: Icons.location_city,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _stateController,
                  labelText: 'State',
                  prefixIcon: Icons.map,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateParty,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : const Text('Update'),
        ),
      ],
    );
  }
}