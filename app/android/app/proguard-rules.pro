# MediaPipe and its protobufs are reached through JNI and reflection, so R8 must not strip them.
-keep class com.google.mediapipe.** { *; }
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.mediapipe.**
-dontwarn com.google.protobuf.**
# Annotation-processing classes MediaPipe references but never loads at runtime.
-dontwarn javax.annotation.**
-dontwarn javax.lang.model.**
-dontwarn com.google.auto.value.**
-dontwarn com.google.common.**
