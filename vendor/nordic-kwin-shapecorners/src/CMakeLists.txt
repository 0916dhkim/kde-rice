set(effect_SRCS
    Effect.h
    Effect.cpp
    Shader.h
    Shader.cpp
    Window.h
    Window.cpp
    TileChecker.h
    TileChecker.cpp
    FloatColor.h
    WindowConfig.h
    WindowConfig.cpp
    WindowManager.h
    WindowManager.cpp
    Animation.h
    Animation.cpp
    plugin.cpp
)

kconfig_add_kcfg_files(effect_SRCS Config.kcfgc)
kcoreaddons_add_plugin(kwin4_effect_shapecorners SOURCES ${effect_SRCS} INSTALL_NAMESPACE "${KWIN_NAMESPACE_PREFIX}/effects/plugins/")

target_link_libraries(kwin4_effect_shapecorners
    Qt${QT_MAJOR_VERSION}::DBus
    KF${QT_MAJOR_VERSION}::ConfigGui
    ${KWIN_LIB_NAME}::kwin
    Qt${QT_MAJOR_VERSION}::CorePrivate
)

string(REPLACE "." ";" _kwin_ver_list "${KWIN_VERSION}")
list(GET _kwin_ver_list 0 _kwin_ver_major)
list(GET _kwin_ver_list 1 _kwin_ver_minor)
list(GET _kwin_ver_list 2 _kwin_ver_patch)
math(EXPR _kwin_ver_num "(${_kwin_ver_major} << 16) | (${_kwin_ver_minor} << 8) | ${_kwin_ver_patch}")
target_compile_definitions(kwin4_effect_shapecorners PRIVATE KWIN_PLUGIN_VERSION_NUM=${_kwin_ver_num})

add_subdirectory(shaders)
