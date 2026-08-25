# ============================================================================
# Custom build configuration overrides
#
# Included by the upstream root CMakeLists.txt as soon as the custom overlay
# directory is detected. Anything set here wins over cmake/CustomOptions.cmake.
#
# This overlay deliberately keeps the stock branding so that the build stays
# a plain QGroundControl with one extra Fly View widget: the app name also
# decides the settings/log directory, and changing it would orphan existing
# QGC settings. Uncomment below if you do want your own identity.
# ============================================================================

# set(QGC_APP_NAME "MyQGroundControl" CACHE STRING "App Name" FORCE)
# set(QGC_ANDROID_PACKAGE_NAME "com.example.myqgroundcontrol" CACHE STRING "Android package identifier" FORCE)
