import '../models/ledger_entry.dart';
import '../models/person.dart';
import '../models/ipo_application.dart';

class DeltaCalculationResult {
  final Person person;
  final double requiredAmount;
  final double availableFloat;
  final double amountToSend;
  final double surplus;
  final bool isFullyCovered;

  DeltaCalculationResult({
    required this.person,
    required this.requiredAmount,
    required this.availableFloat,
    required this.amountToSend,
    required this.surplus,
    required this.isFullyCovered,
  });

  String get summaryText {
    if (isFullyCovered) {
      if (surplus > 0) {
        return 'No money needed. Existing float of ₹${availableFloat.toStringAsFixed(0)} covers ₹${requiredAmount.toStringAsFixed(0)} with ₹${surplus.toStringAsFixed(0)} remaining.';
      } else {
        return 'No money needed. Existing float of ₹${availableFloat.toStringAsFixed(0)} covers exact cost.';
      }
    } else {
      return 'Send ₹${amountToSend.toStringAsFixed(0)} more (Has ₹${availableFloat.toStringAsFixed(0)}, Needs ₹${requiredAmount.toStringAsFixed(0)}).';
    }
  }
}

class PersonFinancialSummary {
  final Person person;
  final double availableFloat;
  final double blockedInIpos;
  final double totalCapitalWithPerson;
  final double totalProfitRealized;
  final int activeApplicationsCount;
  final int totalAllotmentsCount;

  PersonFinancialSummary({
    required this.person,
    required this.availableFloat,
    required this.blockedInIpos,
    required this.totalCapitalWithPerson,
    required this.totalProfitRealized,
    required this.activeApplicationsCount,
    required this.totalAllotmentsCount,
  });
}

class SyndicateDashboardSummary {
  final double totalFloatBalance;
  final double totalBlockedInIpos;
  final double totalCapitalDeployed;
  final double totalProfitRealized;
  final int totalPeopleCount;
  final int activeApplicationsCount;

  SyndicateDashboardSummary({
    required this.totalFloatBalance,
    required this.totalBlockedInIpos,
    required this.totalCapitalDeployed,
    required this.totalProfitRealized,
    required this.totalPeopleCount,
    required this.activeApplicationsCount,
  });
}

class LedgerService {
  /// Calculates the available unblocked float balance for a specific person
  static double calculateAvailableFloat(
    String personId,
    List<LedgerEntry> entries,
  ) {
    double balance = 0.0;
    for (final entry in entries) {
      if (entry.personId != personId) continue;
      switch (entry.type) {
        case LedgerEntryType.sendToPerson:
          balance += entry.amount;
          break;
        case LedgerEntryType.blockForIpo:
          balance -= entry.amount;
          break;
        case LedgerEntryType.refundUnblock:
          balance += entry.amount;
          break;
        case LedgerEntryType.allotmentDebit:
          // Money was already removed from available float during blockForIpo.
          // Debit confirms equity acquisition.
          break;
        case LedgerEntryType.returnToUser:
          balance -= entry.amount;
          break;
        case LedgerEntryType.profitReceived:
          balance += entry.amount;
          break;
      }
    }
    return balance < 0 ? 0.0 : balance;
  }

  /// Calculates funds currently blocked in pending IPOs for a person
  static double calculateBlockedAmount(
    String personId,
    List<IpoApplication> applications,
  ) {
    double blocked = 0.0;
    for (final app in applications) {
      if (app.personId == personId && app.status == ApplicationStatus.applied) {
        blocked += app.amountBlocked;
      }
    }
    return blocked;
  }

  /// Calculates total realized profit for a person
  static double calculateProfit(
    String personId,
    List<IpoApplication> applications,
  ) {
    double profit = 0.0;
    for (final app in applications) {
      if (app.personId == personId && app.profitRealized != null) {
        profit += app.profitRealized!;
      }
    }
    return profit;
  }

  /// Complete financial summary for a person
  static PersonFinancialSummary getPersonSummary({
    required Person person,
    required List<LedgerEntry> entries,
    required List<IpoApplication> applications,
  }) {
    final float = calculateAvailableFloat(person.id, entries);
    final blocked = calculateBlockedAmount(person.id, applications);
    final profit = calculateProfit(person.id, applications);
    final activeCount = applications
        .where((a) => a.personId == person.id && a.status == ApplicationStatus.applied)
        .length;
    final allotmentsCount = applications
        .where((a) => a.personId == person.id && a.status == ApplicationStatus.allotted)
        .length;

    return PersonFinancialSummary(
      person: person,
      availableFloat: float,
      blockedInIpos: blocked,
      totalCapitalWithPerson: float + blocked,
      totalProfitRealized: profit,
      activeApplicationsCount: activeCount,
      totalAllotmentsCount: allotmentsCount,
    );
  }

  /// Smart Delta calculation: determines how much money must be transferred
  /// to a person for an upcoming IPO lot, factoring in their unallotted float.
  static DeltaCalculationResult calculateDelta({
    required Person person,
    required double requiredCost,
    required List<LedgerEntry> entries,
  }) {
    final availableFloat = calculateAvailableFloat(person.id, entries);

    if (availableFloat >= requiredCost) {
      return DeltaCalculationResult(
        person: person,
        requiredAmount: requiredCost,
        availableFloat: availableFloat,
        amountToSend: 0.0,
        surplus: availableFloat - requiredCost,
        isFullyCovered: true,
      );
    } else {
      final deficit = requiredCost - availableFloat;
      return DeltaCalculationResult(
        person: person,
        requiredAmount: requiredCost,
        availableFloat: availableFloat,
        amountToSend: deficit,
        surplus: 0.0,
        isFullyCovered: false,
      );
    }
  }

  /// Overall dashboard metrics across the entire portfolio
  static SyndicateDashboardSummary getDashboardSummary({
    required List<Person> people,
    required List<LedgerEntry> entries,
    required List<IpoApplication> applications,
  }) {
    double totalFloat = 0.0;
    double totalBlocked = 0.0;
    double totalProfit = 0.0;

    for (final person in people) {
      totalFloat += calculateAvailableFloat(person.id, entries);
      totalBlocked += calculateBlockedAmount(person.id, applications);
      totalProfit += calculateProfit(person.id, applications);
    }

    final activeAppsCount = applications
        .where((a) => a.status == ApplicationStatus.applied)
        .length;

    return SyndicateDashboardSummary(
      totalFloatBalance: totalFloat,
      totalBlockedInIpos: totalBlocked,
      totalCapitalDeployed: totalFloat + totalBlocked,
      totalProfitRealized: totalProfit,
      totalPeopleCount: people.length,
      activeApplicationsCount: activeAppsCount,
    );
  }
}
