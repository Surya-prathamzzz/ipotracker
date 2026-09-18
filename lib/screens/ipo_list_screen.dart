import 'dart:async';
import 'package:flutter/material.dart';
import '../models/ipo.dart';
import '../models/ipo_application.dart';
import '../services/biometric_service.dart';
import '../services/ledger_service.dart';
import '../services/market_intelligence_service.dart';
import '../services/storage_service.dart';
import '../widgets/filter_sort_sheet.dart';
import '../widgets/ipo_card.dart';
import '../widgets/subscription_breakdown_sheet.dart';
import '../widgets/summary_card.dart';
import 'allotment_checker_screen.dart';
import 'applications_screen.dart';
import 'apply_ipo_screen.dart';

class IpoListScreen extends StatefulWidget {
  final StorageService storageService;
  final MarketIntelligenceService marketService;
  final BiometricService biometricService;

  const IpoListScreen({
    super.key,
    required this.storageService,
    required this.marketService,
    required this.biometricService,
  });

  @override
  State<IpoListScreen> createState() => _IpoListScreenState();
}

class _IpoListScreenState extends State<IpoListScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  IpoCategory? _selectedCategory;
  IpoSortOption _selectedSort = IpoSortOption.defaultOrder;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedCategory = widget.storageService.ipoCategoryFilter;
    _selectedSort = widget.storageService.ipoSortOption;
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
        // Auto-sync in background on tab switch if stale (> 15 mins)
        widget.marketService.refreshIfStale();
      }
    });

    // Auto-sync on app open if data is stale
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.marketService.refreshIfStale();
    });

    // Background periodic check every 5 minutes
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      widget.marketService.refreshIfStale();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Auto-sync when app resumes from background if stale (> 15 mins)
      widget.marketService.refreshIfStale();
    }
  }

  @override
  void didUpdateWidget(covariant IpoListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.storageService.ipoCategoryFilter != _selectedCategory) {
      _selectedCategory = widget.storageService.ipoCategoryFilter;
    }
    if (widget.storageService.ipoSortOption != _selectedSort) {
      _selectedSort = widget.storageService.ipoSortOption;
    }
  }

  List<Ipo> _getFilteredIpos(List<Ipo> ipos) {
    // Stage filtering based on active Tab
    List<Ipo> stageFiltered;
    switch (_tabController.index) {
      case 0: // Open / Closed: Show IPOs from open until they get allotment
        stageFiltered = ipos.where((i) => !i.isUpcoming && !i.isAllotmentOut).toList();
        break;
      case 1: // Upcoming
        stageFiltered = ipos.where((i) => i.isUpcoming).toList();
        break;
      case 2: // Allotted / Listed: Show IPOs with allotment till 5 days after listing
        stageFiltered = ipos.where((i) => i.isAllottedOrListed).toList();
        break;
      case 3: // Watchlist
        stageFiltered = ipos.where((i) => widget.storageService.isWatchlisted(i.id)).toList();
        break;
      default:
        stageFiltered = ipos;
    }

    // Category filtering
    if (_selectedCategory != null) {
      stageFiltered = stageFiltered.where((i) => i.category == _selectedCategory).toList();
    }

    // Sorting
    final result = List<Ipo>.from(stageFiltered);
    switch (_selectedSort) {
      case IpoSortOption.gmpPercentHighToLow:
        result.sort((a, b) => b.gmpPercent.compareTo(a.gmpPercent));
        break;
      case IpoSortOption.subscriptionHighToLow:
        result.sort((a, b) => b.totalSubscription.compareTo(a.totalSubscription));
        break;
      case IpoSortOption.closingSoonest:
        result.sort((a, b) => a.closeDate.compareTo(b.closeDate));
        break;
      case IpoSortOption.defaultOrder:
        break;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final ipos = widget.storageService.ipos;
    final people = widget.storageService.people;
    final entries = widget.storageService.ledgerEntries;
    final apps = widget.storageService.applications;

    final summary = LedgerService.getDashboardSummary(
      people: people,
      entries: entries,
      applications: apps,
    );

    final displayIpos = _getFilteredIpos(ipos);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'IPO Tracker & Float',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // 1-Tap Privacy Mode Toggle
          IconButton(
            icon: Icon(
              widget.storageService.privacyMode
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: widget.storageService.privacyMode
                  ? Colors.amber.shade700
                  : null,
            ),
            tooltip: widget.storageService.privacyMode
                ? 'Privacy Mode ON (PANs Hidden)'
                : 'Privacy Mode OFF',
            onPressed: () {
              widget.storageService.togglePrivacyMode();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    widget.storageService.privacyMode
                        ? 'Privacy Mode Enabled: PANs & identifiers masked'
                        : 'Privacy Mode Disabled',
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),

          // Filter & Sort Modal Trigger
          IconButton(
            icon: Badge(
              isLabelVisible: _selectedCategory != null || _selectedSort != IpoSortOption.defaultOrder,
              child: const Icon(Icons.tune_rounded),
            ),
            tooltip: 'Filter & Sort',
            onPressed: () => FilterSortSheet.show(
              context,
              currentCategory: _selectedCategory,
              currentSort: _selectedSort,
              onApply: (cat, sort) {
                setState(() {
                  _selectedCategory = cat;
                  _selectedSort = sort;
                });
                widget.storageService.setIpoFilters(category: cat, sort: sort);
              },
            ),
          ),

          // Settings & Security Action
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings & Security',
            onPressed: () => _showSettingsSheet(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await widget.marketService.refreshMarketData();
        },
        color: Colors.teal.shade700,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Top Summary Cards
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SummaryCard(
                            title: 'Available Float',
                            amount: summary.totalFloatBalance,
                            icon: Icons.account_balance_wallet,
                            color: Colors.teal.shade800,
                            subtitle: 'Idle for next IPO',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SummaryCard(
                            title: 'Locked in Bids',
                            amount: summary.totalBlockedInIpos,
                            icon: Icons.lock_clock,
                            color: Colors.amber.shade900,
                            subtitle: '${summary.activeApplicationsCount} applications',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Header row with section label & Live Pulse Pill
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'MARKET STAGES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    _buildLivePulsePill(isDark),
                  ],
                ),
              ),
            ),

            // 4-Stage Subtabs (Open / Closed, Upcoming, Listed, Watchlist)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  labelColor: isDark ? Colors.white : Colors.indigo.shade900,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 10.5),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                  tabs: [
                    const Tab(text: 'Open / Closed'),
                    const Tab(text: 'Upcoming'),
                    const Tab(text: 'Allotted / Listed'),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.storageService.watchlistIpoIds.isNotEmpty
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 13,
                            color: widget.storageService.watchlistIpoIds.isNotEmpty
                                ? Colors.amber.shade600
                                : null,
                          ),
                          const SizedBox(width: 2),
                          Text('Saved (${widget.storageService.watchlistIpoIds.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Active filter indicator chip bar (if filtered)
          if (_selectedCategory != null || _selectedSort != IpoSortOption.defaultOrder)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    if (_selectedCategory != null) ...[
                      Chip(
                        label: Text(_selectedCategory == IpoCategory.mainboard ? 'Mainboard' : 'SME'),
                        onDeleted: () {
                          setState(() => _selectedCategory = null);
                          widget.storageService.setIpoFilters(
                            category: null,
                            sort: _selectedSort,
                          );
                        },
                        deleteIcon: const Icon(Icons.close, size: 14),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (_selectedSort != IpoSortOption.defaultOrder) ...[
                      Chip(
                        label: Text('Sort: ${_selectedSort.displayName}'),
                        onDeleted: () {
                          setState(() => _selectedSort = IpoSortOption.defaultOrder);
                          widget.storageService.setIpoFilters(
                            category: _selectedCategory,
                            sort: IpoSortOption.defaultOrder,
                          );
                        },
                        deleteIcon: const Icon(Icons.close, size: 14),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // IPO Cards List
          if (displayIpos.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _tabController.index == 3
                          ? Icons.star_outline_rounded
                          : Icons.inventory_2_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _tabController.index == 3
                          ? 'No starred IPOs in your Watchlist yet\nTap the star on any card to track it here'
                          : 'No IPOs found in this tab',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final ipo = displayIpos[index];
                    final appliedCount = apps
                        .where((a) => a.ipoId == ipo.id && a.status == ApplicationStatus.applied)
                        .length;
                    final isSaved = widget.storageService.isWatchlisted(ipo.id);

                    return IpoCard(
                      ipo: ipo,
                      appliedCount: appliedCount,
                      totalSyndicateAccounts: widget.storageService.people.length,
                      isWatchlisted: isSaved,
                      onToggleWatchlist: () => widget.storageService.toggleWatchlist(ipo.id),
                      onShowSubscription: () => SubscriptionBreakdownSheet.show(
                        context,
                        ipo,
                        onApply: () => _navigateToApply(context, ipo),
                      ),
                      onEditGmp: (newGmp, isCustom) async {
                        await widget.marketService.updateCustomGmp(
                          ipoId: ipo.id,
                          customGmp: newGmp,
                          isCustom: isCustom,
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isCustom
                                  ? 'Updated custom GMP for ${ipo.name} to ₹${newGmp?.toStringAsFixed(0)}'
                                  : 'Reset GMP to live market rate for ${ipo.name}',
                            ),
                            backgroundColor:
                                isCustom ? Colors.indigo.shade800 : Colors.teal.shade800,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      onCheckAllotment: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AllotmentCheckerScreen(
                              ipo: ipo,
                              storageService: widget.storageService,
                            ),
                          ),
                        );
                      },
                      onViewApplications: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ApplicationsScreen(
                              storageService: widget.storageService,
                              filterIpoId: ipo.id,
                            ),
                          ),
                        );
                      },
                      onApply: () => _navigateToApply(context, ipo),
                    );
                  },
                  childCount: displayIpos.length,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

  void _navigateToApply(BuildContext context, Ipo ipo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApplyIpoScreen(
          ipo: ipo,
          storageService: widget.storageService,
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return ListenableBuilder(
          listenable: widget.storageService,
          builder: (context, _) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Settings & Preferences',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // Privacy Mode Toggle
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.security, color: Colors.amber.shade900),
                      ),
                      title: const Text('Privacy Mode'),
                      subtitle: const Text('Masks PAN numbers across all cards & screens'),
                      value: widget.storageService.privacyMode,
                      activeColor: Colors.amber.shade800,
                      onChanged: (_) => widget.storageService.togglePrivacyMode(),
                    ),

                    // Pure Black AMOLED Theme Toggle
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.black12,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.dark_mode, color: Colors.black87),
                      ),
                      title: const Text('Pure Black (AMOLED Mode)'),
                      subtitle: const Text('Turns dark theme into pitch black (#000000)'),
                      value: widget.storageService.pureBlackMode,
                      activeColor: Colors.indigo.shade800,
                      onChanged: (_) => widget.storageService.togglePureBlackMode(),
                    ),

                    // Biometric Lock Toggle
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.fingerprint, color: Colors.indigo.shade900),
                      ),
                      title: const Text('Biometric App Lock'),
                      subtitle: const Text('Require fingerprint / PIN on launch & resume'),
                      value: widget.biometricService.isBiometricEnabled,
                      activeColor: Colors.indigo.shade800,
                      onChanged: (val) async {
                        final success = await widget.biometricService.setBiometricEnabled(val);
                        if (!context.mounted) return;
                        if (!success && val) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Biometric verification cancelled or unavailable.'),
                            ),
                          );
                        }
                      },
                    ),

                    const Divider(),

                    // Fetch Live Market Data
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.sync_rounded, color: Colors.green.shade900),
                      ),
                      title: const Text('Update Live Market GMP'),
                      subtitle: const Text('Refresh grey market premium & subscription multiples'),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final count = await widget.marketService.refreshMarketData();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Updated live GMP & subscription for $count issues!'),
                            backgroundColor: Colors.teal.shade800,
                          ),
                        );
                      },
                    ),

                    // Reload Real Market IPOs
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.restart_alt, color: Colors.blue.shade900),
                      ),
                      title: const Text('Reload Real Market IPOs'),
                      subtitle: const Text('Reset catalog to latest scheduled Indian issues'),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await widget.storageService.resetDemoData();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Market IPO catalog reloaded!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'Tap to sync';
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildLivePulsePill(bool isDark) {
    return ListenableBuilder(
      listenable: widget.marketService,
      builder: (context, _) {
        final isRefreshing = widget.marketService.isRefreshing;
        final lastRefreshed = widget.marketService.lastRefreshed;
        final timeAgo = _formatTimeAgo(lastRefreshed);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isRefreshing
                ? null
                : () async {
                    final count = await widget.marketService.refreshMarketData();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Updated live market data ($count issues updated)'),
                        duration: const Duration(seconds: 2),
                        backgroundColor: Colors.teal.shade800,
                      ),
                    );
                  },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? (isRefreshing
                        ? Colors.amber.shade900.withValues(alpha: 0.3)
                        : const Color(0xFF0F291E))
                    : (isRefreshing
                        ? Colors.amber.shade50
                        : const Color(0xFFE6F4EA)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? (isRefreshing ? Colors.amber.shade700 : const Color(0xFF1E5E3A))
                      : (isRefreshing ? Colors.amber.shade300 : const Color(0xFFA8DAB5)),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isRefreshing)
                    SizedBox(
                      width: 8,
                      height: 8,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark ? Colors.amber.shade300 : Colors.amber.shade800,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 6.5,
                      height: 6.5,
                      decoration: BoxDecoration(
                        color: lastRefreshed == null
                            ? Colors.grey
                            : const Color(0xFF34A853),
                        shape: BoxShape.circle,
                        boxShadow: lastRefreshed != null
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF34A853).withValues(alpha: 0.5),
                                  blurRadius: 3,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  const SizedBox(width: 5),
                  Text(
                    isRefreshing ? 'Updating...' : 'Live • $timeAgo',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? (isRefreshing ? Colors.amber.shade300 : const Color(0xFF81C784))
                          : (isRefreshing ? Colors.amber.shade900 : const Color(0xFF137333)),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
