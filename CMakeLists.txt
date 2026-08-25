# ============================================================================
# QGroundControl custom overlay
#
# This directory is added by the upstream root CMakeLists.txt when it is
# present (or symlinked) at ${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}, which
# defaults to "custom". Nothing in the upstream tree is modified.
#
# NOTE: this file is processed BEFORE qt_add_executable() runs upstream, so
# the ${CMAKE_PROJECT_NAME} target does not exist yet. Everything is handed
# to upstream through the CUSTOM_* cache variables and QGC_RESOURCES.
#
# To add a feature see "新機能の追加手順" in README.md — in short: create
# res/Custom/<Name>/ with its own CMakeLists.txt and add <Name> below.
# ============================================================================

message(STATUS "QGC: Custom overlay")

# ----------------------------------------------------------------------------
# Features
# ----------------------------------------------------------------------------
set(QGC_CUSTOM_FEATURES
    EscTelemetry
)

# ----------------------------------------------------------------------------
# Shared resources
#
# custom.qrc maps our replacements for upstream .qml files onto
# :/Custom/qml/<original path>. At runtime the url interceptor installed by
# CustomPlugin rewrites qrc:/<path> to qrc:/Custom/<path> when that resource
# exists, which is what makes an override take effect without touching the
# upstream file.
#
# REMOVE_DUPLICATES matters: these are FORCE'd cache variables, so without it
# every re-configure would append our entry again and the executable would end
# up with the same .qrc listed several times.
# ----------------------------------------------------------------------------
set(_custom_resources ${QGC_RESOURCES} "${CMAKE_CURRENT_SOURCE_DIR}/custom.qrc")
list(REMOVE_DUPLICATES _custom_resources)
set(QGC_RESOURCES ${_custom_resources} CACHE STRING "Paths to .qrc Resources" FORCE)

# Let QML tooling (qmllint / Qt Creator) resolve `import Custom.<Feature>`
set(_custom_qml_import_path ${QML_IMPORT_PATH} "${CMAKE_CURRENT_SOURCE_DIR}/res")
list(REMOVE_DUPLICATES _custom_qml_import_path)
set(QML_IMPORT_PATH ${_custom_qml_import_path} CACHE STRING "Extra qml import paths" FORCE)

# ----------------------------------------------------------------------------
# Baseline handed to upstream. Features append to these; resetting them here
# keeps re-configures from accumulating stale entries in the CMake cache.
# ----------------------------------------------------------------------------
set(CUSTOM_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/CustomPlugin.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/CustomPlugin.h
    CACHE INTERNAL "" FORCE
)
set(CUSTOM_LIBRARIES "" CACHE INTERNAL "" FORCE)
set(CUSTOM_INCLUDE_DIRECTORIES
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    CACHE INTERNAL "" FORCE
)

# ----------------------------------------------------------------------------
# qgc_custom_add_feature
#
# Declares one feature as a static QML module named Custom.<NAME>, plus any
# C++ it needs, and registers all of it with the upstream build.
#
#   qgc_custom_add_feature(
#       NAME       EscTelemetry           # module URI becomes Custom.EscTelemetry
#       QML_FILES  Foo.qml Bar.qml        # relative to the calling directory
#       SOURCES    Baz.cc Baz.h           # optional, relative to the calling directory
#   )
# ----------------------------------------------------------------------------
function(qgc_custom_add_feature)
    cmake_parse_arguments(FEATURE "" "NAME" "QML_FILES;SOURCES" ${ARGN})

    if(NOT FEATURE_NAME)
        message(FATAL_ERROR "QGC: qgc_custom_add_feature requires NAME")
    endif()

    set(_target "Custom${FEATURE_NAME}Module")

    set(_qml_paths "")
    foreach(_qml IN LISTS FEATURE_QML_FILES)
        list(APPEND _qml_paths "${CMAKE_CURRENT_SOURCE_DIR}/${_qml}")
    endforeach()

    qt_add_library(${_target} STATIC)

    # Flattens each file to its bare name inside the module's resource dir
    qgc_set_qt_resource_alias(${_qml_paths})

    qt_add_qml_module(${_target}
        URI Custom.${FEATURE_NAME}
        VERSION 1.0
        RESOURCE_PREFIX /qml
        QML_FILES ${_qml_paths}
        NO_PLUGIN
    )

    set(_libs ${CUSTOM_LIBRARIES} ${_target})
    list(REMOVE_DUPLICATES _libs)
    set(CUSTOM_LIBRARIES ${_libs} CACHE INTERNAL "" FORCE)

    if(FEATURE_SOURCES)
        set(_sources ${CUSTOM_SOURCES})
        foreach(_src IN LISTS FEATURE_SOURCES)
            list(APPEND _sources "${CMAKE_CURRENT_SOURCE_DIR}/${_src}")
        endforeach()
        list(REMOVE_DUPLICATES _sources)
        set(CUSTOM_SOURCES ${_sources} CACHE INTERNAL "" FORCE)

        set(_includes ${CUSTOM_INCLUDE_DIRECTORIES} "${CMAKE_CURRENT_SOURCE_DIR}")
        list(REMOVE_DUPLICATES _includes)
        set(CUSTOM_INCLUDE_DIRECTORIES ${_includes} CACHE INTERNAL "" FORCE)
    endif()

    message(STATUS "QGC: Custom feature - ${FEATURE_NAME}")
endfunction()

foreach(_feature IN LISTS QGC_CUSTOM_FEATURES)
    add_subdirectory("res/Custom/${_feature}")
endforeach()

# ----------------------------------------------------------------------------
# Build configuration handed to upstream
# ----------------------------------------------------------------------------

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
