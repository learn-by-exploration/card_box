import Flutter
import UIKit

final class IOSFileShareHandler: NSObject {
  func register(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "card_box/file_share",
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      self.handle(call: call, result: result)
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "shareFile" else {
      result(FlutterMethodNotImplemented)
      return
    }

    guard
      let arguments = call.arguments as? [String: Any],
      let path = arguments["path"] as? String,
      !path.isEmpty
    else {
      result(false)
      return
    }

    let subject = arguments["subject"] as? String
    let text = arguments["text"] as? String
    let fileURL = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      result(false)
      return
    }

    guard let presenter = topViewController() else {
      result(false)
      return
    }

    DispatchQueue.main.async {
      var items: [Any] = [fileURL]
      if let text, !text.isEmpty {
        items.insert(text, at: 0)
      }
      let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
      if let subject, !subject.isEmpty {
        controller.setValue(subject, forKey: "subject")
      }
      if let popover = controller.popoverPresentationController {
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(
          x: presenter.view.bounds.midX,
          y: presenter.view.bounds.midY,
          width: 1,
          height: 1
        )
      }
      presenter.present(controller, animated: true)
      result(true)
    }
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
}
