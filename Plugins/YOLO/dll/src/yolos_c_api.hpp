#pragma once

// ============================================================================
// yolos_c_api.hpp - C-style API for YOLOs-CPP DLL (AHK/ctypes compatible)
//
// Provides a plain C ABI for YOLO object detection, usable from:
//   - AutoHotkey v2 (DllCall)
//   - Python (ctypes)
//   - Any FFI-capable language
// ============================================================================

#include <cstdint>

#ifdef _WIN32
    #ifdef YOLOSCPP_BUILD_DLL
        #define YOLOS_C_API_EXPORT __declspec(dllexport)
    #else
        #define YOLOS_C_API_EXPORT __declspec(dllimport)
    #endif
#else
    #define YOLOS_C_API_EXPORT __attribute__((visibility("default")))
#endif

// ============================================================================
// Opaque handle types
// ============================================================================

using YolosHandle = void*;

// ============================================================================
// Detection result (single box)
// ============================================================================

struct YolosDetection {
    int classId;       // Class index
    float confidence;  // Confidence score 0.0~1.0
    int x;             // Top-left x
    int y;             // Top-left y
    int width;         // Box width
    int height;        // Box height
};

// ============================================================================
// Inference result summary
// ============================================================================

struct YolosResult {
    int detectionCount;              // Number of detections found
    int64_t inferenceMs;             // Inference time in milliseconds
    char resultImagePath[512];       // Output image path (if requested)
    char errorMessage[256];          // Error message on failure
};

// ============================================================================
// C API functions
// ============================================================================

extern "C" {

/// Get last error message string (thread-local)
YOLOS_C_API_EXPORT const char* yolos_get_last_error(void);

/// Create a new detector instance
/// @param modelPath Path to ONNX model file (.onnx)
/// @param labelsPath Path to labels file (one class name per line)
/// @param useGPU Use CUDA GPU for inference (0=CPU, 1=GPU)
/// @return Opaque handle, or nullptr on error
YOLOS_C_API_EXPORT YolosHandle yolos_create(const char* modelPath,
                                            const char* labelsPath,
                                            int useGPU);

/// Run detection on an image file
/// @param handle Detector handle from yolos_create()
/// @param imagePath Input image path (jpg/png/bmp etc.)
/// @param outputPath Optional output image path (drawn boxes), can be NULL
/// @param outResult Pointer to result struct to fill
/// @return 0 on success, negative on error
YOLOS_C_API_EXPORT int yolos_detect(YolosHandle handle,
                                    const char* imagePath,
                                    const char* outputPath,
                                    YolosResult* outResult);

/// Get a single detection result by index
/// @param handle Detector handle
/// @param index Detection index (0 .. detectionCount-1)
/// @param out Pointer to detection struct to fill
/// @return 0 on success, -1 if index out of range
YOLOS_C_API_EXPORT int yolos_get_detection(YolosHandle handle,
                                           int index,
                                           YolosDetection* out);

/// Destroy a detector instance and free resources
YOLOS_C_API_EXPORT void yolos_destroy(YolosHandle handle);

} // extern "C"
