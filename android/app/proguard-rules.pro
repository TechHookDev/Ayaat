# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep enum com.dexterous.flutterlocalnotifications.** { *; }
-keep interface com.dexterous.flutterlocalnotifications.** { *; }

# Gson preservation for notification details
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type { *; }
-keep public class * implements java.lang.reflect.ParameterizedType { *; }

# Adhan (Prayer calculation)
-keep class adhan.** { *; }
-keep enum adhan.** { *; }

# Geolocator
-keep class com.google.android.gms.location.** { *; }
-keep class com.baseflow.geolocator.** { *; }

# General ProGuard for Flutter 
-keepattributes Signature,Exceptions,*Annotation*,InnerClasses,EnclosingMethod

# Keep generic signatures for reflection (essential for Gson)
-keepattributes Signature
