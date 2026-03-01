cmake_minimum_required(VERSION 3.10)
project(volvoxgrid_jni LANGUAGES C)

# VolvoxGrid JNI (ANativeWindow helper)
add_library(
    volvoxgrid_jni
    SHARED
    native_window_helper.c
    text_renderer_bridge.c
)
target_link_libraries(volvoxgrid_jni android dl)
