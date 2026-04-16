/**
 * @file yolos_c_api.cpp
 * @brief C-style API for YOLOs-CPP DLL (AHK DllCall compatible)
 *
 * 导出函数仅3个（参考 FindScreenImage 设计模式）：
 *   YoloCreate       → 创建检测器（直接传入类别字符串，无临时文件）
 *   YoloDetectScreen → 截屏+检测+绘制+保存（一体化）
 *   YoloDestroy      → 销毁检测器
 *
 * 内部辅助函数（不导出）：
 *   captureScreenInternal, drawDetections, parseClassesCsv, findBestTarget
 *
 * 零侵入设计：通过 yolos_detector_patch.hpp 继承 YOLODetector
 * 实现纯内存初始化，不修改 YOLOs-CPP 源码
 */

#define YOLOSCPP_BUILD_DLL
#include "yolos/core/yolos_c_api.hpp"
#include "yolos_detector_patch.hpp"

#include <iostream>
#include <string>
#include <chrono>
#include <cstring>
#include <sstream>
#include <algorithm>
#include <vector>
#include <windows.h>

using namespace yolos::det;

// ============================================================================
// 内部辅助函数（不导出）
// ============================================================================

static thread_local char g_lastError[1024] = {0};

struct YolosContext {
    std::unique_ptr<YolosDllDetector> detector;
    std::vector<Detection> lastResults;
    int lastFilteredCount = 0;

    YolosContext(const char* modelPath, const std::vector<std::string>& classNames, bool useGPU)
        : detector(std::make_unique<YolosDllDetector>(modelPath, classNames, useGPU)) {}
};

static std::vector<std::string> parseClassesCsv(const char* csv) {
    std::vector<std::string> names;
    if (!csv || !csv[0]) return names;
    std::stringstream ss(csv);
    std::string item;
    while (std::getline(ss, item, ',')) {
        size_t start = item.find_first_not_of(" \t");
        size_t end = item.find_last_not_of(" \t");
        if (start != std::string::npos)
            names.push_back(item.substr(start, end - start + 1));
    }
    return names;
}

static int findBestTarget(const std::vector<Detection>& results, int targetClassId) {
    int bestIdx = -1;
    float bestConf = 0.0f;
    for (int i = 0; i < static_cast<int>(results.size()); i++) {
        const Detection& d = results[i];
        if (targetClassId >= 0 && d.classId != targetClassId)
            continue;
        if (d.conf > bestConf) {
            bestConf = d.conf;
            bestIdx = i;
        }
    }
    return bestIdx;
}

static void drawDetections(cv::Mat& image, const std::vector<Detection>& results,
                           const std::vector<std::string>& classNames) {
    static const cv::Scalar colors[] = {
        {255, 0, 0}, {0, 255, 0}, {0, 0, 255}, {255, 255, 0},
        {255, 0, 255}, {0, 255, 255}, {128, 0, 255}, {255, 128, 0},
        {0, 128, 255}, {128, 255, 0}, {255, 0, 128}, {0, 255, 128}
    };
    int numColors = sizeof(colors) / sizeof(colors[0]);

    for (const Detection& d : results) {
        const cv::Rect box(d.box.x, d.box.y, d.box.width, d.box.height);
        const cv::Scalar& color = colors[d.classId % numColors];
        cv::rectangle(image, box, color, 2);

        std::string label = (d.classId < static_cast<int>(classNames.size()))
            ? classNames[d.classId]
            : "class_" + std::to_string(d.classId);
        label += ": " + std::to_string(static_cast<int>(d.conf * 100)) + "%";

        int baseLine = 0;
        cv::Size textSize = cv::getTextSize(label, cv::FONT_HERSHEY_SIMPLEX, 0.6, 1, &baseLine);

        cv::Point textPos(box.x, box.y - 5);
        if (textPos.y < textSize.height)
            textPos.y = box.y + textSize.height + 5;

        cv::rectangle(image,
                      cv::Point(textPos.x, textPos.y - textSize.height),
                      cv::Point(textPos.x + textSize.width, textPos.y + baseLine),
                      color, -1);
        cv::putText(image, label, textPos, cv::FONT_HERSHEY_SIMPLEX, 0.6,
                    cv::Scalar(255, 255, 255), 1);
    }
}

static cv::Mat captureScreenInternal(int x, int y, int width, int height) {
    HDC hDesktopDC = GetDC(NULL);
    HDC hCaptureDC = CreateCompatibleDC(hDesktopDC);
    HBITMAP hBitmap = CreateCompatibleBitmap(hDesktopDC, width, height);
    SelectObject(hCaptureDC, hBitmap);
    BitBlt(hCaptureDC, 0, 0, width, height, hDesktopDC, x, y, SRCCOPY | CAPTUREBLT);

    BITMAPINFOHEADER bi = {};
    bi.biSize = sizeof(BITMAPINFOHEADER);
    bi.biWidth = width;
    bi.biHeight = -height;
    bi.biPlanes = 1;
    bi.biBitCount = 32;

    cv::Mat mat(height, width, CV_8UC4);
    GetDIBits(hCaptureDC, hBitmap, 0, height, mat.data, (BITMAPINFO*)&bi, DIB_RGB_COLORS);

    DeleteObject(hBitmap);
    DeleteDC(hCaptureDC);
    ReleaseDC(NULL, hDesktopDC);
    return mat;
}

// ============================================================================
// 导出函数（仅3个，AHK 直接调用）
// ============================================================================

extern "C" {

YOLOS_C_API_EXPORT YolosHandle __cdecl YoloCreate(const char* modelPath,
                                                   const char* classesCsv,
                                                   int useGPU) {
    try {
        std::vector<std::string> classNames = parseClassesCsv(classesCsv);
        return static_cast<void*>(new YolosContext(modelPath, classNames, useGPU != 0));
    } catch (...) {
        return nullptr;
    }
}

/// 截屏 + 检测 + [可选] 绘制 + [可选] 保存（一体化，类似 FindScreenImage 接口风格）
///
/// 参数顺序：handle → 截屏区域 → 输出路径 → 阈值 → 目标类别 → saveResult → 输出坐标
/// 返回值含义与 FindScreenImage 一致：1=找到, 0=未找到, 负数=错误
///
/// saveResult=0: 仅截屏+推理+返回坐标（RMT 项目正常使用，无绘图开销）
/// saveResult=1: 截屏+推理+绘制检测框+保存图片（测试/调试用）
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
                                                int* outY) {
    if (!handle || !outX || !outY)
        return -1;

    *outX = 0;
    *outY = 0;

    auto* ctx = static_cast<YolosContext*>(handle);

    try {
        // 1. 截屏
        if (screenW <= 0 || screenH <= 0)
            return -1;

        cv::Mat src = captureScreenInternal(screenX, screenY, screenW, screenH);
        if (src.empty())
            return 0;

        // BGRA → BGR
        cv::Mat image;
        if (src.channels() == 4)
            cv::cvtColor(src, image, cv::COLOR_BGRA2BGR);
        else
            image = src;

        // 2. 推理
        ctx->lastResults = ctx->detector->detect(image, confThresh, nmsThresh);
        ctx->lastFilteredCount = static_cast<int>(ctx->lastResults.size());

        // 3. [可选] 绘制检测框 & 保存
        if (saveResult && outputPath && outputPath[0]) {
            // 根据 targetClassId 过滤要绘制的检测结果
            std::vector<Detection> drawResults;
            if (targetClassId >= 0) {
                for (const Detection& d : ctx->lastResults) {
                    if (d.classId == targetClassId)
                        drawResults.push_back(d);
                }
            } else {
                drawResults = ctx->lastResults;
            }
            drawDetections(image, drawResults, {});
            cv::imwrite(outputPath, image);
        }

        // 4. 返回最佳目标中心坐标
        if (ctx->lastResults.empty())
            return 0;

        int bestIdx = findBestTarget(ctx->lastResults, targetClassId);
        if (bestIdx < 0)
            return 0;

        const Detection& best = ctx->lastResults[bestIdx];
        *outX = screenX + best.box.x + best.box.width / 2;
        *outY = screenY + best.box.y + best.box.height / 2;

        return 1;

    } catch (const std::exception& e) {
        snprintf(g_lastError, sizeof(g_lastError), "YoloDetectScreen: %s", e.what());
        return -2;
    } catch (...) {
        snprintf(g_lastError, sizeof(g_lastError), "YoloDetectScreen: unknown exception");
        return -2;
    }
}

YOLOS_C_API_EXPORT void __cdecl YoloDestroy(YolosHandle handle) {
    if (!handle) return;
    auto* ctx = static_cast<YolosContext*>(handle);
    delete ctx;
}

} // extern "C"
