import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipotracker/models/person.dart';
import 'package:ipotracker/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('People & Narada Sync Tests', () {
    test('Initializes with all 9 Narada accounts with Prathamesh marked as isSelf', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      expect(storage.people.length, equals(9));
      expect(storage.people.first.name, contains('Prathamesh'));
      expect(storage.people.first.isSelf, isTrue);
      expect(storage.people.first.pan, equals('MMEPS3478L'));

      // Check all 9 PANs are present
      final pans = storage.people.map((p) => p.pan).toSet();
      expect(pans.contains('UNRPS7862E'), isTrue); // Aryan
      expect(pans.contains('MMEPS3478L'), isTrue); // Prathamesh (YOU)
      expect(pans.contains('AGNPW9609C'), isTrue); // Ritesh
      expect(pans.contains('EYHPP5611K'), isTrue); // Sarang
      expect(pans.contains('HHTPK9732C'), isTrue); // Vinay
      expect(pans.contains('PLDPS5929F'), isTrue); // Dhanshri
      expect(pans.contains('IAIPK8933G'), isTrue); // Varun
      expect(pans.contains('DULPG9849D'), isTrue); // Priyanka
      expect(pans.contains('AHDPW5924D'), isTrue); // Kunal
    });

    test('Merges existing database preserving bank/phone while adding new Narada accounts', () async {
      // Simulate existing state where only 2 people existed with partial names
      final existingPrathamesh = Person(
        id: '8cf283aa-3ad7-445a-8722-0b2bd9e132b0',
        name: 'Prathamesh Suryawanshi',
        pan: 'MMEPS3478L',
        phone: '8080044997',
        upiId: 'prathameshsuryawanshi51@oksbi',
        bankName: 'Canara Bank',
        accountNumber: '2091',
        isSelf: false, // Old state without isSelf
      );
      final existingSarang = Person(
        id: '0b73432b-bc88-4bde-9fd1-c22b27e0ebda',
        name: 'Sarang Phasale',
        pan: 'EYHPP5611K',
        phone: '7249645243',
        upiId: 'sarangphasale@okicici',
      );

      SharedPreferences.setMockInitialValues({
        'storage_people': jsonEncode([existingPrathamesh.toJson(), existingSarang.toJson()]),
      });

      final storage = StorageService();
      await storage.init();

      // Should now have all 9 accounts
      expect(storage.people.length, equals(9));

      // Prathamesh should be at top with isSelf = true, updated full name, and preserved bank/UPI/id
      final prathamesh = storage.people.first;
      expect(prathamesh.id, equals('8cf283aa-3ad7-445a-8722-0b2bd9e132b0'));
      expect(prathamesh.name, equals('Prathamesh Govind Suryawanshi'));
      expect(prathamesh.isSelf, isTrue);
      expect(prathamesh.phone, equals('8080044997'));
      expect(prathamesh.upiId, equals('prathameshsuryawanshi51@oksbi'));
      expect(prathamesh.bankName, equals('Canara Bank'));
      expect(prathamesh.accountNumber, equals('2091'));

      // Sarang should have preserved phone/UPI/id and updated full name
      final sarang = storage.people.firstWhere((p) => p.pan == 'EYHPP5611K');
      expect(sarang.id, equals('0b73432b-bc88-4bde-9fd1-c22b27e0ebda'));
      expect(sarang.name, equals('Sarang Gorakh Phasale'));
      expect(sarang.phone, equals('7249645243'));
    });
  });
}
