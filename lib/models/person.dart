import 'package:uuid/uuid.dart';

class Person {
  final String id;
  final String name;
  final String pan;
  final String phone;
  final String upiId;
  final String bankName;
  final String accountNumber;
  final String notes;
  final bool isSelf;
  final DateTime createdAt;

  Person({
    String? id,
    required this.name,
    required this.pan,
    this.phone = '',
    this.upiId = '',
    this.bankName = '',
    this.accountNumber = '',
    this.notes = '',
    this.isSelf = false,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Person copyWith({
    String? name,
    String? pan,
    String? phone,
    String? upiId,
    String? bankName,
    String? accountNumber,
    String? notes,
    bool? isSelf,
  }) {
    return Person(
      id: id,
      name: name ?? this.name,
      pan: pan ?? this.pan,
      phone: phone ?? this.phone,
      upiId: upiId ?? this.upiId,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      notes: notes ?? this.notes,
      isSelf: isSelf ?? this.isSelf,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pan': pan.toUpperCase().trim(),
      'phone': phone,
      'upiId': upiId.trim(),
      'bankName': bankName,
      'accountNumber': accountNumber,
      'notes': notes,
      'isSelf': isSelf,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'] as String,
      name: json['name'] as String,
      pan: (json['pan'] as String).toUpperCase().trim(),
      phone: json['phone'] as String? ?? '',
      upiId: json['upiId'] as String? ?? '',
      bankName: json['bankName'] as String? ?? '',
      accountNumber: json['accountNumber'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      isSelf: json['isSelf'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
