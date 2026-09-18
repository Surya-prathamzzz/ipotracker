import 'package:flutter/material.dart';
import '../services/biometric_service.dart';
import '../services/market_intelligence_service.dart';
import '../services/storage_service.dart';
import 'applications_screen.dart';
import 'ipo_list_screen.dart';
import 'people_screen.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storageService;
  final BiometricService biometricService;
  final MarketIntelligenceService marketService;

  const HomeScreen({
    super.key,
    required this.storageService,
    required this.biometricService,
    required this.marketService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.storageService,
      builder: (context, _) {
        if (widget.storageService.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final pendingAppsCount = widget.storageService.applications
            .where((a) => a.status.name == 'applied')
            .length;

        final screens = [
          IpoListScreen(
            storageService: widget.storageService,
            marketService: widget.marketService,
            biometricService: widget.biometricService,
          ),
          ApplicationsScreen(storageService: widget.storageService),
          PeopleScreen(storageService: widget.storageService),
        ];

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
            indicatorColor: Colors.indigo.shade100,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.trending_up_outlined),
                selectedIcon: Icon(Icons.trending_up),
                label: 'IPOs',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: pendingAppsCount > 0,
                  label: Text('$pendingAppsCount'),
                  child: const Icon(Icons.assignment_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: pendingAppsCount > 0,
                  label: Text('$pendingAppsCount'),
                  child: const Icon(Icons.assignment),
                ),
                label: 'Applications',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: widget.storageService.people.isNotEmpty,
                  label: Text('${widget.storageService.people.length}'),
                  backgroundColor: Colors.teal.shade700,
                  child: const Icon(Icons.people_outline),
                ),
                selectedIcon: Badge(
                  isLabelVisible: widget.storageService.people.isNotEmpty,
                  label: Text('${widget.storageService.people.length}'),
                  backgroundColor: Colors.teal.shade700,
                  child: const Icon(Icons.people),
                ),
                label: 'People & Float',
              ),
            ],
          ),
        );
      },
    );
  }
}
