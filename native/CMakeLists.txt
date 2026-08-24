cmake_minimum_required(VERSION 3.21)
project(OmaDeckTouch LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Widgets)

add_library(omadecktouchplugin SHARED
  TouchBridge.cpp
  TouchBridge.h
  TouchPlugin.cpp
)

target_link_libraries(omadecktouchplugin PRIVATE
  Qt6::Core
  Qt6::Gui
  Qt6::Qml
  Qt6::Quick
)

set_target_properties(omadecktouchplugin PROPERTIES
  LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/OmaDeck/Touch"
)

add_executable(omadeck-tray
  TrayApp.cpp
)

target_link_libraries(omadeck-tray PRIVATE
  Qt6::Core
  Qt6::Gui
  Qt6::Widgets
)

set_target_properties(omadeck-tray PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/bin"
)
