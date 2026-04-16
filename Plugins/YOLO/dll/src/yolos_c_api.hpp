#pragma once

// ============================================================================
// yolos_c_api.hpp - C-style API for YOLOs-CPP DLL (AHK/ctypes compatible)
//
// 导出函数（仅3个）：
//   YoloCreate        → 创建检测器
//   YoloDetectScreen → 截屏+检测+绘制+保存+返回坐标（类似 FindScreenImage）
//   YoloDestroy      → 销毁检测器
//
// AHK 使用流程：
//   handle := DllCall("yolos.dll\YoloCreate", ...)
//   ret := DllCall("yolos.dll\YoloDetectScreen", handle, x, y, w, h, outputPath, conf, nms, targetId, &outX, &outY)
//   DllCall("yolos.dll\YoloDestroy", handle)
// ============================================================================

#include <cstdint>
#include <string>

#ifdef _WIN32
    #ifdef YOLOSCPP_BUILD_DLL
        #define YOLOS_C_API_EXPORT __declspec(dllexport)
    #else
        #define YOLOS_C_API_EXPORT __declspec(dllimport)
    #endif
#else
    #define YOLOS_C_API_EXPORT __attribute__((visibility("default")))
#endif

using YolosHandle = void*;

extern "C" {

/// 创建 YOLO 检测器实例（耗时操作，只调用一次）
/// @param modelPath ONNX 模型路径
/// @param classesCsv 类别列表（逗号分隔），如 "person,car"
/// @param useGPU 0=CPU, 1=CUDA GPU
/// @return 句柄，失败返回 nullptr
YOLOS_C_API_EXPORT YolosHandle __cdecl YoloCreate(const char* modelPath,
                                                   const char* classesCsv,
                                                   int useGPU);

/// 截屏 + 目标检测 + [可选]绘制框+保存结果图片
///
/// 流程：截取屏幕指定区域 → YOLO 推理 → [可选] 绘制检测框和标签 → [可选] 保存到文件 → 返回最佳目标坐标
///
/// @param handle YoloCreate 返回的句柄
/// @param screenX 截屏左上角 X 坐标
/// @param screenY 截屏左上角 Y 坐标
/// @param screenW 截屏宽度
/// @param screenH 截屏高度
/// @param outputPath 结果图片保存路径（saveResult=1 时有效，带检测框的 jpg/png/bmp）
/// @param confThresh 置信度阈值 (0.0~1.0)，如 0.35
/// @param nmsThresh NMS 阈值 (0.0~1.0)，如 0.45
/// @param targetClassId 目标类别 ID，-1=全部（不过滤）
/// @param saveResult 是否绘制检测框并保存图片 (0=否, 1=是)，RMT 项目用 0 跳过绘图开销
/// @param outX [输出] 最佳目标中心 X 坐标（相对于屏幕）
/// @param outY [输出] 最佳目标中心 Y 坐标（相对于屏幕）
/// @return 1=检测到目标, 0=未检测到, -1=参数错误, -2=异常
YOLOS_C_API_EXPORT int __cdecl YoloDetectScreen(YolosHandle handle,
                                                int screenX,
                                                int screenY,
                                                int screenW,
                                                int screenH,
                                                const char* outputPath,
                                                float confThresh,
                                                float nmsThresh,
                                                int targetClassId,
                                                int saveResult,
                                                int* outX,
                                                int* outY);

/// 销毁检测器实例，释放资源
YOLOS_C_API_EXPORT void __cdecl YoloDestroy(YolosHandle handle);

} // extern "C"
