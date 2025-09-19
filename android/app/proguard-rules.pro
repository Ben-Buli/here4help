# Keep Google Credentials API classes for smart_auth plugin
-keep class com.google.android.gms.auth.api.credentials.** { *; }
-keep class com.google.android.gms.auth.api.** { *; }
-dontwarn com.google.android.gms.auth.api.credentials.**

# Keep Google Play Services Auth classes
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Keep smart_auth plugin classes
-keep class fman.ge.smart_auth.** { *; }
