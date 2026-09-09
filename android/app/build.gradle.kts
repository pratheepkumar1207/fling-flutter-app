plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
}
