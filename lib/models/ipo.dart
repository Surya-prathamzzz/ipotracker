import 'dart:math' as math;
import 'package:uuid/uuid.dart';

enum IpoCategory {
  mainboard,
  sme,
}

enum IpoSortOption {
  defaultOrder,
  gmpPercentHighToLow,
  subscriptionHighToLow,
  closingSoonest,
}

extension IpoSortOptionExtension on IpoSortOption {
  String get displayName {
    switch (this) {
      case IpoSortOption.defaultOrder:
        return 'Default';
      case IpoSortOption.gmpPercentHighToLow:
        return 'GMP (% Gain)';
      case IpoSortOption.subscriptionHighToLow:
        return 'Subscription';
      case IpoSortOption.closingSoonest:
        return 'Closing Soon';
    }
  }
}

enum GmpTrend {
  up,
  down,
  stable,
}

enum RegistrarType {
  linkIntime,
  kfintech,
  bigshare,
  maashitla,
  skyline,
  purva,
  other,
}

extension RegistrarTypeExtension on RegistrarType {
  String get displayName {
    switch (this) {
      case RegistrarType.linkIntime:
        return 'Link Intime';
      case RegistrarType.kfintech:
        return 'KFintech';
      case RegistrarType.bigshare:
        return 'Bigshare Services';
      case RegistrarType.maashitla:
        return 'Maashitla';
      case RegistrarType.skyline:
        return 'Skyline Financial';
      case RegistrarType.purva:
        return 'Purva Sharegistry';
      case RegistrarType.other:
        return 'Other';
    }
  }

  String get defaultPortalUrl {
    switch (this) {
      case RegistrarType.linkIntime:
        return 'https://linkintime.co.in/initial_offer/public-issues.html';
      case RegistrarType.kfintech:
        return 'https://ris.kfintech.com/ipostatus/';
      case RegistrarType.bigshare:
        return 'https://ipo.bigshareonline.com/ipo_status.html';
      case RegistrarType.maashitla:
        return 'https://maashitla.com/allotment-status';
      case RegistrarType.skyline:
        return 'https://www.skylinerta.com/ipo.php';
      case RegistrarType.purva:
        return 'https://www.purvashare.com/investor-service/ipo-query';
      case RegistrarType.other:
        return 'https://www.bseindia.com/investors/appli_check.aspx';
    }
  }
}

class Ipo {
  final String id;
  final String name;
  final String symbol;
  final int lotSize;
  final double pricePerShare;
  final double lotCost; // lotSize * pricePerShare
  final IpoCategory category;
  final DateTime openDate;
  final DateTime closeDate;
  final DateTime allotmentDate;
  final DateTime? listingDate;
  final RegistrarType registrar;
  final String customRegistrarUrl;
  final double gmp; // Grey market premium per share
  final GmpTrend gmpTrend;
  final double? customGmp; // User-defined or dealer-quoted custom GMP override
  final bool isCustomGmp; // Whether user has activated custom GMP override
  final double retailSubscription;
  final double qibSubscription;
  final double niiSubscription;
  final double bNiiSubscription;
  final double sNiiSubscription;
  final double employeeSubscription;
  final double totalSubscription;
  final double issueSizeCrores;
  final double minPrice;
  final double maxPrice;
  final double? currentPrice; // Current market trading price after listing
  final double? listingPrice; // Exchange listing opening price
  final int? naradaId; // Optional backend ID for live Narada allotment API
  final DateTime lastUpdated;
  final String notes;

  Ipo({
    String? id,
    required this.name,
    required this.symbol,
    required this.lotSize,
    required this.pricePerShare,
    double? lotCost,
    this.category = IpoCategory.mainboard,
    required this.openDate,
    required this.closeDate,
    required this.allotmentDate,
    DateTime? listingDate,
    this.registrar = RegistrarType.linkIntime,
    this.customRegistrarUrl = '',
    this.gmp = 0.0,
    this.gmpTrend = GmpTrend.stable,
    this.customGmp,
    this.isCustomGmp = false,
    this.retailSubscription = 0.0,
    this.qibSubscription = 0.0,
    this.niiSubscription = 0.0,
    this.bNiiSubscription = 0.0,
    this.sNiiSubscription = 0.0,
    this.employeeSubscription = 0.0,
    this.totalSubscription = 0.0,
    this.issueSizeCrores = 0.0,
    double? minPrice,
    double? maxPrice,
    double? currentPrice,
    double? listingPrice,
    this.naradaId,
    DateTime? lastUpdated,
    this.notes = '',
  })  : id = id ?? const Uuid().v4(),
        lotCost = (lotSize > 0 && pricePerShare > 0)
            ? (lotSize * pricePerShare)
            : ((lotCost != null && lotCost > 0) ? lotCost : 0.0),
        minPrice = (minPrice != null && maxPrice != null && minPrice > maxPrice)
            ? maxPrice
            : (minPrice ?? (pricePerShare > 0 ? pricePerShare : (maxPrice ?? 0.0))),
        maxPrice = (minPrice != null && maxPrice != null && maxPrice < minPrice)
            ? minPrice
            : (maxPrice ?? (pricePerShare > 0 ? pricePerShare : (minPrice ?? 0.0))),
        listingDate = (listingDate != null && listingDate.isBefore(closeDate))
            ? closeDate.add(const Duration(days: 3))
            : listingDate,
        listingPrice = (DateTime.now().isBefore(closeDate)) ? null : listingPrice,
        currentPrice = (DateTime.now().isBefore(closeDate)) ? null : currentPrice,
        lastUpdated = lastUpdated ?? DateTime.now();

  String get portalUrl {
    if (customRegistrarUrl.isNotEmpty) return customRegistrarUrl;
    return registrar.defaultPortalUrl;
  }

  bool get isUpcoming {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final openDay = DateTime(openDate.year, openDate.month, openDate.day);
    return today.isBefore(openDay);
  }

  bool get isClosed {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final localClose = closeDate.toLocal();
    final closeDay = DateTime(localClose.year, localClose.month, localClose.day);

    // If closeDay was before today, it is already closed
    if (today.isAfter(closeDay)) return true;

    // If closeDay is in the future, it is not closed yet
    if (today.isBefore(closeDay)) return false;

    // On the closing day itself, Indian IPO market bidding closes at 17:00 (5:00 PM IST)
    final marketCloseTime = DateTime(closeDay.year, closeDay.month, closeDay.day, 17, 0);
    return now.isAfter(marketCloseTime);
  }

  bool get isOpen => !isUpcoming && !isClosed && !isListed;

  /// Whether the IPO has been listed on the stock exchange
  bool get isListed {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final localClose = closeDate.toLocal();
    final closeDay = DateTime(localClose.year, localClose.month, localClose.day);
    // An issue cannot be listed while bidding is still ongoing
    if (today.isBefore(closeDay)) return false;
    return listingDate != null && now.isAfter(listingDate!);
  }

  /// Whether the allotment status has been finalized/announced
  bool get isAllotmentOut {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final localClose = closeDate.toLocal();
    final closeDay = DateTime(localClose.year, localClose.month, localClose.day);
    // Allotment cannot occur before bidding closes
    if (today.isBefore(closeDay)) return false;
    return now.isAfter(allotmentDate);
  }

  /// In the "Allotted / Listed" tab, show IPOs that have allotment,
  /// and if listed, keep them visible till 5 days after listing date.
  bool get isAllottedOrListed {
    final now = DateTime.now();
    if (!isAllotmentOut) return false;

    if (listingDate != null && now.isAfter(listingDate!)) {
      final listingDay = DateTime(listingDate!.year, listingDate!.month, listingDate!.day);
      final currentDay = DateTime(now.year, now.month, now.day);
      final daysSinceListing = currentDay.difference(listingDay).inDays;
      if (daysSinceListing > 5) {
        return false;
      }
    }
    return true;
  }

  /// Effective current trading or estimated price
  double get effectiveCurrentPrice {
    if (currentPrice != null && currentPrice! > 0) return currentPrice!;
    if (listingPrice != null && listingPrice! > 0) return listingPrice!;
    return pricePerShare + effectiveGmp;
  }

  /// Effective listing price (opening price on exchange)
  double get effectiveListingPrice {
    if (listingPrice != null && listingPrice! > 0) return listingPrice!;
    return pricePerShare;
  }

  /// Gain percentage of listing opening price compared to issue price
  double get listingGainPercent {
    if (pricePerShare <= 0) return 0.0;
    return ((effectiveListingPrice - pricePerShare) / pricePerShare) * 100.0;
  }

  /// Gain per share compared to issue/cut-off price
  double get gainFromIssuePrice => effectiveCurrentPrice - pricePerShare;

  /// Gain percentage compared to issue/cut-off price
  double get gainPercentFromIssuePrice {
    if (pricePerShare <= 0) return 0.0;
    return (gainFromIssuePrice / pricePerShare) * 100.0;
  }

  /// Gain per lot based on current market price
  double get totalGainPerLot => gainFromIssuePrice * lotSize;

  /// Returns custom GMP if user has overridden it, else the live market GMP.
  double get effectiveGmp => (isCustomGmp && customGmp != null) ? customGmp! : gmp;

  double get gmpPercent {
    if (pricePerShare <= 0) return 0.0;
    return (effectiveGmp / pricePerShare) * 100.0;
  }

  double get estimatedListingGainPerLot {
    return effectiveGmp * lotSize;
  }

  double get estimatedListingPrice {
    return pricePerShare + effectiveGmp;
  }

  /// Formatted issue size string, e.g. "₹500 Cr", "₹22,569 Cr", "₹125.5 Cr"
  String get formattedIssueSize {
    if (issueSizeCrores <= 0) return '';
    if (issueSizeCrores >= 1000) {
      final rounded = issueSizeCrores.round();
      final str = rounded.toString();
      String formatted;
      if (str.length > 3) {
        final last3 = str.substring(str.length - 3);
        var rest = str.substring(0, str.length - 3);
        final parts = <String>[];
        while (rest.length > 2) {
          parts.insert(0, rest.substring(rest.length - 2));
          rest = rest.substring(0, rest.length - 2);
        }
        parts.insert(0, rest);
        formatted = '${parts.join(',')},$last3';
      } else {
        formatted = str;
      }
      return '₹$formatted Cr';
    } else if (issueSizeCrores >= 100) {
      if ((issueSizeCrores - issueSizeCrores.round()).abs() < 0.1) {
        return '₹${issueSizeCrores.round()} Cr';
      }
      return '₹${issueSizeCrores.toStringAsFixed(1)} Cr';
    } else if (issueSizeCrores >= 10) {
      if ((issueSizeCrores - issueSizeCrores.round()).abs() < 0.1) {
        return '₹${issueSizeCrores.round()} Cr';
      }
      return '₹${issueSizeCrores.toStringAsFixed(1)} Cr';
    } else {
      return '₹${issueSizeCrores.toStringAsFixed(1)} Cr';
    }
  }

  /// Calculates probability of getting at least 1 allotment based on retail oversubscription.
  /// For example, if Retail is 25x, single account chance is 1/25 = 4%.
  /// With 5 family accounts, chance is 1 - (1 - 0.04)^5 = 18.46%.
  double getRetailAllotmentProbability({int accountsCount = 1}) {
    if (retailSubscription <= 0.0) return 0.0;
    if (retailSubscription <= 1.0) return 100.0;
    final singleChance = 1.0 / retailSubscription;
    if (accountsCount <= 1) {
      return singleChance * 100.0;
    }
    final noneChance = math.pow(1.0 - singleChance, accountsCount).toDouble();
    final combined = (1.0 - noneChance) * 100.0;
    return combined.clamp(0.0, 100.0);
  }

  Ipo copyWith({
    String? id,
    String? name,
    String? symbol,
    int? lotSize,
    double? pricePerShare,
    double? lotCost,
    IpoCategory? category,
    DateTime? openDate,
    DateTime? closeDate,
    DateTime? allotmentDate,
    DateTime? listingDate,
    RegistrarType? registrar,
    String? customRegistrarUrl,
    double? gmp,
    GmpTrend? gmpTrend,
    double? customGmp,
    bool? isCustomGmp,
    double? retailSubscription,
    double? qibSubscription,
    double? niiSubscription,
    double? bNiiSubscription,
    double? sNiiSubscription,
    double? employeeSubscription,
    double? totalSubscription,
    double? issueSizeCrores,
    double? minPrice,
    double? maxPrice,
    double? currentPrice,
    double? listingPrice,
    bool clearCurrentPrice = false,
    bool clearListingPrice = false,
    int? naradaId,
    DateTime? lastUpdated,
    String? notes,
  }) {
    return Ipo(
      id: id ?? this.id,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      lotSize: lotSize ?? this.lotSize,
      pricePerShare: pricePerShare ?? this.pricePerShare,
      lotCost: lotCost ?? ((lotSize ?? this.lotSize) * (pricePerShare ?? this.pricePerShare)),
      category: category ?? this.category,
      openDate: openDate ?? this.openDate,
      closeDate: closeDate ?? this.closeDate,
      allotmentDate: allotmentDate ?? this.allotmentDate,
      listingDate: listingDate ?? this.listingDate,
      registrar: registrar ?? this.registrar,
      customRegistrarUrl: customRegistrarUrl ?? this.customRegistrarUrl,
      gmp: gmp ?? this.gmp,
      gmpTrend: gmpTrend ?? this.gmpTrend,
      customGmp: customGmp ?? this.customGmp,
      isCustomGmp: isCustomGmp ?? this.isCustomGmp,
      retailSubscription: retailSubscription ?? this.retailSubscription,
      qibSubscription: qibSubscription ?? this.qibSubscription,
      niiSubscription: niiSubscription ?? this.niiSubscription,
      bNiiSubscription: bNiiSubscription ?? this.bNiiSubscription,
      sNiiSubscription: sNiiSubscription ?? this.sNiiSubscription,
      employeeSubscription: employeeSubscription ?? this.employeeSubscription,
      totalSubscription: totalSubscription ?? this.totalSubscription,
      issueSizeCrores: issueSizeCrores ?? this.issueSizeCrores,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      currentPrice: clearCurrentPrice ? null : (currentPrice ?? this.currentPrice),
      listingPrice: clearListingPrice ? null : (listingPrice ?? this.listingPrice),
      naradaId: naradaId ?? this.naradaId,
      lastUpdated: lastUpdated ?? DateTime.now(),
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'symbol': symbol,
      'lotSize': lotSize,
      'pricePerShare': pricePerShare,
      'lotCost': lotCost,
      'category': category.name,
      'openDate': openDate.toIso8601String(),
      'closeDate': closeDate.toIso8601String(),
      'allotmentDate': allotmentDate.toIso8601String(),
      'listingDate': listingDate?.toIso8601String(),
      'registrar': registrar.name,
      'customRegistrarUrl': customRegistrarUrl,
      'gmp': gmp,
      'gmpTrend': gmpTrend.name,
      'customGmp': customGmp,
      'isCustomGmp': isCustomGmp,
      'retailSubscription': retailSubscription,
      'qibSubscription': qibSubscription,
      'niiSubscription': niiSubscription,
      'bNiiSubscription': bNiiSubscription,
      'sNiiSubscription': sNiiSubscription,
      'employeeSubscription': employeeSubscription,
      'totalSubscription': totalSubscription,
      'issueSizeCrores': issueSizeCrores,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'currentPrice': currentPrice,
      'listingPrice': listingPrice,
      'naradaId': naradaId,
      'lastUpdated': lastUpdated.toIso8601String(),
      'notes': notes,
    };
  }

  factory Ipo.fromJson(Map<String, dynamic> json) {
    return Ipo(
      id: json['id'] as String,
      name: json['name'] as String,
      symbol: json['symbol'] as String,
      lotSize: json['lotSize'] as int,
      pricePerShare: (json['pricePerShare'] as num).toDouble(),
      lotCost: (json['lotCost'] as num?)?.toDouble(),
      category: IpoCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => IpoCategory.mainboard,
      ),
      openDate: DateTime.parse(json['openDate'] as String),
      closeDate: DateTime.parse(json['closeDate'] as String),
      allotmentDate: DateTime.parse(json['allotmentDate'] as String),
      listingDate: json['listingDate'] != null
          ? DateTime.parse(json['listingDate'] as String)
          : null,
      registrar: RegistrarType.values.firstWhere(
        (e) => e.name == json['registrar'],
        orElse: () => RegistrarType.linkIntime,
      ),
      customRegistrarUrl: json['customRegistrarUrl'] as String? ?? '',
      gmp: (json['gmp'] as num?)?.toDouble() ?? 0.0,
      gmpTrend: GmpTrend.values.firstWhere(
        (e) => e.name == json['gmpTrend'],
        orElse: () => GmpTrend.stable,
      ),
      customGmp: (json['customGmp'] as num?)?.toDouble(),
      isCustomGmp: json['isCustomGmp'] as bool? ?? false,
      retailSubscription: (json['retailSubscription'] as num?)?.toDouble() ?? 0.0,
      qibSubscription: (json['qibSubscription'] as num?)?.toDouble() ?? 0.0,
      niiSubscription: (json['niiSubscription'] as num?)?.toDouble() ?? 0.0,
      bNiiSubscription: (json['bNiiSubscription'] as num?)?.toDouble() ?? 0.0,
      sNiiSubscription: (json['sNiiSubscription'] as num?)?.toDouble() ?? 0.0,
      employeeSubscription: (json['employeeSubscription'] as num?)?.toDouble() ?? 0.0,
      totalSubscription: (json['totalSubscription'] as num?)?.toDouble() ?? 0.0,
      issueSizeCrores: (json['issueSizeCrores'] as num?)?.toDouble() ?? 0.0,
      minPrice: (json['minPrice'] as num?)?.toDouble(),
      maxPrice: (json['maxPrice'] as num?)?.toDouble(),
      currentPrice: (json['currentPrice'] as num?)?.toDouble(),
      listingPrice: (json['listingPrice'] as num?)?.toDouble(),
      naradaId: json['naradaId'] as int?,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : DateTime.now(),
      notes: json['notes'] as String? ?? '',
    );
  }
}
