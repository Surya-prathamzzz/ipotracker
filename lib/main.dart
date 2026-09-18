import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/biometric_service.dart';
import 'services/market_intelligence_service.dart';
import 'services/storage_service.dart';
import 'widgets/app_lock_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();

  final biometricService = BiometricService();
  await biometricService.init();

  final marketService = MarketIntelligenceService(storageService);

  runApp(IpoTrackerApp(
    storageService: storageService,
    biometricService: biometricService,
    marketService: marketService,
  ));
}

class IpoTrackerApp extends StatelessWidget {
  final StorageService storageService;
  final BiometricService biometricService;
  final MarketIntelligenceService marketService;

  const IpoTrackerApp({
    super.key,
    required this.storageService,
    required this.biometricService,
    required this.marketService,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: storageService,
      builder: (context, _) {
        final isPureBlack = storageService.pureBlackMode;
        return MaterialApp(
          title: 'IPO Float & Allotment Tracker',
          debugShowCheckedModeBanner: false,
          themeMode: isPureBlack ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1E3A8A), // Deep Royal Navy Indigo
              primary: const Color(0xFF1E3A8A),
              secondary: const Color(0xFF0F766E), // Deep Teal
              surface: const Color(0xFFF8FAFC),
            ),
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF0F172A),
              elevation: 0,
              centerTitle: false,
              scrolledUnderElevation: 1,
            ),
            cardTheme: const CardTheme(
              color: Colors.white,
              elevation: 1,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF38BDF8),
              secondary: Color(0xFF2DD4BF),
              surface: Color(0xFF121212),
            ),
            scaffoldBackgroundColor: Colors.black,
            canvasColor: Colors.black,
            dialogBackgroundColor: const Color(0xFF121212),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: false,
              scrolledUnderElevation: 1,
            ),
            cardTheme: const CardTheme(
              color: Color(0xFF121212),
              elevation: 1,
            ),
            bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: Color(0xFF121212),
              modalBackgroundColor: Color(0xFF121212),
            ),
          ),
          home: AppLockWrapper(
            biometricService: biometricService,
            child: HomeScreen(
              storageService: storageService,
              biometricService: biometricService,
              marketService: marketService,
            ),
          ),
        );
      },
    );
  }
}
