cmake_minimum_required(VERSION 3.20)
project(nordic-borderless VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(QT_MAJOR_VERSION 6)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)

find_package(Qt6 REQUIRED COMPONENTS Core Gui)
find_package(KF6 REQUIRED COMPONENTS CoreAddons)
find_package(KDecoration3 REQUIRED)

add_library(nordicborderless MODULE
    NordicBorderlessDecoration.cpp
)

set_target_properties(nordicborderless PROPERTIES
    PREFIX ""
    OUTPUT_NAME "org.kde.nordicborderless"
)

target_link_libraries(nordicborderless PRIVATE
    Qt6::Core
    Qt6::Gui
    KF6::CoreAddons
    KDecoration3::KDecoration
)

install(TARGETS nordicborderless
    DESTINATION "${KDE_INSTALL_PLUGINDIR}/org.kde.kdecoration3"
)
