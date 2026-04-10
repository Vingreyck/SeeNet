# Fix androidx.window missing classes
-dontwarn androidx.window.extensions.**
-dontwarn androidx.window.sidecar.**
-keep class androidx.window.extensions.** { *; }
-keep class androidx.window.sidecar.** { *; }

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }

# GetStorage
-keep class ** extends com.tekartik.sqflite.** { *; }
# Play Core (deferred components)
-dontwarn com.google.android.play.core.**