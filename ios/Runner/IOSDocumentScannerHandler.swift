import Flutter
import UIKit
import VisionKit

final class IOSDocumentScannerHandler: NSObject, VNDocumentCameraViewControllerDelegate {
  private var result: FlutterResult?
  private weak var scannerController: VNDocumentCameraViewController?

  func register(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "card_box/document_scanner",
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      self.handle(call: call, result: result)
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "scanSinglePage" else {
      result(FlutterMethodNotImplemented)
      return
    }

    guard VNDocumentCameraViewController.isSupported else {
      result(
        FlutterError(
          code: "unsupported",
          message: "Document scanning is not supported on this device.",
          details: nil
        )
      )
      return
    }

    guard self.result == nil else {
      result(
        FlutterError(
          code: "busy",
          message: "A document scan is already in progress.",
          details: nil
        )
      )
      return
    }

    guard let presenter = topViewController() else {
      result(
        FlutterError(
          code: "unavailable",
          message: "The document scanner could not be presented right now.",
          details: nil
        )
      )
      return
    }

    DispatchQueue.main.async {
      self.result = result
      let controller = VNDocumentCameraViewController()
      controller.delegate = self
      self.scannerController = controller
      presenter.present(controller, animated: true)
    }
  }

  func documentCameraViewControllerDidCancel(
    _ controller: VNDocumentCameraViewController
  ) {
    controller.dismiss(animated: true) {
      self.finish(with: nil)
    }
  }

  func documentCameraViewController(
    _ controller: VNDocumentCameraViewController,
    didFailWithError error: Error
  ) {
    controller.dismiss(animated: true) {
      self.finish(
        with: FlutterError(
          code: "scan_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  func documentCameraViewController(
    _ controller: VNDocumentCameraViewController,
    didFinishWith scan: VNDocumentCameraScan
  ) {
    controller.dismiss(animated: true) {
      guard scan.pageCount > 0 else {
        self.finish(with: nil)
        return
      }

      let image = scan.imageOfPage(at: 0)
      guard let data = image.jpegData(compressionQuality: 0.92) else {
        self.finish(
          with: FlutterError(
            code: "scan_failed",
            message: "The scanned image could not be saved.",
            details: nil
          )
        )
        return
      }

      do {
        let tempDirectory = FileManager.default.temporaryDirectory
        let targetURL = tempDirectory
          .appendingPathComponent("card_box_scan_\(UUID().uuidString)")
          .appendingPathExtension("jpg")
        try data.write(to: targetURL, options: [.atomic])
        self.finish(with: targetURL.path)
      } catch {
        self.finish(
          with: FlutterError(
            code: "scan_failed",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    }
  }

  private func finish(with value: Any?) {
    let callback = result
    result = nil
    scannerController = nil
    callback?(value)
  }

  private func topViewController(
    from controller: UIViewController? = IOSDocumentScannerHandler.rootViewController()
  ) -> UIViewController? {
    if let navigation = controller as? UINavigationController {
      return topViewController(from: navigation.visibleViewController)
    }
    if let tab = controller as? UITabBarController {
      return topViewController(from: tab.selectedViewController)
    }
    if let presented = controller?.presentedViewController {
      return topViewController(from: presented)
    }
    return controller
  }

  static func rootViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap {
      $0 as? UIWindowScene
    }
    let activeScene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    return activeScene?.windows.first(where: \.isKeyWindow)?.rootViewController
  }
}
