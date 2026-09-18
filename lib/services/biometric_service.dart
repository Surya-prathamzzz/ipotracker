import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService extends ChangeNotifier {
  static const String _keyBiometricEnabled = 'ipotracker_biometric_enabled';
  final LocalAuthentication _auth = LocalAuthentication();
  final bool isTestMode;

  bool _isBiometricEnabled = false;
  bool _isLocked = false;
  bool _canCheckBiometrics = false;
  bool _isDeviceSupported = false;

  BiometricService({this.isTestMode = false});

  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isLocked => _isLocked;
  bool get canCheckBiometrics => _canCheckBiometrics;
  bool get isDeviceSupported => _isDeviceSupported;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isBiometricEnabled = prefs.getBool(_keyBiometricEnabled) ?? false;

    if (isTestMode) {
      _isLocked = false;
      notifyListeners();
      return;
    }

    try {
      _canCheckBiometrics = await _auth.canCheckBiometrics
          .timeout(const Duration(seconds: 1), onTimeout: () => false);
      _isDeviceSupported = await _auth.isDeviceSupported()
          .timeout(const Duration(seconds: 1), onTimeout: () => false);
    } catch (_) {
      _canCheckBiometrics = false;
      _isDeviceSupported = false;
    }

    if (_isBiometricEnabled) {
      _isLocked = true;
    }

    notifyListeners();
  }

  Future<bool> setBiometricEnabled(bool enabled) async {
    if (enabled) {
      // Prompt verification before enabling
      final success = await authenticate(
        reason: 'Verify your fingerprint or PIN to enable App Lock',
      );
      if (!success) return false;
    }

    _isBiometricEnabled = enabled;
    _isLocked = false;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, enabled);
    return true;
  }

  Future<bool> authenticate({
    String reason = 'Authenticate to access your IPO syndicate portfolio',
  }) async {
    // If biometric lock is disabled in settings, allow access immediately
    if (!_isBiometricEnabled) {
      _isLocked = false;
      notifyListeners();
      return true;
    }

    try {
      final authenticated = await _auth
          .authenticate(
            localizedReason: reason,
            options: const AuthenticationOptions(
              stickyAuth: true,
              biometricOnly: false, // Fallback to PIN/Pattern/Password if biometric fails
            ),
          )
          .timeout(const Duration(seconds: 15), onTimeout: () => false);

      if (authenticated) {
        _isLocked = false;
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void lock() {
    if (_isBiometricEnabled && !_isLocked) {
      _isLocked = true;
      notifyListeners();
    }
  }

  void unlockDirectly() {
    _isLocked = false;
    notifyListeners();
  }
}
