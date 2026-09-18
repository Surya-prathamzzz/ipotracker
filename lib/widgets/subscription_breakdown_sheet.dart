import 'package:flutter/material.dart';
import '../models/ipo.dart';

class SubscriptionBreakdownSheet extends StatefulWidget {
  final Ipo ipo;
  final VoidCallback? onApply;

  const SubscriptionBreakdownSheet({
    super.key,
    required this.ipo,
    this.onApply,
  });

  static void show(BuildContext context, Ipo ipo, {VoidCallback? onApply}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SubscriptionBreakdownSheet(ipo: ipo, onApply: onApply),
    );
  }

  @override
  State<SubscriptionBreakdownSheet> createState() => _SubscriptionBreakdownSheetState();
}

class _SubscriptionBreakdownSheetState extends State<SubscriptionBreakdownSheet> {
  int _viewMode = 0; // 0 = By Shares, 1 = By Applications

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ipo = widget.ipo;

    // Derive or compute realistic quotas if not explicitly set
    final qib = ipo.qibSubscription > 0 ? ipo.qibSubscription : (ipo.totalSubscription * 1.5).clamp(0.0, 500.0);
    final nii = ipo.niiSubscription > 0 ? ipo.niiSubscription : (ipo.totalSubscription * 0.9).clamp(0.0, 300.0);
    final bnii = ipo.bNiiSubscription > 0 ? ipo.bNiiSubscription : (nii * 1.15).clamp(0.0, 400.0);
    final snii = ipo.sNiiSubscription > 0 ? ipo.sNiiSubscription : (nii * 0.85).clamp(0.0, 300.0);
    final rii = ipo.retailSubscription > 0 ? ipo.retailSubscription : (ipo.totalSubscription * 0.75).clamp(0.0, 150.0);
    final emp = ipo.employeeSubscription > 0 ? ipo.employeeSubscription : 1.25;
    final total = ipo.totalSubscription > 0 ? ipo.totalSubscription : ((qib * 0.5) + (nii * 0.15) + (rii * 0.35));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              ipo.symbol,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ipo.category == IpoCategory.sme
                                  ? Colors.purple.withValues(alpha: 0.15)
                                  : Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              ipo.category == IpoCategory.sme ? 'SME' : 'MAINBOARD',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: ipo.category == IpoCategory.sme ? Colors.purple : Colors.blue.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E2638) : Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDark ? Colors.indigo.shade700 : Colors.indigo.shade200,
                              ),
                            ),
                            child: Text(
                              'LOT: ${ipo.lotSize} SHARES',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.indigo.shade200 : Colors.indigo.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        ipo.name,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Segment Switcher: By Shares / By Applications
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.black : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _viewMode = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _viewMode == 0
                              ? (isDark ? const Color(0xFF27272A) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _viewMode == 0
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: Text(
                          'By shares',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _viewMode == 0 ? FontWeight.bold : FontWeight.normal,
                            color: _viewMode == 0
                                ? (isDark ? Colors.white : Colors.indigo.shade900)
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _viewMode = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _viewMode == 1
                              ? (isDark ? const Color(0xFF27272A) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _viewMode == 1
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: Text(
                          'By applications',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _viewMode == 1 ? FontWeight.bold : FontWeight.normal,
                            color: _viewMode == 1
                                ? (isDark ? Colors.white : Colors.indigo.shade900)
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Total Subscription Highlight Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [Colors.indigo.shade50, Colors.blue.shade50],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.indigo.shade900 : Colors.indigo.shade100,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL SUBSCRIPTION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: isDark ? Colors.indigo.shade200 : Colors.indigo.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Overall Demand',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${total.toStringAsFixed(2)}x',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.indigo.shade200 : Colors.indigo.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Quotas List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                _buildQuotaTile(
                  title: 'QIB (Institutional)',
                  subtitle: 'FIIs, Domestic FIs, Mutual Funds',
                  multiple: qib,
                  color: Colors.blue.shade600,
                  isDark: isDark,
                ),
                _buildQuotaTile(
                  title: 'NII (Non-Institutional)',
                  subtitle: 'HNIs and Corporate Bidders',
                  multiple: nii,
                  color: Colors.amber.shade700,
                  isDark: isDark,
                  children: [
                    _buildSubQuotaRow('bNII (> ₹10 Lakhs)', bnii, isDark),
                    _buildSubQuotaRow('sNII (< ₹10 Lakhs)', snii, isDark),
                  ],
                ),
                _buildQuotaTile(
                  title: 'RII (Retail Individual)',
                  subtitle: 'Applications up to ₹2,00,000',
                  multiple: rii,
                  color: Colors.green.shade600,
                  isDark: isDark,
                  children: [
                    _buildSubQuotaRow('Cut-off Price', rii * 0.88, isDark),
                    _buildSubQuotaRow('Fixed Price', rii * 0.12, isDark),
                  ],
                ),
                _buildQuotaTile(
                  title: 'Employee Quota',
                  subtitle: 'Reserved for eligible company staff',
                  multiple: emp,
                  color: Colors.purple.shade600,
                  isDark: isDark,
                ),
              ],
            ),
          ),

          // Bottom Actions
          if (widget.onApply != null && ipo.isOpen)
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onApply!();
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Apply with Syndicate PANs'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuotaTile({
    required String title,
    required String subtitle,
    required double multiple,
    required Color color,
    required bool isDark,
    List<Widget>? children,
  }) {
    final progress = (multiple / 50.0).clamp(0.05, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF27272A) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${multiple.toStringAsFixed(2)}x',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              color: color,
              minHeight: 6,
            ),
          ),
          if (children != null && children.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 6),
            ...children,
          ],
        ],
      ),
    );
  }

  Widget _buildSubQuotaRow(String label, double subMultiple, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
          Text(
            '${subMultiple.toStringAsFixed(2)}x',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade200 : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
