cmake_minimum_required(VERSION 3.16)
project(custom_drone_plugins VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(gz-sim8 QUIET)
if(NOT gz-sim8_FOUND)
  find_package(gz-sim7 REQUIRED)
  set(GZ_SIM_VER 7)
else()
  set(GZ_SIM_VER 8)
endif()

find_package(gz-plugin2 REQUIRED)
find_package(gz-math7 REQUIRED)

add_library(CustomDronePlugin SHARED
  src/StandardPlugin.cpp
)

target_include_directories(CustomDronePlugin PRIVATE include)

target_link_libraries(CustomDronePlugin PRIVATE
  gz-sim${GZ_SIM_VER}::gz-sim${GZ_SIM_VER}
  gz-plugin2::gz-plugin2
  gz-math7::gz-math7
)

set_target_properties(CustomDronePlugin PROPERTIES
  OUTPUT_NAME "CustomDronePlugin"
  PREFIX "lib"
)
