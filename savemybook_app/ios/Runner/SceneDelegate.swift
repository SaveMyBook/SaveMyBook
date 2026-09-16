import Flutter
import UIKit

// iOS 26 SDK 起，App 必須採用 UIScene 生命週期，否則啟動就會被系統終止。
// 自訂的 Scene Delegate 必須把每個回呼轉給 FlutterPluginSceneLifeCycleDelegate，
// 否則外掛（Google 登入、url_launcher 的 OAuth 回跳等）收不到事件。
@objc class SceneDelegate: UIResponder, UIWindowSceneDelegate, FlutterSceneLifeCycleProvider {
  var window: UIWindow?
  var sceneLifeCycleDelegate = FlutterPluginSceneLifeCycleDelegate()

  func scene(_ scene: UIScene,
             willConnectTo session: UISceneSession,
             options connectionOptions: UIScene.ConnectionOptions) {
    sceneLifeCycleDelegate.scene(scene, willConnectToSession: session, options: connectionOptions)
    if let url = connectionOptions.urlContexts.first?.url {
      AppDelegate.shared?.receiveDeepLink(url)
    }
  }

  func sceneDidDisconnect(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneDidDisconnect(scene)
  }

  func sceneWillEnterForeground(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneWillEnterForeground(scene)
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneDidBecomeActive(scene)
  }

  func sceneWillResignActive(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneWillResignActive(scene)
  }

  func sceneDidEnterBackground(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneDidEnterBackground(scene)
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if let url = URLContexts.first?.url {
      AppDelegate.shared?.receiveDeepLink(url)
    }
    sceneLifeCycleDelegate.scene(scene, openURLContexts: URLContexts)
  }

  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    sceneLifeCycleDelegate.scene(scene, continueUserActivity: userActivity)
  }

  func windowScene(_ windowScene: UIWindowScene,
                   performActionFor shortcutItem: UIApplicationShortcutItem,
                   completionHandler: @escaping (Bool) -> Void) {
    sceneLifeCycleDelegate.windowScene(windowScene,
                                       performActionForShortcutItem: shortcutItem,
                                       completionHandler: completionHandler)
  }
}
