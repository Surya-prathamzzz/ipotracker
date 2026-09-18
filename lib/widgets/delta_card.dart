import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ledger_entry.dart';
import '../models/person.dart';
import '../services/ledger_service.dart';
import '../services/storage_service.dart';
import '../services/upi_service.dart';
import '../utils/currency_formatter.dart';

class DeltaCard extends StatelessWidget {
  final Person person;
  final double requiredCost;
  final List<LedgerEntry> entries;
  final bool isSelected;
  final ValueChanged<bool?> onSelectedChanged;
  final bool markFundsSent;
  final ValueChanged<bool?> onMarkFundsSentChanged;
  final StorageService? storageService;

  const DeltaCard({
    super.key,
    required this.person,
    required this.requiredCost,
    required this.entries,
    required this.isSelected,
    required this.onSelectedChanged,
    required this.markFundsSent,
    required this.onMarkFundsSentChanged,
    this.storageService,
  });

  @override
  Widget build(BuildContext context) {
    final delta = LedgerService.calculateDelta(
      person: person,
      requiredCost: requiredCost,
      entries: entries,
    );

    final hasDeficit = !delta.isFullyCovered;
    final displayName = storageService != null ? storageService!.formatName(person.name) : person.name;
    final displayPan = storageService != null ? storageService!.formatPan(person.pan) : person.pan;

    return Card(
      elevation: isSelected ? 3 : 1,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? (hasDeficit ? Colors.orange.shade700 : Colors.teal.shade700)
              : Colors.grey.shade300,
          width: isSelected ? 1.8 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Checkbox + Name + PAN Badge
            Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: onSelectedChanged,
                  activeColor: hasDeficit ? Colors.orange.shade800 : Colors.teal.shade800,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'PAN: $displayPan',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          if (person.bankName.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '• ${person.bankName}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 20),

            // Financial comparison row
            Row(
              children: [
                Expanded(
                  child: _buildMiniStat(
                    label: 'Existing Float',
                    value: CurrencyFormatter.format(delta.availableFloat),
                    color: Colors.blueGrey.shade800,
                  ),
                ),
                Container(width: 1, height: 35, color: Colors.grey.shade300),
                Expanded(
                  child: _buildMiniStat(
                    label: 'Required',
                    value: CurrencyFormatter.format(delta.requiredAmount),
                    color: Colors.black87,
                  ),
                ),
                Container(width: 1, height: 35, color: Colors.grey.shade300),
                Expanded(
                  child: _buildMiniStat(
                    label: hasDeficit ? 'Top-Up Needed' : 'Surplus Float',
                    value: hasDeficit
                        ? '+${CurrencyFormatter.format(delta.amountToSend)}'
                        : CurrencyFormatter.format(delta.surplus),
                    color: hasDeficit ? Colors.orange.shade900 : Colors.teal.shade800,
                    isBold: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Status Banner / Action Section
            if (hasDeficit) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 20, color: Colors.orange.shade900),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Need to send ${CurrencyFormatter.format(delta.amountToSend)} more into ${person.name.split(' ').first}\'s account.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // UPI Action Button
                        if (person.upiId.isNotEmpty)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final success = await UpiService.launchUpiPayment(
                                  upiId: person.upiId,
                                  payeeName: person.name,
                                  amount: delta.amountToSend,
                                  note: 'IPO Top-up ${person.name}',
                                );
                                if (!context.mounted) return;
                                if (!success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Copied ${person.upiId} to clipboard for manual transfer.'),
                                      backgroundColor: Colors.blueGrey,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.payment, size: 16),
                              label: Text(
                                'Pay ${CurrencyFormatter.format(delta.amountToSend)} (UPI)',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade800,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                if (person.phone.isNotEmpty) {
                                  Clipboard.setData(ClipboardData(text: person.phone));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Copied phone number ${person.phone}')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.copy, size: 14),
                              label: const Text('Copy Details to Transfer', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (isSelected) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: markFundsSent,
                            onChanged: onMarkFundsSentChanged,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            activeColor: Colors.orange.shade800,
                          ),
                          Expanded(
                            child: Text(
                              'Record ₹${delta.amountToSend.toStringAsFixed(0)} transfer in ledger when applying',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 20, color: Colors.teal.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Fully covered! ₹${delta.surplus.toStringAsFixed(0)} float will remain after bidding.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat({
    required String label,
    required String value,
    required Color color,
    bool isBold = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
