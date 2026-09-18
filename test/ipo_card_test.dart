import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipotracker/models/ipo.dart';
import 'package:ipotracker/widgets/ipo_card.dart';

void main() {
  testWidgets('IpoCard renders 5-zone information architecture correctly', (tester) async {
    final now = DateTime.now();
    final ipo = Ipo(
      id: 'test-1',
      name: 'Hero Motors Ltd',
      symbol: 'HEROMOTO',
      lotSize: 178,
      pricePerShare: 84,
      minPrice: 79,
      maxPrice: 84,
      openDate: now.subtract(const Duration(days: 1)),
      closeDate: now, // Closes today!
      allotmentDate: now.add(const Duration(days: 3)),
      gmp: 19.0,
      gmpTrend: GmpTrend.up,
      retailSubscription: 18.4,
      totalSubscription: 24.1,
      issueSizeCrores: 850,
    );

    bool appliedTapped = false;
    bool watchlistTapped = false;
    bool subscriptionTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IpoCard(
            ipo: ipo,
            appliedCount: 0,
            totalSyndicateAccounts: 3,
            isWatchlisted: false,
            onApply: () => appliedTapped = true,
            onToggleWatchlist: () => watchlistTapped = true,
            onShowSubscription: () => subscriptionTapped = true,
          ),
        ),
      ),
    );

    // Zone 1: Identity & Urgency
    expect(find.text('HEROMOTO'), findsOneWidget);
    expect(find.text('MAINBOARD'), findsOneWidget);
    expect(find.text('CLOSES TODAY'), findsOneWidget);
    expect(find.textContaining('850 Cr'), findsOneWidget);

    // Zone 2: 3-Column Valuation Grid
    expect(find.text('PRICE (LOT: 178)'), findsOneWidget);
    expect(find.text('₹79 - ₹84'), findsOneWidget);
    expect(find.textContaining('178 shares •'), findsOneWidget);
    expect(find.text('GMP'), findsOneWidget);
    expect(find.textContaining('+₹19'), findsOneWidget);
    expect(find.text('EST. GAIN / LOT'), findsOneWidget);
    expect(find.textContaining('+₹3,382'), findsOneWidget);

    // Zone 3: Subscription & Syndicate Strip
    expect(find.textContaining('18.4x RII • 24.1x Total'), findsOneWidget);
    expect(find.textContaining('Win: 5% → 15% (3)'), findsOneWidget);

    // Zone 4: Footer
    expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
    expect(find.text('Apply Syndicate'), findsOneWidget);

    // Interactions
    await tester.tap(find.text('Apply Syndicate'));
    expect(appliedTapped, isTrue);

    await tester.tap(find.byIcon(Icons.star_outline_rounded));
    expect(watchlistTapped, isTrue);

    await tester.tap(find.textContaining('18.4x RII'));
    expect(subscriptionTapped, isTrue);
  });
}
