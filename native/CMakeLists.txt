cmake_minimum_required(VERSION 3.21)
project(OmaDeckTouch LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Widgets)
include(CTest)

set(OMADECK_ARTIFACT_ROOT "${CMAKE_BINARY_DIR}/artifacts" CACHE PATH
  "Private staging root for OmaDeck runtime artifacts")

add_library(omadecktouchplugin SHARED
  EvdevTouchState.cpp
  EvdevTouchState.h
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
  LIBRARY_OUTPUT_DIRECTORY "${OMADECK_ARTIFACT_ROOT}/OmaDeck/Touch"
)

add_executable(omadeck-tray
  TrayApp.cpp
  TrayCallbacks.h
)

target_link_libraries(omadeck-tray PRIVATE
  Qt6::Core
  Qt6::Gui
  Qt6::Widgets
)

set_target_properties(omadeck-tray PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${OMADECK_ARTIFACT_ROOT}/bin"
)

if(BUILD_TESTING)
  find_package(Qt6 REQUIRED COMPONENTS Test)

  add_executable(touchbridge-lifetime-test
    tests/TouchBridgeLifetimeTest.cpp
    EvdevTouchState.cpp
    EvdevTouchState.h
    TouchBridge.cpp
    TouchBridge.h
  )

  target_link_libraries(touchbridge-lifetime-test PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::Test
  )

  add_test(NAME touchbridge-lifetime COMMAND touchbridge-lifetime-test)
  set_tests_properties(touchbridge-lifetime PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
  )

  add_executable(evdev-touch-state-test
    tests/EvdevTouchStateTest.cpp
    EvdevTouchState.cpp
    EvdevTouchState.h
  )

  target_link_libraries(evdev-touch-state-test PRIVATE
    Qt6::Core
    Qt6::Test
  )

  add_test(NAME evdev-touch-state COMMAND evdev-touch-state-test)

  add_executable(tray-callback-test
    tests/TrayCallbackTest.cpp
    TrayCallbacks.h
  )

  target_link_libraries(tray-callback-test PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    Qt6::Test
  )

  add_test(NAME tray-callback COMMAND tray-callback-test)
  set_tests_properties(tray-callback PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
  )
endif()
