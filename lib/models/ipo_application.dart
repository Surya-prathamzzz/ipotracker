import 'package:uuid/uuid.dart';

enum ApplicationStatus {
  applied,      // Application submitted, funds blocked
  allotted,     // Allotment confirmed, funds debited
  notAllotted,  // No allotment, funds unblocked / refunded
  withdrawn,    // Bid withdrawn before close
}

extension ApplicationStatusExtension on ApplicationStatus {
  String get displayName {
    switch (this) {
      case ApplicationStatus.applied:
        return 'Applied (Pending)';
      case ApplicationStatus.allotted:
        return 'Allotted 🎉';
      case ApplicationStatus.notAllotted:
        return 'Not Allotted (Refunded)';
      case ApplicationStatus.withdrawn:
        return 'Withdrawn';
    }
  }

  bool get isActive => this == ApplicationStatus.applied;
  bool get isWithdrawn => this == ApplicationStatus.withdrawn;
  bool get isResolved =>
      this == ApplicationStatus.allotted ||
      this == ApplicationStatus.notAllotted ||
      this == ApplicationStatus.withdrawn;
}

class IpoApplication {
  final String id;
  final String ipoId;
  final String personId;
  final int lots;
  final double amountBlocked;
  final DateTime appliedAt;
  final ApplicationStatus status;
  final int sharesAllotted;
  final double? soldPricePerShare;
  final double? profitRealized;
  final String notes;

  IpoApplication({
    String? id,
    required this.ipoId,
    required this.personId,
    this.lots = 1,
    required this.amountBlocked,
    DateTime? appliedAt,
    this.status = ApplicationStatus.applied,
    this.sharesAllotted = 0,
    this.soldPricePerShare,
    this.profitRealized,
    this.notes = '',
  })  : id = id ?? const Uuid().v4(),
        appliedAt = appliedAt ?? DateTime.now();

  IpoApplication copyWith({
    String? id,
    String? ipoId,
    String? personId,
    int? lots,
    double? amountBlocked,
    DateTime? appliedAt,
    ApplicationStatus? status,
    int? sharesAllotted,
    double? soldPricePerShare,
    double? profitRealized,
    String? notes,
  }) {
    return IpoApplication(
      id: id ?? this.id,
      ipoId: ipoId ?? this.ipoId,
      personId: personId ?? this.personId,
      lots: lots ?? this.lots,
      amountBlocked: amountBlocked ?? this.amountBlocked,
      appliedAt: appliedAt ?? this.appliedAt,
      status: status ?? this.status,
      sharesAllotted: sharesAllotted ?? this.sharesAllotted,
      soldPricePerShare: soldPricePerShare ?? this.soldPricePerShare,
      profitRealized: profitRealized ?? this.profitRealized,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ipoId': ipoId,
      'personId': personId,
      'lots': lots,
      'amountBlocked': amountBlocked,
      'appliedAt': appliedAt.toIso8601String(),
      'status': status.name,
      'sharesAllotted': sharesAllotted,
      'soldPricePerShare': soldPricePerShare,
      'profitRealized': profitRealized,
      'notes': notes,
    };
  }

  factory IpoApplication.fromJson(Map<String, dynamic> json) {
    return IpoApplication(
      id: json['id'] as String,
      ipoId: json['ipoId'] as String,
      personId: json['personId'] as String,
      lots: json['lots'] as int? ?? 1,
      amountBlocked: (json['amountBlocked'] as num).toDouble(),
      appliedAt: DateTime.parse(json['appliedAt'] as String),
      status: ApplicationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ApplicationStatus.applied,
      ),
      sharesAllotted: json['sharesAllotted'] as int? ?? 0,
      soldPricePerShare: (json['soldPricePerShare'] as num?)?.toDouble(),
      profitRealized: (json['profitRealized'] as num?)?.toDouble(),
      notes: json['notes'] as String? ?? '',
    );
  }
}
