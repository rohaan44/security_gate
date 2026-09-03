# 🛡️ Security Gate — Comprehensive Usage Guide

A step-by-step guide on how to integrate and use the **`security_gate`** plugin in any Flutter application.

---

## 📑 Table of Contents

1. [Installation](#1-installation)
2. [How It Works](#2-how-it-works)
3. [Quick Start (Simple Usage)](#3-quick-start-simple-usage)
4. [Complete Splash Screen Implementation](#4-complete-splash-screen-implementation)
5. [Type-Safe Failure Handling](#5-type-safe-failure-handling)
6. [Built-in Security Checks Reference](#6-built-in-security-checks-reference)
7. [Creating Custom Security Checks](#7-creating-custom-security-checks)
8. [Configuring Retries & Timeouts](#8-configuring-retries--timeouts)
9. [Plugging in a Custom Logger](#9-plugging-in-a-custom-logger)
10. [Best Practices](#10-best-practices)

---

## 1. Installation

Add `security_gate` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  security_gate: ^0.1.0 # Or use path/git reference
```

Then install it:

```bash
flutter pub get
```

Import it in your Dart code:

```dart
import 'package:security_gate/security_gate.dart';
```

---

## 2. How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                      SecurityPipeline                       │
│                                                             │
│   Step 1: InternetWifiSecurityCheck  ──► [ PASS / FAIL ]    │
│   Step 2: JailbreakRootCheck         ──► [ PASS / FAIL ]    │
│   Step 3: ProxyDetectionCheck        ──► [ PASS / FAIL ]    │
│   Step 4: BlockedNetworkCheck        ──► [ PASS / FAIL ]    │
│                                                             │
│   • Stops on the first non-retryable failure                │
│   • Wraps each check in a timeout                           │
│   • Automatically retries with exponential backoff          │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
                    PipelineResult (passed)
                               │
               ┌───────────────┴───────────────┐
               ▼                               ▼
     [result.passed == true]       [result.passed == false]
       Custom Success Flow           Custom Failure Handling
       (e.g., Navigate to Home)      (e.g., Dialog, Exit, Retry)
```

---

## 3. Quick Start (Simple Usage)

Run security checks anywhere in your app with a few lines:

```dart
import 'package:security_gate/security_gate.dart';

Future<void> runChecks() async {
  // 1. Create pipeline with desired checks
  final pipeline = SecurityPipeline(
    checks: [
      InternetWifiSecurityCheck(),
      JailbreakRootCheck(),
      ProxyDetectionCheck(),
      BlockedNetworkCheck(blockVpn: true),
    ],
  );

  // 2. Execute pipeline
  final PipelineResult result = await pipeline.execute();

  // 3. Act on result
  if (result.passed) {
    print('✅ All ${result.checksPassed} checks passed in ${result.totalElapsed.inMilliseconds}ms');
    // Proceed into the app...
  } else {
    print('❌ Failed at: ${result.failedCheck?.checkName}');
    print('❌ Reason: ${result.failedCheck?.failureReason}');
  }
}
```

---

## 4. Complete Splash Screen Implementation

Here is a production-ready **Splash Screen** widget demonstrating progress updates, mounted safety checks, and failure handling:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:security_gate/security_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Initializing security checks...';
  int _completed = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPipeline());
  }

  Future<void> _startPipeline() async {
    final checks = <SecurityCheck>[
      InternetWifiSecurityCheck(),
      JailbreakRootCheck(),
      ProxyDetectionCheck(),
      BlockedNetworkCheck(blockVpn: true),
      ThirdPartyKeyboardCheck(),
    ];

    setState(() {
      _total = checks.length;
      _completed = 0;
    });

    final pipeline = SecurityPipeline(
      checks: checks,
      onCheckStart: (check) {
        if (mounted) setState(() => _status = 'Verifying: ${check.name}...');
      },
      onCheckPassed: (check, result) {
        if (mounted) setState(() => _completed++);
      },
      onCheckFailed: (check, result) {
        if (mounted) setState(() => _status = 'Failed: ${check.name}');
      },
    );

    final result = await pipeline.execute();

    // ⚠️ Crucial: Check mounted after async operations
    if (!mounted) return;

    if (result.passed) {
      // ✅ All checks passed — navigate to Home
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      // ❌ Handle specific failure
      _handleSecurityFailure(result.failedCheck!);
    }
  }

  void _handleSecurityFailure(CheckResult failed) {
    switch (failed.check) {
      case BlockedNetworkCheck():
        _showErrorDialog(
          title: 'VPN Detected',
          message: 'Banking services cannot be used over a VPN connection. Please disconnect and tap Retry.',
          canRetry: true,
        );

      case JailbreakRootCheck():
        _showErrorDialog(
          title: 'Device Security Alert',
          message: 'This application cannot run on rooted or jailbroken devices.',
          canRetry: false,
          showExit: true,
        );

      case InternetWifiSecurityCheck():
        _showErrorDialog(
          title: 'No Internet Connection',
          message: 'Please verify your internet connection and try again.',
          canRetry: true,
        );

      case ProxyDetectionCheck():
        _showErrorDialog(
          title: 'Proxy Detected',
          message: 'Please disable your HTTP/HTTPS proxy to continue.',
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
    bool showExit = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (canRetry)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _startPipeline(); // Retry full pipeline
              },
              child: const Text('Retry'),
            ),
          if (showExit)
            TextButton(
              onPressed: () {
                if (Platform.isAndroid) {
                  exit(0);
                } else {
                  Navigator.pop(ctx);
                  setState(() => _status = 'Please close the app manually.');
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_outlined, size: 70, color: Colors.blueAccent),
              const SizedBox(height: 24),
              LinearProgressIndicator(
                value: _total > 0 ? _completed / _total : null,
              ),
              const SizedBox(height: 16),
              Text(_status, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const Center(child: Text('Welcome to the Secure App!')),
    );
  }
}
```

---

## 5. Type-Safe Failure Handling

Instead of relying on fragile string names, you can match directly against the **check class types**:

```dart
final result = await pipeline.execute();

if (!result.passed) {
  final failed = result.failedCheck!;

  // 🛡️ 100% Type-Safe Pattern Matching:
  switch (failed.check) {
    case BlockedNetworkCheck check:
      print('VPN Blocked: ${check.blockVpn}');
      _showVpnModal();

    case JailbreakRootCheck():
      _showRootDialog();

    case InternetWifiSecurityCheck():
      _showNoInternetDialog();

    case ProxyDetectionCheck():
      _showProxyDialog();

    case PlayIntegrityCheck():
      _showPlayIntegrityDialog();

    case ThirdPartyKeyboardCheck():
      _showKeyboardWarning();

    default:
      _showGenericError(failed.failureReason);
  }
}
```

You can also use the `isA<T>()` helper:

```dart
if (failed.isA<BlockedNetworkCheck>()) {
  _showVpnModal();
}
```

---

## 6. Built-in Security Checks Reference

| Class | Description | Platform | Native Integration Required? |
| :--- | :--- | :--- | :--- |
| `BlockedNetworkCheck` | Detects VPN tunnel interfaces & blocked subnet IP ranges | Android, iOS | ❌ No (`dart:io`) |
| `ProxyDetectionCheck` | Inspects system environment variables for HTTP/HTTPS proxies | Android, iOS | ❌ No (`dart:io`) |
| `InternetWifiSecurityCheck` | Checks internet connectivity via DNS and network state | Android, iOS | ⚠️ Opt-in (`connectivity_plus`) |
| `JailbreakRootCheck` | Detects jailbroken iOS or rooted Android devices | Android, iOS | ⚠️ Opt-in (`flutter_jailbreak_detection`) |
| `PlayIntegrityCheck` | Google Play Integrity API verification | Android only | ⚠️ Opt-in (`play_integrity`) |
| `ThirdPartyKeyboardCheck` | Detects non-system third-party keyboards | Android, iOS | ⚠️ Opt-in (Platform Channel) |

### Setting Custom Error Messages in Constructors
Every check accepts an optional `customFailureMessage`:

```dart
BlockedNetworkCheck(
  blockVpn: true,
  customFailureMessage: 'Please disconnect from VPN to access your account.',
)
```

---

## 7. Creating Custom Security Checks

Implement the `SecurityCheck` abstract class to add custom verifications (e.g. Developer Mode, Minimum App Version, Biometrics, Mock Location):

```dart
class DeveloperModeCheck extends SecurityCheck {
  @override
  String get name => 'Developer Mode Detection';

  @override
  Duration get timeout => const Duration(seconds: 5);

  @override
  Future<CheckResult> execute() async {
    final isDevModeOn = await checkDeviceDeveloperMode();

    if (isDevModeOn) {
      return CheckResult.fail(
        checkName: name,
        check: this,
        reason: 'Developer Options are enabled. Please disable them to proceed.',
        action: FailureAction.dialog,
      );
    }

    return CheckResult.pass(checkName: name, check: this);
  }
}
```

Add your custom check to the pipeline like any other:

```dart
final pipeline = SecurityPipeline(
  checks: [
    DeveloperModeCheck(), // 👈 Your custom check
    JailbreakRootCheck(),
  ],
);
```

---

## 8. Configuring Retries & Timeouts

### Per-Check Timeouts
Prevent hanging pipelines by setting custom timeouts on any check:

```dart
class SlowServerIntegrityCheck extends SecurityCheck {
  @override
  String get name => 'Server Integrity';

  // ⏱ Custom 30-second timeout
  @override
  Duration get timeout => const Duration(seconds: 30);

  @override
  Future<CheckResult> execute() async { ... }
}
```

### Exponential Backoff Retries
Configure how failed checks automatically retry:

```dart
class NetworkTokenCheck extends SecurityCheck {
  @override
  String get name => 'Token Verification';

  // 🔄 Retry up to 3 times with 2s initial delay and 1.5x exponential backoff
  @override
  RetryPolicy? get retryPolicy => const RetryPolicy(
    maxAttempts: 3,
    backoff: Duration(seconds: 2),
    backoffMultiplier: 1.5, // 2s -> 3s -> 4.5s
  );

  @override
  Future<CheckResult> execute() async {
    try {
      final token = await fetchSecurityToken();
      return CheckResult.pass(checkName: name, check: this);
    } catch (e) {
      return CheckResult.fail(
        checkName: name,
        check: this,
        reason: 'Network failure: $e',
        action: FailureAction.retry, // 👈 Signals pipeline to retry
      );
    }
  }
}
```

---

## 9. Plugging in a Custom Logger

Implement `SecurityLogger` to forward logs to your telemetry system (Firebase Crashlytics, Sentry, Datadog):

```dart
class CrashlyticsSecurityLogger implements SecurityLogger {
  @override
  void log(String message, {LogLevel level = LogLevel.info}) {
    FirebaseCrashlytics.instance.log('[SecurityGate/${level.name}] $message');
  }
}

// Pass it to the pipeline:
final pipeline = SecurityPipeline(
  checks: [...],
  logger: CrashlyticsSecurityLogger(),
);
```

---

## 10. Best Practices

1. **Always check `mounted`**: Before calling `Navigator` or updating `setState`, verify `if (!mounted) return;` after `await pipeline.execute()`.
2. **Never call `exit(0)` on iOS**: Programmatic `exit(0)` on iOS violates Apple App Store Review Guidelines. On iOS, display a non-dismissible modal and ask the user to manually exit.
3. **Put fast checks first**: Place local checks (`InternetWifiSecurityCheck`, `ProxyDetectionCheck`, `BlockedNetworkCheck`) before slower network/API checks to fail fast.
4. **Use `CheckResult.fail` instead of throwing**: Handle internal exceptions inside `execute()` and return `CheckResult.fail` for clean, human-readable error messages.

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
