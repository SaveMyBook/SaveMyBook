import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Scene Delegate 需要把深層連結轉回這裡，啟動流程只會有一個 App Delegate 實例。
  static private(set) var shared: AppDelegate?

  private static let channelName = "savemybook/deeplink"
  private static let shareChannelName = "savemybook/share"
  private static let pushChannelName = "savemybook/push"

  private var deepLinkChannel: FlutterMethodChannel?
  private var pendingLink: String?
  private var apnsTokenReceived = false
  private var apnsError: String?
  private var pendingSaveResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    AppDelegate.shared = self
    if let url = launchOptions?[.url] as? URL {
      pendingLink = url.absoluteString
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // 採用 UIScene 後，畫面由 Storyboard 建立，window 在啟動當下還是 nil；
  // 外掛註冊與各方法通道改在引擎初始化完成時設定。
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()

    let channel = FlutterMethodChannel(name: AppDelegate.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "getInitialLink" {
        result(self?.pendingLink)
        self?.pendingLink = nil
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    deepLinkChannel = channel

    let share = FlutterMethodChannel(name: AppDelegate.shareChannelName, binaryMessenger: messenger)
    share.setMethodCallHandler { [weak self] call, result in
      self?.handleShare(call: call, result: result)
    }

    let push = FlutterMethodChannel(name: AppDelegate.pushChannelName, binaryMessenger: messenger)
    push.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "openNotificationSettings":
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
        result(nil)
      case "registerForRemoteNotifications":
        UIApplication.shared.registerForRemoteNotifications()
        result(nil)
      case "apnsState":
        result([
          "registered": UIApplication.shared.isRegisteredForRemoteNotifications,
          "token": self?.apnsTokenReceived ?? false,
          "error": (self?.apnsError).map { $0 as Any } ?? NSNull()
        ])
      case "setBadge":
        let count = max(0, call.arguments as? Int ?? 0)
        if #available(iOS 16.0, *) {
          UNUserNotificationCenter.current().setBadgeCount(count) { _ in result(nil) }
        } else {
          UIApplication.shared.applicationIconBadgeNumber = count
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func receiveDeepLink(_ url: URL) {
    if let channel = deepLinkChannel {
      channel.invokeMethod("onLink", arguments: url.absoluteString)
    } else {
      pendingLink = url.absoluteString
    }
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    receiveDeepLink(url)
    return super.application(app, open: url, options: options)
  }

  override func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    apnsTokenReceived = true
    apnsError = nil
    // firebase_messaging 在 Release 組態一律把 APNs token 標成正式環境，用開發描述檔安裝時推播會送不到。
    // 改用 FIRMessaging 的 APNSToken setter（type unknown），由 Firebase 依描述檔判斷環境。
    if let cls = NSClassFromString("FIRMessaging"),
       let messaging = (cls as AnyObject).perform(NSSelectorFromString("messaging"))?.takeUnretainedValue() as? NSObject {
      messaging.setValue(deviceToken, forKey: "APNSToken")
    } else {
      super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }
  }

  override func application(_ application: UIApplication,
                            didFailToRegisterForRemoteNotificationsWithError error: Error) {
    apnsError = error.localizedDescription
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  private func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
    var controller = scene?.windows.first { $0.isKeyWindow }?.rootViewController
      ?? scene?.windows.first?.rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    return controller
  }

  private func handleShare(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    guard let host = topViewController() else {
      result(FlutterError(code: "no_window", message: "目前沒有可顯示的畫面", details: nil))
      return
    }

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
      var fileItems: [Any] = [URL(fileURLWithPath: path)]
      if let text = args["text"] as? String, !text.isEmpty { fileItems.append(text) }
      present(items: fileItems, from: host, result: result)

    case "saveImage":
      guard let path = args["path"] as? String,
            let image = UIImage(contentsOfFile: path) else {
        result(FlutterError(code: "no_image", message: "找不到圖片", details: nil))
        return
      }
      pendingSaveResult?(false)
      pendingSaveResult = result
      UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
    let result = pendingSaveResult
    pendingSaveResult = nil
    DispatchQueue.main.async { result?(error == nil) }
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
