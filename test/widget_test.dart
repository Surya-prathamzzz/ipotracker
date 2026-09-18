import 'package:flutter_test/flutter_test.dart';
import 'package:ipotracker/main.dart';
import 'package:ipotracker/services/biometric_service.dart';
import 'package:ipotracker/services/market_intelligence_service.dart';
import 'package:ipotracker/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('IPO Tracker App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storageService = StorageService();
    await storageService.init();

    final biometricService = BiometricService(isTestMode: true);
    await biometricService.init();

    final marketService = MarketIntelligenceService(storageService);

    await tester.pumpWidget(IpoTrackerApp(
      storageService: storageService,
      biometricService: biometricService,
      marketService: marketService,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify IPOs tab title renders
    expect(find.text('IPO Tracker & Float'), findsOneWidget);
    // Verify tabs exist
    expect(find.text('IPOs'), findsWidgets);
    expect(find.text('Applications'), findsOneWidget);
    expect(find.text('People & Float'), findsOneWidget);
  });
}
