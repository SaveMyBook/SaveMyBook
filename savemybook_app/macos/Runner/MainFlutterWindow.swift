import AVFoundation
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.title = "救舊我的書"
    self.contentMinSize = NSSize(width: 380, height: 640)
    self.setContentSize(NSSize(width: 1280, height: 820))
    self.center()
    self.setFrameAutosaveName("SaveMyBookMainWindow")

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerPermissionChannel(messenger: flutterViewController.engine.binaryMessenger)
    registerShareChannel(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  private func registerPermissionChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "savemybook/permissions", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let name = call.arguments as? String ?? ""
      let media: AVMediaType? = name == "camera" ? .video : name == "microphone" ? .audio : nil

      switch call.method {
      case "status":
        guard let media else { return result(nil) }
        result(Self.describe(AVCaptureDevice.authorizationStatus(for: media)))
      case "request":
        guard let media else { return result(nil) }
        AVCaptureDevice.requestAccess(for: media) { _ in
          DispatchQueue.main.async { result(Self.describe(AVCaptureDevice.authorizationStatus(for: media))) }
        }
      case "openSettings":
        let pane = ["camera": "Privacy_Camera", "microphone": "Privacy_Microphone", "location": "Privacy_LocationServices"][name]
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security" + (pane.map { "?" + $0 } ?? "")) {
          NSWorkspace.shared.open(url)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func registerShareChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "savemybook/share", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "saveImage" else { return result(FlutterMethodNotImplemented) }
      let args = call.arguments as? [String: Any] ?? [:]
      guard let path = args["path"] as? String, FileManager.default.fileExists(atPath: path) else {
        return result(FlutterError(code: "no_image", message: "找不到圖片", details: nil))
      }
      result(Self.copyToDownloads(URL(fileURLWithPath: path)))
    }
  }

  private static func copyToDownloads(_ source: URL) -> Bool {
    let manager = FileManager.default
    guard let downloads = manager.urls(for: .downloadsDirectory, in: .userDomainMask).first else { return false }
    let base = source.deletingPathExtension().lastPathComponent
    let ext = source.pathExtension
    var target = downloads.appendingPathComponent(source.lastPathComponent)
    var index = 1
    while manager.fileExists(atPath: target.path) {
      target = downloads.appendingPathComponent(ext.isEmpty ? "\(base) (\(index))" : "\(base) (\(index)).\(ext)")
      index += 1
    }
    do {
      try manager.copyItem(at: source, to: target)
      return true
    } catch {
      return false
    }
  }

  private static func describe(_ status: AVAuthorizationStatus) -> String {
    switch status {
    case .authorized: return "granted"
    case .denied: return "denied"
    case .restricted: return "restricted"
    default: return "notDetermined"
    }
  }
}
