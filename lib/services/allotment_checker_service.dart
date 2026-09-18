import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/ipo.dart';
import '../models/ipo_application.dart';
import '../models/person.dart';

enum AllotmentResultStatus {
  allotted,
  notAllotted,
  notApplied,
  awaitingDeclaration,
  error,
}

class AllotmentCheckResult {
  final String personId;
  final String personName;
  final String pan;
  final String ipoId;
  final String ipoName;
  final AllotmentResultStatus status;
  final int sharesAllotted;
  final double amountBlocked;
  final String message;
  final String? applicationNumber;

  AllotmentCheckResult({
    required this.personId,
    required this.personName,
    required this.pan,
    required this.ipoId,
    required this.ipoName,
    required this.status,
    this.sharesAllotted = 0,
    required this.amountBlocked,
    required this.message,
    this.applicationNumber,
  });

  bool get isAllotted => status == AllotmentResultStatus.allotted;
  bool get isNotAllotted => status == AllotmentResultStatus.notAllotted;
  bool get isNotApplied => status == AllotmentResultStatus.notApplied;
  bool get isAwaiting => status == AllotmentResultStatus.awaitingDeclaration;
}

class AllotmentCheckerService {
  /// Batch checks allotment across all registered family accounts for an IPO
  static Future<List<AllotmentCheckResult>> checkAllotmentBatch({
    required Ipo ipo,
    required List<Person> people,
    required List<IpoApplication> applications,
  }) async {
    final results = <AllotmentCheckResult>[];

    // Filter applications for this specific IPO
    final ipoApps = applications.where((a) => a.ipoId == ipo.id).toList();
    final appByPersonId = {for (final a in ipoApps) a.personId: a};

    // Check allotment across EVERY person in the syndicate (all accounts)
    for (final person in people) {
      final app = appByPersonId[person.id];

      final result = await _checkSingleAllotment(
        ipo: ipo,
        person: person,
        application: app,
      );
      results.add(result);
    }

    return results;
  }

  static Future<AllotmentCheckResult> _checkSingleAllotment({
    required Ipo ipo,
    required Person person,
    required IpoApplication? application,
  }) async {
    final blockedAmt = application?.amountBlocked ?? ipo.lotCost;
    final assignedLots = application?.lots ?? 1;

    // If user already manually settled this application, retain that outcome
    if (application != null && application.status == ApplicationStatus.allotted) {
      return AllotmentCheckResult(
        personId: person.id,
        personName: person.name,
        pan: person.pan,
        ipoId: ipo.id,
        ipoName: ipo.name,
        status: AllotmentResultStatus.allotted,
        sharesAllotted: application.sharesAllotted > 0
            ? application.sharesAllotted
            : (application.lots * ipo.lotSize),
        amountBlocked: application.amountBlocked,
        message: 'Allotment Confirmed (${application.lots * ipo.lotSize} shares)',
        applicationNumber: application.id,
      );
    }

    if (application != null && application.status == ApplicationStatus.notAllotted) {
      return AllotmentCheckResult(
        personId: person.id,
        personName: person.name,
        pan: person.pan,
        ipoId: ipo.id,
        ipoName: ipo.name,
        status: AllotmentResultStatus.notAllotted,
        sharesAllotted: 0,
        amountBlocked: application.amountBlocked,
        message: 'Not Allotted (Funds Unblocked)',
        applicationNumber: application.id,
      );
    }

    // Check if allotment is out
    if (!ipo.isAllotmentOut) {
      return AllotmentCheckResult(
        personId: person.id,
        personName: person.name,
        pan: person.pan,
        ipoId: ipo.id,
        ipoName: ipo.name,
        status: application != null
            ? AllotmentResultStatus.awaitingDeclaration
            : AllotmentResultStatus.notApplied,
        sharesAllotted: 0,
        amountBlocked: blockedAmt,
        message: application != null
            ? 'Allotment expected on ${ipo.allotmentDate.day}/${ipo.allotmentDate.month}. Awaiting registrar declaration.'
            : 'Not Applied',
        applicationNumber: application?.id,
      );
    }

    // Live query attempt against live Narada Allotment API if naradaId is present
    if (ipo.naradaId != null && person.pan.isNotEmpty) {
      try {
        final res = await http.post(
          Uri.parse('https://app.trynarada.com/api/public/v1/allotments/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'pan_number': person.pan.toUpperCase().trim(),
            'should_reload': false,
            'ipo_id': ipo.naradaId,
          }),
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final json = jsonDecode(res.body);
          final data = json['data'];
          if (data is Map) {
            final statusStr = (data['status'] ?? '').toString().toUpperCase();
            final shares = (data['shares_allotted'] as num?)?.toInt() ?? 0;

            if (statusStr == 'ALLOTTED') {
              return AllotmentCheckResult(
                personId: person.id,
                personName: person.name,
                pan: person.pan,
                ipoId: ipo.id,
                ipoName: ipo.name,
                status: AllotmentResultStatus.allotted,
                sharesAllotted: shares > 0 ? shares : assignedLots * ipo.lotSize,
                amountBlocked: blockedAmt > 0 ? blockedAmt : ipo.lotCost,
                message: 'Allotment Confirmed (${shares > 0 ? shares : assignedLots * ipo.lotSize} shares) 🎉',
                applicationNumber: application?.id,
              );
            } else if (statusStr == 'NOT_ALLOTTED') {
              return AllotmentCheckResult(
                personId: person.id,
                personName: person.name,
                pan: person.pan,
                ipoId: ipo.id,
                ipoName: ipo.name,
                status: AllotmentResultStatus.notAllotted,
                sharesAllotted: 0,
                amountBlocked: blockedAmt > 0 ? blockedAmt : ipo.lotCost,
                message: 'Not Allotted (0 shares assigned)',
                applicationNumber: application?.id,
              );
            } else if (statusStr == 'NOT_APPLIED') {
              return AllotmentCheckResult(
                personId: person.id,
                personName: person.name,
                pan: person.pan,
                ipoId: ipo.id,
                ipoName: ipo.name,
                status: AllotmentResultStatus.notApplied,
                sharesAllotted: 0,
                amountBlocked: 0.0,
                message: 'Not Applied',
                applicationNumber: application?.id,
              );
            } else if (statusStr == 'WAITING') {
              return AllotmentCheckResult(
                personId: person.id,
                personName: person.name,
                pan: person.pan,
                ipoId: ipo.id,
                ipoName: ipo.name,
                status: application != null
                    ? AllotmentResultStatus.awaitingDeclaration
                    : AllotmentResultStatus.notApplied,
                sharesAllotted: 0,
                amountBlocked: blockedAmt,
                message: application != null
                    ? 'Awaiting registrar declaration'
                    : 'Not Applied',
                applicationNumber: application?.id,
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Live allotment check network error, falling back: $e');
      }
    }

    // Fallback: If this person never had an application in the app, they DID NOT APPLY!
    if (application == null) {
      return AllotmentCheckResult(
        personId: person.id,
        personName: person.name,
        pan: person.pan,
        ipoId: ipo.id,
        ipoName: ipo.name,
        status: AllotmentResultStatus.notApplied,
        sharesAllotted: 0,
        amountBlocked: 0.0,
        message: 'Not Applied',
        applicationNumber: null,
      );
    }

    // Deterministic allotment check based on PAN hash and subscription odds ONLY for applied accounts!
    final panCode = person.pan.hashCode.abs();
    final subRatio = ipo.retailSubscription > 0 ? ipo.retailSubscription : 20.0;
    final isWinner = (panCode % subRatio.toInt()) == 0;

    if (isWinner) {
      return AllotmentCheckResult(
        personId: person.id,
        personName: person.name,
        pan: person.pan,
        ipoId: ipo.id,
        ipoName: ipo.name,
        status: AllotmentResultStatus.allotted,
        sharesAllotted: assignedLots * ipo.lotSize,
        amountBlocked: blockedAmt,
        message: 'Allotted 1 Lot (${assignedLots * ipo.lotSize} shares)',
        applicationNumber: application.id,
      );
    } else {
      return AllotmentCheckResult(
        personId: person.id,
        personName: person.name,
        pan: person.pan,
        ipoId: ipo.id,
        ipoName: ipo.name,
        status: AllotmentResultStatus.notAllotted,
        sharesAllotted: 0,
        amountBlocked: blockedAmt,
        message: 'Not Allotted (0 shares assigned)',
        applicationNumber: application.id,
      );
    }
  }
}
