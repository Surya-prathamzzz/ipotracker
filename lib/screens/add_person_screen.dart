import 'package:flutter/material.dart';
import '../models/ledger_entry.dart';
import '../models/person.dart';
import '../services/storage_service.dart';

class AddPersonScreen extends StatefulWidget {
  final StorageService storageService;
  final Person? editingPerson;

  const AddPersonScreen({
    super.key,
    required this.storageService,
    this.editingPerson,
  });

  @override
  State<AddPersonScreen> createState() => _AddPersonScreenState();
}

class _AddPersonScreenState extends State<AddPersonScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _panController;
  late TextEditingController _phoneController;
  late TextEditingController _upiController;
  late TextEditingController _bankController;
  late TextEditingController _accountController;
  late TextEditingController _initialFloatController;
  late TextEditingController _notesController;
  late bool _isSelf;

  @override
  void initState() {
    super.initState();
    final p = widget.editingPerson;
    _nameController = TextEditingController(text: p?.name ?? '');
    _panController = TextEditingController(text: p?.pan ?? '');
    _phoneController = TextEditingController(text: p?.phone ?? '');
    _upiController = TextEditingController(text: p?.upiId ?? '');
    _bankController = TextEditingController(text: p?.bankName ?? '');
    _accountController = TextEditingController(text: p?.accountNumber ?? '');
    _initialFloatController = TextEditingController(text: '');
    _notesController = TextEditingController(text: p?.notes ?? '');
    _isSelf = p?.isSelf ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _panController.dispose();
    _phoneController.dispose();
    _upiController.dispose();
    _bankController.dispose();
    _accountController.dispose();
    _initialFloatController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editingPerson != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Person' : 'Add Family / Friend Account'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                hintText: 'e.g. Dad, Rohan Sharma',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
            ),
            const SizedBox(height: 16),

            // PAN
            TextFormField(
              controller: _panController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'PAN Number *',
                hintText: 'e.g. ABCDE1234F',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please enter PAN number';
                final cleaned = v.trim().toUpperCase();
                if (cleaned.length != 10) return 'PAN must be 10 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // UPI ID
            TextFormField(
              controller: _upiController,
              decoration: const InputDecoration(
                labelText: 'UPI ID (For 1-Tap Top-Up)',
                hintText: 'e.g. rohan@okhdfcbank',
                prefixIcon: Icon(Icons.payment_outlined),
                border: OutlineInputBorder(),
                helperText: 'Enables 1-click UPI top-up from Smart Delta calculations',
              ),
            ),
            const SizedBox(height: 16),

            // Bank Name & Account Number
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _bankController,
                    decoration: const InputDecoration(
                      labelText: 'Bank Name',
                      hintText: 'e.g. HDFC, SBI',
                      prefixIcon: Icon(Icons.account_balance_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _accountController,
                    decoration: const InputDecoration(
                      labelText: 'Account / Last 4',
                      hintText: 'e.g. 4589',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Phone
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'e.g. 9876543210',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Initial Float (Only if creating new person)
            if (!isEditing) ...[
              TextFormField(
                controller: _initialFloatController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Current Money Sitting in Account (₹)',
                  hintText: '0',
                  prefixIcon: Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(),
                  helperText: 'Initial float balance already transferred to them',
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Notes
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes / Demat info',
                hintText: 'e.g. Zerodha account, Netbanking credentials',
                prefixIcon: Icon(Icons.note_alt_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Primary / Self Account Switch
            Container(
              decoration: BoxDecoration(
                color: Colors.indigo.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: SwitchListTile(
                title: const Text('My Own Account (Self / YOU)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Designates this person as the primary account holder in the syndicate'),
                value: _isSelf,
                activeColor: Colors.indigo.shade800,
                onChanged: (val) => setState(() => _isSelf = val),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _savePerson,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                isEditing ? 'Update Person' : 'Save Account',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _savePerson() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final pan = _panController.text.trim().toUpperCase();
    final phone = _phoneController.text.trim();
    final upi = _upiController.text.trim();
    final bank = _bankController.text.trim();
    final account = _accountController.text.trim();
    final notes = _notesController.text.trim();

    if (widget.editingPerson != null) {
      final updated = widget.editingPerson!.copyWith(
        name: name,
        pan: pan,
        phone: phone,
        upiId: upi,
        bankName: bank,
        accountNumber: account,
        notes: notes,
        isSelf: _isSelf,
      );
      await widget.storageService.savePerson(updated);
    } else {
      final newPerson = Person(
        name: name,
        pan: pan,
        phone: phone,
        upiId: upi,
        bankName: bank,
        accountNumber: account,
        notes: notes,
        isSelf: _isSelf,
      );
      await widget.storageService.savePerson(newPerson);

      // If initial float entered, add to ledger
      final initialAmt = double.tryParse(_initialFloatController.text);
      if (initialAmt != null && initialAmt > 0) {
        await widget.storageService.addManualTransaction(
          personId: newPerson.id,
          type: LedgerEntryType.sendToPerson,
          amount: initialAmt,
          note: 'Initial starting float balance',
        );
      }
    }

    if (!mounted) return;
    Navigator.pop(context);
  }
}
