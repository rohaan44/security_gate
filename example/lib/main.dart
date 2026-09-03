import 'dart:io';

import 'package:flutter/material.dart';
import 'package:security_gate/security_gate.dart';

void main() {
  runApp(const SecurityGateExampleApp());
}

/// Example app demonstrating how to use the security_gate plugin
/// in a splash screen to run security checks before navigating
/// to the main app.
class SecurityGateExampleApp extends StatelessWidget {
  const SecurityGateExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Security Gate Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

/// Splash screen that runs the security pipeline before allowing
/// the user into the app.
///
/// This demonstrates the recommended pattern:
/// 1. Create a [SecurityPipeline] with your desired checks.
/// 2. Wire callbacks to update UI (progress, status).
/// 3. On completion, check `context.mounted` before navigating.
/// 4. Handle failures with your own custom UI/logic.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _currentCheck = 'Initializing...';
  int _checksCompleted = 0;
  int _totalChecks = 0;
  bool _isRunning = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Start the security pipeline after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runSecurityChecks();
    });
  }

  Future<void> _runSecurityChecks() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _errorMessage = null;
      _checksCompleted = 0;
    });

    // Configure the checks you want to run.
    // Only include checks relevant to your app.
    final checks = <SecurityCheck>[
      InternetWifiSecurityCheck(),
      JailbreakRootCheck(),
      PlayIntegrityCheck(),
      ProxyDetectionCheck(),
      BlockedNetworkCheck(blockVpn: true),
      ThirdPartyKeyboardCheck(),
    ];

    setState(() => _totalChecks = checks.length);

    final pipeline = SecurityPipeline(
      checks: checks,
      // Optional: plug in your own logger.
      // logger: MyFirebaseLogger(),
      onCheckStart: (check) {
        if (mounted) {
          setState(() => _currentCheck = check.name);
        }
      },
      onCheckPassed: (check, result) {
        if (mounted) {
          setState(() => _checksCompleted++);
        }
      },
      onCheckFailed: (check, result) {
        if (mounted) {
          setState(() {
            _checksCompleted++;
            _errorMessage = result.failureReason;
          });
        }
      },
    );

    final result = await pipeline.execute();

    // ⚠️ CRITICAL: Always check `mounted` before using `context`
    // after an async gap. This prevents crashes if the widget was
    // disposed while checks were running.
    if (!mounted) return;

    if (result.passed) {
      // ✅ All checks passed — navigate to your home screen.
      _navigateToHome();
    } else {
      // ❌ A check failed — handle based on the failure action.
      _handleFailure(result);
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _handleFailure(PipelineResult result) {
    final failed = result.failedCheck;
    if (failed == null) return;

    // 💡 TYPE-SAFE MATCHING: No magic strings!
    // Match directly on the check class type using Dart pattern matching:
    switch (failed.check) {
      case BlockedNetworkCheck():
        _showErrorDialog(
          title: 'VPN / Blocked Network Detected',
          message: failed.failureReason ??
              'Please disconnect from VPN to continue using banking services.',
          canRetry: true,
        );
      case JailbreakRootCheck():
        _showErrorDialog(
          title: 'Device Security Compromised',
          message: failed.failureReason ??
              'This app cannot run on rooted or jailbroken devices.',
          canRetry: false,
          showExitButton: true,
        );
      case InternetWifiSecurityCheck():
        _showErrorDialog(
          title: 'No Internet Connection',
          message: failed.failureReason ??
              'Please check your network settings and tap Retry.',
          canRetry: true,
        );
      case ProxyDetectionCheck():
        _showErrorDialog(
          title: 'Proxy Detected',
          message: failed.failureReason ??
              'Please disable HTTP proxy settings to proceed.',
          canRetry: true,
        );
      default:
        _showErrorDialog(
          title: '${failed.checkName} Failed',
          message: failed.failureReason ?? 'Security check failed.',
          canRetry: true,
        );
    }
  }

  void _showErrorDialog({
    required String title,
    required String message,
    bool canRetry = false,
    bool showExitButton = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: canRetry,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (canRetry)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _runSecurityChecks(); // Retry the full pipeline.
              },
              child: const Text('Retry'),
            ),
          if (showExitButton)
            TextButton(
              onPressed: () {
                // On Android, close the app. On iOS, ask the user to close manually.
                if (Platform.isAndroid) {
                  exit(0);
                } else {
                  // On iOS, we can't programmatically exit. Show a message.
                  Navigator.of(dialogContext).pop();
                  if (mounted) {
                    setState(() {
                      _errorMessage =
                          'Please close the app manually for your security.';
                    });
                  }
                }
              },
              child: const Text('Close App'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.security,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 32),
                const Text(
                  'Security Gate',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Running security checks...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 48),
                // Progress indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _totalChecks > 0
                              ? _checksCompleted / _totalChecks
                              : null,
                          minHeight: 8,
                          backgroundColor: Colors.white24,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _errorMessage != null
                                ? Colors.redAccent
                                : Colors.greenAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage ?? _currentCheck,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: _errorMessage != null
                              ? Colors.redAccent.shade100
                              : Colors.white70,
                        ),
                      ),
                      if (_totalChecks > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          '$_checksCompleted / $_totalChecks checks completed',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder home screen — your real app content goes here.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 80, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'All security checks passed!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Welcome to the app.'),
          ],
        ),
      ),
    );
  }
}
