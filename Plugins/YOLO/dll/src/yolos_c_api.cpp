/**
 * @file yolos_c_api.cpp
 * @brief C-style API implementation for YOLOs-CPP DLL (AHK/ctypes compatible)
 */

#define YOLOSCPP_BUILD_DLL
#include "yolos/core/yolos_c_api.hpp"
#include "yolos/tasks/detection.hpp"

#include <iostream>
#include <string>
#include <chrono>
#include <cstring>

using namespace yolos::det;

static thread_local char g_lastError[1024] = {0};

struct YolosContext {
    std::unique_ptr<YOLODetector> detector;
    std::vector<Detection> lastResults;
    YolosResult lastResultInfo;
    cv::Mat lastImage;

    YolosContext(const char* modelPath, const char* labelsPath, bool useGPU)
        : detector(std::make_unique<YOLODetector>(modelPath, labelsPath, useGPU)) {
        memset(&lastResultInfo, 0, sizeof(lastResultInfo));
    }
};

extern "C" {

YOLOS_C_API_EXPORT const char* yolos_get_last_error(void) {
    return g_lastError;
}

YOLOS_C_API_EXPORT YolosHandle yolos_create(const char* modelPath,
                                             const char* labelsPath,
                                             int useGPU) {
    try {
        auto* ctx = new YolosContext(modelPath, labelsPath, useGPU != 0);
        snprintf(g_lastError, sizeof(g_lastError), "OK");
        return static_cast<void*>(ctx);
    } catch (const std::exception& e) {
        snprintf(g_lastError, sizeof(g_lastError), "yolos_create: %s", e.what());
        return nullptr;
    } catch (...) {
        snprintf(g_lastError, sizeof(g_lastError), "yolos_create: unknown exception");
        return nullptr;
    }
}

YOLOS_C_API_EXPORT int yolos_detect(YolosHandle handle,
                                      const char* imagePath,
                                      const char* outputPath,
                                      YolosResult* outResult) {
    if (!handle || !outResult) return -1;
    memset(outResult, 0, sizeof(YolosResult));

    auto* ctx = static_cast<YolosContext*>(handle);

    try {
        ctx->lastImage = cv::imread(imagePath);
        if (ctx->lastImage.empty()) {
            snprintf(outResult->errorMessage, sizeof(outResult->errorMessage),
                     "Cannot read image: %s", imagePath);
            return -1;
        }

        auto t0 = std::chrono::high_resolution_clock::now();
        ctx->lastResults = ctx->detector->detect(ctx->lastImage);
        auto t1 = std::chrono::high_resolution_clock::now();

        outResult->detectionCount = static_cast<int>(ctx->lastResults.size());
        outResult->inferenceMs = std::chrono::duration_cast<std::chrono::milliseconds>(t1 - t0).count();

        ctx->detector->drawDetections(ctx->lastImage, ctx->lastResults);

        if (outputPath && outputPath[0] != '\0') {
            cv::imwrite(outputPath, ctx->lastImage);
            strncpy(outResult->resultImagePath, outputPath, sizeof(outResult->resultImagePath) - 1);
        }

        ctx->lastResultInfo = *outResult;

    } catch (const std::exception& e) {
        snprintf(outResult->errorMessage, sizeof(outResult->errorMessage),
                 "yolos_detect: %s", e.what());
        return -2;
    } catch (...) {
        strncpy(outResult->errorMessage, "yolos_detect: unknown exception",
                sizeof(outResult->errorMessage) - 1);
        return -2;
    }

    return 0;
}

YOLOS_C_API_EXPORT int yolos_get_detection(YolosHandle handle,
                                            int index,
                                            YolosDetection* out) {
    if (!handle || !out) return -1;

    auto* ctx = static_cast<YolosContext*>(handle);

    if (index < 0 || index >= static_cast<int>(ctx->lastResults.size())) {
        return -1;
    }

    const Detection& d = ctx->lastResults[index];
    out->classId     = d.classId;
    out->confidence  = d.conf;
    out->x           = d.box.x;
    out->y           = d.box.y;
    out->width       = d.box.width;
    out->height      = d.box.height;

    return 0;
}

YOLOS_C_API_EXPORT void yolos_destroy(YolosHandle handle) {
    if (!handle) return;
    delete static_cast<YolosContext*>(handle);
}

}
