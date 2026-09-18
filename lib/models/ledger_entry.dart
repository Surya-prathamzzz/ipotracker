import 'package:uuid/uuid.dart';

enum LedgerEntryType {
  sendToPerson,     // User sends capital to person (+ Float)
  blockForIpo,      // Blocked / Applied for an IPO (- Float, + Blocked)
  refundUnblock,    // IPO not allotted: fund unblocked (+ Float, - Blocked)
  allotmentDebit,   // IPO allotted: fund consumed for equity (- Blocked, + Asset)
  returnToUser,     // Person returns idle money back to user (- Float)
  profitReceived,   // Shares sold, sale proceeds received in person's account (+ Float)
}

class LedgerEntry {
  final String id;
  final String personId;
  final String? applicationId;
  final String? ipoId;
  final String? ipoName;
  final LedgerEntryType type;
  final double amount;
  final String note;
  final DateTime createdAt;

  LedgerEntry({
    String? id,
    required this.personId,
    this.applicationId,
    this.ipoId,
    this.ipoName,
    required this.type,
    required this.amount,
    this.note = '',
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'personId': personId,
      'applicationId': applicationId,
      'ipoId': ipoId,
      'ipoName': ipoName,
      'type': type.name,
      'amount': amount,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      id: json['id'] as String,
      personId: json['personId'] as String,
      applicationId: json['applicationId'] as String?,
      ipoId: json['ipoId'] as String?,
      ipoName: json['ipoName'] as String?,
      type: LedgerEntryType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LedgerEntryType.sendToPerson,
      ),
      amount: (json['amount'] as num).toDouble(),
      note: json['note'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  String get typeDisplayTitle {
    switch (type) {
      case LedgerEntryType.sendToPerson:
        return 'Sent to Person';
      case LedgerEntryType.blockForIpo:
        return 'Blocked for IPO';
      case LedgerEntryType.refundUnblock:
        return 'Unblocked / Refunded';
      case LedgerEntryType.allotmentDebit:
        return 'Allotted (Fund Debited)';
      case LedgerEntryType.returnToUser:
        return 'Returned to User';
      case LedgerEntryType.profitReceived:
        return 'Sale Proceeds / Profit';
    }
  }
}
