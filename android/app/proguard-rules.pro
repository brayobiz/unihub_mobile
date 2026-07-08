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
-dontwarn com.google.firebase.**

# Play Core / Deferred Components (Fix for R8 missing classes)
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# Hive Rules
-keep class com.hivedb.** { *; }
-dontwarn com.hivedb.**
-keep class io.hive.** { *; }
-dontwarn io.hive.**

# Keep models (Freezed/JSON) and their generated files
-keep class com.unihub.unihub_mobile.features.**.models.** { *; }
-keepclassmembers class com.unihub.unihub_mobile.features.**.models.** {
    *** fromJson(...);
    *** toJson(...);
}

# AdMob
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Standard AndroidX and Google keeps
-keep class androidx.lifecycle.** { *; }
-dontwarn androidx.lifecycle.**

# Prevent obfuscation of native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep the R class
-keep class **.R$* {
    <fields>;
}

# Fix for common plugins that might be stripped
-keep class com.google.android.play.core.common.PlayCoreDialogWrapperActivity
-keep class com.google.android.play.core.review.** { *; }
-keep class com.google.android.play.core.appupdate.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
