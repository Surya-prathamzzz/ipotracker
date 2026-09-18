import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ipo.dart';
import '../models/ipo_application.dart';
import '../models/person.dart';
import '../services/storage_service.dart';
import '../services/upi_service.dart';
import '../utils/currency_formatter.dart';
import 'allotment_checker_screen.dart';

class ApplicationsScreen extends StatefulWidget {
  final StorageService storageService;
  final String? filterIpoId;

  const ApplicationsScreen({
    super.key,
    required this.storageService,
    this.filterIpoId,
  });

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  ApplicationStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    if (widget.filterIpoId == null) {
      _filterStatus = widget.storageService.appStatusFilter;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allApps = widget.storageService.applications;
    final peopleMap = {for (var p in widget.storageService.people) p.id: p};
    final ipoMap = {for (var i in widget.storageService.ipos) i.id: i};

    final scopedApps = widget.filterIpoId != null
        ? allApps.where((a) => a.ipoId == widget.filterIpoId).toList()
        : allApps;

    final filteredApps = _filterStatus == null
        ? scopedApps
        : scopedApps.where((a) => a.status == _filterStatus).toList();

    final ipoTitle = widget.filterIpoId != null ? ipoMap[widget.filterIpoId]?.name : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(ipoTitle != null ? 'Bids: $ipoTitle' : 'Applications & Allotment'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Allotment & Float Explanation',
            onPressed: () => _showAllotmentExplanationDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('All (${scopedApps.length})', null),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Pending (${scopedApps.where((a) => a.status == ApplicationStatus.applied).length})',
                  ApplicationStatus.applied,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Allotted (${scopedApps.where((a) => a.status == ApplicationStatus.allotted).length})',
                  ApplicationStatus.allotted,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Not Allotted (${scopedApps.where((a) => a.status == ApplicationStatus.notAllotted).length})',
                  ApplicationStatus.notAllotted,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Withdrawn (${scopedApps.where((a) => a.status == ApplicationStatus.withdrawn).length})',
                  ApplicationStatus.withdrawn,
                ),
              ],
            ),
          ),

          // Applications List
          Expanded(
            child: filteredApps.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No applications in this category',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredApps.length,
                    itemBuilder: (context, index) {
                      final app = filteredApps[index];
                      final person = peopleMap[app.personId] ??
                          Person(name: 'Unknown Person', pan: 'UNKNOWN');
                      final ipo = ipoMap[app.ipoId] ??
                          Ipo(
                            name: 'Unknown IPO',
                            symbol: 'IPO',
                            lotSize: 1,
                            pricePerShare: app.amountBlocked,
                            openDate: DateTime.now(),
                            closeDate: DateTime.now(),
                            allotmentDate: DateTime.now(),
                          );

                      return _buildApplicationCard(context, app, person, ipo);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, ApplicationStatus? status) {
    final isSelected = _filterStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _filterStatus = status;
        });
        if (widget.filterIpoId == null) {
          widget.storageService.setAppStatusFilter(status);
        }
      },
      selectedColor: Colors.indigo.shade100,
      checkmarkColor: Colors.indigo.shade900,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.indigo.shade900 : Colors.grey.shade800,
      ),
    );
  }

  Widget _buildApplicationCard(
    BuildContext context,
    IpoApplication app,
    Person person,
    Ipo ipo,
  ) {
    Color statusColor;
    IconData statusIcon;
    switch (app.status) {
      case ApplicationStatus.applied:
        statusColor = Colors.orange.shade800;
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case ApplicationStatus.allotted:
        statusColor = Colors.green.shade800;
        statusIcon = Icons.check_circle_rounded;
        break;
      case ApplicationStatus.notAllotted:
        statusColor = Colors.blueGrey.shade700;
        statusIcon = Icons.replay_rounded;
        break;
      case ApplicationStatus.withdrawn:
        statusColor = Colors.red.shade700;
        statusIcon = Icons.cancel_outlined;
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: IPO Name & Status badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ipo.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Applied: ${CurrencyFormatter.formatDate(app.appliedAt)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        app.status.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                  tooltip: 'Delete application record',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => _confirmDeleteApplication(context, app, person, ipo),
                ),
              ],
            ),

            const Divider(height: 20),

            // Person Details & PAN copy
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.indigo.shade50,
                  foregroundColor: Colors.indigo.shade800,
                  child: Text(
                    person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.storageService.formatName(person.name),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      Row(
                        children: [
                          Text(
                            'PAN: ${widget.storageService.formatPan(person.pan)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
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
                            child: Icon(Icons.copy, size: 14, color: Colors.indigo.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(app.amountBlocked),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${app.lots} lot (${app.lots * ipo.lotSize} sh)',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Check Registrar link & Actions
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => UpiService.launchWebUrl(ipo.portalUrl),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: Text(
                    'Portal (${ipo.registrar.displayName})',
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AllotmentCheckerScreen(
                          ipo: ipo,
                          storageService: widget.storageService,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.verified_outlined, size: 14),
                  label: const Text(
                    'In-App Checker',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade50,
                    foregroundColor: Colors.indigo.shade900,
                    elevation: 0,
                    side: BorderSide(color: Colors.indigo.shade200),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),

                // Status changer buttons if still pending
                if (app.status == ApplicationStatus.applied) ...[
                  // Withdraw Bid Button -> Restores Float!
                  TextButton.icon(
                    onPressed: () => _confirmWithdraw(context, app, person, ipo),
                    icon: const Icon(Icons.undo_rounded, size: 15, color: Colors.deepOrange),
                    label: const Text(
                      'Withdraw Bid',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Not Allotted Button -> Restores Float!
                  TextButton.icon(
                    onPressed: () => _confirmNotAllotted(context, app, person, ipo),
                    icon: const Icon(Icons.close, size: 15, color: Colors.blueGrey),
                    label: const Text(
                      'Not Allotted',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Allotted Button
                  ElevatedButton.icon(
                    onPressed: () => _confirmAllotted(context, app, person, ipo),
                    icon: const Icon(Icons.celebration, size: 14),
                    label: const Text(
                      'Allotted',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ] else if (app.status == ApplicationStatus.withdrawn) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '⚡ Bid Withdrawn • Float restored to ${person.name.split(' ').first}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange.shade900,
                      ),
                    ),
                  ),
                ] else if (app.status == ApplicationStatus.notAllotted) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '⚡ Float restored to ${person.name.split(' ').first}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade900,
                      ),
                    ),
                  ),
                ] else if (app.status == ApplicationStatus.allotted) ...[
                  if (app.profitRealized != null)
                    Text(
                      'Profit: +${CurrencyFormatter.format(app.profitRealized!)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: () => _recordSaleGain(context, app, person, ipo),
                      child: const Text('Record Sale Proceeds', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmWithdraw(
    BuildContext context,
    IpoApplication app,
    Person person,
    Ipo ipo,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Bid?'),
        content: Text(
          'Withdraw ${person.name}\'s bid for ${ipo.name}?\n\n'
          '⚡ This will cancel the application and immediately unblock ${CurrencyFormatter.format(app.amountBlocked)} back to ${person.name}\'s available float balance.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep Bid')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.storageService.withdrawApplication(applicationId: app.id);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Withdrew bid. Unblocked ${CurrencyFormatter.format(app.amountBlocked)} back to ${person.name}!',
                  ),
                  backgroundColor: Colors.teal.shade800,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange.shade800,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Withdrawal & Unblock'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteApplication(
    BuildContext context,
    IpoApplication app,
    Person person,
    Ipo ipo,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Application Record?'),
        content: Text(
          'Permanently remove this application record for ${person.name} (${ipo.name})?\n\n'
          '${app.status == ApplicationStatus.applied ? "⚡ Since this bid is currently active, deleting it will restore ${CurrencyFormatter.format(app.amountBlocked)} back to available float." : "This removes the entry from your history."}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.storageService.deleteApplication(app.id);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted application for ${person.name}'),
                  backgroundColor: Colors.blueGrey.shade800,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Record'),
          ),
        ],
      ),
    );
  }

  void _confirmNotAllotted(
    BuildContext context,
    IpoApplication app,
    Person person,
    Ipo ipo,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm: Not Allotted'),
        content: Text(
          'Mark ${ipo.name} as Not Allotted for ${person.name}?\n\n'
          '⚡ This will automatically restore ${CurrencyFormatter.format(app.amountBlocked)} back into ${person.name}\'s Available Float so you can reuse it for the next IPO!',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.storageService.updateApplicationStatus(
                applicationId: app.id,
                newStatus: ApplicationStatus.notAllotted,
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Unblocked ${CurrencyFormatter.format(app.amountBlocked)} back to ${person.name}\'s float balance!',
                  ),
                  backgroundColor: Colors.teal.shade800,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey.shade800,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm & Unblock Float'),
          ),
        ],
      ),
    );
  }

  void _confirmAllotted(
    BuildContext context,
    IpoApplication app,
    Person person,
    Ipo ipo,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🎉 Congratulations on Allotment!'),
        content: Text(
          'Mark ${ipo.name} as Allotted for ${person.name}?\n\n'
          'This will record the funds (${CurrencyFormatter.format(app.amountBlocked)}) as successfully debited for ${app.lots * ipo.lotSize} shares.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.storageService.updateApplicationStatus(
                applicationId: app.id,
                newStatus: ApplicationStatus.allotted,
                sharesAllotted: app.lots * ipo.lotSize,
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Allotment recorded successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Allotment'),
          ),
        ],
      ),
    );
  }

  void _recordSaleGain(
    BuildContext context,
    IpoApplication app,
    Person person,
    Ipo ipo,
  ) {
    final priceController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Listing Sale Price'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shares: ${app.sharesAllotted} shares'),
            Text('Issue Price: ₹${ipo.pricePerShare.toStringAsFixed(0)}'),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Selling Price per Share (₹)',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final soldPrice = double.tryParse(priceController.text);
              if (soldPrice == null) return;
              Navigator.pop(ctx);
              await widget.storageService.updateApplicationStatus(
                applicationId: app.id,
                newStatus: ApplicationStatus.allotted,
                sharesAllotted: app.sharesAllotted,
                soldPricePerShare: soldPrice,
              );
            },
            child: const Text('Save Sale Gain'),
          ),
        ],
      ),
    );
  }

  void _showAllotmentExplanationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How Float Recovery Works'),
        content: const Text(
          '1. When you check your allotment on registrar portals, if an application was not allotted, tap "Not Allotted".\n\n'
          '2. The app automatically unblocks the exact funds back into that person\'s Available Float.\n\n'
          '3. When the next IPO arrives, the Smart Delta calculator automatically subtracts this idle money, so you only transfer the difference needed!',
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
        ],
      ),
    );
  }
}
