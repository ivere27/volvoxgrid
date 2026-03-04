#include <jni.h>
#include <android/native_window_jni.h>
#include <stdint.h>

JNIEXPORT jlong JNICALL
Java_io_github_ivere27_volvoxgrid_NativeWindowHelper_nativeGetNativeWindow(
    JNIEnv *env, jclass clazz, jobject surface
) {
    if (surface == NULL) return 0;
    ANativeWindow *window = ANativeWindow_fromSurface(env, surface);
    return (jlong)(uintptr_t)window;
}

JNIEXPORT void JNICALL
Java_io_github_ivere27_volvoxgrid_NativeWindowHelper_nativeReleaseNativeWindow(
    JNIEnv *env, jclass clazz, jlong ptr
) {
    if (ptr != 0) {
        ANativeWindow_release((ANativeWindow*)(uintptr_t)ptr);
    }
}

JNIEXPORT void JNICALL
Java_io_github_ivere27_volvoxgrid_NativeWindowHelper_nativeAcquireNativeWindow(
    JNIEnv *env, jclass clazz, jlong ptr
) {
    if (ptr != 0) {
        ANativeWindow_acquire((ANativeWindow*)(uintptr_t)ptr);
    }
}
