import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing comes from android/key.properties (git-ignored; points at
// the keystore kept outside the repo). Without it, release builds fall back
// to the debug key so `flutter run --release` still works on other machines.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    // Agora ships every optional add-on for all CPU types. The app only uses
    // voice, video calls and live (the core SDK plus its audio/video codec
    // add-ons), so the unused ones are left out — about 22 MB per CPU type.
    // Agora documents these as removable; add one back here if a feature
    // that needs it (e.g. virtual background = segmentation) is built.
    packaging {
        jniLibs {
            excludes += listOf(
                "**/libagora_lip_sync_extension.so",
                "**/libagora_face_capture_extension.so",
                "**/libagora_face_detection_extension.so",
                "**/libagora_segmentation_extension.so",
                "**/libagora_spatial_audio_extension.so",
                "**/libagora_content_inspect_extension.so",
                "**/libagora_clear_vision_extension.so",
                "**/libagora_screen_capture_extension.so",
                "**/libagora_audio_beauty_extension.so",
                "**/libagora_video_quality_analyzer_extension.so",
            )
        }
    }
    namespace = "com.fling.app"
    // Flutter's own default (flutter.compileSdkVersion, 31 in this SDK) is
    // too old for agora_rtc_engine's transitive androidx dependencies,
    // several of which require compileSdk 33/34+. Pin explicitly instead.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.fling.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystoreProperties.getProperty("storeFile") != null) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// agora_rtc_engine's iris-rtc and full-sdk AARs both ship an AndroidManifest
// declaring package="io.agora.rtc" — a real duplicate-namespace bug in
// Agora's own packaging that AGP's manifest merger rejects outright (not
// fixable from this project's config alone). Workaround: drop the original
// iris-rtc artifact and substitute a local copy whose manifest package was
// patched to "io.agora.rtc.iris" (its actual Kotlin/Java classes still live
// under io.agora.rtc.* unchanged — only the manifest's own namespace moved,
// and iris-rtc declares no activities/services that depend on it).
configurations.all {
    exclude(group = "io.agora.rtc", module = "iris-rtc")
}

dependencies {
    implementation(files("libs/iris-rtc-4.3.2-build.1-patched.aar"))

    // Media3/ExoPlayer native player (see media3/ package) — media3-exoplayer
    // is the core Player implementation, media3-ui provides PlayerView (the
    // actual <video>-equivalent surface), -hls/-dash add adaptive-streaming
    // MediaSource support (spec: "HLS/DASH/progressive media"), -datasource
    // adds HTTP/cache DataSource implementations progressive+adaptive sources
    // both need.
    val media3Version = "1.5.1"
    implementation("androidx.media3:media3-exoplayer:$media3Version")
    implementation("androidx.media3:media3-exoplayer-hls:$media3Version")
    implementation("androidx.media3:media3-exoplayer-dash:$media3Version")
    implementation("androidx.media3:media3-ui:$media3Version")
    implementation("androidx.media3:media3-datasource:$media3Version")
    implementation("androidx.media3:media3-common:$media3Version")
    // Trims, filters and cartoons clips on the phone (VideoEditChannel.kt).
    implementation("androidx.media3:media3-transformer:$media3Version")
    implementation("androidx.media3:media3-effect:$media3Version")
    implementation("androidx.exifinterface:exifinterface:1.3.7")
}
