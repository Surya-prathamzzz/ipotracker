import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ipotracker/models/ipo.dart';
import 'package:ipotracker/models/ipo_application.dart';
import 'package:ipotracker/services/storage_service.dart';
import 'package:ipotracker/widgets/ipo_card.dart';
import 'package:ipotracker/screens/apply_ipo_screen.dart';
import 'package:ipotracker/widgets/subscription_breakdown_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IPO Model Data Integrity & Mathematical Invariants', () {
    test('lotCost is always locked to lotSize * pricePerShare', () {
      final ipo = Ipo(
        name: 'SS Retail Ltd',
        symbol: 'SSRETAIL',
        lotSize: 35,
        pricePerShare: 424.0,
        lotCost: 99999.0, // Erroneous input passed from external source
        openDate: DateTime.now().subtract(const Duration(days: 1)),
        closeDate: DateTime.now().add(const Duration(days: 2)),
        allotmentDate: DateTime.now().add(const Duration(days: 4)),
      );

      // Must mathematically equal 35 * 424 = 14840, ignoring erroneous input
      expect(ipo.lotCost, equals(14840.0));
    });

    test('minPrice and maxPrice automatically swap if minPrice > maxPrice', () {
      final ipo = Ipo(
        name: 'Test IPO',
        symbol: 'TEST',
        lotSize: 10,
        pricePerShare: 200,
        minPrice: 220.0,
        maxPrice: 190.0, // Inverted bounds
        openDate: DateTime.now(),
        closeDate: DateTime.now().add(const Duration(days: 2)),
        allotmentDate: DateTime.now().add(const Duration(days: 4)),
      );

      expect(ipo.minPrice, equals(190.0));
      expect(ipo.maxPrice, equals(220.0));
    });

    test('Active/open IPO can NEVER be isListed or isAllotmentOut even if dates are corrupted', () {
      final now = DateTime.now();
      final openIpo = Ipo(
        name: 'National Stock Exchange',
        symbol: 'NSE',
        lotSize: 8,
        pricePerShare: 1785.0,
        openDate: now.subtract(const Duration(hours: 2)),
        closeDate: now.add(const Duration(days: 3)), // Closes in 3 days!
        allotmentDate: now.subtract(const Duration(days: 1)), // Corrupted date in past
        listingDate: now.subtract(const Duration(days: 2)), // Corrupted date in past
      );

      expect(openIpo.isOpen, isTrue);
      expect(openIpo.isClosed, isFalse);
      expect(openIpo.isListed, isFalse);
      expect(openIpo.isAllotmentOut, isFalse);
    });

    test('isClosed respects 17:00 IST market close and past close dates', () {
      final now = DateTime.now();
      final pastCloseIpo = Ipo(
        name: 'Manika Plastech Ltd',
        symbol: 'MANIKA',
        lotSize: 348,
        pricePerShare: 43.0,
        openDate: now.subtract(const Duration(days: 5)),
        closeDate: now.subtract(const Duration(days: 1)), // Closed yesterday
        allotmentDate: now.add(const Duration(days: 1)),
      );

      expect(pastCloseIpo.isClosed, isTrue);
      expect(pastCloseIpo.isOpen, isFalse);
    });
  });

  group('StorageService Auto-Healing on Boot', () {
    test('auto-heals corrupted cache records on init', () async {
      SharedPreferences.setMockInitialValues({
        'ipotracker_ipos': jsonEncode([
          {
            'id': 'corrupted-ssretail',
            'name': 'SS Retail Ltd',
            'symbol': 'SSRETAIL',
            'lotSize': 35,
            'pricePerShare': 424.0,
            'lotCost': 5000.0, // Corrupted lotCost
            'category': 'mainboard',
            'openDate': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
            'closeDate': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
            'allotmentDate': DateTime.now().add(const Duration(days: 4)).toIso8601String(),
            'listingDate': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), // Erroneous past listing date
            'listingPrice': 500.0, // Erroneous listing price on open IPO
            'currentPrice': 520.0, // Erroneous current price on open IPO
            'naradaId': 9999, // Wrong naradaId
            'registrar': 'kfintech',
            'customRegistrarUrl': '',
            'gmp': 124.0,
            'gmpTrend': 'up',
            'retailSubscription': 3.5,
            'totalSubscription': 3.5,
          }
        ]),
      });

      final storage = StorageService();
      await storage.init();

      final ssRetail = storage.ipos.firstWhere((i) => i.symbol == 'SSRETAIL');
      expect(ssRetail.lotCost, equals(14840.0)); // 35 * 424 healed!
      expect(ssRetail.naradaId, equals(1088)); // Official ID healed!
      expect(ssRetail.listingPrice, isNull); // Erroneous price purged!
      expect(ssRetail.currentPrice, isNull); // Erroneous price purged!
      expect(ssRetail.isOpen, isTrue);
    });
  });

  group('UI Lot Size Visibility Verification', () {
    testWidgets('IpoCard displays issue size near date in Zone 4 and lot info in Zone 2', (tester) async {
      final ipo = Ipo(
        name: 'SS Retail Ltd',
        symbol: 'SSRETAIL',
        lotSize: 35,
        pricePerShare: 424.0,
        minPrice: 403.0,
        maxPrice: 424.0,
        issueSizeCrores: 500.0,
        openDate: DateTime.now().subtract(const Duration(days: 1)),
        closeDate: DateTime.now().add(const Duration(days: 1)),
        allotmentDate: DateTime.now().add(const Duration(days: 3)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IpoCard(
              ipo: ipo,
              appliedCount: 0,
              onApply: () {},
            ),
          ),
        ),
      );

      // Top middle should NOT show number of shares pill
      expect(find.text('35 SHARES'), findsNothing);
      // Issue size displayed near date in Zone 4
      expect(find.text('₹500 Cr'), findsOneWidget);
      // Zone 2 label & subtext
      expect(find.text('PRICE (LOT: 35)'), findsOneWidget);
      expect(find.textContaining('35 shares • ₹14,840'), findsOneWidget);
    });

    testWidgets('ApplyIpoScreen displays lot size breakdown in bid quantity row', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      final ipo = Ipo(
        name: 'SS Retail Ltd',
        symbol: 'SSRETAIL',
        lotSize: 35,
        pricePerShare: 424.0,
        minPrice: 403.0,
        maxPrice: 424.0,
        openDate: DateTime.now().subtract(const Duration(days: 1)),
        closeDate: DateTime.now().add(const Duration(days: 1)),
        allotmentDate: DateTime.now().add(const Duration(days: 3)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ApplyIpoScreen(
            ipo: ipo,
            storageService: storage,
          ),
        ),
      );

      expect(find.textContaining('1 Lot = 35 shares • ₹14,840'), findsOneWidget);
    });

    testWidgets('SubscriptionBreakdownSheet displays lot size pill in header', (tester) async {
      final ipo = Ipo(
        name: 'SS Retail Ltd',
        symbol: 'SSRETAIL',
        lotSize: 35,
        pricePerShare: 424.0,
        minPrice: 403.0,
        maxPrice: 424.0,
        openDate: DateTime.now().subtract(const Duration(days: 1)),
        closeDate: DateTime.now().add(const Duration(days: 1)),
        allotmentDate: DateTime.now().add(const Duration(days: 3)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubscriptionBreakdownSheet(ipo: ipo),
          ),
        ),
      );

      expect(find.text('LOT: 35 SHARES'), findsOneWidget);
    });

    testWidgets('IpoCard displays issue size badge in Upcoming, Allotted, and Listed states', (tester) async {
      final now = DateTime.now();
      // 1. Upcoming IPO
      final upcomingIpo = Ipo(
        name: 'Sonaselection India Ltd',
        symbol: 'SONASEL',
        lotSize: 50,
        pricePerShare: 298.0,
        issueSizeCrores: 45.0,
        openDate: now.add(const Duration(days: 2)),
        closeDate: now.add(const Duration(days: 5)),
        allotmentDate: now.add(const Duration(days: 7)),
      );

      // 2. Allotted IPO
      final allottedIpo = Ipo(
        name: 'Rentomojo Ltd',
        symbol: 'RENTOMOJO',
        lotSize: 37,
        pricePerShare: 404.0,
        issueSizeCrores: 450.0,
        openDate: now.subtract(const Duration(days: 5)),
        closeDate: now.subtract(const Duration(days: 2)),
        allotmentDate: now.subtract(const Duration(hours: 4)), // Allotment announced
        listingDate: now.add(const Duration(days: 2)),
      );

      // 3. Listed IPO
      final listedIpo = Ipo(
        name: 'Kanohar Electricals Ltd',
        symbol: 'KANOHAR',
        lotSize: 23,
        pricePerShare: 632.0,
        issueSizeCrores: 320.0,
        openDate: now.subtract(const Duration(days: 7)),
        closeDate: now.subtract(const Duration(days: 4)),
        allotmentDate: now.subtract(const Duration(days: 2)),
        listingDate: now.subtract(const Duration(hours: 8)), // Listed
        listingPrice: 685.0,
        currentPrice: 750.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  IpoCard(ipo: upcomingIpo, appliedCount: 0, onApply: () {}),
                  IpoCard(ipo: allottedIpo, appliedCount: 0, onApply: () {}),
                  IpoCard(ipo: listedIpo, appliedCount: 0, onApply: () {}),
                ],
              ),
            ),
          ),
        ),
      );

      // All 3 cards must display their issue size badges near the date
      expect(find.text('₹45 Cr'), findsOneWidget); // Upcoming
      expect(find.text('₹450 Cr'), findsOneWidget); // Allotted
      expect(find.text('₹320 Cr'), findsOneWidget); // Listed
    });
  });

  group('IPO Deduplication and Single-Instance Safeguards', () {
    test('StorageService merges duplicate NSE records and purges duplicates', () async {
      SharedPreferences.setMockInitialValues({
        'ipotracker_ipos': jsonEncode([
          {
            'id': 'real-ipo-2',
            'name': 'National Stock Exchange (NSE)',
            'symbol': 'NSE',
            'lotSize': 8,
            'pricePerShare': 1785.0,
            'minPrice': 1700.0,
            'maxPrice': 1785.0,
            'issueSizeCrores': 22569.0,
            'category': 'mainboard',
            'openDate': DateTime(2026, 9, 17, 10, 0).toIso8601String(),
            'closeDate': DateTime(2026, 9, 21, 17, 0).toIso8601String(),
            'allotmentDate': DateTime(2026, 9, 22, 18, 0).toIso8601String(),
            'listingDate': DateTime(2026, 9, 24, 10, 0).toIso8601String(),
            'naradaId': 1089,
            'gmp': 148.0,
          },
          {
            'id': 'scraper-duplicate-uuid',
            'name': 'NSE',
            'symbol': 'NSE',
            'lotSize': 8,
            'pricePerShare': 1785.0,
            'issueSizeCrores': 0.0,
            'category': 'mainboard',
            'openDate': DateTime(2026, 9, 17, 10, 0).toIso8601String(),
            'closeDate': DateTime(2026, 9, 21, 17, 0).toIso8601String(),
            'allotmentDate': DateTime(2026, 9, 22, 18, 0).toIso8601String(),
            'gmp': 148.0,
          },
        ]),
      });

      final storage = StorageService();
      await storage.init();

      final nseMatches = storage.ipos.where((i) => i.symbol.toUpperCase() == 'NSE').toList();
      expect(nseMatches.length, equals(1)); // Exactly ONE NSE instance!
      expect(nseMatches.first.name, equals('National Stock Exchange (NSE)'));
      expect(nseMatches.first.naradaId, equals(1089));
      expect(nseMatches.first.issueSizeCrores, equals(22569.0));
      expect(nseMatches.first.formattedIssueSize, equals('₹22,569 Cr'));
    });

    test('saveIpo prevents inserting duplicate by matching symbol or naradaId', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      final initialNseCount = storage.ipos.where((i) => i.symbol.toUpperCase() == 'NSE').length;
      expect(initialNseCount, equals(1));

      // Attempt to save an incoming duplicate with a different UUID ID
      final incomingDuplicate = Ipo(
        id: 'new-uuid-from-scraper',
        name: 'National Stock Exchange of India Limited',
        symbol: 'NSE',
        lotSize: 8,
        pricePerShare: 1785.0,
        minPrice: 1700.0,
        maxPrice: 1785.0,
        naradaId: 1089,
        openDate: DateTime.now(),
        closeDate: DateTime.now().add(const Duration(days: 3)),
        allotmentDate: DateTime.now().add(const Duration(days: 4)),
      );

      await storage.saveIpo(incomingDuplicate);

      // Must remain exactly ONE NSE instance
      final updatedNseMatches = storage.ipos.where((i) => i.symbol.toUpperCase() == 'NSE').toList();
      expect(updatedNseMatches.length, equals(1));
    });

    test('StorageService persists and restores category filter and sort option across restarts', () async {
      SharedPreferences.setMockInitialValues({});
      final storage1 = StorageService();
      await storage1.init();

      // By default, category filter is null (All) and sort is defaultOrder
      expect(storage1.ipoCategoryFilter, isNull);
      expect(storage1.ipoSortOption, equals(IpoSortOption.defaultOrder));

      // User applies SME filter and GMP (% Gain) sort
      await storage1.setIpoFilters(
        category: IpoCategory.sme,
        sort: IpoSortOption.gmpPercentHighToLow,
      );
      expect(storage1.ipoCategoryFilter, equals(IpoCategory.sme));
      expect(storage1.ipoSortOption, equals(IpoSortOption.gmpPercentHighToLow));

      // Simulate app close and restart by initializing a new StorageService instance from SharedPreferences
      final storage2 = StorageService();
      await storage2.init();

      // Filter and sort MUST be preserved exactly as saved!
      expect(storage2.ipoCategoryFilter, equals(IpoCategory.sme));
      expect(storage2.ipoSortOption, equals(IpoSortOption.gmpPercentHighToLow));

      // User changes or resets filter back to All and Default sort
      await storage2.setIpoFilters(
        category: null,
        sort: IpoSortOption.defaultOrder,
      );

      final storage3 = StorageService();
      await storage3.init();
      expect(storage3.ipoCategoryFilter, isNull);
      expect(storage3.ipoSortOption, equals(IpoSortOption.defaultOrder));
    });

    test('StorageService persists and restores application status filter', () async {
      SharedPreferences.setMockInitialValues({});
      final storage1 = StorageService();
      await storage1.init();

      expect(storage1.appStatusFilter, isNull);

      await storage1.setAppStatusFilter(ApplicationStatus.applied);
      expect(storage1.appStatusFilter, equals(ApplicationStatus.applied));

      final storage2 = StorageService();
      await storage2.init();
      expect(storage2.appStatusFilter, equals(ApplicationStatus.applied));
    });
  });
}
