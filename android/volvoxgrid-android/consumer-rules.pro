# Keep JNI bridge class/members stable under consumer app minification.
# The native library exports JNI symbols for NativeWindowHelper.
-keep class io.github.ivere27.volvoxgrid.NativeWindowHelper { *; }
