# Generic imzaları koru (TypeToken hatasını çözer)
-keepattributes Signature
-keepattributes *Annotation*

# Gson ve Bildirim kütüphanesini koru
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.dexterous.flutterlocalnotifications.** { *; }
