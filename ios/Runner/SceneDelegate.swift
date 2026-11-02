import FirebaseAuth
import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  // Firebase Phone Auth on iOS falls back to a reCAPTCHA web page when there
  // is no APNs token, and returns to the app through the
  // `app-1-…-ios-…` URL scheme (Info.plist) carrying the reCAPTCHA token.
  //
  // That URL is Firebase's alone. Without this filter Flutter's deep linking
  // pushes it as a route and the rep lands on "No route: /link?deep_link_id=…".
  //
  // It is recognised by its scheme and host, not by `Auth.canHandle`:
  // Firebase's scene-delegate swizzling has usually consumed the URL before
  // this runs, after which `canHandle` answers false and the URL would leak
  // through to Flutter. `canHandle` is still called, for the case where the
  // swizzling did not run. Every other URL goes on to Flutter unchanged.
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    var others = Set<UIOpenURLContext>()
    for context in URLContexts {
      if isFirebaseAuthURL(context.url) {
        _ = Auth.auth().canHandle(context.url)
        #if DEBUG
        // The URL carries the reCAPTCHA token, so only the fact is logged.
        NSLog("[ISI] auth.phone_recaptcha_returned handledBy=Firebase")
        #endif
      } else {
        others.insert(context)
      }
    }
    if !others.isEmpty {
      super.scene(scene, openURLContexts: others)
    }
  }

  /// `app-<GOOGLE_APP_ID with ':' as '-'>://firebaseauth/…` — the scheme
  /// Firebase derives from GoogleService-Info.plist.
  private func isFirebaseAuthURL(_ url: URL) -> Bool {
    if url.host?.lowercased() == "firebaseauth" { return true }
    guard
      let scheme = url.scheme?.lowercased(),
      let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
      let appId = NSDictionary(contentsOfFile: path)?["GOOGLE_APP_ID"] as? String
    else { return false }
    return scheme == "app-" + appId.replacingOccurrences(of: ":", with: "-").lowercased()
  }
}
