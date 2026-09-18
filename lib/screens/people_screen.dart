import 'package:flutter/material.dart';
import '../models/ledger_entry.dart';
import '../models/person.dart';
import '../services/ledger_service.dart';
import '../services/storage_service.dart';
import '../utils/currency_formatter.dart';
import '../widgets/person_float_card.dart';
import 'add_person_screen.dart';
import 'person_detail_screen.dart';

class PeopleScreen extends StatelessWidget {
  final StorageService storageService;

  const PeopleScreen({super.key, required this.storageService});

  @override
  Widget build(BuildContext context) {
    final people = List<Person>.from(storageService.people)..sort((a, b) {
      if (a.isSelf && !b.isSelf) return -1;
      if (!a.isSelf && b.isSelf) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    final entries = storageService.ledgerEntries;
    final apps = storageService.applications;

    double totalFloat = 0.0;
    double totalBlocked = 0.0;
    for (final p in people) {
      totalFloat += LedgerService.calculateAvailableFloat(p.id, entries);
      totalBlocked += LedgerService.calculateBlockedAmount(p.id, apps);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('People & Float Balances'),
      ),
      body: Column(
        children: [
          // Float Summary Banner
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.teal.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Idle Float Available',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal.shade900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(totalFloat),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade900,
                      ),
                    ),
                    Text(
                      'Sitting in bank accounts, ready for next IPO',
                      style: TextStyle(fontSize: 11, color: Colors.teal.shade700),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Locked in Bids',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                    Text(
                      CurrencyFormatter.format(totalBlocked),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                    Text(
                      '${people.length} accounts',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // People List
          Expanded(
            child: people.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_outlined, size: 54, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No family or friends added yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Add PAN accounts to start tracking your capital & float',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _openAddPerson(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Add First Account'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: people.length,
                    itemBuilder: (context, index) {
                      final person = people[index];
                      final summary = LedgerService.getPersonSummary(
                        person: person,
                        entries: entries,
                        applications: apps,
                      );

                      return PersonFloatCard(
                        summary: summary,
                        storageService: storageService,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PersonDetailScreen(
                                person: person,
                                storageService: storageService,
                              ),
                            ),
                          );
                        },
                        onAddFunds: () => _showTransactionDialog(
                          context,
                          person,
                          LedgerEntryType.sendToPerson,
                        ),
                        onReturnFunds: () => _showTransactionDialog(
                          context,
                          person,
                          LedgerEntryType.returnToUser,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddPerson(context),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Person'),
      ),
    );
  }

  void _openAddPerson(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddPersonScreen(storageService: storageService),
      ),
    );
  }

  void _showTransactionDialog(
    BuildContext context,
    Person person,
    LedgerEntryType type,
  ) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final isSend = type == LedgerEntryType.sendToPerson;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isSend ? 'Send Money to ${person.name}' : 'Record Money Returned from ${person.name}',
          style: const TextStyle(fontSize: 16),
        ),
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
                hintText: isSend ? 'Sent for upcoming IPO bids' : 'Unallotted money sent back',
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
                    : (isSend ? 'Fund transfer' : 'Funds returned'),
              );
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }
}
