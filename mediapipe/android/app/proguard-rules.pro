# Mediapipe
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# Protobuf
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# AutoValue / JavaPoet
-keep class com.google.auto.value.** { *; }
-dontwarn com.google.auto.value.**

# javax.lang.model
-dontwarn javax.lang.model.**

# OkHttp & BouncyCastle & Conscrypt
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
