import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/ipo.dart';
import 'storage_service.dart';

class MarketIntelligenceService extends ChangeNotifier {
  final StorageService _storageService;
  bool _isRefreshing = false;
  DateTime? _lastRefreshed;

  static const String _naradaEndpointBase =
      'https://app.trynarada.com/api/public/v1/ipos/';
  static const String _liveEndpointBase =
      'https://webnodejs.investorgain.com/cloud/v2/report/data-read/331/1';

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

  MarketIntelligenceService(this._storageService);

  bool get isRefreshing => _isRefreshing;
  DateTime? get lastRefreshed => _lastRefreshed;

  /// Returns true if data has never been synced or is older than 15 minutes.
  bool get isStale {
    if (_lastRefreshed == null) return true;
    return DateTime.now().difference(_lastRefreshed!) > const Duration(minutes: 15);
  }

  /// Automatically refreshes in background if data is older than 15 minutes.
  Future<int> refreshIfStale() async {
    if (isStale && !_isRefreshing) {
      return await refreshMarketData();
    }
    return 0;
  }

  /// Updates or resets the custom GMP for a specific IPO.
  /// If [isCustom] is true, [customGmp] overrides the market rate.
  /// If [isCustom] is false, reverts to live market quote.
  Future<void> updateCustomGmp({
    required String ipoId,
    required double? customGmp,
    required bool isCustom,
  }) async {
    final ipo = _storageService.getIpo(ipoId);
    if (ipo == null) return;

    final updated = ipo.copyWith(
      customGmp: customGmp,
      isCustomGmp: isCustom,
      lastUpdated: DateTime.now(),
    );

    await _storageService.saveIpo(updated);
    notifyListeners();
  }

  /// Fetches the latest live GMP, listing prices, current prices, and subscriptions.
  /// Prioritizes Narada's clean public feed with InvestorGain and local fallback.
  Future<int> refreshMarketData() async {
    _isRefreshing = true;
    notifyListeners();

    int updatedCount = 0;
    try {
      // 1. Primary: Narada's live public IPO feed
      try {
        updatedCount = await _fetchNaradaMarketData();
      } catch (e) {
        debugPrint('Narada live feed error, falling back to secondary: $e');
        // 2. Secondary: InvestorGain live web feed
        updatedCount = await _fetchLiveMarketData();
      }
    } catch (e) {
      debugPrint('Live web feed unavailable, applying local/cached fallback: $e');
      // 3. Offline / network failure fallback
      updatedCount = await _applyLocalFallback();
    } finally {
      _lastRefreshed = DateTime.now();
      _isRefreshing = false;
      notifyListeners();
    }

    return updatedCount;
  }

  /// Fetches authoritative detail for an individual IPO from Narada backend
  Future<Map<String, dynamic>?> _fetchNaradaDetail(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$_naradaEndpointBase$id/'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['data'] is Map<String, dynamic>) {
          return json['data'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('Error fetching Narada detail for id $id: $e');
    }
    return null;
  }

  /// Fetches real-time market data directly from Narada's public IPO backend
  Future<int> _fetchNaradaMarketData() async {
    final response = await http.get(
      Uri.parse(_naradaEndpointBase),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw Exception('Narada HTTP error ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final list = json['data'] as List?;
    if (list == null || list.isEmpty) {
      throw Exception('Empty data in Narada response');
    }

    final currentIpos = List<Ipo>.from(_storageService.ipos);
    int updatedCount = 0;

    // Pre-fetch authoritative details for active, upcoming, allotted & recent listed issues concurrently
    final activeItems = list.where((raw) {
      if (raw is! Map) return false;
      final st = (raw['stage'] ?? '').toString().toUpperCase();
      final id = raw['id'];
      if (id is! int) return false;
      if (st == 'OPEN' || st == 'UPCOMING' || st == 'CLOSED' || st == 'ALLOTTED') return true;
      if (st == 'LISTED') {
        if (raw['listing_at'] == null) return false;
        final listingAt = DateTime.tryParse(raw['listing_at'].toString());
        if (listingAt != null && DateTime.now().difference(listingAt).inDays.abs() <= 10) {
          return true;
        }
      }
      return false;
    }).toList();

    final detailsMap = <int, Map<String, dynamic>>{};
    if (activeItems.isNotEmpty) {
      try {
        final futures = activeItems.map((item) {
          final id = item['id'] as int;
          return _fetchNaradaDetail(id);
        });
        final results = await Future.wait(futures).timeout(const Duration(seconds: 8));
        for (int i = 0; i < activeItems.length; i++) {
          final res = results[i];
          if (res != null) {
            detailsMap[activeItems[i]['id'] as int] = res;
          }
        }
      } catch (e) {
        debugPrint('Error batch-fetching active IPO details: $e');
      }
    }

    for (final raw in list) {
      if (raw is! Map) continue;
      final item = raw as Map<String, dynamic>;

      final rawName = (item['name'] ?? '').toString().trim();
      final symbol = (item['symbol'] ?? '').toString().trim().toUpperCase();
      if (rawName.isEmpty && symbol.isEmpty) continue;

      final naradaId = item['id'] as int?;
      final isSme = item['is_sme'] == true;
      final category = isSme ? IpoCategory.sme : IpoCategory.mainboard;
      final stage = (item['stage'] ?? '').toString().toUpperCase();
      final allotmentStatus = (item['allotment_status'] ?? '').toString().toUpperCase();

      DateTime? openAt = item['open_at'] != null ? DateTime.tryParse(item['open_at'].toString())?.toLocal() : null;
      DateTime? closeAt = item['close_at'] != null ? DateTime.tryParse(item['close_at'].toString())?.toLocal() : null;
      DateTime? allotmentAt = item['allotment_at'] != null ? DateTime.tryParse(item['allotment_at'].toString())?.toLocal() : null;
      DateTime? listingAt = item['listing_at'] != null ? DateTime.tryParse(item['listing_at'].toString())?.toLocal() : null;
      String? allotmentUrl = item['allotment_url']?.toString();

      int lot = (item['lot_size'] as num?)?.toInt() ?? 0;
      final gmp = (item['gmp'] as num?)?.toDouble() ?? 0.0;
      final sub = (item['total_subscription'] as num?)?.toDouble() ?? 0.0;
      double minPrice = (item['min_price'] as num?)?.toDouble() ?? 0.0;
      double maxPrice = (item['max_price'] as num?)?.toDouble() ?? (minPrice > 0 ? minPrice : 100.0);
      final issuePrice = (item['issue_price'] as num?)?.toDouble() ?? maxPrice;
      final listingPrice = (item['listing_price'] as num?)?.toDouble();
      final currentPrice = (item['current_price'] as num?)?.toDouble();
      double issueSizeCrores = 0.0;

      // Apply pre-fetched authoritative detail if available
      final detail = detailsMap[naradaId];
      if (detail != null) {
        final detailLot = (detail['lot_size'] as num?)?.toInt() ?? 0;
        if (detailLot > 0) lot = detailLot;
        final dMin = (detail['min_price'] as num?)?.toDouble() ?? 0.0;
        if (dMin > 0) minPrice = dMin;
        final dMax = (detail['max_price'] as num?)?.toDouble() ?? 0.0;
        if (dMax > 0) maxPrice = dMax;
        final rawShares = (detail['issue_size'] as num?)?.toDouble() ?? 0.0;
        final maxP = dMax > 0 ? dMax : maxPrice;
        if (rawShares > 0 && maxP > 0) {
          final calc = (rawShares * maxP) / 10000000.0;
          final nearest50 = (calc / 50).round() * 50.0;
          if ((calc - nearest50).abs() <= 1.0) {
            issueSizeCrores = nearest50;
          } else {
            issueSizeCrores = (calc * 10).round() / 10.0;
          }
        }
        if (detail['open_at'] != null) {
          final dt = DateTime.tryParse(detail['open_at'].toString())?.toLocal();
          if (dt != null) openAt = dt;
        }
        if (detail['close_at'] != null) {
          final dt = DateTime.tryParse(detail['close_at'].toString())?.toLocal();
          if (dt != null) closeAt = dt;
        }
        if (detail['allotment_at'] != null) {
          final dt = DateTime.tryParse(detail['allotment_at'].toString())?.toLocal();
          if (dt != null) allotmentAt = dt;
        }
        if (detail['listing_at'] != null) {
          final dt = DateTime.tryParse(detail['listing_at'].toString())?.toLocal();
          if (dt != null) listingAt = dt;
        }
        if (detail['allotment_url'] != null && detail['allotment_url'].toString().isNotEmpty) {
          allotmentUrl = detail['allotment_url'].toString();
        }
      }

      RegistrarType? detectedRegistrar;
      if (allotmentUrl != null && allotmentUrl.isNotEmpty) {
        final lowerUrl = allotmentUrl.toLowerCase();
        if (lowerUrl.contains('kfintech')) {
          detectedRegistrar = RegistrarType.kfintech;
        } else if (lowerUrl.contains('linkintime') || lowerUrl.contains('mufg') || lowerUrl.contains('mpms')) {
          detectedRegistrar = RegistrarType.linkIntime;
        } else if (lowerUrl.contains('bigshare')) {
          detectedRegistrar = RegistrarType.bigshare;
        } else if (lowerUrl.contains('maashitla')) {
          detectedRegistrar = RegistrarType.maashitla;
        } else if (lowerUrl.contains('skyline')) {
          detectedRegistrar = RegistrarType.skyline;
        } else if (lowerUrl.contains('purva')) {
          detectedRegistrar = RegistrarType.purva;
        }
      }

      final pricePerShare = issuePrice > 0 ? issuePrice : maxPrice;

      // Fallback issue size if not resolved from detail
      if (issueSizeCrores <= 0) {
        final cleanSym = symbol.isNotEmpty ? symbol : _extractSymbol(rawName);
        if (_knownIssueSizes.containsKey(cleanSym)) {
          issueSizeCrores = _knownIssueSizes[cleanSym]!;
        } else {
          issueSizeCrores = isSme ? 25.0 : 250.0;
        }
      }

      // Estimate dates if missing
      final openDate = openAt ?? DateTime.now();
      final closeDate = closeAt ?? openDate.add(const Duration(days: 3));
      final calculatedAllotmentDate = allotmentAt ?? closeDate.add(const Duration(days: 2));
      final calculatedListingDate = listingAt ?? closeDate.add(const Duration(days: 4));

      final isStageActive = stage == 'UPCOMING' || stage == 'OPEN';

      // Match against existing IPOs in storage
      final existing = _findMatchingIpoBySymbolOrName(symbol, rawName, currentIpos, naradaId);

      if (existing != null) {
        final trend = gmp > existing.gmp
            ? GmpTrend.up
            : (gmp < existing.gmp ? GmpTrend.down : existing.gmpTrend);

        final updated = existing.copyWith(
          naradaId: naradaId ?? existing.naradaId,
          gmp: existing.isCustomGmp ? existing.gmp : gmp,
          gmpTrend: trend,
          totalSubscription: sub > 0 ? sub : existing.totalSubscription,
          issueSizeCrores: issueSizeCrores > 0 ? issueSizeCrores : existing.issueSizeCrores,
          lotSize: lot > 0 ? lot : existing.lotSize,
          pricePerShare: pricePerShare > 0 ? pricePerShare : existing.pricePerShare,
          minPrice: minPrice > 0 ? minPrice : existing.minPrice,
          maxPrice: maxPrice > 0 ? maxPrice : existing.maxPrice,
          listingPrice: isStageActive ? null : (listingPrice ?? existing.listingPrice),
          currentPrice: isStageActive ? null : (currentPrice ?? existing.currentPrice),
          openDate: openAt ?? existing.openDate,
          closeDate: closeAt ?? existing.closeDate,
          allotmentDate: allotmentAt ?? ((allotmentStatus == 'AVAILABLE' && existing.allotmentDate.isAfter(DateTime.now()))
              ? DateTime.now().subtract(const Duration(hours: 1))
              : (stage == 'UPCOMING' && openAt != null
                  ? openAt.add(const Duration(days: 3))
                  : ((stage == 'OPEN' && (existing.allotmentDate.isBefore(DateTime.now()) || existing.allotmentDate.isBefore(closeDate)))
                      ? closeDate.add(const Duration(days: 1))
                      : existing.allotmentDate))),
          listingDate: isStageActive
              ? (listingAt ?? (openAt != null ? openAt.add(const Duration(days: 5)) : closeDate.add(const Duration(days: 3))))
              : (stage == 'LISTED' && (existing.listingDate == null || existing.listingDate!.isAfter(DateTime.now()))
                  ? DateTime.now().subtract(const Duration(hours: 1))
                  : (listingAt ?? existing.listingDate)),
          registrar: detectedRegistrar ?? existing.registrar,
          customRegistrarUrl: (allotmentUrl != null && allotmentUrl.isNotEmpty) ? allotmentUrl : existing.customRegistrarUrl,
          lastUpdated: DateTime.now(),
        );

        if (updated.currentPrice != existing.currentPrice ||
            updated.listingPrice != existing.listingPrice ||
            updated.lotSize != existing.lotSize ||
            updated.issueSizeCrores != existing.issueSizeCrores ||
            updated.pricePerShare != existing.pricePerShare ||
            updated.gmp != existing.gmp) {
          updatedCount++;
        }
        await _storageService.saveIpo(updated);
        final idx = currentIpos.indexWhere((i) => i.id == existing.id);
        if (idx >= 0) {
          currentIpos[idx] = updated;
        }
      } else {
        // Newly discovered IPO from live Narada feed
        final isListed = stage == 'LISTED';
        final isAllotted = allotmentStatus == 'AVAILABLE';

        final effectiveAllotmentDate = isAllotted || isListed
            ? DateTime.now().subtract(const Duration(hours: 2))
            : calculatedAllotmentDate;
        final effectiveListingDate = isListed
            ? DateTime.now().subtract(const Duration(hours: 1))
            : calculatedListingDate;

        // Skip listed issues that were closed long ago (> 10 days)
        if (isListed && closeDate.difference(DateTime.now()).inDays.abs() > 10) {
          continue;
        }

        final newIpo = Ipo(
          naradaId: naradaId,
          name: rawName,
          symbol: symbol.isNotEmpty ? symbol : _extractSymbol(rawName),
          lotSize: lot > 0 ? lot : (isSme ? 1000 : (pricePerShare > 0 ? (15000 / pricePerShare).round().clamp(1, 1000) : 30)),
          pricePerShare: pricePerShare > 0 ? pricePerShare : 100.0,
          minPrice: minPrice > 0 ? minPrice : pricePerShare,
          maxPrice: maxPrice > 0 ? maxPrice : pricePerShare,
          issueSizeCrores: issueSizeCrores,
          category: category,
          openDate: openDate,
          closeDate: closeDate,
          allotmentDate: allotmentAt ?? effectiveAllotmentDate,
          listingDate: isStageActive ? (listingAt ?? effectiveListingDate) : effectiveListingDate,
          gmp: gmp,
          gmpTrend: gmp > 0 ? GmpTrend.up : GmpTrend.stable,
          listingPrice: isStageActive ? null : listingPrice,
          currentPrice: isStageActive ? null : currentPrice,
          totalSubscription: sub,
          retailSubscription: sub,
          registrar: detectedRegistrar ?? RegistrarType.linkIntime,
          customRegistrarUrl: allotmentUrl ?? '',
          lastUpdated: DateTime.now(),
        );

        await _storageService.saveIpo(newIpo);
        currentIpos.add(newIpo);
        updatedCount++;
      }
    }

    return updatedCount;
  }

  /// Queries the live Indian IPO & GMP cloud data feed
  Future<int> _fetchLiveMarketData() async {
    final now = DateTime.now();
    final month = now.month;
    final year = now.year;
    final fy = month >= 4 ? '$year-${(year % 100) + 1}' : '${year - 1}-${year % 100}';
    final url = Uri.parse('$_liveEndpointBase/$month/$year/$fy/0/all?search=');

    final response = await http.get(
      url,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Origin': 'https://www.investorgain.com',
        'Referer': 'https://www.investorgain.com/',
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw Exception('HTTP error ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['msg'] != 1 || data['reportTableData'] is! List) {
      throw Exception('Invalid data structure');
    }

    final list = data['reportTableData'] as List;
    final currentIpos = List<Ipo>.from(_storageService.ipos);
    int updatedCount = 0;

    final gmpRegex = RegExp(r'<b>([0-9\.]+)</b>');
    final subRegex = RegExp(r'([0-9\.]+)x?');

    for (final rawItem in list) {
      if (rawItem is! Map) continue;
      final item = rawItem as Map<String, dynamic>;

      final rawName = (item['~ipo_name'] ?? item['Name'] ?? '').toString().trim();
      if (rawName.isEmpty) continue;

      // Extract GMP
      final gmpHtml = (item['GMP'] ?? '').toString();
      final gmpMatch = gmpRegex.firstMatch(gmpHtml);
      final liveGmp = gmpMatch != null ? (double.tryParse(gmpMatch.group(1)!) ?? 0.0) : 0.0;

      // Extract GMP %
      final pct = double.tryParse(
            (item['~gmp_percent_calc'] ?? '0').toString().replaceAll('%', '').trim(),
          ) ??
          0.0;

      // Extract Lot size
      final lot = int.tryParse(
            (item['Lot'] ?? '0').toString().replaceAll(',', '').trim(),
          ) ??
          0;

      // Extract Subscriptions
      final subHtml = (item['Sub'] ?? '').toString();
      final subMatch = subRegex.firstMatch(subHtml);
      final sub = subMatch != null ? (double.tryParse(subMatch.group(1)!) ?? 0.0) : 0.0;

      // Extract IPO Size in Crores
      double issueSizeCrores = 0.0;
      final ipoSizeRaw = (item['IPO Size'] ?? '').toString();
      final sizeMatch = RegExp(r'([\d,.]+)\s*Cr', caseSensitive: false).firstMatch(ipoSizeRaw);
      if (sizeMatch != null) {
        issueSizeCrores = double.tryParse(sizeMatch.group(1)!.replaceAll(',', '')) ?? 0.0;
      }

      // Extract Category
      final isSme = (item['~IPO_Category'] ?? '').toString().toUpperCase() == 'SME';
      final category = isSme ? IpoCategory.sme : IpoCategory.mainboard;

      // Dates normalized to local time
      final openDate = DateTime.tryParse((item['~Srt_Open'] ?? '').toString())?.toLocal();
      final closeDate = DateTime.tryParse((item['~Srt_Close'] ?? '').toString())?.toLocal();
      final boaDate = DateTime.tryParse((item['~Srt_BoA_Dt'] ?? '').toString())?.toLocal();
      final listingDate = DateTime.tryParse((item['~Str_Listing'] ?? '').toString())?.toLocal();

      // Issue Price estimation if not provided directly
      double price = double.tryParse((item['Price (?)'] ?? '').toString()) ?? 0.0;
      if (price <= 0 && liveGmp > 0 && pct > 0) {
        price = (liveGmp / (pct / 100)).roundToDouble();
      }

      final isAlreadyListed = (listingDate != null && DateTime.now().isAfter(listingDate)) ||
          ((item['~ipo_status1'] ?? '') == 'LP' || (item['~ipo_status1'] ?? '') == 'LN');

      final isStageActive = closeDate != null && closeDate.isAfter(DateTime.now().subtract(const Duration(hours: 5)));

      double? estimatedCurrentPrice;
      if (isAlreadyListed && !isStageActive && price > 0 && liveGmp != 0) {
        estimatedCurrentPrice = price + liveGmp;
      }

      // Check for match in existing database by extracted symbol first
      final symbol = _extractSymbol(rawName);
      final existing = _findMatchingIpoBySymbolOrName(symbol, rawName, currentIpos);

      // Fallback issue size if not resolved from feed
      if (issueSizeCrores <= 0) {
        if (_knownIssueSizes.containsKey(symbol)) {
          issueSizeCrores = _knownIssueSizes[symbol]!;
        } else {
          issueSizeCrores = isSme ? 25.0 : 250.0;
        }
      }

      if (existing != null) {
        final trend = liveGmp > existing.gmp
            ? GmpTrend.up
            : (liveGmp < existing.gmp ? GmpTrend.down : existing.gmpTrend);

        final updated = existing.copyWith(
          gmp: liveGmp,
          gmpTrend: trend,
          retailSubscription: sub > 0 ? sub : existing.retailSubscription,
          totalSubscription: sub > 0 ? sub : existing.totalSubscription,
          issueSizeCrores: issueSizeCrores > 0 ? issueSizeCrores : existing.issueSizeCrores,
          lotSize: lot > 0 ? lot : existing.lotSize,
          pricePerShare: price > 0 ? price : existing.pricePerShare,
          allotmentDate: boaDate ?? existing.allotmentDate,
          listingDate: listingDate ?? existing.listingDate,
          currentPrice: isStageActive ? null : (existing.currentPrice ?? estimatedCurrentPrice),
          listingPrice: isStageActive ? null : existing.listingPrice,
          lastUpdated: DateTime.now(),
        );

        if (updated.gmp != existing.gmp ||
            updated.retailSubscription != existing.retailSubscription ||
            updated.issueSizeCrores != existing.issueSizeCrores ||
            updated.currentPrice != existing.currentPrice) {
          updatedCount++;
        }
        await _storageService.saveIpo(updated);
        final idx = currentIpos.indexWhere((i) => i.id == existing.id);
        if (idx >= 0) {
          currentIpos[idx] = updated;
        }
      } else if ((closeDate != null &&
              closeDate.isAfter(DateTime.now().subtract(const Duration(days: 10)))) ||
          (listingDate != null &&
              listingDate.isAfter(DateTime.now().subtract(const Duration(days: 5))))) {
        // Active, upcoming, or recently listed issue discovered from live market
        final newIpo = Ipo(
          name: rawName,
          symbol: symbol,
          lotSize: lot > 0 ? lot : (isSme ? 1000 : 30),
          pricePerShare: price > 0 ? price : 100.0,
          issueSizeCrores: issueSizeCrores,
          category: category,
          openDate: openDate ?? DateTime.now(),
          closeDate: closeDate ?? DateTime.now(),
          allotmentDate: boaDate ?? (closeDate ?? DateTime.now()).add(const Duration(days: 2)),
          listingDate: listingDate ?? (closeDate ?? DateTime.now()).add(const Duration(days: 4)),
          gmp: liveGmp,
          gmpTrend: liveGmp > 0 ? GmpTrend.up : GmpTrend.stable,
          currentPrice: estimatedCurrentPrice,
          retailSubscription: sub,
          totalSubscription: sub,
          lastUpdated: DateTime.now(),
        );

        await _storageService.saveIpo(newIpo);
        currentIpos.add(newIpo);
        updatedCount++;
      }
    }

    return updatedCount;
  }

  /// Match existing IPOs by symbol, naradaId, or normalized company name
  Ipo? _findMatchingIpoBySymbolOrName(String? symbol, String name, List<Ipo> ipos, [int? naradaId]) {
    // 1. Symbol is globally unique per exchange and most authoritative
    if (symbol != null && symbol.isNotEmpty) {
      final cleanSym = symbol.toUpperCase().trim();
      for (final ipo in ipos) {
        if (ipo.symbol.toUpperCase().trim() == cleanSym) return ipo;
      }
    }
    // 2. naradaId matching
    if (naradaId != null) {
      for (final ipo in ipos) {
        if (ipo.naradaId == naradaId) return ipo;
      }
    }
    // 3. Name matching
    return _findMatchingIpo(name, ipos);
  }

  /// Match existing IPOs by normalized company name (never loose substring of short tickers)
  Ipo? _findMatchingIpo(String name, List<Ipo> ipos) {
    final norm = _normalize(name);
    if (norm.isEmpty) return null;
    for (final ipo in ipos) {
      final ipoNorm = _normalize(ipo.name);
      if (ipoNorm == norm) return ipo;
      if (ipo.symbol.toLowerCase() == norm) return ipo;
      if (norm.length >= 6 && ipoNorm.length >= 6) {
        if (norm.startsWith(ipoNorm) || ipoNorm.startsWith(norm)) {
          return ipo;
        }
      }
    }
    return null;
  }

  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll('limited', '')
        .replaceAll('ltd', '')
        .replaceAll('ipo', '')
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll('-', '')
        .replaceAll('&', 'and')
        .replaceAll(' ', '')
        .trim();
  }

  String _extractSymbol(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
        .replaceAll('Limited', '')
        .replaceAll('Ltd', '')
        .trim();
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.isNotEmpty && parts.first.length >= 3) {
      return parts.first.toUpperCase();
    }
    return cleaned.toUpperCase().replaceAll(' ', '');
  }

  /// Offline local fallback in case network is disconnected
  Future<int> _applyLocalFallback() async {
    final currentIpos = List<Ipo>.from(_storageService.ipos);
    int updatedCount = 0;

    for (final ipo in currentIpos) {
      final feed = _getLocalFeedForSymbol(ipo.symbol);
      if (feed != null) {
        final newGmp = feed['gmp'] as double;
        final trend = newGmp > ipo.gmp
            ? GmpTrend.up
            : (newGmp < ipo.gmp ? GmpTrend.down : ipo.gmpTrend);

        final updated = ipo.copyWith(
          gmp: newGmp,
          gmpTrend: trend,
          retailSubscription: feed['retail'] as double,
          qibSubscription: feed['qib'] as double,
          niiSubscription: feed['nii'] as double,
          totalSubscription: feed['total'] as double,
          lastUpdated: DateTime.now(),
        );

        if (updated.gmp != ipo.gmp ||
            updated.retailSubscription != ipo.retailSubscription) {
          updatedCount++;
        }
        await _storageService.saveIpo(updated);
      }
    }

    return updatedCount;
  }

  Map<String, double>? _getLocalFeedForSymbol(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'HEROMOTO':
      case 'HERO':
        return {
          'gmp': 19.0,
          'retail': 18.4,
          'qib': 32.6,
          'nii': 21.2,
          'total': 24.1,
        };
      case 'NSE':
        return {
          'gmp': 132.0,
          'retail': 42.5,
          'qib': 118.0,
          'nii': 64.2,
          'total': 74.9,
        };
      case 'SSRETAIL':
        return {
          'gmp': 128.0,
          'retail': 9.2,
          'qib': 14.5,
          'nii': 11.8,
          'total': 11.8,
        };
      case 'SONASEL':
        return {
          'gmp': 8.0,
          'retail': 6.8,
          'qib': 12.0,
          'nii': 8.4,
          'total': 9.1,
        };
      case 'SPECTRAA':
        return {
          'gmp': 50.0,
          'retail': 54.2,
          'qib': 48.0,
          'nii': 82.5,
          'total': 61.5,
        };
      case 'ROBOKIDZ':
        return {
          'gmp': 45.0,
          'retail': 22.0,
          'qib': 15.0,
          'nii': 30.0,
          'total': 25.0,
        };
      case 'KHERIA':
        return {
          'gmp': 10.0,
          'retail': 12.5,
          'qib': 8.2,
          'nii': 15.0,
          'total': 11.9,
        };
      default:
        return null;
    }
  }
}
