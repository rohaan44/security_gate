import '../check_result.dart';
import '../failure_action.dart';
import '../security_check.dart';

/// Detects whether a third-party keyboard is active on the device.
///
/// Third-party keyboards can potentially intercept sensitive input
/// (e.g. passwords, PINs) and pose a security risk in banking and
/// financial applications.
///
/// ## Native dependency
///
/// This check requires a platform channel or a keyboard detection package:
/// - Custom platform channel to query installed/active input methods
/// - Android: `InputMethodManager.getEnabledInputMethodList()`
/// - iOS: `UITextInputMode.activeInputModes`
///
/// ## Usage
///
/// ```dart
/// final pipeline = SecurityPipeline(
///   checks: [
///     ThirdPartyKeyboardCheck(
///       allowedKeyboardPackages: ['com.google.android.inputmethod.latin'],
///     ),
///   ],
/// );
/// ```
class ThirdPartyKeyboardCheck extends SecurityCheck {
  /// Package names / bundle IDs of keyboards considered safe.
  ///
  /// On Android, these are package names (e.g. `com.google.android.inputmethod.latin`).
  /// On iOS, these are bundle identifiers.
  final List<String> allowedKeyboardPackages;

  /// Creates a [ThirdPartyKeyboardCheck].
  ThirdPartyKeyboardCheck({this.allowedKeyboardPackages = const []});

  @override
  String get name => 'Third-Party Keyboard Detection';

  @override
  Duration get timeout => const Duration(seconds: 5);

  @override
  Future<CheckResult> execute() async {
    try {
      // TODO: wire to platform channel to detect active keyboard
      //
      // Android implementation:
      //   final inputMethodManager = context.getSystemService(INPUT_METHOD_SERVICE);
      //   final enabledMethods = inputMethodManager.getEnabledInputMethodList();
      //   for (final method in enabledMethods) {
      //     if (!allowedKeyboardPackages.contains(method.packageName)) {
      //       return CheckResult.fail(...);
      //     }
      //   }
      //
      // iOS implementation:
      //   let keyboards = UITextInputMode.activeInputModes
      //   // Check against allowed list

      // Stub: always passes until wired to a real detection mechanism.
      return CheckResult.pass(checkName: name);
    } catch (e) {
      return CheckResult.fail(
        checkName: name,
        reason: 'Keyboard detection failed: $e',
        action: FailureAction.dialog,
      );
    }
  }
}
