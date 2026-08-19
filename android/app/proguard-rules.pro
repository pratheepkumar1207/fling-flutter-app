# Agora's native SDK calls into its own Java classes via JNI, referencing
# them by their literal (unobfuscated) name from native code — R8 has no
# visibility into that, so without an explicit keep it happily renames/
# strips those classes, which doesn't fail the build but crashes the app
# the instant Agora's native layer can't find what it's looking for
# (VoiceChatController initializes Agora unconditionally on EVERY room
# entry, not just voice/live rooms — that's why this wasn't isolated to
# one room type). This is Agora's own documented ProGuard requirement.
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# The two classes below are referenced by Agora's AAR but never actually
# shipped in it — a known Agora/AGP R8 compatibility gap (see pubspec.yaml's
# dependency_overrides comment for the matching debug-build issue). Missing
# at runtime only on code paths Agora itself doesn't hit, so suppressing
# beats failing minification outright.
-dontwarn com.google.devtools.build.android.desugar.runtime.ThrowableExtension
-dontwarn io.agora.iris.IrisApiEngine

# google_sign_in / Firebase / Play Services — these generally ship their
# own consumer ProGuard rules, but keep them explicitly too since a
# release-only crash here would look identical to the Agora one above and
# be just as painful to bisect blind.
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.firebase.** { *; }

# socket_io_client's underlying Java Socket.IO/Engine.IO client uses
# okhttp/okio and org.json; keeping them avoids the same class of
# release-only "worked in debug" failure for the realtime connection every
# room depends on.
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class org.json.** { *; }

# razorpay_flutter's checkout SDK (com.razorpay:checkout) reflectively
# invokes its own classes and ProGuard/R8 will otherwise strip or rename
# them in release builds, breaking the payment flow silently (same failure
# shape as the Agora/Firebase rules above) — this is Razorpay's own
# documented ProGuard requirement.
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**
-keepclasseswithmembers class * {
  @android.webkit.JavascriptInterface <methods>;
}
