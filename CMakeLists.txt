# ============================================================================
# QGroundControl custom overlay: ESC telemetry graphs on the Fly View
#
# This directory is added by the upstream root CMakeLists.txt when it is
# present (or symlinked) at ${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}, which
# defaults to "custom". Nothing in the upstream tree is modified.
#
# NOTE: this file is processed BEFORE qt_add_executable() runs upstream, so
# the ${CMAKE_PROJECT_NAME} target does not exist yet. Everything is handed
# to upstream through the CUSTOM_* cache variables and QGC_RESOURCES, exactly
# like custom-example does.
# ============================================================================

message(STATUS "QGC: Custom overlay - ESC telemetry graphs")

# ----------------------------------------------------------------------------
# Resources
#
# custom.qrc maps our FlyViewCustomLayer.qml onto the resource path
# :/Custom/qml/QGroundControl/FlyView/FlyViewCustomLayer.qml. At runtime the
# url interceptor installed by CustomPlugin rewrites any qrc:/<path> to
# qrc:/Custom/<path> when that resource exists, which is what makes the
# override take effect without touching the upstream .qml file.
# ----------------------------------------------------------------------------
# REMOVE_DUPLICATES matters: these are FORCE'd cache variables, so without it
# every re-configure would append our entry again and the executable would end
# up with the same .qrc listed several times.
set(_custom_resources ${QGC_RESOURCES} "${CMAKE_CURRENT_SOURCE_DIR}/custom.qrc")
list(REMOVE_DUPLICATES _custom_resources)
set(QGC_RESOURCES ${_custom_resources} CACHE STRING "Paths to .qrc Resources" FORCE)

# Let QML tooling (qmllint / Qt Creator) resolve `import Custom.EscTelemetry`
set(_custom_qml_import_path ${QML_IMPORT_PATH} "${CMAKE_CURRENT_SOURCE_DIR}/res")
list(REMOVE_DUPLICATES _custom_qml_import_path)
set(QML_IMPORT_PATH ${_custom_qml_import_path} CACHE STRING "Extra qml import paths" FORCE)

# ----------------------------------------------------------------------------
# Custom QML module: Custom.EscTelemetry
# ----------------------------------------------------------------------------
qt_add_library(CustomEscTelemetryModule STATIC)

qgc_set_qt_resource_alias(
    ${CMAKE_CURRENT_SOURCE_DIR}/res/Custom/EscTelemetry/EscTelemetryPanel.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/res/Custom/EscTelemetry/EscTelemetryChart.qml
)

qt_add_qml_module(CustomEscTelemetryModule
    URI Custom.EscTelemetry
    VERSION 1.0
    RESOURCE_PREFIX /qml
    QML_FILES
        ${CMAKE_CURRENT_SOURCE_DIR}/res/Custom/EscTelemetry/EscTelemetryPanel.qml
        ${CMAKE_CURRENT_SOURCE_DIR}/res/Custom/EscTelemetry/EscTelemetryChart.qml
    NO_PLUGIN
)

# ----------------------------------------------------------------------------
# Custom plugin sources
# ----------------------------------------------------------------------------
set(CUSTOM_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/CustomPlugin.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/CustomPlugin.h
    CACHE INTERNAL "" FORCE
)

set(CUSTOM_LIBRARIES
    CustomEscTelemetryModule
    CACHE INTERNAL "" FORCE
)

set(CUSTOM_INCLUDE_DIRECTORIES
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    CACHE INTERNAL "" FORCE
)

# QGC_CUSTOM_BUILD switches QGCCorePlugin::instance() over to CUSTOMCLASS.
set(CUSTOM_DEFINITIONS
    QGC_CUSTOM_BUILD
    CUSTOMHEADER="CustomPlugin.h"
    CUSTOMCLASS=CustomPlugin
    CACHE INTERNAL "" FORCE
)

set(CUSTOM_QT_COMPONENTS
    Core
    Qml
    CACHE INTERNAL "" FORCE
)
