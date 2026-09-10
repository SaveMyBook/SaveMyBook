import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private static let channelName = "savemybook/deeplink"

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
}
