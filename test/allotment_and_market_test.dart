import 'package:flutter_test/flutter_test.dart';
import 'package:ipotracker/models/ipo.dart';
import 'package:ipotracker/models/ipo_application.dart';
import 'package:ipotracker/models/person.dart';
import 'package:ipotracker/services/allotment_checker_service.dart';
import 'package:ipotracker/services/market_intelligence_service.dart';
import 'package:ipotracker/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('IPO Probability & Market Calculations', () {
    test('Calculates GMP percentage and listing gain per lot accurately', () {
      final ipo = Ipo(
        name: 'Hero Motors Ltd',
        symbol: 'HEROMOTO',
        lotSize: 35,
        pricePerShare: 412,
        openDate: DateTime.now(),
        closeDate: DateTime.now().add(const Duration(days: 2)),
        allotmentDate: DateTime.now().add(const Duration(days: 4)),
        gmp: 52,
      );

      // GMP % = (52 / 412) * 100 = ~12.62%
      expect(ipo.gmpPercent, closeTo(12.62, 0.1));
      // Est. Gain = 52 * 35 = 1820
      expect(ipo.estimatedListingGainPerLot, 1820.0);
      expect(ipo.estimatedListingPrice, 464.0);
    });

    test('Calculates Retail Allotment Probability for single vs syndicate accounts', () {
      final ipo = Ipo(
        name: 'Test IPO',
        symbol: 'TEST',
        lotSize: 20,
        pricePerShare: 500,
        openDate: DateTime.now(),
        closeDate: DateTime.now(),
        allotmentDate: DateTime.now(),
        retailSubscription: 25.0, // 25x oversubscribed
      );

      // Single account: 1 / 25 = 4%
      final single = ipo.getRetailAllotmentProbability(accountsCount: 1);
      expect(single, closeTo(4.0, 0.01));

      // 5 accounts: 1 - (1 - 0.04)^5 = 1 - 0.81537 = ~18.46%
      final fiveAccounts = ipo.getRetailAllotmentProbability(accountsCount: 5);
      expect(fiveAccounts, closeTo(18.46, 0.1));

      // 10 accounts: 1 - (1 - 0.04)^10 = ~33.51%
      final tenAccounts = ipo.getRetailAllotmentProbability(accountsCount: 10);
      expect(tenAccounts, closeTo(33.51, 0.1));
    });

    test('Returns 100% probability if undersubscribed or exactly 1x', () {
      final ipo = Ipo(
        name: 'Undersubscribed IPO',
        symbol: 'UNDER',
        lotSize: 10,
        pricePerShare: 100,
        openDate: DateTime.now(),
        closeDate: DateTime.now(),
        allotmentDate: DateTime.now(),
        retailSubscription: 0.85,
      );

      expect(ipo.getRetailAllotmentProbability(accountsCount: 1), 100.0);
    });
  });

  group('AllotmentCheckerService Tests', () {
    test('Batch check processes all applicant PANs and returns formatted results', () async {
      final ipo = Ipo(
        id: 'ipo-test',
        name: 'Hero Motors Ltd',
        symbol: 'HEROMOTO',
        lotSize: 35,
        pricePerShare: 412,
        openDate: DateTime.now().subtract(const Duration(days: 5)),
        closeDate: DateTime.now().subtract(const Duration(days: 2)),
        allotmentDate: DateTime.now().subtract(const Duration(days: 1)), // Allotment out
        retailSubscription: 15.0,
      );

      final person1 = Person(id: 'p1', name: 'Dad', pan: 'ABCDE1234F');
      final person2 = Person(id: 'p2', name: 'Mom', pan: 'BCDEF2345G');

      final app1 = IpoApplication(
        id: 'app-1',
        ipoId: ipo.id,
        personId: person1.id,
        lots: 1,
        amountBlocked: 14420,
      );
      final app2 = IpoApplication(
        id: 'app-2',
        ipoId: ipo.id,
        personId: person2.id,
        lots: 1,
        amountBlocked: 14420,
      );

      final results = await AllotmentCheckerService.checkAllotmentBatch(
        ipo: ipo,
        people: [person1, person2],
        applications: [app1, app2],
      );

      expect(results.length, 2);
      expect(results[0].personName, 'Dad');
      expect(results[1].personName, 'Mom');
      expect(results[0].amountBlocked, 14420.0);
    });

    test('Batch check checks all registered accounts even when applications list is empty', () async {
      final ipo = Ipo(
        id: 'ipo-kanohar',
        name: 'Kanohar Electricals Limited',
        symbol: 'KANOHAR',
        lotSize: 23,
        pricePerShare: 632.0,
        openDate: DateTime.now().subtract(const Duration(days: 8)),
        closeDate: DateTime.now().subtract(const Duration(days: 6)),
        allotmentDate: DateTime.now().subtract(const Duration(days: 4)),
      );

      final p1 = Person(id: 'p1', name: 'Prathamesh', pan: 'MMEPS3478L');
      final p2 = Person(id: 'p2', name: 'Sarang', pan: 'EYHPP5611K');
      final p3 = Person(id: 'p3', name: 'Aryan', pan: 'UNRPS7862E');

      // 0 applications recorded locally!
      final results = await AllotmentCheckerService.checkAllotmentBatch(
        ipo: ipo,
        people: [p1, p2, p3],
        applications: [],
      );

      // Must check all 3 registered people and mark unapplied as notApplied!
      expect(results.length, 3);
      expect(results.map((r) => r.personName), containsAll(['Prathamesh', 'Sarang', 'Aryan']));
      for (final r in results) {
        expect(r.status, AllotmentResultStatus.notApplied);
        expect(r.isNotApplied, isTrue);
        expect(r.message, 'Not Applied');
      }
    });

    test('Upcoming IPO scheduled for tomorrow is classified as upcoming, not open', () {
      final now = DateTime.now();
      final nse = Ipo(
        name: 'National Stock Exchange (NSE)',
        symbol: 'NSE',
        lotSize: 8,
        pricePerShare: 1785.0,
        openDate: now.add(const Duration(days: 1)), // Tomorrow
        closeDate: now.add(const Duration(days: 4)),
        allotmentDate: now.add(const Duration(days: 7)),
      );

      expect(nse.isUpcoming, isTrue);
      expect(nse.isOpen, isFalse);
      expect(nse.isClosed, isFalse);
      expect(nse.isAllotmentOut, isFalse);
      expect(nse.isAllottedOrListed, isFalse);
    });

    test('Listed IPO price metrics calculate accurate gains from issue and listing prices', () {
      final listedIpo = Ipo(
        name: 'Kanohar Electricals Limited',
        symbol: 'KANOHAR',
        lotSize: 23,
        pricePerShare: 632.0, // Issue price
        openDate: DateTime.now().subtract(const Duration(days: 8)),
        closeDate: DateTime.now().subtract(const Duration(days: 6)),
        allotmentDate: DateTime.now().subtract(const Duration(days: 4)),
        listingDate: DateTime.now().subtract(const Duration(days: 2)),
        listingPrice: 685.5, // Narada listing price
        currentPrice: 751.5, // Narada current market price
      );

      expect(listedIpo.isListed, isTrue);
      expect(listedIpo.effectiveListingPrice, 685.5);
      // Listing gain % = ((685.5 - 632.0) / 632.0) * 100 = 8.465%
      expect(listedIpo.listingGainPercent, closeTo(8.46, 0.05));

      expect(listedIpo.effectiveCurrentPrice, 751.5);
      // Current gain from issue = 751.5 - 632.0 = 119.5
      expect(listedIpo.gainFromIssuePrice, 119.5);
      // Current gain % = (119.5 / 632.0) * 100 = 18.908%
      expect(listedIpo.gainPercentFromIssuePrice, closeTo(18.91, 0.05));

      // Gain per lot = 119.5 * 23 = 2748.5
      expect(listedIpo.totalGainPerLot, 2748.5);
    });
  });

  group('MarketIntelligenceService Tests', () {
    test('Fetches and updates live GMP and subscriptions into storage', () async {
      SharedPreferences.setMockInitialValues({});
      final storageService = StorageService();
      await storageService.init();

      final marketService = MarketIntelligenceService(storageService);
      final updatedCount = await marketService.refreshMarketData();

      expect(updatedCount, greaterThanOrEqualTo(0));
      expect(marketService.lastRefreshed, isNotNull);
    });

    test('Allows custom GMP override and recalculates listing gains', () async {
      SharedPreferences.setMockInitialValues({});
      final storageService = StorageService();
      await storageService.init();

      final testIpo = Ipo(
        id: 'test-custom-ipo',
        name: 'Custom Quote Corp',
        symbol: 'CUSTOM',
        lotSize: 50,
        pricePerShare: 200,
        openDate: DateTime.now(),
        closeDate: DateTime.now().add(const Duration(days: 2)),
        allotmentDate: DateTime.now().add(const Duration(days: 4)),
        gmp: 20, // Live quote is ₹20
      );
      await storageService.saveIpo(testIpo);

      expect(testIpo.effectiveGmp, 20.0);
      expect(testIpo.estimatedListingGainPerLot, 1000.0);

      final marketService = MarketIntelligenceService(storageService);

      // Apply custom dealer quote of ₹65
      await marketService.updateCustomGmp(
        ipoId: testIpo.id,
        customGmp: 65,
        isCustom: true,
      );

      final updated = storageService.getIpo(testIpo.id);
      expect(updated, isNotNull);
      expect(updated!.isCustomGmp, isTrue);
      expect(updated.customGmp, 65.0);
      expect(updated.effectiveGmp, 65.0);
      expect(updated.gmp, 20.0); // Live quote preserved
      expect(updated.estimatedListingGainPerLot, 3250.0); // 65 * 50
      expect(updated.estimatedListingPrice, 265.0); // 200 + 65

      // Reset to live market rate
      await marketService.updateCustomGmp(
        ipoId: testIpo.id,
        customGmp: null,
        isCustom: false,
      );

      final resetIpo = storageService.getIpo(testIpo.id);
      expect(resetIpo!.isCustomGmp, isFalse);
      expect(resetIpo.effectiveGmp, 20.0);
      expect(resetIpo.estimatedListingGainPerLot, 1000.0);
    });
  });
}
