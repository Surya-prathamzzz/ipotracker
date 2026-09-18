import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ipo.dart';
import '../models/ipo_application.dart';
import '../models/person.dart';
import '../services/allotment_checker_service.dart';
import '../services/storage_service.dart';
import '../services/upi_service.dart';
import '../utils/currency_formatter.dart';
import 'apply_ipo_screen.dart';

class AllotmentCheckerScreen extends StatefulWidget {
  final Ipo ipo;
  final StorageService storageService;

  const AllotmentCheckerScreen({
    super.key,
    required this.ipo,
    required this.storageService,
  });

  @override
  State<AllotmentCheckerScreen> createState() => _AllotmentCheckerScreenState();
}

class _AllotmentCheckerScreenState extends State<AllotmentCheckerScreen> {
  bool _isChecking = false;
  List<AllotmentCheckResult>? _results;

  @override
  void initState() {
    super.initState();
    // Auto-run allotment verification across all family accounts when opening
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.storageService.people.isNotEmpty) {
        _runBatchCheck();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allPeople = widget.storageService.people;
    final ipoApps = widget.storageService.applications
        .where((a) => a.ipoId == widget.ipo.id)
        .toList();

    // Map applications by personId
    final appByPersonId = {for (final a in ipoApps) a.personId: a};

    final appliedPeople = allPeople.where((p) => appByPersonId.containsKey(p.id)).toList();
    final notAppliedPeople = allPeople.where((p) => !appByPersonId.containsKey(p.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Allotment Status', style: TextStyle(fontSize: 16)),
            Text(
              widget.ipo.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isChecking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh / Check Now',
            onPressed: (_isChecking || allPeople.isEmpty) ? null : _runBatchCheck,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open ${widget.ipo.registrar.displayName} Portal',
            onPressed: () => UpiService.launchWebUrl(widget.ipo.portalUrl),
          ),
        ],
      ),
      body: Column(
        children: [
          // IPO Registrar & Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? const Color(0xFF1E293B) : Colors.indigo.shade50,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registrar: ${widget.ipo.registrar.displayName}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF93C5FD) : Colors.indigo.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Allotment Date: ${CurrencyFormatter.formatDate(widget.ipo.allotmentDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.ipo.isAllotmentOut
                        ? (isDark ? Colors.green.shade900.withValues(alpha: 0.4) : Colors.green.shade50)
                        : (isDark ? Colors.amber.shade900.withValues(alpha: 0.4) : Colors.amber.shade50),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.ipo.isAllotmentOut ? Colors.green.shade400 : Colors.amber.shade400,
                    ),
                  ),
                  child: Text(
                    widget.ipo.isAllotmentOut ? 'Allotment Out' : 'Expected Soon',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: widget.ipo.isAllotmentOut
                          ? (isDark ? Colors.green.shade300 : Colors.green.shade900)
                          : (isDark ? Colors.amber.shade300 : Colors.amber.shade900),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: allPeople.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_off_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No family PANs registered yet',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Add family members in the People tab to track allotment.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Scorecard Summary (if results are available or applications exist)
                      if (_results != null) ...[
                        _buildScorecard(_results!, isDark),
                        const SizedBox(height: 16),
                      ],

                      // Section 1 & 2: Applied Accounts & Family Accounts
                      if (appliedPeople.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Applied Accounts (${appliedPeople.length})',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            if (_results == null && !_isChecking)
                              Text(
                                'Ready to verify',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...appliedPeople.map((person) {
                          final app = appByPersonId[person.id]!;
                          AllotmentCheckResult? result;
                          if (_results != null) {
                            try {
                              result = _results!.firstWhere((r) => r.personId == person.id);
                            } catch (_) {}
                          }
                          return _buildPersonAllotmentCard(
                            person: person,
                            app: app,
                            result: result,
                            isDark: isDark,
                          );
                        }),
                        if (notAppliedPeople.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Other Family Accounts (${notAppliedPeople.length})',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                ),
                              ),
                              if (_results != null)
                                Text(
                                  'Checked via Registrar',
                                  style: TextStyle(fontSize: 12, color: Colors.teal.shade600),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...notAppliedPeople.map((person) {
                            AllotmentCheckResult? result;
                            if (_results != null) {
                              try {
                                result = _results!.firstWhere((r) => r.personId == person.id);
                              } catch (_) {}
                            }
                            return _buildPersonAllotmentCard(
                              person: person,
                              app: null,
                              result: result,
                              isDark: isDark,
                            );
                          }),
                        ],
                      ] else ...[
                        // All syndicate members together when no local application was recorded
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Family Accounts (${allPeople.length})',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            if (_results != null)
                              Text(
                                'Checked via Registrar',
                                style: TextStyle(fontSize: 12, color: Colors.teal.shade600),
                              )
                            else if (!_isChecking)
                              Text(
                                'Ready to check',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...allPeople.map((person) {
                          AllotmentCheckResult? result;
                          if (_results != null) {
                            try {
                              result = _results!.firstWhere((r) => r.personId == person.id);
                            } catch (_) {}
                          }
                          return _buildPersonAllotmentCard(
                            person: person,
                            app: null,
                            result: result,
                            isDark: isDark,
                          );
                        }),
                      ],
                    ],
                  ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121212) : Colors.white,
              border: isDark ? Border(top: BorderSide(color: Colors.grey.shade800, width: 0.5)) : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: _results == null
                  ? SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: (_isChecking || allPeople.isEmpty) ? null : _runBatchCheck,
                        icon: _isChecking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.flash_on, size: 20),
                        label: Text(
                          _isChecking
                              ? 'Checking Registrar Across All PANs...'
                              : 'Check Allotment for All Accounts (${allPeople.length})',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade800,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _runBatchCheck,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Re-check'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _applyResultsToPortfolio,
                            icon: const Icon(Icons.sync, size: 18),
                            label: const Text(
                              'Sync Float Balance',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
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

  Widget _buildScorecard(List<AllotmentCheckResult> results, bool isDark) {
    final allottedCount = results.where((r) => r.isAllotted).length;
    final notAllottedCount = results.where((r) => r.isNotAllotted).length;
    final notAppliedCount = results.where((r) => r.isNotApplied).length;
    final appliedCount = results.where((r) => !r.isNotApplied).length;
    final totalRecoveredFloat = results
        .where((r) => r.isNotAllotted)
        .fold<double>(0.0, (sum, r) => sum + r.amountBlocked);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: allottedCount > 0
            ? (isDark ? Colors.green.shade900.withValues(alpha: 0.3) : Colors.green.shade50)
            : (isDark ? Colors.teal.shade900.withValues(alpha: 0.3) : Colors.teal.shade50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allottedCount > 0 ? Colors.green.shade400 : Colors.teal.shade400,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allottedCount > 0 ? Icons.celebration : Icons.insights,
                color: allottedCount > 0 ? Colors.green.shade600 : Colors.teal.shade600,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                allottedCount > 0
                    ? '🎉 Allotment Scorecard: $allottedCount Winner(s)!'
                    : (appliedCount == 0 ? 'Allotment Scorecard: 0 Bids Placed' : 'Allotment Scorecard: 0 Allotted'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: allottedCount > 0
                      ? (isDark ? Colors.green.shade300 : Colors.green.shade900)
                      : (isDark ? Colors.teal.shade300 : Colors.teal.shade900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Allotted', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
                    Text(
                      '$allottedCount / $appliedCount',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: allottedCount > 0 ? Colors.green.shade600 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Not Allotted', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
                    Text(
                      '$notAllottedCount',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey.shade300 : Colors.blueGrey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              if (notAppliedCount > 0)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Not Applied', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
                      Text(
                        '$notAppliedCount',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (totalRecoveredFloat > 0)
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Float to Restore', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
                      Text(
                        CurrencyFormatter.format(totalRecoveredFloat),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.teal.shade300 : Colors.teal.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonAllotmentCard({
    required Person person,
    required IpoApplication? app,
    required AllotmentCheckResult? result,
    required bool isDark,
  }) {
    Color badgeColor = Colors.grey.shade600;
    Color badgeBgColor = isDark ? Colors.grey.shade900 : Colors.grey.shade100;
    String badgeText = 'Not Applied';
    IconData badgeIcon = Icons.remove_circle_outline;

    if (result != null) {
      if (result.isAllotted) {
        badgeColor = Colors.green.shade600;
        badgeBgColor = isDark ? badgeColor.withValues(alpha: 0.2) : Colors.green.shade50;
        badgeText = '${result.sharesAllotted > 0 ? result.sharesAllotted : widget.ipo.lotSize} Shares Allotted 🎉';
        badgeIcon = Icons.check_circle;
      } else if (result.isNotAllotted) {
        badgeColor = Colors.orange.shade700;
        badgeBgColor = isDark ? badgeColor.withValues(alpha: 0.2) : Colors.orange.shade50;
        badgeText = 'Not Allotted';
        badgeIcon = Icons.cancel;
      } else if (result.isNotApplied) {
        badgeColor = Colors.grey.shade600;
        badgeBgColor = isDark ? Colors.grey.shade900 : Colors.grey.shade100;
        badgeText = 'Not Applied';
        badgeIcon = Icons.remove_circle_outline;
      } else {
        badgeColor = Colors.blue.shade600;
        badgeBgColor = isDark ? badgeColor.withValues(alpha: 0.2) : Colors.blue.shade50;
        badgeText = 'Awaiting';
        badgeIcon = Icons.schedule;
      }
    } else if (app != null) {
      // Based on existing app status
      if (app.status == ApplicationStatus.allotted) {
        badgeColor = Colors.green.shade600;
        badgeBgColor = isDark ? badgeColor.withValues(alpha: 0.2) : Colors.green.shade50;
        badgeText = '${app.sharesAllotted > 0 ? app.sharesAllotted : (app.lots * widget.ipo.lotSize)} Shares Allotted 🎉';
        badgeIcon = Icons.check_circle;
      } else if (app.status == ApplicationStatus.notAllotted) {
        badgeColor = Colors.orange.shade700;
        badgeBgColor = isDark ? badgeColor.withValues(alpha: 0.2) : Colors.orange.shade50;
        badgeText = 'Not Allotted';
        badgeIcon = Icons.cancel;
      } else if (app.status == ApplicationStatus.withdrawn) {
        badgeColor = Colors.red.shade700;
        badgeBgColor = isDark ? badgeColor.withValues(alpha: 0.2) : Colors.red.shade50;
        badgeText = 'Withdrawn';
        badgeIcon = Icons.cancel_outlined;
      } else {
        badgeColor = Colors.blue.shade600;
        badgeBgColor = isDark ? badgeColor.withValues(alpha: 0.2) : Colors.blue.shade50;
        badgeText = 'Applied (Awaiting)';
        badgeIcon = Icons.hourglass_top_rounded;
      }
    }

    final displayName = widget.storageService.formatName(person.name);
    final displayPan = widget.storageService.formatPan(person.pan);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDark ? BorderSide(color: Colors.grey.shade800, width: 0.5) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.indigo.shade50,
              foregroundColor: isDark ? const Color(0xFF93C5FD) : Colors.indigo.shade800,
              radius: 18,
              child: Text(
                person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'PAN: $displayPan',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: person.pan));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied ${person.name}\'s PAN: ${person.pan}'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Icon(Icons.copy, size: 12, color: isDark ? Colors.blue.shade300 : Colors.indigo.shade600),
                      ),
                    ],
                  ),
                  if (result != null) ...[
                    if (!result.isNotApplied) ...[
                      const SizedBox(height: 3),
                      Text(
                        result.message,
                        style: TextStyle(fontSize: 12, color: badgeColor, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ] else if (app != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      '${app.lots} lot(s) • ${CurrencyFormatter.format(app.amountBlocked)} blocked',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
            // Only show Apply button if user has not applied AND the IPO is genuinely still open AND we haven't checked result!
            // Never show Apply on closed, allotted, or listed IPOs.
            if (app == null && widget.ipo.isOpen && result == null)
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ApplyIpoScreen(
                        ipo: widget.ipo,
                        storageService: widget.storageService,
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(60, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Apply', style: TextStyle(fontSize: 12)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 13, color: badgeColor),
                    const SizedBox(width: 5),
                    Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _runBatchCheck() async {
    setState(() => _isChecking = true);

    final results = await AllotmentCheckerService.checkAllotmentBatch(
      ipo: widget.ipo,
      people: widget.storageService.people,
      applications: widget.storageService.applications,
    );

    if (mounted) {
      setState(() {
        _results = results;
        _isChecking = false;
      });
    }
  }

  Future<void> _applyResultsToPortfolio() async {
    if (_results == null) return;

    int unblockedCount = 0;
    int allottedCount = 0;

    for (final res in _results!) {
      try {
        final app = widget.storageService.applications.firstWhere(
          (a) => a.ipoId == widget.ipo.id && a.personId == res.personId,
        );

        if (res.isNotAllotted && app.status != ApplicationStatus.notAllotted) {
          await widget.storageService.updateApplicationStatus(
            applicationId: app.id,
            newStatus: ApplicationStatus.notAllotted,
          );
          unblockedCount++;
        } else if (res.isAllotted && app.status != ApplicationStatus.allotted) {
          await widget.storageService.updateApplicationStatus(
            applicationId: app.id,
            newStatus: ApplicationStatus.allotted,
            sharesAllotted: res.sharesAllotted,
          );
          allottedCount++;
        }
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Updated portfolio: $allottedCount allotted, $unblockedCount unblocked to float!',
        ),
        backgroundColor: Colors.teal.shade800,
      ),
    );
  }
}
