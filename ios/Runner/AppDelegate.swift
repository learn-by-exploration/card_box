import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let documentScannerHandler = IOSDocumentScannerHandler()
  private let fileShareHandler = IOSFileShareHandler()
  private let settingsHandler = IOSSettingsHandler()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    documentScannerHandler.register(binaryMessenger: engineBridge.binaryMessenger)
    fileShareHandler.register(binaryMessenger: engineBridge.binaryMessenger)
    settingsHandler.register(binaryMessenger: engineBridge.binaryMessenger)
  }
}
