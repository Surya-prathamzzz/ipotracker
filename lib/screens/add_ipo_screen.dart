import 'package:flutter/material.dart';
import '../models/ipo.dart';
import '../services/storage_service.dart';
import '../utils/currency_formatter.dart';

class AddIpoScreen extends StatefulWidget {
  final StorageService storageService;

  const AddIpoScreen({super.key, required this.storageService});

  @override
  State<AddIpoScreen> createState() => _AddIpoScreenState();
}

class _AddIpoScreenState extends State<AddIpoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _symbolController = TextEditingController();
  final _lotSizeController = TextEditingController(text: '30');
  final _priceController = TextEditingController(text: '500');
  final _gmpController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  IpoCategory _category = IpoCategory.mainboard;
  RegistrarType _registrar = RegistrarType.linkIntime;
  DateTime _openDate = DateTime.now();
  DateTime _closeDate = DateTime.now().add(const Duration(days: 3));
  DateTime _allotmentDate = DateTime.now().add(const Duration(days: 5));

  double get _calculatedLotCost {
    final size = int.tryParse(_lotSizeController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    return size * price;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _symbolController.dispose();
    _lotSizeController.dispose();
    _priceController.dispose();
    _gmpController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New IPO'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Company Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Company Name *',
                hintText: 'e.g. Acme Tech Solutions Ltd.',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter company name' : null,
            ),
            const SizedBox(height: 14),

            // Symbol & Category
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _symbolController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Symbol *',
                      hintText: 'e.g. ACMETECH',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter symbol' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<IpoCategory>(
                    value: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: IpoCategory.mainboard, child: Text('Mainboard')),
                      DropdownMenuItem(value: IpoCategory.sme, child: Text('SME')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _category = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Lot Size & Cut-off Price
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _lotSizeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Lot Size (Shares) *',
                      hintText: '30',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Valid size';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price per Share (₹) *',
                      hintText: '500',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Valid price';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Live Calculated Lot Cost Callout
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Cost per Lot:', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    CurrencyFormatter.format(_calculatedLotCost),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Registrar Dropdown
            DropdownButtonFormField<RegistrarType>(
              value: _registrar,
              decoration: const InputDecoration(
                labelText: 'Registrar Portal',
                border: OutlineInputBorder(),
              ),
              items: RegistrarType.values.map((r) {
                return DropdownMenuItem(value: r, child: Text(r.displayName));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _registrar = val);
              },
            ),
            const SizedBox(height: 14),

            // Expected GMP
            TextFormField(
              controller: _gmpController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Grey Market Premium (GMP) (Optional)',
                hintText: '0',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),

            // Dates Pickers
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month),
              title: const Text('Bidding Open Date'),
              subtitle: Text(CurrencyFormatter.formatDate(_openDate)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _openDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _openDate = picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_busy),
              title: const Text('Bidding Close Date'),
              subtitle: Text(CurrencyFormatter.formatDate(_closeDate)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _closeDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _closeDate = picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Allotment Date'),
              subtitle: Text(CurrencyFormatter.formatDate(_allotmentDate)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _allotmentDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _allotmentDate = picked);
              },
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _saveIpo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Add IPO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveIpo() async {
    if (!_formKey.currentState!.validate()) return;

    final lotSize = int.parse(_lotSizeController.text.trim());
    final price = double.parse(_priceController.text.trim());
    final gmp = double.tryParse(_gmpController.text.trim()) ?? 0.0;

    final ipo = Ipo(
      name: _nameController.text.trim(),
      symbol: _symbolController.text.trim().toUpperCase(),
      lotSize: lotSize,
      pricePerShare: price,
      lotCost: lotSize * price,
      category: _category,
      openDate: _openDate,
      closeDate: _closeDate,
      allotmentDate: _allotmentDate,
      registrar: _registrar,
      gmp: gmp,
      notes: _notesController.text.trim(),
    );

    await widget.storageService.saveIpo(ipo);
    if (!mounted) return;
    Navigator.pop(context);
  }
}
