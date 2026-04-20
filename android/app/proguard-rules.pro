# ===========================================================================
# ML Kit — keep everything. The plugins ship NO consumer-rules.pro, and the
# detector SDKs use reflection to reach internal vision classes. Without
# these, R8 strips them in release builds and the detector silently returns
# empty results — which is the classic "works in debug, broken in release"
# ML Kit bug.
# Source: https://developers.google.com/ml-kit/known-issues
# ===========================================================================
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_** { *; }
-keep interface com.google.android.gms.internal.mlkit_vision_** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.internal.mlkit_vision_**

# MediaPipe native bindings used by face-mesh
-keep class com.google.android.gms.internal.mlkit_face_mesh_bundled.** { *; }
-dontwarn com.google.android.gms.internal.mlkit_face_mesh_bundled.**

# Flutter plugin method channel handlers
-keep class io.flutter.plugin.common.** { *; }
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_face_detection.** { *; }
-keep class com.google_mlkit_face_mesh_detection.** { *; }
