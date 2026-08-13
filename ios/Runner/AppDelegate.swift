import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  private static let channelName = "app.aegis/probe"
  private let probe = SecurityProbe()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    let channel = FlutterMethodChannel(name: AppDelegate.channelName, binaryMessenger: messenger)

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "read":
        result(self.probe.read())

      case "openSettings":
        result(self.openSettings())

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// iOS publishes exactly one settings URL to third-party apps: the app's own
  /// page. Deep links into other panes rely on private URL schemes that App
  /// Review rejects, so every other destination is handled by showing the user
  /// the precise path instead. Honest, and it survives review.
  private func openSettings() -> Bool {
    guard let url = URL(string: UIApplication.openSettingsURLString),
          UIApplication.shared.canOpenURL(url)
    else { return false }
    UIApplication.shared.open(url)
    return true
  }
}
