cmake_minimum_required(VERSION 3.16)
project(yolos-dll VERSION 1.0.0 LANGUAGES CXX)

# ============================================================================
# YOLOs-CPP DLL 独立构建
# ============================================================================
# 前置条件: build.ps1 已将头文件同步到 ${CMAKE_SOURCE_DIR}/include/
#
# Usage:
#   cmake -B build -S . -DONNXRUNTIME_DIR=path/to/onnxruntime-win-x64-* ^
#         -DOpenCV_DIR=C:\opencv\build ^
#         -DOpenCV_RUNTIME=vc16 -DOpenCV_ARCH=x64
#   cmake --build build --config Release

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(BUILD_EXAMPLES "Build example applications" OFF)

# ============================================================================
# 本地头文件目录（由 build.ps1 从 YOLOs-CPP 仓库同步）
# ============================================================================
set(LOCAL_INCLUDE_DIR "${CMAKE_SOURCE_DIR}/include")

if(NOT EXISTS "${LOCAL_INCLUDE_DIR}/yolos/yolos.hpp")
    message(FATAL_ERROR
        "本地头文件缺失: ${LOCAL_INCLUDE_DIR}/yolos/yolos.hpp\n"
        "请先运行: .\\build.ps1 -YolosPath <YOLOs-CPP仓库路径>\n"
        "脚本会自动从 YOLOs-CPP 仓库同步头文件到 include/ 目录。"
    )
endif()

message(STATUS "Local include: ${LOCAL_INCLUDE_DIR}")

# ============================================================================
# OpenCV
# ============================================================================
find_package(OpenCV REQUIRED COMPONENTS core imgproc imgcodecs highgui videoio)
message(STATUS "OpenCV version: ${OpenCV_VERSION}")

# ============================================================================
# ONNX Runtime
# ============================================================================
if(NOT DEFINED ONNXRUNTIME_DIR AND NOT ENV{ONNXRUNTIME_DIR})
    set(ONNXRUNTIME_SEARCH_PATHS
        "${CMAKE_SOURCE_DIR}/onnxruntime-win-x64-1.24.4"
        "${CMAKE_SOURCE_DIR}/onnxruntime-win-x64-1.22.0"
        "${CMAKE_SOURCE_DIR}/onnxruntime-win-x64-1.20.1"
    )
    foreach(search_path ${ONNXRUNTIME_SEARCH_PATHS})
        if(EXISTS "${search_path}/include/onnxruntime_cxx_api.h")
            set(ONNXRUNTIME_DIR "${search_path}")
            break()
        endif()
    endforeach()
endif()

if(NOT EXISTS "${ONNXRUNTIME_DIR}/include/onnxruntime_cxx_api.h")
    message(FATAL_ERROR
        "ONNX Runtime 未找到!\n"
        "设置 -DONNXRUNTIME_DIR=<path> 或运行: .\\build.ps1 -Download"
    )
endif()

set(ONNXRUNTIME_INCLUDE_DIR "${ONNXRUNTIME_DIR}/include")
set(ONNXRUNTIME_LIB_DIR     "${ONNXRUNTIME_DIR}/lib")

if(WIN32)
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        set(ONNXRUNTIME_LIB "${ONNXRUNTIME_LIB_DIR}/onnxruntime.lib")
    else()
        message(FATAL_ERROR "Only x64 builds are supported on Windows")
    endif()
else()
    set(ONNXRUNTIME_LIB "${ONNXRUNTIME_LIB_DIR}/libonnxruntime.so")
endif()

message(STATUS "ONNX Runtime:  ${ONNXRUNTIME_DIR}")

# ============================================================================
# Threads
# ============================================================================
find_package(Threads REQUIRED)

# ============================================================================
# yolos DLL target
# ============================================================================
add_library(yolos SHARED
    src/yolos_dll.cpp
    src/yolos_c_api.cpp
)

target_include_directories(yolos PUBLIC
    "${LOCAL_INCLUDE_DIR}"
)
target_include_directories(yolos PRIVATE
    "${ONNXRUNTIME_INCLUDE_DIR}"
)

target_compile_definitions(yolos PUBLIC YOLOSCPP_USE_DLL)
target_compile_definitions(yolos PRIVATE YOLOSCPP_BUILD_DLL)

target_link_libraries(yolos PUBLIC
    ${OpenCV_LIBS}
    ${ONNXRUNTIME_LIB}
    Threads::Threads
)

set_target_properties(yolos PROPERTIES
    VERSION ${PROJECT_VERSION}
    SOVERSION ${PROJECT_VERSION_MAJOR}
    OUTPUT_NAME "yolos"
    WINDOWS_EXPORT_ALL_SYMBOLS ON
)

# 复制 ONNX Runtime DLL 到输出目录
if(WIN32)
    set(ORT_DLL "${ONNXRUNTIME_LIB_DIR}/onnxruntime.dll")
    if(EXISTS "${ORT_DLL}")
        add_custom_command(TARGET yolos POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${ORT_DLL}" "$<TARGET_FILE_DIR:yolos>"
            COMMENT "Copying onnxruntime.dll -> Release/"
        )
    endif()
endif()

# ============================================================================
# 输出摘要
# ============================================================================
message(STATUS "")
message(STATUS "============================================")
message(STATUS "  YOLOs-DLL Configuration")
message(STATUS "============================================")
message(STATUS "  Version:       ${PROJECT_VERSION}")
message(STATUS "  Build Type:    ${CMAKE_BUILD_TYPE}")
message(STATUS "  OpenCV:        ${OpenCV_VERSION}")
message(STATUS "  ONNX Runtime:  ${ONNXRUNTIME_DIR}")
message(STATUS "  Output:        ${CMAKE_BINARY_DIR}/Release/yolos.dll")
message(STATUS "")

# ============================================================================
# Install rules (可选，用于打包分发)
# ============================================================================
install(TARGETS yolos
    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
)

install(DIRECTORY ${LOCAL_INCLUDE_DIR}/yolos DESTINATION include
    FILES_MATCHING PATTERN "*.hpp"
)
