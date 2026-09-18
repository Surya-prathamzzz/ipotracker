import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ledger_service.dart';
import '../services/storage_service.dart';
import '../utils/currency_formatter.dart';

class PersonFloatCard extends StatelessWidget {
  final PersonFinancialSummary summary;
  final VoidCallback onTap;
  final VoidCallback onAddFunds;
  final VoidCallback onReturnFunds;
  final StorageService? storageService;

  const PersonFloatCard({
    super.key,
    required this.summary,
    required this.onTap,
    required this.onAddFunds,
    required this.onReturnFunds,
    this.storageService,
  });

  @override
  Widget build(BuildContext context) {
    final person = summary.person;
    final displayName = storageService != null ? storageService!.formatName(person.name) : person.name;
    final displayPan = storageService != null ? storageService!.formatPan(person.pan) : person.pan;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Name, PAN, More / Actions
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.indigo.shade50,
                    foregroundColor: Colors.indigo.shade800,
                    child: Text(
                      person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (person.isSelf) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade800,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'YOU',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: person.pan));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Copied PAN ${person.pan}')),
                                );
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      displayPan,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blueGrey.shade900,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.copy, size: 10, color: Colors.grey.shade600),
                                  ],
                                ),
                              ),
                            ),
                            if (person.bankName.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${person.bankName} ${person.accountNumber}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),

              const Divider(height: 24),

              // Float Balance Highlight
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: summary.availableFloat > 0
                      ? Colors.teal.shade50.withValues(alpha: 0.6)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: summary.availableFloat > 0
                        ? Colors.teal.shade300
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Available Float',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blueGrey.shade800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Tooltip(
                              message: 'Unblocked cash currently in their account, available for next IPO',
                              child: Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.format(summary.availableFloat),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: summary.availableFloat > 0
                                ? Colors.teal.shade800
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _buildActionButton(
                          icon: Icons.add,
                          label: 'Send Funds',
                          color: Colors.indigo,
                          onPressed: onAddFunds,
                        ),
                        const SizedBox(width: 8),
                        if (summary.availableFloat > 0)
                          _buildActionButton(
                            icon: Icons.arrow_downward,
                            label: 'Return',
                            color: Colors.blueGrey,
                            onPressed: onReturnFunds,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Sub-metrics: Blocked & Total Capital
              Row(
                children: [
                  Expanded(
                    child: _buildSubMetric(
                      label: 'Locked in Bids',
                      value: CurrencyFormatter.format(summary.blockedInIpos),
                      color: Colors.amber.shade900,
                      count: summary.activeApplicationsCount > 0
                          ? '${summary.activeApplicationsCount} active'
                          : null,
                    ),
                  ),
                  Container(width: 1, height: 30, color: Colors.grey.shade300),
                  Expanded(
                    child: _buildSubMetric(
                      label: 'Total Capital',
                      value: CurrencyFormatter.format(summary.totalCapitalWithPerson),
                      color: Colors.blue.shade900,
                      count: 'Float + Bids',
                    ),
                  ),
                  if (summary.totalProfitRealized > 0) ...[
                    Container(width: 1, height: 30, color: Colors.grey.shade300),
                    Expanded(
                      child: _buildSubMetric(
                        label: 'Total Profit',
                        value: '+${CurrencyFormatter.format(summary.totalProfitRealized)}',
                        color: Colors.green.shade800,
                        count: '${summary.totalAllotmentsCount} allotted',
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required MaterialColor color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color.shade800),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubMetric({
    required String label,
    required String value,
    required Color color,
    String? count,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        if (count != null)
          Text(
            count,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
      ],
    );
  }
}
