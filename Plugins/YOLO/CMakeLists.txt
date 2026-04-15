cmake_minimum_required(VERSION 3.14)
project(RMT_YOLO CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 查找依赖
find_package(OpenCV REQUIRED)
find_package(ONNXRuntime REQUIRED)

# 定义源文件
add_library(RMT_YOLO SHARED
    RMT_YOLO.cpp
    RMT_YOLO.h
)

target_include_directories(RMT_YOLO PRIVATE
    ${OpenCV_INCLUDE_DIRS}
    ${ONNXRUNTIME_INCLUDE_DIRS}
)

# Windows DLL 导出符号
target_compile_definitions(RMT_YOLO PRIVATE YOLO_EXPORTS)
set_target_properties(RMT_YOLO PROPERTIES
    WINDOWS_EXPORT_ALL_SYMBOLS OFF
)

target_link_libraries(RMT_YOLO PRIVATE
    ${OpenCV_LIBS}
    onnxruntime
)

# 输出到 Release 目录 (与现有项目结构一致)
set_target_properties(RMT_YOLO PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_SOURCE_DIR}/../ReleaseX64/Plugins/YOLO"
    LIBRARY_OUTPUT_DIRECTORY_RELEASE "${CMAKE_SOURCE_DIR}/../ReleaseX64/Plugins/YOLO"
    ARCHIVE_OUTPUT_DIRECTORY_RELEASE "${CMAKE_SOURCE_DIR}/../ReleaseX64/Plugins/YOLO"
)
