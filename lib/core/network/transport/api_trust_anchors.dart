/// Certificate pinning for the SteelForce API: the CA certificates the API's
/// TLS chain is allowed to end at. **Empty means pinning is off** and the
/// platform's normal trust store decides, as before.
///
/// ## Why CA anchoring and not a leaf-key check
///
/// Dio's `validateCertificate` hook runs *after* the request has been written
/// — by then the bearer token and the request body have already gone to
/// whoever answered. Anchoring trust in the TLS `SecurityContext` instead
/// fails the handshake itself, so an intercepting proxy (Burp, mitmproxy, a
/// user-installed CA, a mis-issued certificate from any other CA) never
/// receives a byte.
///
/// Pinning the CA rather than the server's own certificate also survives the
/// routine 60–90-day renewals of the leaf certificate.
///
/// ## How to turn it on
///
/// 1. Find the chain's root and intermediate:
///    `openssl s_client -connect <api-host>:443 -showcerts </dev/null`
/// 2. Paste the PEM of the **root** CA below, plus a **backup** root — the
///    CA's other root, or the root of the CA you would move to. With only one
///    anchor, a CA change bricks every installed app until it updates.
/// 3. Run `flutter test test/core/network/http_transport_test.dart`, then a
///    release build against staging, before shipping.
///
/// These are public certificates, not secrets; they belong in source control.
/// Only API clients built by `AppNetwork` are pinned. The reachability probe,
/// map tiles and images keep the platform trust store (docs/security/README.md §4).
const List<String> apiTrustAnchorsPem = [];
