#pragma once

/**
 * @file yolos_detector_patch.hpp
 * @brief 零侵入补丁 - 纯内存初始化（与 YOLOs-CPP 官方 YOLOEDetector 相同模式）
 *
 * 设计：
 *   接受 vector<string> → 基类传 "" (安全返回空向量) → 直接覆盖 protected 成员
 *   无临时文件，无文件 I/O，纯内存操作
 */

#include "yolos/tasks/detection.hpp"

namespace yolos {
namespace det {

/// @brief DLL 专用检测器：纯内存初始化（无临时文件）
///
/// 与 YOLOs-CPP 官方 YOLOEDetector (yoloe.hpp:88-101) 使用完全相同的模式：
///   1. 基类传入空字符串 "" → utils::getClassNames("") 安全返回空向量
///   2. 构造函数体内直接覆盖 classNames_ 和 classColors_
class YolosDllDetector : public YOLODetector {
public:
    /// @brief 纯内存构造函数
    /// @param modelPath ONNX 模型路径
    /// @param classNames 类别名称向量
    /// @param useGPU 是否使用 GPU
    /// @param version YOLO 版本
    YolosDllDetector(const std::string& modelPath,
                     const std::vector<std::string>& classNames,
                     bool useGPU = false,
                     YOLOVersion version = YOLOVersion::Auto)
        : YOLODetector(modelPath, "", useGPU, version) {
        classNames_ = classNames;
        classColors_ = drawing::generateColors(classNames_);
    }
};

} // namespace det
} // namespace yolos
