import Flutter
import UIKit
import receive_sharing_intent

class SceneDelegate: FlutterSceneDelegate {

  // Two consumers share this app's incoming URLs: receive_sharing_intent
  // (ShareMedia-… links from the Share Extension) and the GPX mailbox
  // (.gpx files opened into WhereLog). The plugin's documentation
  // prescribes this disambiguation for exactly that case: offer every
  // URL to the plugin first; only what it does not consume falls
  // through to the mailbox and the standard Flutter handling. Without
  // the explicit forwarding, a share opened WhereLog but the shared
  // media never reached Dart — the queue stayed empty (2026-11-10).
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    _ = ReceiveSharingIntentPlugin.instance.scene(
      scene, willConnectTo: session, options: connectionOptions)
    for context in connectionOptions.urlContexts {
      IncomingGpxMailbox.shared.store(url: context.url)
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    if ReceiveSharingIntentPlugin.instance.scene(
      scene, openURLContexts: URLContexts) {
      return
    }
    for context in URLContexts {
      IncomingGpxMailbox.shared.store(url: context.url)
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}
