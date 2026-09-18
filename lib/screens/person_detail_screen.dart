import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ledger_entry.dart';
import '../models/person.dart';
import '../services/ledger_service.dart';
import '../services/storage_service.dart';
import '../utils/currency_formatter.dart';
import 'add_person_screen.dart';

class PersonDetailScreen extends StatelessWidget {
  final Person person;
  final StorageService storageService;

  const PersonDetailScreen({
    super.key,
    required this.person,
    required this.storageService,
  });

  @override
  Widget build(BuildContext context) {
    // Current state from storage
    final currentPerson = storageService.people.firstWhere(
      (p) => p.id == person.id,
      orElse: () => person,
    );

    final summary = LedgerService.getPersonSummary(
      person: currentPerson,
      entries: storageService.ledgerEntries,
      applications: storageService.applications,
    );

    final personEntries = storageService.ledgerEntries
        .where((e) => e.personId == person.id)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(currentPerson.name, overflow: TextOverflow.ellipsis)),
            if (currentPerson.isSelf) ...[
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
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddPersonScreen(
                    storageService: storageService,
                    editingPerson: currentPerson,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Card with Balances
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.indigo.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: currentPerson.pan));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied PAN ${currentPerson.pan}')),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.indigo.shade200),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'PAN: ${storageService.formatPan(currentPerson.pan)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade900,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.copy, size: 14, color: Colors.indigo),
                          ],
                        ),
                      ),
                    ),
                    if (currentPerson.upiId.isNotEmpty)
                      Text(
                        'UPI: ${currentPerson.upiId}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildBalanceBox(
                        title: 'Available Float',
                        amount: summary.availableFloat,
                        color: Colors.teal.shade800,
                        subtitle: 'Ready for next IPO',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBalanceBox(
                        title: 'Locked in Bids',
                        amount: summary.blockedInIpos,
                        color: Colors.amber.shade900,
                        subtitle: '${summary.activeApplicationsCount} active bids',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Ledger Passbook Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Transaction Passbook',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _showAddTransactionDialog(context, LedgerEntryType.sendToPerson),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Send Funds', style: TextStyle(fontSize: 12)),
                    ),
                    TextButton.icon(
                      onPressed: () => _showAddTransactionDialog(context, LedgerEntryType.returnToUser),
                      icon: const Icon(Icons.arrow_downward, size: 16),
                      label: const Text('Returned', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Passbook Entries List
          Expanded(
            child: personEntries.isEmpty
                ? Center(
                    child: Text(
                      'No transactions yet for ${currentPerson.name}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: personEntries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = personEntries[index];
                      return _buildLedgerTile(entry);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceBox({
    required String title,
    required double amount,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.format(amount),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildLedgerTile(LedgerEntry entry) {
    Color amountColor;
    String prefix;
    IconData icon;

    switch (entry.type) {
      case LedgerEntryType.sendToPerson:
        amountColor = Colors.teal.shade800;
        prefix = '+';
        icon = Icons.arrow_upward_rounded;
        break;
      case LedgerEntryType.blockForIpo:
        amountColor = Colors.orange.shade900;
        prefix = '-';
        icon = Icons.lock_outline_rounded;
        break;
      case LedgerEntryType.refundUnblock:
        amountColor = Colors.teal.shade700;
        prefix = '+';
        icon = Icons.replay_rounded;
        break;
      case LedgerEntryType.allotmentDebit:
        amountColor = Colors.blueGrey.shade700;
        prefix = '';
        icon = Icons.check_circle_outline;
        break;
      case LedgerEntryType.returnToUser:
        amountColor = Colors.blueGrey.shade800;
        prefix = '-';
        icon = Icons.arrow_downward_rounded;
        break;
      case LedgerEntryType.profitReceived:
        amountColor = Colors.green.shade800;
        prefix = '+';
        icon = Icons.trending_up_rounded;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: amountColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: amountColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.typeDisplayTitle,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                if (entry.note.isNotEmpty)
                  Text(
                    entry.note,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                Text(
                  CurrencyFormatter.formatDateTime(entry.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Text(
            '$prefix${CurrencyFormatter.format(entry.amount)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTransactionDialog(BuildContext context, LedgerEntryType type) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    final isSend = type == LedgerEntryType.sendToPerson;
    final title = isSend ? 'Record Funds Sent to ${person.name}' : 'Record Funds Returned to You';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: 'Note (Optional)',
                border: const OutlineInputBorder(),
                hintText: isSend ? 'Transferred for IPO bids' : 'Refund transferred back',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amountController.text);
              if (amt == null || amt <= 0) return;
              Navigator.pop(ctx);
              await storageService.addManualTransaction(
                personId: person.id,
                type: type,
                amount: amt,
                note: noteController.text.trim().isNotEmpty
                    ? noteController.text.trim()
                    : (isSend ? 'Manual fund transfer' : 'Funds returned'),
              );
            },
            child: const Text('Save Transaction'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${person.name}?'),
        content: const Text(
          'This will remove this person along with all associated applications and ledger history.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await storageService.deletePerson(person.id);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
