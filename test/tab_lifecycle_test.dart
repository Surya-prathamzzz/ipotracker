import 'package:flutter_test/flutter_test.dart';
import 'package:ipotracker/models/ipo.dart';

void main() {
  group('IPO Lifecycle & Tab Retention Tests', () {
    final now = DateTime.now();

    final openIpo = Ipo(
      name: 'Open IPO',
      symbol: 'OPEN',
      lotSize: 50,
      pricePerShare: 100,
      openDate: now.subtract(const Duration(days: 1)),
      closeDate: now.add(const Duration(days: 2)),
      allotmentDate: now.add(const Duration(days: 4)),
      listingDate: now.add(const Duration(days: 7)),
    );

    final closedAwaitingAllotmentIpo = Ipo(
      name: 'Closed Awaiting Allotment',
      symbol: 'CLOSED',
      lotSize: 50,
      pricePerShare: 100,
      openDate: now.subtract(const Duration(days: 4)),
      closeDate: now.subtract(const Duration(days: 1)),
      allotmentDate: now.add(const Duration(days: 2)), // Allotment in 2 days
      listingDate: now.add(const Duration(days: 5)),
    );

    final allottedIpo = Ipo(
      name: 'Allotted Awaiting Listing',
      symbol: 'ALLOTTED',
      lotSize: 50,
      pricePerShare: 100,
      openDate: now.subtract(const Duration(days: 7)),
      closeDate: now.subtract(const Duration(days: 4)),
      allotmentDate: now.subtract(const Duration(days: 1)), // Allotment yesterday
      listingDate: now.add(const Duration(days: 2)), // Listing in 2 days
    );

    final listedRecentIpo = Ipo(
      name: 'Recently Listed',
      symbol: 'RECENT',
      lotSize: 50,
      pricePerShare: 100,
      openDate: now.subtract(const Duration(days: 10)),
      closeDate: now.subtract(const Duration(days: 7)),
      allotmentDate: now.subtract(const Duration(days: 5)),
      listingDate: now.subtract(const Duration(days: 2)), // Listed 2 days ago (<= 5 days)
      currentPrice: 125.0,
    );

    final listedOldIpo = Ipo(
      name: 'Old Listed',
      symbol: 'OLD',
      lotSize: 50,
      pricePerShare: 100,
      openDate: now.subtract(const Duration(days: 20)),
      closeDate: now.subtract(const Duration(days: 17)),
      allotmentDate: now.subtract(const Duration(days: 15)),
      listingDate: now.subtract(const Duration(days: 8)), // Listed 8 days ago (> 5 days)
      currentPrice: 140.0,
    );

    final upcomingIpo = Ipo(
      name: 'Upcoming IPO',
      symbol: 'UPCOMING',
      lotSize: 50,
      pricePerShare: 100,
      openDate: now.add(const Duration(days: 2)),
      closeDate: now.add(const Duration(days: 5)),
      allotmentDate: now.add(const Duration(days: 7)),
      listingDate: now.add(const Duration(days: 10)),
    );

    final allIpos = [
      openIpo,
      closedAwaitingAllotmentIpo,
      allottedIpo,
      listedRecentIpo,
      listedOldIpo,
      upcomingIpo,
    ];

    test('Open / Closed tab shows IPOs till they get allotment (just like Narada)', () {
      final openClosedTab = allIpos.where((i) => !i.isUpcoming && !i.isAllotmentOut).toList();

      // Should include Open IPO
      expect(openClosedTab.any((i) => i.symbol == 'OPEN'), isTrue);
      // Should include Closed IPO awaiting allotment
      expect(openClosedTab.any((i) => i.symbol == 'CLOSED'), isTrue);
      // Must NOT include Allotted IPO
      expect(openClosedTab.any((i) => i.symbol == 'ALLOTTED'), isFalse);
      // Must NOT include Listed IPOs
      expect(openClosedTab.any((i) => i.symbol == 'RECENT'), isFalse);
      expect(openClosedTab.any((i) => i.symbol == 'OLD'), isFalse);
      // Must NOT include Upcoming IPO
      expect(openClosedTab.any((i) => i.symbol == 'UPCOMING'), isFalse);
    });

    test('Allotted / Listed tab shows IPOs till 5 days after listing', () {
      final allottedListedTab = allIpos.where((i) => i.isAllottedOrListed).toList();

      // Should include Allotted IPO awaiting listing
      expect(allottedListedTab.any((i) => i.symbol == 'ALLOTTED'), isTrue);
      // Should include IPO listed 2 days ago (within 5-day window)
      expect(allottedListedTab.any((i) => i.symbol == 'RECENT'), isTrue);
      // Must NOT include IPO listed 8 days ago (past 5-day window)
      expect(allottedListedTab.any((i) => i.symbol == 'OLD'), isFalse);
      // Must NOT include Open or Closed awaiting allotment
      expect(allottedListedTab.any((i) => i.symbol == 'OPEN'), isFalse);
      expect(allottedListedTab.any((i) => i.symbol == 'CLOSED'), isFalse);
    });

    test('Current Price and Gain calculations for listed IPOs', () {
      expect(listedRecentIpo.isListed, isTrue);
      expect(listedRecentIpo.effectiveCurrentPrice, 125.0);
      expect(listedRecentIpo.gainFromIssuePrice, 25.0);
      expect(listedRecentIpo.gainPercentFromIssuePrice, 25.0);
      // 50 lotSize * ₹25 = ₹1250 gain per lot
      expect(listedRecentIpo.totalGainPerLot, 1250.0);
    });

    test('SS Retail price lot and cost recalculation', () {
      final ssRetail = Ipo(
        name: 'SS Retail Ltd',
        symbol: 'SSRETAIL',
        lotSize: 35,
        pricePerShare: 424.0,
        minPrice: 403.0,
        maxPrice: 424.0,
        openDate: DateTime(2026, 9, 16, 10, 0),
        closeDate: DateTime(2026, 9, 18, 17, 0),
        allotmentDate: DateTime(2026, 9, 21, 18, 0),
      );

      expect(ssRetail.lotSize, 35);
      expect(ssRetail.pricePerShare, 424.0);
      expect(ssRetail.lotCost, 35 * 424.0); // 14,840
      expect(ssRetail.minPrice, 403.0);
      expect(ssRetail.maxPrice, 424.0);

      // Verify copyWith recalculates lotCost dynamically
      final updated = ssRetail.copyWith(pricePerShare: 430.0);
      expect(updated.lotCost, 35 * 430.0);
    });

    test('NSE IPO open today is classified as open and not listed', () {
      final nse = Ipo(
        name: 'National Stock Exchange (NSE)',
        symbol: 'NSE',
        naradaId: 1089,
        lotSize: 8,
        pricePerShare: 1785.0,
        minPrice: 1700.0,
        maxPrice: 1785.0,
        openDate: DateTime(2026, 9, 17, 10, 0), // Today
        closeDate: DateTime(2026, 9, 21, 17, 0),
        allotmentDate: DateTime(2026, 9, 22, 18, 0),
        listingDate: DateTime(2026, 9, 24, 10, 0),
      );

      expect(nse.isOpen, isTrue);
      expect(nse.isUpcoming, isFalse);
      expect(nse.isClosed, isFalse);
      expect(nse.isListed, isFalse);
      expect(nse.isAllottedOrListed, isFalse);
      expect(nse.lotCost, 8 * 1785.0); // 14,280
    });

    test('Manika Plastech closed yesterday is marked closed awaiting allotment', () {
      final testNow = DateTime.now();
      final manika = Ipo(
        name: 'Manika Plastech Ltd',
        symbol: 'MANIKA',
        naradaId: 1079,
        lotSize: 348,
        pricePerShare: 43.0,
        minPrice: 40.0,
        maxPrice: 43.0,
        openDate: testNow.subtract(const Duration(days: 4)),
        closeDate: testNow.subtract(const Duration(days: 1)), // Closed yesterday
        allotmentDate: testNow.add(const Duration(days: 1)), // Allotment upcoming
        listingDate: testNow.add(const Duration(days: 4)),
      );

      expect(manika.isClosed, isTrue);
      expect(manika.isOpen, isFalse);
      expect(manika.isUpcoming, isFalse);
      expect(manika.isListed, isFalse);
      // In Open / Closed tab because allotment is not finalized yet
      expect(manika.isAllotmentOut, isFalse);
      expect(manika.isAllottedOrListed, isFalse);
    });
  });
}
