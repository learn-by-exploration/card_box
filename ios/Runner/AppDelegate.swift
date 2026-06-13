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
    // Flutter 3.44 dropped `binaryMessenger` on FlutterImplicitEngineBridge
    // in favour of `applicationRegistrar.messenger()`. The path
    // pluginRegistry -> registrar -> messenger() is the supported way to
    // reach a FlutterBinaryMessenger from an implicit-engine delegate.
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    documentScannerHandler.register(binaryMessenger: messenger)
    fileShareHandler.register(binaryMessenger: messenger)
    settingsHandler.register(binaryMessenger: messenger)
  }
}
