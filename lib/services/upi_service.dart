import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class UpiService {
  /// Generates a standard UPI deep-link URI
  static Uri buildUpiUri({
    required String upiId,
    required String payeeName,
    required double amount,
    String note = 'IPO Application Funds',
  }) {
    final queryParameters = {
      'pa': upiId.trim(),
      'pn': payeeName.trim(),
      'am': amount.toStringAsFixed(2),
      'cu': 'INR',
      'tn': note,
    };

    return Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: queryParameters,
    );
  }

  /// Attempts to launch UPI apps (Google Pay, PhonePe, Paytm, BHIM)
  static Future<bool> launchUpiPayment({
    required String upiId,
    required String payeeName,
    required double amount,
    String note = 'IPO Application Funds',
  }) async {
    final uri = buildUpiUri(
      upiId: upiId,
      payeeName: payeeName,
      amount: amount,
      note: note,
    );

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: copy to clipboard
        await Clipboard.setData(ClipboardData(text: upiId));
        return false;
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: upiId));
      return false;
    }
  }

  /// Launch external web URL (for registrars or bank portals)
  static Future<bool> launchWebUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      return false;
    }
  }
}
