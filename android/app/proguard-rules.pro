# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**

# Keep Firebase Auth
-keep class com.google.firebase.auth.** { *; }

# Keep Cloud Firestore
-keep class com.google.cloud.firestore.** { *; }

# Keep Firebase Storage
-keep class com.google.firebase.storage.** { *; }

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.api.** { *; }

# RevenueCat (purchases_flutter)
-keep class com.revenuecat.purchases.** { *; }
-keep class com.revenuecat.applifecycle.** { *; }
-dontwarn com.revenuecat.**

# Image packages
-keep class com.github.huangyizhi.** { *; } # image_cropper
-keep class vip.magicengine.** { *; } # gal

# Video player
-keep class com.google.android.exoplayer2.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Remove logging in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Keep model classes (if using serialization)
-keep class lib.Models.** { *; }
-keep class lib.**.model.** { *; }

# Pro Image Editor
-keep class ch.waio.pro_image_editor.** { *; }

# Play Core / Play Store Split Install (Deferred Components)
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# ONNX Runtime and flutter_onnxruntime plugin rules
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**
-keep class com.masicai.flutteronnxruntime.** { *; }
-dontwarn com.masicai.flutteronnxruntime.**