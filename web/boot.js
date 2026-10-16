// First-paint loader teardown.
//
// Kept in its own file rather than inline in index.html so the deployed Content
// Security Policy can stay at `script-src 'self' 'wasm-unsafe-eval'` — no
// 'unsafe-inline', and no hash that would have to be recomputed on every edit.
//
// `flutter-first-frame` fires once the app has actually painted, which is later
// than `window.load` (assets downloaded) and is the moment the loader should
// go: the user sees the spinner until there is something usable behind it.
window.addEventListener('flutter-first-frame', function () {
  var boot = document.getElementById('boot');
  if (!boot) return;
  boot.classList.add('hidden');
  // Matches the 0.35s opacity transition in index.html, plus a small margin, so
  // the node is removed only after it has finished fading out.
  setTimeout(function () { boot.remove(); }, 400);
});
