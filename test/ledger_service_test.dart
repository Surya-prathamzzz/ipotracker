import 'package:flutter_test/flutter_test.dart';
import 'package:ipotracker/models/ipo_application.dart';
import 'package:ipotracker/models/ledger_entry.dart';
import 'package:ipotracker/models/person.dart';
import 'package:ipotracker/services/ledger_service.dart';

void main() {
  group('LedgerService Math & Delta Tests', () {
    late Person dad;

    setUp(() {
      dad = Person(
        id: 'dad-1',
        name: 'Dad',
        pan: 'ABCDE1234F',
        upiId: 'dad@hdfcbank',
      );
    });

    test('Initial state has zero float and zero blocked', () {
      final entries = <LedgerEntry>[];
      final apps = <IpoApplication>[];

      final float = LedgerService.calculateAvailableFloat(dad.id, entries);
      final blocked = LedgerService.calculateBlockedAmount(dad.id, apps);

      expect(float, 0.0);
      expect(blocked, 0.0);
    });

    test('User sends ₹14,500 -> Float is ₹14,500', () {
      final entries = [
        LedgerEntry(
          personId: dad.id,
          type: LedgerEntryType.sendToPerson,
          amount: 14500,
        ),
      ];

      final float = LedgerService.calculateAvailableFloat(dad.id, entries);
      expect(float, 14500.0);
    });

    test('Funds blocked for IPO X (₹14,500) -> Available Float becomes ₹0', () {
      final entries = [
        LedgerEntry(
          personId: dad.id,
          type: LedgerEntryType.sendToPerson,
          amount: 14500,
        ),
        LedgerEntry(
          personId: dad.id,
          type: LedgerEntryType.blockForIpo,
          amount: 14500,
        ),
      ];

      final float = LedgerService.calculateAvailableFloat(dad.id, entries);
      expect(float, 0.0);
    });

    test(
        'User scenario: IPO X Not Allotted (Unblocked) -> Float restored to ₹14,500. Next IPO Y costs ₹14,800 -> Smart Delta outputs ₹300 deficit!',
        () {
      // 1. Sent 14,500
      // 2. Blocked 14,500
      // 3. Unblocked 14,500
      final entries = [
        LedgerEntry(
          personId: dad.id,
          type: LedgerEntryType.sendToPerson,
          amount: 14500,
        ),
        LedgerEntry(
          personId: dad.id,
          type: LedgerEntryType.blockForIpo,
          amount: 14500,
        ),
        LedgerEntry(
          personId: dad.id,
          type: LedgerEntryType.refundUnblock,
          amount: 14500,
        ),
      ];

      // Float should now be 14,500
      final float = LedgerService.calculateAvailableFloat(dad.id, entries);
      expect(float, 14500.0);

      // Now calculate delta for IPO Y costing 14,800
      final delta = LedgerService.calculateDelta(
        person: dad,
        requiredCost: 14800,
        entries: entries,
      );

      expect(delta.isFullyCovered, false);
      expect(delta.availableFloat, 14500.0);
      expect(delta.requiredAmount, 14800.0);
      expect(delta.amountToSend, 300.0); // Exact delta!
      expect(delta.surplus, 0.0);
    });

    test('If next IPO costs less (e.g. ₹13,000), surplus is ₹1,500 and amountToSend is 0', () {
      final entries = [
        LedgerEntry(
          personId: dad.id,
          type: LedgerEntryType.sendToPerson,
          amount: 14500,
        ),
      ];

      final delta = LedgerService.calculateDelta(
        person: dad,
        requiredCost: 13000,
        entries: entries,
      );

      expect(delta.isFullyCovered, true);
      expect(delta.amountToSend, 0.0);
      expect(delta.surplus, 1500.0);
    });

    test('Person returns idle float back to user -> Float decreases accordingly', () {
      final entries = [
        LedgerEntry(
          personId: dad.id,
          type: LedgerEntryType.sendToPerson,
          amount: 14500,
        ),
        LedgerEntry(
          personId: dad.id,
          type: LedgerEntryType.returnToUser,
          amount: 5000,
        ),
      ];

      final float = LedgerService.calculateAvailableFloat(dad.id, entries);
      expect(float, 9500.0);
    });
  });
}
