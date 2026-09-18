import 'package:flutter/material.dart';
import '../models/ipo.dart';
import '../services/ledger_service.dart';
import '../services/storage_service.dart';
import '../utils/currency_formatter.dart';
import '../widgets/delta_card.dart';

class ApplyIpoScreen extends StatefulWidget {
  final Ipo ipo;
  final StorageService storageService;

  const ApplyIpoScreen({
    super.key,
    required this.ipo,
    required this.storageService,
  });

  @override
  State<ApplyIpoScreen> createState() => _ApplyIpoScreenState();
}

class _ApplyIpoScreenState extends State<ApplyIpoScreen> {
  final Set<String> _selectedPersonIds = {};
  final Map<String, bool> _markFundsSentMap = {};
  bool _isSubmitting = false;

  int _lots = 1;
  bool _isCutoffPrice = true;
  String _quotaCategory = 'RII'; // RII, sNII, bNII

  @override
  void initState() {
    super.initState();
    final existingAppPersonIds = widget.storageService.applications
        .where((a) => a.ipoId == widget.ipo.id)
        .map((a) => a.personId)
        .toSet();

    for (final person in widget.storageService.people) {
      if (!existingAppPersonIds.contains(person.id)) {
        _selectedPersonIds.add(person.id);
        _markFundsSentMap[person.id] = true;
      }
    }
  }

  int get _maxRetailLots {
    if (widget.ipo.lotCost <= 0) return 1;
    // ₹2,00,000 retail limit in India
    final maxL = (200000 / widget.ipo.lotCost).floor();
    return maxL > 0 ? maxL : 1;
  }

  double get _currentApplicationCost => widget.ipo.lotCost * _lots;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final people = widget.storageService.people;
    final entries = widget.storageService.ledgerEntries;
    final costPerApp = _currentApplicationCost;

    // Aggregated metrics for selected people
    double totalCost = 0.0;
    double totalFloatUsed = 0.0;
    double totalFreshCashNeeded = 0.0;

    for (final person in people) {
      if (_selectedPersonIds.contains(person.id)) {
        totalCost += costPerApp;
        final delta = LedgerService.calculateDelta(
          person: person,
          requiredCost: costPerApp,
          entries: entries,
        );
        if (delta.isFullyCovered) {
          totalFloatUsed += costPerApp;
        } else {
          totalFloatUsed += delta.availableFloat;
          totalFreshCashNeeded += delta.amountToSend;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Apply with Syndicate', style: TextStyle(fontSize: 16)),
            Text(
              widget.ipo.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Bidding & Lot Calculator Card (Narada style)
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? const Color(0xFF1E293B) : Colors.indigo.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category & Cut-off Price Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Category Chips
                    Wrap(
                      spacing: 6,
                      children: [
                        _buildCategoryChip('RII (Retail)', 'RII'),
                        _buildCategoryChip('sNII (<10L)', 'sNII'),
                        _buildCategoryChip('bNII (>10L)', 'bNII'),
                      ],
                    ),

                    // Cut-off price toggle
                    InkWell(
                      onTap: () => setState(() => _isCutoffPrice = !_isCutoffPrice),
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _isCutoffPrice,
                            onChanged: (val) => setState(() => _isCutoffPrice = val ?? true),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          const Text(
                            'Cut-off price',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Lot Selector with MAX button
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BID QUANTITY (LOTS)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: isDark ? Colors.indigo.shade200 : Colors.indigo.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.ipo.lotSize * _lots} shares @ ₹${widget.ipo.pricePerShare.toStringAsFixed(0)} (1 Lot = ${widget.ipo.lotSize} shares • ${CurrencyFormatter.format(widget.ipo.lotCost)})',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Counter with MAX button
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.indigo.shade800 : Colors.indigo.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 16),
                            visualDensity: VisualDensity.compact,
                            onPressed: _lots > 1
                                ? () => setState(() => _lots--)
                                : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '$_lots',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 16),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _lots++),
                          ),
                          const SizedBox(width: 4),
                          // MAX Button
                          InkWell(
                            onTap: () {
                              setState(() {
                                _lots = _maxRetailLots;
                              });
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.indigo.shade900 : Colors.indigo.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'MAX',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.indigo.shade900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Amount block per application
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Per Application Block:',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      '${CurrencyFormatter.format(costPerApp)} (${widget.ipo.lotSize * _lots} × ₹${widget.ipo.pricePerShare.toStringAsFixed(0)})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.indigo.shade200 : Colors.indigo.shade900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // People list header with Select All / Deselect
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SELECT FAMILY PANS (${_selectedPersonIds.length}/${people.length})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.grey.shade600,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedPersonIds.length == people.length) {
                        _selectedPersonIds.clear();
                      } else {
                        _selectedPersonIds.addAll(people.map((p) => p.id));
                      }
                    });
                  },
                  child: Text(
                    _selectedPersonIds.length == people.length ? 'Deselect All' : 'Select All',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // People list with Delta Cards
          Expanded(
            child: people.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'No family accounts added yet.\nGo to People tab to register PANs.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: people.length,
                    itemBuilder: (context, index) {
                      final person = people[index];
                      final isSelected = _selectedPersonIds.contains(person.id);
                      final markFundsSent = _markFundsSentMap[person.id] ?? true;

                      final alreadyApplied = widget.storageService.applications.any(
                        (a) => a.ipoId == widget.ipo.id && a.personId == person.id,
                      );

                      if (alreadyApplied) {
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                          child: ListTile(
                            leading: const Icon(Icons.check_circle, color: Colors.green),
                            title: Text(widget.storageService.formatName(person.name)),
                            subtitle: Text(
                              'Already applied (PAN: ${widget.storageService.formatPan(person.pan)})',
                            ),
                          ),
                        );
                      }

                      return DeltaCard(
                        person: person,
                        storageService: widget.storageService,
                        requiredCost: costPerApp,
                        entries: entries,
                        isSelected: isSelected,
                        onSelectedChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedPersonIds.add(person.id);
                            } else {
                              _selectedPersonIds.remove(person.id);
                            }
                          });
                        },
                        markFundsSent: markFundsSent,
                        onMarkFundsSentChanged: (val) {
                          setState(() {
                            _markFundsSentMap[person.id] = val ?? false;
                          });
                        },
                      );
                    },
                  ),
          ),

          // Bottom Summary & Confirm Action
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181B) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected ${_selectedPersonIds.length} Accounts',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            'Total: ${CurrencyFormatter.format(totalCost)}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Float Used: ${CurrencyFormatter.format(totalFloatUsed)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.teal.shade300 : Colors.teal.shade800,
                            ),
                          ),
                          Text(
                            'Top-up: ${CurrencyFormatter.format(totalFreshCashNeeded)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: totalFreshCashNeeded > 0
                                  ? Colors.orange.shade800
                                  : (isDark ? Colors.teal.shade300 : Colors.teal.shade800),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: (_selectedPersonIds.isEmpty || _isSubmitting)
                          ? null
                          : () async {
                              setState(() => _isSubmitting = true);
                              for (final personId in _selectedPersonIds) {
                                final person = people.firstWhere((p) => p.id == personId);
                                final delta = LedgerService.calculateDelta(
                                  person: person,
                                  requiredCost: costPerApp,
                                  entries: entries,
                                );

                                final bool markSent = _markFundsSentMap[personId] ?? false;
                                final double fundsToAdd = (!delta.isFullyCovered && markSent)
                                    ? delta.amountToSend
                                    : 0.0;

                                await widget.storageService.applyForIpo(
                                  ipo: widget.ipo,
                                  person: person,
                                  lots: _lots,
                                  additionalFundsSent: fundsToAdd,
                                  note: 'Applied for $_lots lot(s) under $_quotaCategory quota',
                                );
                              }

                              if (!context.mounted) return;
                              setState(() => _isSubmitting = false);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Applied for ${_selectedPersonIds.length} accounts ($_lots lots each) in ${widget.ipo.name}!',
                                  ),
                                  backgroundColor: Colors.teal.shade800,
                                ),
                              );
                            },
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        _isSubmitting
                            ? 'Submitting Applications...'
                            : 'CONFIRM & APPLY FOR ${_selectedPersonIds.length} ACCOUNTS',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.indigo.shade800,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, String value) {
    final isSelected = _quotaCategory == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _quotaCategory = value),
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
