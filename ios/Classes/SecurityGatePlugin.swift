import Flutter
import UIKit

/**
 * SecurityGatePlugin — iOS platform implementation.
 *
 * Provides a MethodChannel for platform-specific security checks
 * that cannot be performed in pure Dart (e.g. keyboard detection,
 * network security details).
 */
public class SecurityGatePlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "security_gate",
            binaryMessenger: registrar.messenger()
        )
        let instance = SecurityGatePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        // TODO: Add platform-specific method handlers:
        //   case "getActiveKeyboards":
        //   case "getWifiSecurityLevel":
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
