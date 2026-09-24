cmake_minimum_required(VERSION 3.21)
project(OmaDeckWatchHost LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick WebEngineQuick Network)
find_package(LayerShellQt REQUIRED)

qt_add_executable(omadeck-watch-host main.cpp)
qt_add_resources(omadeck-watch-host watch-qml PREFIX "/" FILES WatchView.qml)
target_link_libraries(omadeck-watch-host PRIVATE
  Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::WebEngineQuick
  Qt6::Network LayerShellQt::Interface)
