cmake_minimum_required(VERSION 3.20)

project(kwin4_effect_shapecorners VERSION 0.7.2 LANGUAGES CXX)

include(cmake/default-vars.cmake)

find_package(ECM "5.100" REQUIRED NO_MODULE)
list(APPEND CMAKE_MODULE_PATH
        ${ECM_MODULE_PATH}
        ${ECM_KDE_MODULE_DIR}
)
include(FeatureSummary)
include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

find_package(KF${QT_MAJOR_VERSION} ${KF_MIN_VERSION} REQUIRED COMPONENTS Config)
find_package(Qt6 REQUIRED COMPONENTS DBus Widgets)
if(${Qt6_VERSION} VERSION_GREATER_EQUAL 6.10)
    find_package(Qt6 REQUIRED COMPONENTS CorePrivate)
endif()

find_package(KWin REQUIRED COMPONENTS kwineffects)
set(CMAKE_PACKAGE_NAME "${CMAKE_PROJECT_NAME}")
set(CMAKE_PROJECT_VERSION "${CMAKE_PROJECT_VERSION}.${KWin_VERSION}")
set(KWIN_LIB_NAME KWin)
set(KWIN_NAMESPACE_PREFIX "kwin")
set(KWIN_VERSION "${KWin_VERSION}")
message(STATUS "Found KWin Version: ${KWIN_VERSION}")

include(cmake/info.cmake)
find_package(epoxy REQUIRED)

add_subdirectory(src)
feature_summary(WHAT ALL FATAL_ON_MISSING_REQUIRED_PACKAGES)
