import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipotracker/models/ipo.dart';
import 'package:ipotracker/models/ipo_application.dart';
import 'package:ipotracker/models/ledger_entry.dart';
import 'package:ipotracker/models/person.dart';
import 'package:ipotracker/services/storage_service.dart';
import 'package:ipotracker/widgets/ipo_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService Application Withdrawal & Deletion Tests', () {
    late StorageService storageService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storageService = StorageService();
      await storageService.init();
    });

    test('withdrawApplication marks status as withdrawn and unblocks float in ledger', () async {
      final person = Person(name: 'Test Investor', pan: 'ABCDE1234F');
      await storageService.savePerson(person);

      final ipo = Ipo(
        name: 'Test Open IPO',
        symbol: 'TESTIPO',
        lotSize: 100,
        pricePerShare: 100.0,
        openDate: DateTime.now().subtract(const Duration(days: 1)),
        closeDate: DateTime.now().add(const Duration(days: 1)),
        allotmentDate: DateTime.now().add(const Duration(days: 3)),
      );
      await storageService.saveIpo(ipo);

      // Apply
      await storageService.applyForIpo(
        ipo: ipo,
        person: person,
        lots: 1,
        additionalFundsSent: 10000.0,
      );

      expect(storageService.applications.length, 1);
      expect(storageService.applications.first.status, ApplicationStatus.applied);

      final appId = storageService.applications.first.id;

      // Withdraw
      await storageService.withdrawApplication(applicationId: appId);

      expect(storageService.applications.first.status, ApplicationStatus.withdrawn);

      // Verify refundUnblock ledger entry exists
      final refundEntry = storageService.ledgerEntries.firstWhere(
        (l) => l.type == LedgerEntryType.refundUnblock && l.applicationId == appId,
      );
      expect(refundEntry.amount, 10000.0);
    });

    test('deleteApplication removes application and restores float if active', () async {
      final person = Person(name: 'Accidental Applicant', pan: 'XYZAB5678C');
      await storageService.savePerson(person);

      final ipo = Ipo(
        name: 'Mistake IPO',
        symbol: 'MISTAKE',
        lotSize: 50,
        pricePerShare: 200.0,
        openDate: DateTime.now().subtract(const Duration(days: 1)),
        closeDate: DateTime.now().add(const Duration(days: 1)),
        allotmentDate: DateTime.now().add(const Duration(days: 4)),
      );
      await storageService.saveIpo(ipo);

      await storageService.applyForIpo(
        ipo: ipo,
        person: person,
        lots: 1,
        additionalFundsSent: 10000.0,
      );

      expect(storageService.applications.length, 1);
      final appId = storageService.applications.first.id;

      // Delete the accidental application
      await storageService.deleteApplication(appId);

      expect(storageService.applications.isEmpty, true);

      // Verify refundUnblock entry restored the funds
      final unblockEntry = storageService.ledgerEntries.firstWhere(
        (l) => l.type == LedgerEntryType.refundUnblock && l.applicationId == appId,
      );
      expect(unblockEntry.amount, 10000.0);
    });
  });

  group('IpoCard Strict Lifecycle State Machine Widget Tests', () {
    testWidgets('Open IPO NEVER displays Allotment button even if appliedCount > 0', (tester) async {
      final openIpo = Ipo(
        name: 'Manika Plastech',
        symbol: 'MANIKA',
        lotSize: 348,
        pricePerShare: 43.0,
        openDate: DateTime.now().subtract(const Duration(days: 1)),
        closeDate: DateTime.now().add(const Duration(days: 1)),
        allotmentDate: DateTime.now().add(const Duration(days: 4)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IpoCard(
              ipo: openIpo,
              appliedCount: 2,
              onApply: () {},
              onCheckAllotment: () {},
            ),
          ),
        ),
      );

      // Must show Apply More
      expect(find.text('Apply More'), findsOneWidget);
      // Must show 2 Applied
      expect(find.text('2 Applied'), findsOneWidget);
      // Must NEVER show Allotment button!
      expect(find.text('Allotment'), findsNothing);
      expect(find.text('Check Allotment'), findsNothing);
    });

    testWidgets('Closed IPO awaiting allotment shows View Bids or Bidding Closed, NEVER Apply', (tester) async {
      final closedIpo = Ipo(
        name: 'Veegaland Developers',
        symbol: 'VEEGALAND',
        lotSize: 100,
        pricePerShare: 150.0,
        openDate: DateTime.now().subtract(const Duration(days: 5)),
        closeDate: DateTime.now().subtract(const Duration(days: 2)),
        allotmentDate: DateTime.now().add(const Duration(days: 2)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IpoCard(
              ipo: closedIpo,
              appliedCount: 1,
              onApply: () {},
              onViewApplications: () {},
            ),
          ),
        ),
      );

      // Must show View Bids
      expect(find.text('View Bids (1)'), findsOneWidget);
      // Must NEVER show Apply
      expect(find.text('Apply Syndicate'), findsNothing);
      expect(find.text('Apply More'), findsNothing);
      // Must NEVER show Allotment before allotment date!
      expect(find.text('Check Allotment'), findsNothing);
    });

    testWidgets('Allotted / Listed IPO shows Check Allotment, NEVER Apply', (tester) async {
      final listedIpo = Ipo(
        name: 'Rentomojo Limited',
        symbol: 'RENTOMOJO',
        lotSize: 37,
        pricePerShare: 404.0,
        openDate: DateTime.now().subtract(const Duration(days: 10)),
        closeDate: DateTime.now().subtract(const Duration(days: 6)),
        allotmentDate: DateTime.now().subtract(const Duration(days: 3)),
        listingDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IpoCard(
              ipo: listedIpo,
              appliedCount: 1,
              onApply: () {},
              onCheckAllotment: () {},
            ),
          ),
        ),
      );

      // Must show Check Allotment
      expect(find.text('Check Allotment'), findsOneWidget);
      // Must NEVER show Apply
      expect(find.text('Apply Syndicate'), findsNothing);
      expect(find.text('Apply More'), findsNothing);
    });
  });
}
