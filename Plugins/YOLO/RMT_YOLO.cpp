#include "RMT_YOLO.h"
#include <opencv2/opencv.hpp>
#include <onnxruntime_cxx_api.h>
#include <vector>
#include <string>
#include <fstream>
#include <algorithm>
#include <numeric>
#include <cstring>

// ==================== 数据结构 ====================

struct DetectionResult {
    int classId;
    float confidence;
    float x, y, w, h;       // 边界框 (归一化坐标 0~1)
    std::vector<float> maskData;  // 分割掩码数据 ( flattened )
    int maskWidth;
    int maskHeight;
};

class YoloeDetector {
public:
    YoloeDetector(const std::string& modelPath, const std::vector<std::string>& classNames, bool useGPU);
    ~YoloeDetector();

    // 执行检测，返回检测结果数量
    int detect(const cv::Mat& bgrImage, float confThresh, float nmsThresh,
               std::vector<DetectionResult>& results);

    const std::vector<std::string>& getClassNames() const { return m_classNames; }

private:
    Ort::Env m_env;
    Ort::SessionOptions m_sessionOptions;
    Ort::Session* m_session = nullptr;
    std::vector<std::string> m_classNames;
    std::vector<const char*> m_inputNames;
    std::vector<const char*> m_outputNames;
    std::vector<std::vector<int64_t>> m_inputShapes;

    bool m_useGPU = false;

    void preprocess(const cv::Mat& image, cv::Mat& outBlob, float& scale, int& padW, int& padH);
    void postprocess(const std::vector<Ort::Value>& outputTensors,
                     float confThresh, float nmsThresh,
                     float scale, int padW, int padH, int imgW, int imgH,
                     std::vector<DetectionResult>& results);
};

// ==================== NMS 实现 ====================

static float iou(const DetectionResult& a, const DetectionResult& b) {
    float interX1 = std::max(a.x, b.x);
    float interY1 = std::max(a.y, b.y);
    float interX2 = std::min(a.x + a.w, b.x + b.w);
    float interY2 = std::min(a.y + a.h, b.y + b.h);

    float interArea = std::max(0.0f, interX2 - interX1) * std::max(0.0f, interY2 - interY1);
    float unionArea = a.w * a.h + b.w * b.h - interArea;
    if (unionArea <= 0) return 0.0f;
    return interArea / unionArea;
}

static std::vector<size_t> nms(std::vector<DetectionResult>& detections, float iouThresh) {
    // 按置信度降序排序
    std::vector<size_t> indices(detections.size());
    std::iota(indices.begin(), indices.end(), 0);
    std::sort(indices.begin(), indices.end(), [&](size_t a, size_t b) {
        return detections[a].confidence > detections[b].confidence;
        });

    std::vector<bool> suppressed(detections.size(), false);
    std::vector<size_t> keep;

    for (size_t i = 0; i < indices.size(); ++i) {
        size_t idx = indices[i];
        if (suppressed[idx]) continue;
        keep.push_back(idx);
        for (size_t j = i + 1; j < indices.size(); ++j) {
            size_t idx2 = indices[j];
            if (suppressed[idx2]) continue;
            if (iou(detections[idx], detections[idx2]) > iouThresh)
                suppressed[idx2] = true;
        }
    }
    return keep;
}

// ==================== YoloeDetector 实现 ====================

YoloeDetector::YoloeDetector(const std::string& modelPath,
                             const std::vector<std::string>& classNames, bool useGPU)
    : m_env(ORT_LOGGING_LEVEL_WARNING, "Yoloe")
    , m_classNames(classNames)
    , m_useGPU(useGPU) {

    m_sessionOptions.SetIntraOpNumThreads(2);
    m_sessionOptions.SetGraphOptimizationLevel(GraphOptimizationLevel::ORT_ENABLE_ALL);
    m_sessionOptions.SetExecutionMode(ExecutionMode::ORT_SEQUENTIAL);
    m_sessionOptions.DisablePerSessionThreads();

    if (useGPU) {
        try {
            OrtCUDAProviderOptions cudaOpts;
            m_sessionOptions.AppendExecutionProvider_CUDA(cudaOpts);
        } catch (...) {
            // GPU 不可用时回退到 CPU
        }
    }

    m_session = new Ort::Session(m_env, modelPath.c_str(), m_sessionOptions);

    // 获取输入/输出信息
    Ort::AllocatorWithDefaultOptions allocator;
    size_t numInputs = m_session->GetInputCount();
    size_t numOutputs = m_session->GetOutputCount();

    m_inputNames.resize(numInputs);
    m_outputNames.resize(numOutputs);
    m_inputShapes.resize(numInputs);

    for (size_t i = 0; i < numInputs; ++i) {
        auto name = m_session->GetInputNameAllocated(i, allocator);
        m_inputNames[i] = name.get();
        auto info = m_session->GetInputTypeInfo(i).GetTensorTypeAndShapeInfo();
        m_inputShapes[i] = info.GetShape();
    }
    for (size_t i = 0; i < numOutputs; ++i) {
        auto name = m_session->GetOutputNameAllocated(i, allocator);
        m_outputNames[i] = name.get();
    }
}

YoloeDetector::~YoloeDetector() {
    delete m_session;
}

void YoloeDetector::preprocess(const cv::Mat& image, cv::Mat& outBlob,
                                float& scale, int& padW, int& padH) {
    int targetSize = 640;
    int imgW = image.cols;
    int imgH = image.rows;

    scale = std::min(float(targetSize) / imgW, float(targetSize) / imgH);
    int newW = int(imgW * scale);
    int newH = int(imgH * scale);

    cv::Mat resized;
    cv::resize(image, resized, cv::Size(newW, newH));

    padW = (targetSize - newW) / 2;
    padH = (targetSize - newH) / 2;

    outBlob = cv::Mat::zeros(targetSize, targetSize, CV_8UC3);
    resized.copyTo(outBlob(cv::Rect(padW, padH, newW, newH)));

    outBlob.convertTo(outBlob, CV_32F, 1.0 / 255.0);
    // HWC -> CHW
    std::vector<cv::Mat> channels;
    cv::split(outBlob, channels);
    cv::vconcat(channels, outBlob);
}

int YoloeDetector::detect(const cv::Mat& bgrImage, float confThresh, float nmsThresh,
                          std::vector<DetectionResult>& results) {
    results.clear();
    if (bgrImage.empty() || !m_session) return -1;

    float scale;
    int padW, padH;
    cv::Mat blob;
    preprocess(bgrImage, blob, scale, padW, padH);

    // 创建输入张量: [1, 3, 640, 640]
    std::vector<int64_t> inputShape = {1, 3, 640, 640};
    size_t tensorSize = 1 * 3 * 640 * 640 * sizeof(float);
    Ort::MemoryInfo memoryInfo = Ort::MemoryInfo::CreateCpu(
        OrtArenaAllocator, OrtMemTypeDefault);

    Ort::Value inputTensor = Ort::Value::CreateTensor<float>(
        memoryInfo, reinterpret_cast<float*>(blob.data), tensorSize, inputShape.data(), inputShape.size());

    // 运行推理
    try {
        auto outputTensors = m_session->Run(
            Ort::RunOptions{nullptr},
            m_inputNames.data(), &inputTensor, 1,
            m_outputNames.data(), m_outputNames.size());

        postprocess(outputTensors, confThresh, nmsThresh,
                    scale, padW, padH, bgrImage.cols, bgrImage.height(), results);

    } catch (Ort::Exception& e) {
        return -1;
    }

    return static_cast<int>(results.size());
}

void YoloeDetector::postprocess(const std::vector<Ort::Value>& outputTensors,
                                float confThresh, float nmsThresh,
                                float scale, int padW, int padH,
                                int imgW, int imgH,
                                std::vector<DetectionResult>& results) {
    // YOLOE 输出格式:
    // output[0]: 检测结果 [N, 5+num_classes] (x_center, y_center, w, h, obj_conf, cls_conf...)
    // output[1]: 原始检测 (proto 输出等)

    std::vector<DetectionResult> allDets;

    for (size_t oi = 0; oi < outputTensors.size(); ++oi) {
        auto& tensor = outputTensors[oi];
        auto info = tensor.GetTensorTypeAndShapeInfo();
        auto shape = info.GetShape();
        auto* data = tensor.GetTensorMutableData<float>();

        if (shape.empty()) continue;
        if (shape.size() == 2 && shape[1] >= 5 + m_classNames.size()) {
            // 标准检测输出: [N, 4+1+numClasses]
            int numDets = static_cast<int>(shape[0]);
            int rowSize = static_cast<int>(shape[1]);
            int numClasses = rowSize - 4 - 1;  // x,y,w,h,objConf,classConfs...

            for (int i = 0; i < numDets; ++i) {
                float* row = data + i * rowSize;
                float objConf = row[4];

                // 找最大类别置信度
                float maxClsConf = 0;
                int maxClsId = 0;
                for (int c = 0; c < numClasses; ++c) {
                    if (row[5 + c] > maxClsConf) {
                        maxClsConf = row[5 + c];
                        maxClsId = c;
                    }
                }

                float finalConf = objConf * maxClsConf;
                if (finalConf < confThresh) continue;

                // 将中心点+宽高 转为左上角+宽高，并从 640 映射回原图尺寸
                float cx = (row[0] - padW) / scale;
                float cy = (row[1] - padH) / scale;
                float rw = row[2] / scale;
                float rh = row[3] / scale;

                DetectionResult det;
                det.classId = maxClsId;
                det.confidence = finalConf;
                det.x = cx - rw / 2;
                det.y = cy - rh / 2;
                det.w = rw;
                det.h = rh;

                allDets.push_back(det);
            }
        } else if (shape.size() == 3 && shape[2] >= 5 + m_classNames.size()) {
            // 备选格式: [batch, N, 4+1+numClasses]
            int numDets = static_cast<int>(shape[1]);
            int rowSize = static_cast<int>(shape[2]);
            int numClasses = rowSize - 4 - 1;

            for (int i = 0; i < numDets; ++i) {
                float* row = data + i * rowSize;
                float objConf = row[4];

                float maxClsConf = 0;
                int maxClsId = 0;
                for (int c = 0; c < numClasses; ++c) {
                    if (row[5 + c] > maxClsConf) {
                        maxClsConf = row[5 + c];
                        maxClsId = c;
                    }
                }

                float finalConf = objConf * maxClsConf;
                if (finalConf < confThresh) continue;

                float cx = (row[0] - padW) / scale;
                float cy = (row[1] - padH) / scale;
                float rw = row[2] / scale;
                float rh = row[3] / scale;

                DetectionResult det;
                det.classId = maxClsId;
                det.confidence = finalConf;
                det.x = cx - rw / 2;
                det.y = cy - rh / 2;
                det.w = rw;
                det.h = rh;

                allDets.push_back(det);
            }
        }
    }

    // 应用 NMS
    auto keepIndices = nms(allDets, nmsThresh);
    for (auto idx : keepIndices) {
        results.push_back(allDets[idx]);
    }
}

// ==================== JSON 工具函数 ====================

static std::string buildResultsJson(const std::vector<DetectionResult>& results,
                                    const std::vector<std::string>& classNames) {
    std::string json = "[";
    for (size_t i = 0; i < results.size(); ++i) {
        const auto& r = results[i];
        char buf[512];
        std::string cname = (r.classId >= 0 && r.classId < (int)classNames.size())
                            ? classNames[r.classId] : "unknown";
        // 转义 JSON 特殊字符
        std::string safeCname;
        for (char c : cname) {
            switch (c) {
                case '"': safeCname += "\\\""; break;
                case '\\': safeCname += "\\\\"; break;
                default: safeCname += c;
            }
        }
        snprintf(buf, sizeof(buf),
                 "{\"class_id\":%d,\"class_name\":\"%s\",\"confidence\":%.4f,\"x\":%.1f,\"y\":%.1f,\"w\":%.1f,\"h\":%.1f}",
                 r.classId, safeCname.c_str(), r.confidence, r.x, r.y, r.w, r.h);
        json += buf;
        if (i + 1 < results.size()) json += ",";
    }
    json += "]";
    return json;
}

// 解析简单的 JSON 数组字符串（仅支持 ["a","b","c"] 格式）
static std::vector<std::string> parseJsonArray(const char* jsonStr) {
    std::vector<std::string> result;
    if (!jsonStr || jsonStr[0] != '[') return result;
    const char* p = jsonStr + 1;
    while (*p && *p != ']') {
        while (*p && (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r')) p++;
        if (*p != '"') break;
        p++; // skip opening quote
        std::string s;
        while (*p && *p != '"') {
            if (*p == '\\' && *(p+1)) { p++; s += *p; }
            else s += *p;
            p++;
        }
        if (*p == '"') p++; // skip closing quote
        result.push_back(s);
        while (*p && (*p == ',' || *p == ' ' || *p == '\t' || *p == '\n' || *p == '\r')) p++;
    }
    return result;
}

// ==================== 导出函数实现 ====================

extern "C" YOLO_API void* __cdecl YoloeInit(const char* modelPath, const char* classesJson, int useGPU) {
    if (!modelPath || !classesJson) return nullptr;

    try {
        auto classNames = parseJsonArray(classesJson);
        if (classNames.empty()) return nullptr;

        auto* detector = new YoloeDetector(std::string(modelPath), classNames, useGPU != 0);
        return detector;
    } catch (...) {
        return nullptr;
    }
}

extern "C" YOLO_API int __cdecl YoloeDetect(void* instance, void* matPtr,
                                            float confThresh, float nmsThresh,
                                            char* outResults, int outResultsSize) {
    if (!instance || !matPtr || !outResults || outResultsSize <= 0) return -1;

    try {
        auto* detector = static_cast<YoloeDetector*>(instance);
        auto* mat = static_cast<cv::Mat*>(matPtr);

        std::vector<DetectionResult> results;
        int count = detector->detect(*mat, confThresh, nmsThresh, results);

        if (count >= 0) {
            std::string json = buildResultsJson(results, detector->getClassNames());
            strncpy_s(outResults, outResultsSize, json.c_str(), _TRUNCATE);
        }
        return count;
    } catch (...) {
        return -1;
    }
}

extern "C" YOLO_API void __cdecl YoloeDestroy(void* instance) {
    if (instance) {
        delete static_cast<YoloeDetector*>(instance);
    }
}
