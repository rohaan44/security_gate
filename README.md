# security_gate

A pluggable, callback-driven device-security-check pipeline for Flutter. Run ordered security checks at app startup (or anywhere) and get a simple **pass/fail** result — then handle it with your own custom code.

[![pub package](https://img.shields.io/pub/v/security_gate.svg)](https://pub.dev/packages/security_gate)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## Features

- ✅ **Simple API** — pipeline returns `true`/`false`; you write the custom code for both outcomes
- 🔌 **Pluggable checks** — implement `SecurityCheck` to add any custom check
- ⏱ **Per-check timeouts** — no more hanging screens; every check has a configurable timeout
- 🔄 **Retry with backoff** — configurable retry policy with exponential backoff per check
- 🛡 **Type-Safe Result Matching** — pattern match directly on `failed.check` class types with no magic strings
- 📢 **Callback-driven** — `onCheckStart`, `onCheckPassed`, `onCheckFailed`, `onPipelineComplete`
- 🚫 **No UI baked in** — zero dependency on Navigator, Riverpod, Provider, GetX, Bloc, or any navigation library
- 🛡 **iOS-safe** — never calls `exit(0)` internally; surfaces `forceExit` via callback for the host app to handle
- 📝 **Pluggable logging** — bring your own logger or use the built-in `DefaultLogger`
- 🧪 **Testable** — core pipeline is fully unit-testable with mock checks

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  security_gate:
    path: path/to/security_gate  # or version from pub.dev
```

Then run:

```bash
flutter pub get
```

---

## Quick Start

```dart
import 'package:security_gate/security_gate.dart';

// 1. Create a pipeline with your desired checks
final pipeline = SecurityPipeline(
  checks: [
    InternetWifiSecurityCheck(),
    JailbreakRootCheck(),
    PlayIntegrityCheck(),
    ProxyDetectionCheck(),
    BlockedNetworkCheck(blockVpn: true),
    ThirdPartyKeyboardCheck(),
  ],
);

// 2. Execute and handle the result
final result = await pipeline.execute();

if (result.passed) {
  // ✅ All checks passed — proceed to home
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => const HomeScreen()),
  );
} else {
  final failed = result.failedCheck!;

  // 🛡️ Type-Safe Handling (No magic strings!)
  // Match directly on check class types using Dart pattern matching:
  switch (failed.check) {
    case BlockedNetworkCheck():
      _showVpnModal();
    case JailbreakRootCheck():
      _showDeviceRootedDialog();
    case InternetWifiSecurityCheck():
      _showNoInternetDialog();
    case ProxyDetectionCheck():
      _showProxyDetectedDialog();
    case PlayIntegrityCheck():
      _showPlayIntegrityDialog();
    case ThirdPartyKeyboardCheck():
      _showKeyboardSecurityDialog();
    default:
      _showGenericDialog(failed.failureReason);
  }
}
```

---

## Splash Screen Example

The recommended pattern for running checks at app startup:

```dart
class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runChecks());
  }

  Future<void> _runChecks() async {
    final pipeline = SecurityPipeline(
      checks: [
        InternetWifiSecurityCheck(),
        JailbreakRootCheck(),
        ProxyDetectionCheck(),
        BlockedNetworkCheck(blockVpn: true),
      ],
      onCheckStart: (check) {
        if (mounted) setState(() => _status = check.name);
      },
    );

    final result = await pipeline.execute();

    // ⚠️ Always guard with mounted after async gaps!
    if (!mounted) return;

    if (result.passed) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      // Handle the failing check
      final failed = result.failedCheck!;
      _showErrorDialog(failed);
    }
  }
}
```

---

## Custom Checks

Implement `SecurityCheck` to create your own:

```dart
class AppVersionCheck extends SecurityCheck {
  @override
  String get name => 'App Version Check';

  @override
  Duration get timeout => const Duration(seconds: 10);

  @override
  RetryPolicy? get retryPolicy => const RetryPolicy(maxAttempts: 2);

  @override
  Future<CheckResult> execute() async {
    final currentVersion = await getAppVersion();
    final minVersion = await fetchMinVersionFromServer();

    if (currentVersion < minVersion) {
      return CheckResult.fail(
        checkName: name,
        reason: 'App version $currentVersion is below minimum $minVersion.',
        action: FailureAction.forceExit,
      );
    }
    return CheckResult.pass(checkName: name);
  }
}
```

---

## Built-in Checks

| Check | Class | Platform | Native Dependency | Description |
|-------|-------|----------|-------------------|-------------|
| Jailbreak / Root | `JailbreakRootCheck` | Android, iOS | `flutter_jailbreak_detection` or similar | Detects rooted/jailbroken devices |
| Play Integrity | `PlayIntegrityCheck` | Android only | `play_integrity` package | Verifies device via Play Integrity API |
| Proxy Detection | `ProxyDetectionCheck` | Android, iOS | None (`dart:io`) | Detects HTTP/HTTPS proxy configuration |
| Blocked Network / VPN | `BlockedNetworkCheck` | Android, iOS | None (`dart:io`) | Detects VPN tunnels and blocked subnets |
| Third-Party Keyboard | `ThirdPartyKeyboardCheck` | Android, iOS | Platform channel | Detects non-system keyboards |
| Internet / Wi-Fi Security | `InternetWifiSecurityCheck` | Android, iOS | `connectivity_plus`, `network_info_plus` | Verifies connectivity and Wi-Fi security |

> **Note:** Built-in checks that require native plugins are **stubbed** — they pass by default until you wire them to a real detection package. See the TODO comments in each check's source.

---

## Custom Logger

Plug in your own logging:

```dart
class FirebaseCrashlyticsLogger implements SecurityLogger {
  @override
  void log(String message, {LogLevel level = LogLevel.info}) {
    FirebaseCrashlytics.instance.log('[SecurityGate] $message');
  }
}

final pipeline = SecurityPipeline(
  checks: [...],
  logger: FirebaseCrashlyticsLogger(),
);
```

---

## Testing

The core pipeline is fully unit-testable with mock checks:

```bash
flutter test
```

---

## License

MIT License. See [LICENSE](LICENSE) for details.
