import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ipo.dart';
import '../models/ipo_application.dart';
import '../models/ledger_entry.dart';
import '../models/person.dart';
import '../utils/sample_data.dart';

class StorageService extends ChangeNotifier {
  static const String _keyPeople = 'ipotracker_people';
  static const String _keyIpos = 'ipotracker_ipos';
  static const String _keyApps = 'ipotracker_applications';
  static const String _keyLedger = 'ipotracker_ledger';
  static const String _keyWatchlist = 'ipotracker_watchlist';
  static const String _keyPrivacyMode = 'ipotracker_privacy_mode';
  static const String _keyPureBlackMode = 'ipotracker_pure_black_mode';
  static const String _keyIpoCategoryFilter = 'ipotracker_filter_category';
  static const String _keyIpoSortOption = 'ipotracker_filter_sort';
  static const String _keyAppStatusFilter = 'ipotracker_filter_app_status';

  List<Person> _people = [];
  List<Ipo> _ipos = [];
  List<IpoApplication> _applications = [];
  List<LedgerEntry> _ledgerEntries = [];
  Set<String> _watchlistIpoIds = {};
  bool _privacyMode = false;
  bool _pureBlackMode = false;
  bool _isLoading = true;
  IpoCategory? _ipoCategoryFilter;
  IpoSortOption _ipoSortOption = IpoSortOption.defaultOrder;
  ApplicationStatus? _appStatusFilter;

  List<Person> get people => List.unmodifiable(_people);
  List<Ipo> get ipos => List.unmodifiable(_ipos);
  List<IpoApplication> get applications => List.unmodifiable(_applications);
  List<LedgerEntry> get ledgerEntries => List.unmodifiable(_ledgerEntries);
  Set<String> get watchlistIpoIds => Set.unmodifiable(_watchlistIpoIds);
  bool get privacyMode => _privacyMode;
  bool get pureBlackMode => _pureBlackMode;
  bool get isLoading => _isLoading;
  IpoCategory? get ipoCategoryFilter => _ipoCategoryFilter;
  IpoSortOption get ipoSortOption => _ipoSortOption;
  ApplicationStatus? get appStatusFilter => _appStatusFilter;

  bool isWatchlisted(String id) => _watchlistIpoIds.contains(id);

  String formatPan(String pan) {
    if (!_privacyMode || pan.length < 6) return pan;
    return '${pan.substring(0, 3)}••••${pan.substring(pan.length - 2)}';
  }

  String formatName(String name) {
    if (!_privacyMode || name.length <= 4) return name;
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts.first} ${parts.sublist(1).map((p) => '${p[0]}.').join(' ')}';
    }
    return '${name.substring(0, 3)}...';
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    _loadFromPrefs(prefs);

    // Auto-heal any corrupted cached records, mismatched lot costs, or stage anomalies
    await _autoHealIpos(prefs);

    // Sync IPO catalog with live market entries, current prices, and retention window
    await _syncInitialIpos(prefs);

    // Ensure Narada syndicate members and Self account status are populated & synced
    await _syncNaradaPeople(prefs);

    _isLoading = false;
    notifyListeners();
  }

  static const Map<String, double> _knownIssueSizes = {
    'HEROMOTO': 900.0,
    'HEROMOTORS': 900.0,
    'SSRETAIL': 500.0,
    'MANIKA': 125.5,
    'VEEGALAND': 180.0,
    'RENTOMOJO': 450.0,
    'KANOHAR': 320.0,
    'GLASSWALL': 240.0,
    'ARCIL': 1150.0,
    'LCCPROJECT': 210.0,
    'OMNITECH': 150.0,
    'NSE': 22569.0,
    'SONASEL': 45.0,
    'SONA': 45.0,
    'JSIPL': 125.0,
    'JINDAL': 125.0,
    'SPECTRAA': 34.0,
    'KHERIAAUTO': 40.0,
    'ROBOKIDZ': 31.1,
    'VIVEKANAND': 22.2,
    'FXML': 45.2,
    'AXIOMGAS': 28.5,
    'SHAKTIPOLY': 35.0,
    'QAL': 18.0,
    'VAMAWOVEN': 24.0,
    'CENTURYOOH': 32.0,
    'INJECTO': 54.0,
    'SPEEDEX': 38.0,
    'RAKSAN': 42.0,
    'PANCHATV': 25.0,
    'OMGL': 30.0,
    'AMTECH': 44.0,
    'KARAMTARA': 120.0,
    'STEAMHOUSE': 350.0,
    'VINOD': 18.0,
    'INFRAX': 60.0,
    'ANAND': 16.0,
    'VARMORA': 500.0,
    'ARMEE': 40.0,
    'SAI': 25.0,
    'LIQVD': 22.0,
    'SKOFFSET': 18.0,
    'AONE': 250.0,
    'PRANAV': 45.0,
    'PRASOL': 800.0,
    'MANIPAL': 600.0,
    'GLASS': 240.0,
    'TRAFIKSOL': 44.87,
    'WAGONS': 35.0,
    'PRIL': 50.0,
    'SPGCL': 30.0,
    'TWINKLE': 28.0,
    'QUALIANCE': 32.0,
    'APANA': 26.0,
  };

  /// Automatically heals data anomalies, recalculates lot costs, deduplicates records, and restores stage integrity.
  Future<void> _autoHealIpos(SharedPreferences prefs) async {
    bool changed = false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 0. Deduplication pass: merge and purge duplicate records sharing the same symbol or naradaId
    final Map<String, List<int>> symbolGroups = {};
    for (int i = 0; i < _ipos.length; i++) {
      final sym = _ipos[i].symbol.toUpperCase().trim();
      if (sym.isNotEmpty) {
        symbolGroups.putIfAbsent(sym, () => []).add(i);
      }
    }

    final Set<int> indicesToRemove = {};
    bool appsRebound = false;

    for (final entry in symbolGroups.entries) {
      final indices = entry.value;
      if (indices.length <= 1) continue;

      // Duplicate detected! Determine primary index (prefer longest name or non-null naradaId)
      int primaryIdx = indices.first;
      for (final idx in indices.skip(1)) {
        final currentPrimary = _ipos[primaryIdx];
        final candidate = _ipos[idx];
        if (candidate.name.length > currentPrimary.name.length ||
            (candidate.naradaId != null && currentPrimary.naradaId == null)) {
          primaryIdx = idx;
        }
      }

      var merged = _ipos[primaryIdx];
      for (final idx in indices) {
        if (idx == primaryIdx) continue;
        final duplicate = _ipos[idx];

        merged = merged.copyWith(
          naradaId: merged.naradaId ?? duplicate.naradaId,
          issueSizeCrores: merged.issueSizeCrores > 0 ? merged.issueSizeCrores : duplicate.issueSizeCrores,
          lotSize: merged.lotSize > 0 ? merged.lotSize : duplicate.lotSize,
          pricePerShare: merged.pricePerShare > 0 ? merged.pricePerShare : duplicate.pricePerShare,
          minPrice: merged.minPrice > 0 ? merged.minPrice : duplicate.minPrice,
          maxPrice: merged.maxPrice > 0 ? merged.maxPrice : duplicate.maxPrice,
          gmp: duplicate.isCustomGmp ? duplicate.gmp : (merged.gmp > 0 ? merged.gmp : duplicate.gmp),
          isCustomGmp: merged.isCustomGmp || duplicate.isCustomGmp,
          customGmp: merged.customGmp ?? duplicate.customGmp,
          retailSubscription: merged.retailSubscription > 0 ? merged.retailSubscription : duplicate.retailSubscription,
          totalSubscription: merged.totalSubscription > 0 ? merged.totalSubscription : duplicate.totalSubscription,
          currentPrice: merged.currentPrice ?? duplicate.currentPrice,
          listingPrice: merged.listingPrice ?? duplicate.listingPrice,
        );

        // Remap any application pointing to duplicate.id -> merged.id
        for (int a = 0; a < _applications.length; a++) {
          if (_applications[a].ipoId == duplicate.id) {
            _applications[a] = _applications[a].copyWith(ipoId: merged.id);
            appsRebound = true;
          }
        }

        // Remap watchlist
        if (_watchlistIpoIds.contains(duplicate.id)) {
          _watchlistIpoIds.remove(duplicate.id);
          _watchlistIpoIds.add(merged.id);
        }

        indicesToRemove.add(idx);
      }
      _ipos[primaryIdx] = merged;
      changed = true;
    }

    if (indicesToRemove.isNotEmpty) {
      final sortedIndices = indicesToRemove.toList()..sort((a, b) => b.compareTo(a));
      for (final idx in sortedIndices) {
        _ipos.removeAt(idx);
      }
      changed = true;
    }

    if (appsRebound) {
      await prefs.setString(
        _keyApps,
        jsonEncode(_applications.map((e) => e.toJson()).toList()),
      );
      await prefs.setStringList(
        _keyWatchlist,
        _watchlistIpoIds.toList(),
      );
    }

    // 1. Correct well-known official Narada IDs and heal fields
    for (int i = 0; i < _ipos.length; i++) {
      var ipo = _ipos[i];
      bool ipoChanged = false;

      if (ipo.symbol.toUpperCase() == 'NSE' && ipo.naradaId != 1089) {
        ipo = ipo.copyWith(naradaId: 1089);
        ipoChanged = true;
      } else if (ipo.symbol.toUpperCase() == 'SSRETAIL' && ipo.naradaId != 1088) {
        ipo = ipo.copyWith(naradaId: 1088);
        ipoChanged = true;
      } else if (ipo.symbol.toUpperCase() == 'MANIKA' && ipo.naradaId != 1079) {
        ipo = ipo.copyWith(naradaId: 1079);
        ipoChanged = true;
      }

      // 2. Mathematically enforce lotCost = lotSize * pricePerShare
      final correctLotCost = ipo.lotSize * ipo.pricePerShare;
      if (correctLotCost > 0 && (ipo.lotCost - correctLotCost).abs() > 0.01) {
        ipo = ipo.copyWith(lotCost: correctLotCost);
        ipoChanged = true;
      }

      // 3. Heal missing issueSizeCrores from reference seeds and known market issues if 0
      if (ipo.issueSizeCrores <= 0) {
        final sym = ipo.symbol.toUpperCase().trim();
        if (_knownIssueSizes.containsKey(sym)) {
          ipo = ipo.copyWith(issueSizeCrores: _knownIssueSizes[sym]!);
          ipoChanged = true;
        } else {
          final match = SampleData.initialIpos.firstWhere(
            (s) => s.symbol.toUpperCase().trim() == sym || s.id == ipo.id,
            orElse: () => ipo,
          );
          if (match.issueSizeCrores > 0) {
            ipo = ipo.copyWith(issueSizeCrores: match.issueSizeCrores);
            ipoChanged = true;
          } else {
            // Intelligent fallback estimation so every card displays an issue size
            final fallback = ipo.category == IpoCategory.sme ? 25.0 : 250.0;
            ipo = ipo.copyWith(issueSizeCrores: fallback);
            ipoChanged = true;
          }
        }
      }

      // 4. Stage isolation: Active issues can never have listingPrice or currentPrice
      final localClose = ipo.closeDate.toLocal();
      final closeDay = DateTime(localClose.year, localClose.month, localClose.day);
      final isBiddingActive = today.isBefore(closeDay) || (today.isAtSameMomentAs(closeDay) && !ipo.isClosed);

      if (isBiddingActive || ipo.isUpcoming) {
        if (ipo.listingPrice != null || ipo.currentPrice != null) {
          ipo = ipo.copyWith(
            clearListingPrice: true,
            clearCurrentPrice: true,
          );
          ipoChanged = true;
        }
        if (ipo.listingDate != null && ipo.listingDate!.isBefore(ipo.closeDate)) {
          ipo = ipo.copyWith(listingDate: ipo.closeDate.add(const Duration(days: 3)));
          ipoChanged = true;
        }
      }

      if (ipoChanged) {
        _ipos[i] = ipo;
        changed = true;
      }
    }

    if (changed) {
      await prefs.setString(
        _keyIpos,
        jsonEncode(_ipos.map((e) => e.toJson()).toList()),
      );
    }
  }

  Future<void> _syncInitialIpos(SharedPreferences prefs) async {
    bool changed = false;

    if (_ipos.isEmpty) {
      _ipos = List.from(SampleData.initialIpos);
      await prefs.setString(
        _keyIpos,
        jsonEncode(_ipos.map((e) => e.toJson()).toList()),
      );
      return;
    }

    for (final incoming in SampleData.initialIpos) {
      final index = _ipos.indexWhere((i) =>
          i.id == incoming.id ||
          i.symbol.toUpperCase() == incoming.symbol.toUpperCase());
      if (index >= 0) {
        final existing = _ipos[index];
        final isIncomingActiveOrUpcoming = incoming.isOpen || incoming.isUpcoming;
        final updated = existing.copyWith(
          naradaId: incoming.naradaId ?? existing.naradaId,
          name: incoming.name,
          symbol: incoming.symbol,
          category: incoming.category,
          pricePerShare: incoming.pricePerShare,
          minPrice: incoming.minPrice,
          maxPrice: incoming.maxPrice,
          lotSize: incoming.lotSize,
          currentPrice: isIncomingActiveOrUpcoming ? null : (incoming.currentPrice ?? existing.currentPrice),
          listingPrice: isIncomingActiveOrUpcoming ? null : (incoming.listingPrice ?? existing.listingPrice),
          clearCurrentPrice: isIncomingActiveOrUpcoming,
          clearListingPrice: isIncomingActiveOrUpcoming,
          listingDate: isIncomingActiveOrUpcoming ? incoming.listingDate : (incoming.listingDate ?? existing.listingDate),
          openDate: incoming.openDate,
          closeDate: incoming.closeDate,
          allotmentDate: incoming.allotmentDate,
          gmp: existing.isCustomGmp ? existing.gmp : incoming.gmp,
          retailSubscription: incoming.retailSubscription > 0 ? incoming.retailSubscription : existing.retailSubscription,
          totalSubscription: incoming.totalSubscription > 0 ? incoming.totalSubscription : existing.totalSubscription,
          issueSizeCrores: incoming.issueSizeCrores > 0 ? incoming.issueSizeCrores : existing.issueSizeCrores,
        );
        if (updated.naradaId != existing.naradaId ||
            updated.currentPrice != existing.currentPrice ||
            updated.listingPrice != existing.listingPrice ||
            updated.listingDate != existing.listingDate ||
            updated.allotmentDate != existing.allotmentDate ||
            updated.openDate != existing.openDate ||
            updated.closeDate != existing.closeDate ||
            updated.pricePerShare != existing.pricePerShare ||
            updated.minPrice != existing.minPrice ||
            updated.maxPrice != existing.maxPrice ||
            updated.lotSize != existing.lotSize ||
            updated.lotCost != existing.lotCost ||
            updated.issueSizeCrores != existing.issueSizeCrores ||
            updated.name != existing.name) {
          _ipos[index] = updated;
          changed = true;
        }
        // Purge any lingering duplicates matching incoming.symbol
        final removed = _ipos.where((i) =>
            i.id != existing.id &&
            i.symbol.toUpperCase().trim() == incoming.symbol.toUpperCase().trim()).toList();
        if (removed.isNotEmpty) {
          _ipos.removeWhere((i) =>
              i.id != existing.id &&
              i.symbol.toUpperCase().trim() == incoming.symbol.toUpperCase().trim());
          changed = true;
        }
      } else {
        _ipos.add(incoming);
        changed = true;
      }
    }

    if (changed) {
      await prefs.setString(
        _keyIpos,
        jsonEncode(_ipos.map((e) => e.toJson()).toList()),
      );
    }
  }

  void _sortPeople() {
    _people.sort((a, b) {
      if (a.isSelf && !b.isSelf) return -1;
      if (!a.isSelf && b.isSelf) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  Future<void> _syncNaradaPeople(SharedPreferences prefs) async {
    bool changed = false;

    if (_people.isEmpty) {
      _people = List.from(SampleData.naradaPeople);
      _sortPeople();
      await prefs.setString(
        _keyPeople,
        jsonEncode(_people.map((e) => e.toJson()).toList()),
      );
      return;
    }

    for (final incoming in SampleData.naradaPeople) {
      final index = _people.indexWhere((p) =>
          (p.pan.isNotEmpty && p.pan.toUpperCase() == incoming.pan.toUpperCase()) ||
          p.id == incoming.id);
      if (index >= 0) {
        final existing = _people[index];
        final updated = existing.copyWith(
          name: incoming.name.isNotEmpty ? incoming.name : existing.name,
          isSelf: incoming.isSelf || existing.isSelf,
          pan: existing.pan.isEmpty ? incoming.pan : existing.pan,
          phone: (existing.phone.isNotEmpty) ? existing.phone : incoming.phone,
          upiId: (existing.upiId.isNotEmpty) ? existing.upiId : incoming.upiId,
          bankName: (existing.bankName.isNotEmpty) ? existing.bankName : incoming.bankName,
          accountNumber: (existing.accountNumber.isNotEmpty) ? existing.accountNumber : incoming.accountNumber,
        );
        if (updated.name != existing.name ||
            updated.isSelf != existing.isSelf ||
            updated.pan != existing.pan) {
          _people[index] = updated;
          changed = true;
        }
      } else {
        _people.add(incoming);
        changed = true;
      }
    }

    // Explicitly guarantee Prathamesh isSelf is true
    final pIndex = _people.indexWhere((p) =>
        p.pan.toUpperCase() == 'MMEPS3478L' ||
        p.name.toLowerCase().contains('prathamesh'));
    if (pIndex >= 0 && !_people[pIndex].isSelf) {
      _people[pIndex] = _people[pIndex].copyWith(isSelf: true);
      changed = true;
    }

    _sortPeople();

    if (changed) {
      await prefs.setString(
        _keyPeople,
        jsonEncode(_people.map((e) => e.toJson()).toList()),
      );
    }
  }

  void _loadFromPrefs(SharedPreferences prefs) {
    // People
    final peopleJson = prefs.getString(_keyPeople);
    if (peopleJson != null) {
      final list = jsonDecode(peopleJson) as List;
      _people = list.map((e) => Person.fromJson(e as Map<String, dynamic>)).toList();
    }

    // IPOs
    final iposJson = prefs.getString(_keyIpos);
    if (iposJson != null) {
      final list = jsonDecode(iposJson) as List;
      _ipos = list.map((e) => Ipo.fromJson(e as Map<String, dynamic>)).toList();
    }

    // Applications
    final appsJson = prefs.getString(_keyApps);
    if (appsJson != null) {
      final list = jsonDecode(appsJson) as List;
      _applications = list
          .map((e) => IpoApplication.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // Ledger Entries
    final ledgerJson = prefs.getString(_keyLedger);
    if (ledgerJson != null) {
      final list = jsonDecode(ledgerJson) as List;
      _ledgerEntries = list
          .map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // Watchlist
    final watchlist = prefs.getStringList(_keyWatchlist);
    if (watchlist != null) {
      _watchlistIpoIds = watchlist.toSet();
    }

    // Preferences
    _privacyMode = prefs.getBool(_keyPrivacyMode) ?? false;
    _pureBlackMode = prefs.getBool(_keyPureBlackMode) ?? false;

    // Filters & Sorting persistence
    final catName = prefs.getString(_keyIpoCategoryFilter);
    if (catName != null) {
      try {
        _ipoCategoryFilter = IpoCategory.values.byName(catName);
      } catch (_) {
        _ipoCategoryFilter = null;
      }
    } else {
      _ipoCategoryFilter = null;
    }

    final sortName = prefs.getString(_keyIpoSortOption);
    if (sortName != null) {
      try {
        _ipoSortOption = IpoSortOption.values.byName(sortName);
      } catch (_) {
        _ipoSortOption = IpoSortOption.defaultOrder;
      }
    } else {
      _ipoSortOption = IpoSortOption.defaultOrder;
    }

    final statusName = prefs.getString(_keyAppStatusFilter);
    if (statusName != null) {
      try {
        _appStatusFilter = ApplicationStatus.values.byName(statusName);
      } catch (_) {
        _appStatusFilter = null;
      }
    } else {
      _appStatusFilter = null;
    }
  }

  Future<void> _saveAll(SharedPreferences prefs) async {
    await prefs.setString(
      _keyPeople,
      jsonEncode(_people.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _keyIpos,
      jsonEncode(_ipos.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _keyApps,
      jsonEncode(_applications.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _keyLedger,
      jsonEncode(_ledgerEntries.map((e) => e.toJson()).toList()),
    );
    await prefs.setStringList(
      _keyWatchlist,
      _watchlistIpoIds.toList(),
    );
    await prefs.setBool(_keyPrivacyMode, _privacyMode);
    await prefs.setBool(_keyPureBlackMode, _pureBlackMode);

    if (_ipoCategoryFilter != null) {
      await prefs.setString(_keyIpoCategoryFilter, _ipoCategoryFilter!.name);
    } else {
      await prefs.remove(_keyIpoCategoryFilter);
    }
    await prefs.setString(_keyIpoSortOption, _ipoSortOption.name);
    if (_appStatusFilter != null) {
      await prefs.setString(_keyAppStatusFilter, _appStatusFilter!.name);
    } else {
      await prefs.remove(_keyAppStatusFilter);
    }
  }

  Future<void> setIpoFilters({
    required IpoCategory? category,
    required IpoSortOption sort,
  }) async {
    _ipoCategoryFilter = category;
    _ipoSortOption = sort;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (category == null) {
      await prefs.remove(_keyIpoCategoryFilter);
    } else {
      await prefs.setString(_keyIpoCategoryFilter, category.name);
    }
    await prefs.setString(_keyIpoSortOption, sort.name);
  }

  Future<void> setAppStatusFilter(ApplicationStatus? status) async {
    _appStatusFilter = status;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (status == null) {
      await prefs.remove(_keyAppStatusFilter);
    } else {
      await prefs.setString(_keyAppStatusFilter, status.name);
    }
  }

  Future<void> toggleWatchlist(String ipoId) async {
    if (_watchlistIpoIds.contains(ipoId)) {
      _watchlistIpoIds.remove(ipoId);
    } else {
      _watchlistIpoIds.add(ipoId);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyWatchlist, _watchlistIpoIds.toList());
  }

  Future<void> togglePrivacyMode() async {
    _privacyMode = !_privacyMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPrivacyMode, _privacyMode);
  }

  Future<void> togglePureBlackMode() async {
    _pureBlackMode = !_pureBlackMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPureBlackMode, _pureBlackMode);
  }

  // --- PERSON OPERATIONS ---
  Future<void> savePerson(Person person) async {
    // If marking as self/primary account, clear isSelf flag on other accounts
    if (person.isSelf) {
      for (int i = 0; i < _people.length; i++) {
        if (_people[i].id != person.id && _people[i].isSelf) {
          _people[i] = _people[i].copyWith(isSelf: false);
        }
      }
    }

    final index = _people.indexWhere((p) => p.id == person.id);
    if (index >= 0) {
      _people[index] = person;
    } else {
      _people.add(person);
    }
    _sortPeople();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyPeople,
      jsonEncode(_people.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> mergePeople(List<Person> incoming) async {
    final prefs = await SharedPreferences.getInstance();
    await _syncNaradaPeople(prefs);
    notifyListeners();
  }

  Future<void> deletePerson(String id) async {
    _people.removeWhere((p) => p.id == id);
    _applications.removeWhere((a) => a.personId == id);
    _ledgerEntries.removeWhere((l) => l.personId == id);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _saveAll(prefs);
  }

  // --- IPO OPERATIONS ---
  Ipo? getIpo(String id) {
    try {
      return _ipos.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveIpo(Ipo ipo) async {
    final cleanSym = ipo.symbol.toUpperCase().trim();
    final index = _ipos.indexWhere((i) =>
        i.id == ipo.id ||
        (cleanSym.isNotEmpty && i.symbol.toUpperCase().trim() == cleanSym) ||
        (ipo.naradaId != null && i.naradaId == ipo.naradaId));

    if (index >= 0) {
      final existing = _ipos[index];
      final targetId = existing.id;
      final targetNaradaId = ipo.naradaId ?? existing.naradaId;
      double finalIssueSize = ipo.issueSizeCrores > 0
          ? ipo.issueSizeCrores
          : (existing.issueSizeCrores > 0 ? existing.issueSizeCrores : 0.0);
      if (finalIssueSize <= 0) {
        if (_knownIssueSizes.containsKey(cleanSym)) {
          finalIssueSize = _knownIssueSizes[cleanSym]!;
        } else {
          finalIssueSize = ipo.category == IpoCategory.sme ? 25.0 : 250.0;
        }
      }
      _ipos[index] = ipo.copyWith(
        id: targetId,
        naradaId: targetNaradaId,
        issueSizeCrores: finalIssueSize,
      );

      // Purge any other duplicate that might have snuck in with the same symbol or naradaId
      _ipos.removeWhere((i) =>
          i.id != targetId &&
          ((cleanSym.isNotEmpty && i.symbol.toUpperCase().trim() == cleanSym) ||
              (targetNaradaId != null && i.naradaId == targetNaradaId)));
    } else {
      var toInsert = ipo;
      if (toInsert.issueSizeCrores <= 0) {
        if (_knownIssueSizes.containsKey(cleanSym)) {
          toInsert = toInsert.copyWith(issueSizeCrores: _knownIssueSizes[cleanSym]!);
        } else {
          final fallback = toInsert.category == IpoCategory.sme ? 25.0 : 250.0;
          toInsert = toInsert.copyWith(issueSizeCrores: fallback);
        }
      }
      _ipos.insert(0, toInsert);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyIpos,
      jsonEncode(_ipos.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> deleteIpo(String id) async {
    _ipos.removeWhere((i) => i.id == id);
    _applications.removeWhere((a) => a.ipoId == id);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _saveAll(prefs);
  }

  // --- APPLICATION & SMART ALLOTMENT OPERATIONS ---
  Future<void> applyForIpo({
    required Ipo ipo,
    required Person person,
    required int lots,
    required double additionalFundsSent,
    String? note,
  }) async {
    final totalAmount = ipo.lotCost * lots;

    // 1. If user sent additional money to top-up the required float, record it
    if (additionalFundsSent > 0) {
      final sendEntry = LedgerEntry(
        personId: person.id,
        ipoId: ipo.id,
        ipoName: ipo.name,
        type: LedgerEntryType.sendToPerson,
        amount: additionalFundsSent,
        note: 'Sent delta/top-up funds for ${ipo.name}',
      );
      _ledgerEntries.insert(0, sendEntry);
    }

    // 2. Create the application record
    final application = IpoApplication(
      ipoId: ipo.id,
      personId: person.id,
      lots: lots,
      amountBlocked: totalAmount,
      status: ApplicationStatus.applied,
      notes: note ?? 'Applied for $lots lot(s)',
    );
    _applications.insert(0, application);

    // 3. Record the blocking in ledger
    final blockEntry = LedgerEntry(
      personId: person.id,
      applicationId: application.id,
      ipoId: ipo.id,
      ipoName: ipo.name,
      type: LedgerEntryType.blockForIpo,
      amount: totalAmount,
      note: 'Funds blocked for $lots lot(s) of ${ipo.name}',
    );
    _ledgerEntries.insert(0, blockEntry);

    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _saveAll(prefs);
  }

  /// Updates application status with smart ledger sync:
  /// - Not Allotted: Automatically creates refundUnblock entry, restoring available float!
  /// - Allotted: Automatically creates allotmentDebit entry!
  Future<void> updateApplicationStatus({
    required String applicationId,
    required ApplicationStatus newStatus,
    int? sharesAllotted,
    double? soldPricePerShare,
  }) async {
    final appIndex = _applications.indexWhere((a) => a.id == applicationId);
    if (appIndex < 0) return;

    final oldApp = _applications[appIndex];
    if (oldApp.status == newStatus) return;

    final ipo = _ipos.firstWhere(
      (i) => i.id == oldApp.ipoId,
      orElse: () => Ipo(
        name: 'Unknown IPO',
        symbol: 'IPO',
        lotSize: 1,
        pricePerShare: oldApp.amountBlocked,
        openDate: DateTime.now(),
        closeDate: DateTime.now(),
        allotmentDate: DateTime.now(),
      ),
    );

    double? profit;
    if (newStatus == ApplicationStatus.allotted && soldPricePerShare != null) {
      final totalShares = sharesAllotted ?? (oldApp.lots * ipo.lotSize);
      final totalSale = soldPricePerShare * totalShares;
      profit = totalSale - oldApp.amountBlocked;
    }

    final updatedApp = oldApp.copyWith(
      status: newStatus,
      sharesAllotted: sharesAllotted ?? (newStatus == ApplicationStatus.allotted ? (oldApp.lots * ipo.lotSize) : 0),
      soldPricePerShare: soldPricePerShare,
      profitRealized: profit,
    );

    _applications[appIndex] = updatedApp;

    // Handle Ledger synchronization
    if (newStatus == ApplicationStatus.notAllotted || newStatus == ApplicationStatus.withdrawn) {
      // ⚡ RECOVERY: Unblock funds back to available float!
      final refundEntry = LedgerEntry(
        personId: oldApp.personId,
        applicationId: oldApp.id,
        ipoId: ipo.id,
        ipoName: ipo.name,
        type: LedgerEntryType.refundUnblock,
        amount: oldApp.amountBlocked,
        note: newStatus == ApplicationStatus.withdrawn
            ? 'Funds unblocked after bid withdrawal for ${ipo.name}'
            : 'Funds unblocked after Not Allotted status for ${ipo.name}',
      );
      _ledgerEntries.insert(0, refundEntry);
    } else if (newStatus == ApplicationStatus.allotted) {
      // Allotment confirmed: fund permanently debited
      final debitEntry = LedgerEntry(
        personId: oldApp.personId,
        applicationId: oldApp.id,
        ipoId: ipo.id,
        ipoName: ipo.name,
        type: LedgerEntryType.allotmentDebit,
        amount: oldApp.amountBlocked,
        note: 'Allotment confirmed for ${ipo.name}. Funds debited for shares.',
      );
      _ledgerEntries.insert(0, debitEntry);

      if (profit != null && profit > 0) {
        final profitEntry = LedgerEntry(
          personId: oldApp.personId,
          applicationId: oldApp.id,
          ipoId: ipo.id,
          ipoName: ipo.name,
          type: LedgerEntryType.profitReceived,
          amount: profit,
          note: 'Listing gains realized from ${ipo.name}',
        );
        _ledgerEntries.insert(0, profitEntry);
      }
    }

    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _saveAll(prefs);
  }

  /// Withdraw / cancel an active IPO application and unblock funds back to float
  Future<void> withdrawApplication({
    required String applicationId,
    String? reason,
  }) async {
    await updateApplicationStatus(
      applicationId: applicationId,
      newStatus: ApplicationStatus.withdrawn,
    );
  }

  /// Completely delete a mistaken or cancelled application record
  Future<void> deleteApplication(String applicationId) async {
    final appIndex = _applications.indexWhere((a) => a.id == applicationId);
    if (appIndex < 0) return;

    final app = _applications[appIndex];
    final ipo = _ipos.firstWhere(
      (i) => i.id == app.ipoId,
      orElse: () => Ipo(
        name: 'Unknown IPO',
        symbol: 'IPO',
        lotSize: 1,
        pricePerShare: app.amountBlocked,
        openDate: DateTime.now(),
        closeDate: DateTime.now(),
        allotmentDate: DateTime.now(),
      ),
    );

    // If deleting an active pending bid that has not been refunded/debited yet,
    // restore the blocked funds so the ledger balance remains accurate.
    if (app.status == ApplicationStatus.applied) {
      final unblockEntry = LedgerEntry(
        personId: app.personId,
        applicationId: app.id,
        ipoId: ipo.id,
        ipoName: ipo.name,
        type: LedgerEntryType.refundUnblock,
        amount: app.amountBlocked,
        note: 'Funds restored after deleting mistaken application for ${ipo.name}',
      );
      _ledgerEntries.insert(0, unblockEntry);
    }

    _applications.removeAt(appIndex);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _saveAll(prefs);
  }

  // --- DIRECT MANUAL LEDGER ENTRIES ---
  Future<void> addManualTransaction({
    required String personId,
    required LedgerEntryType type,
    required double amount,
    required String note,
  }) async {
    final entry = LedgerEntry(
      personId: personId,
      type: type,
      amount: amount,
      note: note,
    );
    _ledgerEntries.insert(0, entry);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyLedger,
      jsonEncode(_ledgerEntries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> resetDemoData() async {
    // Only reloads real market IPO catalog. Leaves people, applications, and ledger completely intact!
    _ipos = List.from(SampleData.initialIpos);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyIpos,
      jsonEncode(_ipos.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clearAllData() async {
    _people = [];
    _ipos = [];
    _applications = [];
    _ledgerEntries = [];
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _saveAll(prefs);
  }
}
