import java.util.Base64
import java.util.Properties
import java.io.FileInputStream

// ── Release signing material ────────────────────────────────────────────────
// Loaded from android/key.properties (git-ignored) for local release builds, or
// from environment variables in CI (docs/release/android-release.md §3).
// Passwords are never hardcoded here.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystoreFile = keystorePropertiesFile.exists()
if (hasKeystoreFile) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// CI path: the workflow decodes ANDROID_KEYSTORE into a file and exports the
// passwords. Takes precedence over key.properties when present.
val envStoreFile: String? = System.getenv("ANDROID_KEYSTORE_PATH")
val hasEnvSigning = !envStoreFile.isNullOrBlank()

// True only when we can actually produce a signed release build. When false,
// debug builds are unaffected, but any release packaging task FAILS the build
// (see the guard at the bottom of this file). A release artifact must never be
// silently signed with the debug key: it looks shippable, but it cannot be
// uploaded to Play or update an install signed with the real key.
val canSignRelease = hasEnvSigning || hasKeystoreFile

// Names (never values) of signing inputs that are missing, so an incomplete
// key.properties or CI variable set fails with a readable message instead of a
// keytool stack trace deep inside the signing task.
val missingSigningInputs: List<String> =
    if (hasEnvSigning) {
        listOf("ANDROID_KEYSTORE_PASSWORD", "ANDROID_KEY_ALIAS", "ANDROID_KEY_PASSWORD")
            .filter { System.getenv(it).isNullOrBlank() } +
            (if (file(envStoreFile!!).exists()) emptyList() else listOf("ANDROID_KEYSTORE_PATH (file not found)"))
    } else if (hasKeystoreFile) {
        listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
            .filter { keystoreProperties.getProperty(it).isNullOrBlank() }
            .map { "key.properties: $it" } +
            (keystoreProperties.getProperty("storeFile")
                ?.takeIf { it.isNotBlank() && !file(it).exists() }
                ?.let { listOf("key.properties: storeFile (file not found)") }
                ?: emptyList())
    } else {
        emptyList()
    }

// ── Environment config ──────────────────────────────────────────────────────
// The Google Maps key is injected as a manifest placeholder rather than being
// committed in AndroidManifest.xml (docs/SECURITY.md §9). Source order:
// GOOGLE_MAPS_ANDROID_KEY env var (CI) → .env file (local dev) → empty.
val dotenv = Properties()
val dotenvFile = rootProject.file("../.env")
if (dotenvFile.exists()) {
    dotenvFile.inputStream().use { dotenv.load(it) }
}
val googleMapsApiKey: String =
    System.getenv("GOOGLE_MAPS_ANDROID_KEY")
        ?: dotenv.getProperty("GOOGLE_MAPS_ANDROID_KEY")
        ?: ""

// ── Demo build ──────────────────────────────────────────────────────────────
// Flutter hands `--dart-define` values to Gradle as one comma-separated list of
// base64 strings in the `dart-defines` property.
val isDemoBuild: Boolean =
    (project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.any { encoded: String ->
            runCatching { String(Base64.getDecoder().decode(encoded)) }
                .getOrNull() == "USE_MOCK_DATA=true"
        }
        ?: false

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Resolved here, applied below — skipped in demo builds.
    id("com.google.gms.google-services") apply false
}

// Must come after the Flutter plugin: it hooks the variant tasks the Flutter
// plugin registers.
//
// TODO(release-gate): demo builds (`--dart-define=USE_MOCK_DATA=true`) skip it.
// They never start Firebase (push uses the no-op transport), so they need no
// Firebase config file, and a mismatched one would otherwise fail the build at
// `process*GoogleServices`. Every other build applies it as before.
if (!isDemoBuild) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.isigroup.steelforce"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by `flutter_local_notifications`, which uses `java.time` on
        // API levels that predate it. Without this the build fails outright at
        // `checkDebugAarMetadata` — it is a hard requirement of the plugin, not
        // an optimisation.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Permanent for the life of the Play listing — do not change after the
        // first upload.
        //
        // Renamed from `com.isigroup.steelsales` to match the iOS bundle id and
        // the Firebase project (`steelforce-94963`), whose Android app is
        // registered as `com.isigroup.steelforce`. Without the rename
        // `processDebugGoogleServices` fails outright: "No matching client found
        // for package name".
        //
        // ⚠️ If this app has already been published, an applicationId change
        // creates a **new Play listing**: existing installs will not receive it
        // as an update and will not migrate their local data. The alternative is
        // to add a second Android app to the Firebase console under the old
        // package name and re-download `google-services.json`.
        applicationId = "com.isigroup.steelforce"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = googleMapsApiKey
    }

    signingConfigs {
        if (canSignRelease) {
            create("release") {
                if (hasEnvSigning) {
                    storeFile = file(envStoreFile!!)
                    storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                    keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                    keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
                } else {
                    storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                    storePassword = keystoreProperties.getProperty("storePassword")
                    keyAlias = keystoreProperties.getProperty("keyAlias")
                    keyPassword = keystoreProperties.getProperty("keyPassword")
                }
            }
        }
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }

        release {
            // R8: strip unused compiled code and unused resources.
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )

            // Never the debug key. Without release signing material this stays
            // null and the guard below fails any release packaging task.
            if (canSignRelease) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

dependencies {
    // The desugaring runtime enabled above. `flutter_local_notifications` 18.x
    // requires 2.1.4 or newer; an older one builds and then throws at runtime on
    // the first scheduled notification.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// ── Release signing guard ───────────────────────────────────────────────────
// Fails the build — before any task runs — when a release artifact is requested
// without release signing material. Checked against the task graph rather than
// at configuration time so debug/profile builds, `./gradlew tasks`, IDE sync,
// and unit tests keep working on a checkout that has no keystore.
val releasePackagingTasks = setOf(
    "assembleRelease",
    "bundleRelease",
    "packageRelease",
    "packageReleaseBundle",
    "signReleaseBundle",
    "installRelease",
)
gradle.taskGraph.whenReady {
    if (canSignRelease && missingSigningInputs.isEmpty()) return@whenReady
    val requested = allTasks.filter {
        it.project.path == project.path && it.name in releasePackagingTasks
    }
    if (requested.isEmpty()) return@whenReady
    if (!canSignRelease) {
        throw GradleException(
            "Release signing is not configured: no android/key.properties and " +
                "no ANDROID_KEYSTORE_PATH. Refusing to build " +
                requested.joinToString { it.name } +
                " — a release artifact must never be signed with the debug key. " +
                "Provide the release keystore (docs/release/android-release.md).",
        )
    }
    throw GradleException(
        "Release signing is incomplete — missing: " +
            missingSigningInputs.joinToString() +
            ". See docs/release/android-release.md.",
    )
}
