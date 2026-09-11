import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private static let channelName = "savemybook/deeplink"
  private static let shareChannelName = "savemybook/share"

  private var deepLinkChannel: FlutterMethodChannel?
  private var pendingLink: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: AppDelegate.channelName,
                                         binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { [weak self] call, result in
        if call.method == "getInitialLink" {
          result(self?.pendingLink)
          self?.pendingLink = nil
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
      deepLinkChannel = channel

      let share = FlutterMethodChannel(name: AppDelegate.shareChannelName,
                                       binaryMessenger: controller.binaryMessenger)
      share.setMethodCallHandler { [weak self] call, result in
        self?.handleShare(call: call, result: result, host: controller)
      }
    }

    if let url = launchOptions?[.url] as? URL {
      pendingLink = url.absoluteString
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if let channel = deepLinkChannel {
      channel.invokeMethod("onLink", arguments: url.absoluteString)
    } else {
      pendingLink = url.absoluteString
    }
    return super.application(app, open: url, options: options)
  }

  private func handleShare(call: FlutterMethodCall,
                           result: @escaping FlutterResult,
                           host: UIViewController) {
    let args = call.arguments as? [String: Any] ?? [:]

    switch call.method {
    case "shareText":
      let text = args["text"] as? String ?? ""
      present(items: [text], from: host, result: result)

    case "shareImage":
      guard let path = args["path"] as? String,
            let image = UIImage(contentsOfFile: path) else {
        result(FlutterError(code: "no_image", message: "找不到圖片", details: nil))
        return
      }
      var items: [Any] = [image]
      if let text = args["text"] as? String, !text.isEmpty { items.append(text) }
      present(items: items, from: host, result: result)

    case "shareFile":
      guard let path = args["path"] as? String,
            FileManager.default.fileExists(atPath: path) else {
        result(FlutterError(code: "no_file", message: "找不到檔案", details: nil))
        return
      }
      // 用 URL 而不是 Data：分享頁才會帶出原本的檔名與副檔名。
      var fileItems: [Any] = [URL(fileURLWithPath: path)]
      if let text = args["text"] as? String, !text.isEmpty { fileItems.append(text) }
      present(items: fileItems, from: host, result: result)

    case "saveImage":
      guard let path = args["path"] as? String,
            let image = UIImage(contentsOfFile: path) else {
        result(FlutterError(code: "no_image", message: "找不到圖片", details: nil))
        return
      }
      UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
      result(true)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func present(items: [Any], from host: UIViewController, result: @escaping FlutterResult) {
    let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)

    // iPad 的分享頁必須有錨點，否則會直接 crash。
    if let popover = sheet.popoverPresentationController {
      popover.sourceView = host.view
      popover.sourceRect = CGRect(x: host.view.bounds.midX,
                                  y: host.view.bounds.midY,
                                  width: 0,
                                  height: 0)
      popover.permittedArrowDirections = []
    }

    host.present(sheet, animated: true) { result(true) }
  }
}
