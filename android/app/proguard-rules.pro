# Flutter Proguard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase Rules
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Hive Rules
-keep class com.hivedb.** { *; }
-dontwarn com.hivedb.**

# Keep models (Freezed/JSON) if they are accessed via reflection (some plugins do this)
-keep class com.unihub.unihub_mobile.features.**.models.** { *; }

# AdMob
-keep class com.google.android.gms.ads.** { *; }

# Prevent obfuscation of native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep the R class
-keep class **.R$* {
    <fields>;
}
