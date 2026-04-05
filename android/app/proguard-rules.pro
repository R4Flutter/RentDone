# Project-specific release rules.
# Keep Flutter engine/plugin entry points stable under shrinking/obfuscation.
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase/Play services warnings may be noisy during minification.
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
