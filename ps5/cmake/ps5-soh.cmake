# Toolchain for Ship of Harkinian: PS5 native toolchain, reported as CMAKE_SYSTEM_NAME "PS5".
include(${CMAKE_CURRENT_LIST_DIR}/ps5-native.cmake)
set(CMAKE_SYSTEM_NAME PS5)
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR})
