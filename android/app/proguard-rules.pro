# R8 / ProGuard keep rules for release builds.
#
# `isMinifyEnabled` and `isShrinkResources` were already enabled without this
# file existing, which meant the release APK was being shrunk with only the
# default Android rules. Shrinking failures are RUNTIME failures — the build
# succeeds and the app crashes on device — so anything reached by reflection or
# JNI has to be kept explicitly.

# ── Flutter engine ──────────────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# ── SQLCipher / sqlite3 (drift) ─────────────────────────────────────────────
# Loaded over JNI; the class names must survive or the encrypted database
# fails to open at boot.
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }
-dontwarn net.sqlcipher.**

# ── Google Maps ─────────────────────────────────────────────────────────────
-keep class com.google.android.gms.maps.** { *; }
-keep interface com.google.android.gms.maps.** { *; }
-dontwarn com.google.android.gms.**

# ── speech_to_text ──────────────────────────────────────────────────────────
# Resolved through the platform RecognitionService; reflection-reachable.
-keep class android.speech.** { *; }
-dontwarn android.speech.**

# ── mobile_scanner / ML Kit barcode ─────────────────────────────────────────
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.mlkit.**

# ML Kit ships optional language models this app does not use. Without this,
# R8 fails the build on missing classes it can prove are unreachable anyway.
-dontwarn com.google.android.play.core.**

# ── geolocator ──────────────────────────────────────────────────────────────
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# ── Keep annotations & generic signatures ───────────────────────────────────
# Needed by anything doing runtime type inspection (JSON codecs, plugin
# registrars).
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# ── Strip logging from release binaries (docs/SECURITY.md §11) ──────────────
# Belt-and-braces: the Dart side already has zero `print()` calls, this covers
# native/plugin logging that would otherwise survive into a release build.
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
