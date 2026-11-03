cmake_minimum_required(VERSION 3.16)
project(openprojmap_cpp_bridge CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(openprojmap_tracker main.cpp)
target_include_directories(openprojmap_tracker PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

enable_testing()
add_executable(test_cpp_bridge test_tracker.cpp)
add_test(NAME test_cpp_bridge COMMAND test_cpp_bridge)
