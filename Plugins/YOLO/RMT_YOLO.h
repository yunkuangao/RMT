#pragma once
#ifdef YOLO_EXPORTS
#define YOLO_API __declspec(dllexport)
#else
#define YOLO_API __declspec(dllimport)
#endif

// 初始化 YOLOE 检测器 (文本提示模式)
// @param modelPath: ONNX 模型文件路径
// @param classesJson: JSON 格式的类别名称数组，如 ["person","car","bus"]
// @param useGPU: 是否使用 GPU (0=CPU, 1=GPU)
// @return: 检测器实例指针，失败返回 nullptr
extern "C" YOLO_API void* __cdecl YoloeInit(
    const char* modelPath,
    const char* classesJson,
    int useGPU);

// 执行目标检测 + 实例分割
// @param instance: 检测器实例指针 (由 YoloeInit 返回)
// @param matPtr: OpenCV Mat 对象指针 (BGR 格式，由 CaptureWinMat 返回)
// @param confThresh: 置信度阈值 (0.0~1.0)，推荐 0.35
// @param nmsThresh: NMS 阈值 (0.0~1.0)，推荐 0.45
// @param outResults: 输出检测结果缓冲区 (JSON 字符串)
//   格式: [{"class_id":0,"class_name":"person","confidence":0.95,"x":100,"y":200,"w":80,"h":160},...]
// @return: 检测到的目标数量，-1 表示错误
extern "C" YOLO_API int __cdecl YoloeDetect(
    void* instance,
    void* matPtr,
    float confThresh,
    float nmsThresh,
    char* outResults,
    int outResultsSize);

// 销毁检测器实例，释放资源
extern "C" YOLO_API void __cdecl YoloeDestroy(void* instance);
