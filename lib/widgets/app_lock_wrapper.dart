import 'package:flutter/material.dart';
import '../services/biometric_service.dart';

class AppLockWrapper extends StatefulWidget {
  final Widget child;
  final BiometricService biometricService;

  const AppLockWrapper({
    super.key,
    required this.child,
    required this.biometricService,
  });

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper> with WidgetsBindingObserver {
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initial authentication on launch if locked
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.biometricService.isLocked) {
        _triggerAuth();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      widget.biometricService.lock();
    } else if (state == AppLifecycleState.resumed) {
      if (widget.biometricService.isLocked) {
        _triggerAuth();
      }
    }
  }

  Future<void> _triggerAuth() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;
    await widget.biometricService.authenticate();
    if (mounted) {
      setState(() {
        _isAuthenticating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.biometricService,
      builder: (context, _) {
        if (!widget.biometricService.isLocked) {
          return widget.child;
        }

        // Lock Screen Overlay
        return Scaffold(
          body: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1E3A8A), // Royal Indigo
                  const Color(0xFF0F172A), // Slate Dark
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.fingerprint_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'IPO Portfolio Locked',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Biometric protection active for your PAN & capital ledgers',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton.icon(
                    onPressed: _triggerAuth,
                    icon: const Icon(Icons.lock_open_rounded, size: 20),
                    label: const Text(
                      'Unlock with Biometrics / PIN',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E3A8A),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
