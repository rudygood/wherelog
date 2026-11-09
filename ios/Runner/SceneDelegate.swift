import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  // A .gpx file opened into WhereLog ("Open with") arrives as a
  // URL context — on a cold start inside the connection options,
  // while running through openURLContexts. Both are handed to
  // the mailbox before the Flutter scene handling runs, so the
  // shared-media URLs keep flowing to their plugin untouched.
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    for context in connectionOptions.urlContexts {
      IncomingGpxMailbox.shared.store(url: context.url)
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    for context in URLContexts {
      IncomingGpxMailbox.shared.store(url: context.url)
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}
