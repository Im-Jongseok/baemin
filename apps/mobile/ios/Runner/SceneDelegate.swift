import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if connectionOptions.urlContexts.contains(where: { $0.url.scheme == "hankki" && $0.url.host == "walking" }) {
      AppDelegate.openWalkingPending = true
    }
  }
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if URLContexts.contains(where: { $0.url.scheme == "hankki" && $0.url.host == "walking" }) {
      AppDelegate.openWalkingPending = true
    } else {
      super.scene(scene, openURLContexts: URLContexts)
    }
  }
}
