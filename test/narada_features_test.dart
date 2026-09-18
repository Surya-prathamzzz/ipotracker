import 'package:flutter_test/flutter_test.dart';
import 'package:ipotracker/models/ipo.dart';
import 'package:ipotracker/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Narada Inherited Feature Tests', () {
    test('1. 4-Stage Lifecycle classification operates accurately', () {
      final now = DateTime.now();

      final upcomingIpo = Ipo(
        name: 'Upcoming Corp',
        symbol: 'UPC',
        lotSize: 50,
        pricePerShare: 200,
        openDate: now.add(const Duration(days: 3)),
        closeDate: now.add(const Duration(days: 5)),
        allotmentDate: now.add(const Duration(days: 7)),
      );
      expect(upcomingIpo.isUpcoming, isTrue);
      expect(upcomingIpo.isOpen, isFalse);
      expect(upcomingIpo.isClosed, isFalse);
      expect(upcomingIpo.isAllottedOrListed, isFalse);

      final openIpo = Ipo(
        name: 'Open Corp',
        symbol: 'OPN',
        lotSize: 50,
        pricePerShare: 200,
        openDate: now.subtract(const Duration(days: 1)),
        closeDate: now.add(const Duration(days: 2)),
        allotmentDate: now.add(const Duration(days: 4)),
      );
      expect(openIpo.isUpcoming, isFalse);
      expect(openIpo.isOpen, isTrue);
      expect(openIpo.isClosed, isFalse);

      final closedIpo = Ipo(
        name: 'Closed Corp',
        symbol: 'CLS',
        lotSize: 50,
        pricePerShare: 200,
        openDate: now.subtract(const Duration(days: 4)),
        closeDate: now.subtract(const Duration(days: 1)),
        allotmentDate: now.add(const Duration(days: 2)),
      );
      expect(closedIpo.isClosed, isTrue);
      expect(closedIpo.isAllottedOrListed, isFalse);

      final allottedIpo = Ipo(
        name: 'Allotted Corp',
        symbol: 'ALT',
        lotSize: 50,
        pricePerShare: 200,
        openDate: now.subtract(const Duration(days: 8)),
        closeDate: now.subtract(const Duration(days: 5)),
        allotmentDate: now.subtract(const Duration(days: 1)),
        listingDate: now.add(const Duration(days: 2)),
      );
      expect(allottedIpo.isAllottedOrListed, isTrue);
    });

    test('2. StorageService manages Watchlist state and persistence', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      expect(storage.isWatchlisted('ipo-1'), isFalse);

      await storage.toggleWatchlist('ipo-1');
      expect(storage.isWatchlisted('ipo-1'), isTrue);
      expect(storage.watchlistIpoIds.contains('ipo-1'), isTrue);

      await storage.toggleWatchlist('ipo-1');
      expect(storage.isWatchlisted('ipo-1'), isFalse);
    });

    test('3. Privacy Mode properly masks PANs and names', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      expect(storage.privacyMode, isFalse);
      expect(storage.formatPan('ABCDE1234F'), 'ABCDE1234F');
      expect(storage.formatName('Rahul Sharma'), 'Rahul Sharma');

      await storage.togglePrivacyMode();
      expect(storage.privacyMode, isTrue);

      // PAN masking: ABCDE1234F -> ABC••••4F
      expect(storage.formatPan('ABCDE1234F'), 'ABC••••4F');
      // Name masking: Rahul Sharma -> Rahul S.
      expect(storage.formatName('Rahul Sharma'), 'Rahul S.');
      // Name masking single word: Mukesh -> Muk...
      expect(storage.formatName('Mukesh'), 'Muk...');

      await storage.togglePrivacyMode();
      expect(storage.privacyMode, isFalse);
      expect(storage.formatPan('ABCDE1234F'), 'ABCDE1234F');
    });

    test('4. Pure Black AMOLED theme toggle works in StorageService', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      expect(storage.pureBlackMode, isFalse);
      await storage.togglePureBlackMode();
      expect(storage.pureBlackMode, isTrue);
      await storage.togglePureBlackMode();
      expect(storage.pureBlackMode, isFalse);
    });

    test('5. Deep Subscription Quotas serialize and compute breakdown correctly', () {
      final ipo = Ipo(
        name: 'Deep Tech Ltd',
        symbol: 'DTECH',
        lotSize: 40,
        pricePerShare: 250,
        openDate: DateTime.now(),
        closeDate: DateTime.now(),
        allotmentDate: DateTime.now(),
        retailSubscription: 12.5,
        qibSubscription: 45.0,
        bNiiSubscription: 22.0,
        sNiiSubscription: 18.0,
        employeeSubscription: 3.5,
        issueSizeCrores: 850.0,
        minPrice: 235,
        maxPrice: 250,
      );

      expect(ipo.bNiiSubscription, 22.0);
      expect(ipo.sNiiSubscription, 18.0);
      expect(ipo.employeeSubscription, 3.5);
      expect(ipo.issueSizeCrores, 850.0);
      expect(ipo.minPrice, 235.0);
      expect(ipo.maxPrice, 250.0);

      // Serialization roundtrip
      final json = ipo.toJson();
      final revived = Ipo.fromJson(json);

      expect(revived.bNiiSubscription, 22.0);
      expect(revived.sNiiSubscription, 18.0);
      expect(revived.employeeSubscription, 3.5);
      expect(revived.issueSizeCrores, 850.0);
      expect(revived.minPrice, 235.0);
      expect(revived.maxPrice, 250.0);
    });

    test('6. Retail Max Lot calculation caps below ₹2,00,000 threshold', () {
      // Lot size: 30, Price: ₹450 -> Lot cost: ₹13,500
      // Max lots under 200,000 = floor(200,000 / 13,500) = 14 lots (₹189,000)
      const lotSize = 30;
      const price = 450.0;
      const lotCost = lotSize * price; // 13500.0

      const retailLimit = 200000.0;
      final maxLots = (retailLimit / lotCost).floor();

      expect(maxLots, 14);
      expect(maxLots * lotCost, lessThanOrEqualTo(retailLimit));
      expect((maxLots + 1) * lotCost, greaterThan(retailLimit));
    });
  });
}
