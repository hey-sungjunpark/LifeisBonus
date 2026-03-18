import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let appEnvironmentChannelName = "lifeisbonus/app_environment"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: appEnvironmentChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "isSimulator":
          #if targetEnvironment(simulator)
            result(true)
          #else
            result(false)
          #endif
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

}
