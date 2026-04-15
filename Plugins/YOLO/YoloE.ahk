;************************************************************************
; * @description YOLOE 目标检测与实例分割封装类
; * 基于 RMT_YOLO.dll (ONNX Runtime + OpenCV)
; * @date 2025/04/15
; * @version 1.0.0
; ************************************************************************

class YoloE {
    ptr := 0
    dllPath := ""
    /**
     * 初始化 YOLOE 检测器
     * @param {String} rootPath 项目根目录路径
     * @param {String} modelPath ONNX 模型文件路径 (如: Plugins\YOLO\models\yoloe-26n-seg.onnx)
     * @param {Array|String} classes 类别名称数组或JSON字符串，如 ["person","car","bus"]
     * @param {Integer} useGPU 是否使用GPU (0=CPU, 1=GPU)
     * @example
     * yl := YoloE(A_ScriptDir, "Plugins\YOLO\models\yoloe-26n-seg.onnx", ["person","car"], 1)
     * results := yl.detect(matPtr, 0.35, 0.45)
     */
    __New(rootPath, modelPath, classes, useGPU := 1) {
        this.dllPath := rootPath "\Plugins\YOLO\RMT_YOLO.dll"

        static init := 0
        if (!init) {
            init := DllCall('LoadLibrary', 'str', this.dllPath, 'ptr')
            if (!init) {
                throw Error("无法加载 RMT_YOLO.dll")
            }
        }

        ; 构建类别 JSON 字符串
        classJson := ""
        if (Type(classes) == "Array") {
            items := []
            for item in classes {
                items.Push('"' item '"')
            }
            classJson := "[" items.Join(",") "]"
        } else if (Type(classes) == "String") {
            classJson := classes
        } else {
            throw Error("classes 参数必须是 Array 或 JSON 字符串")
        }

        fullPath := (InStr(modelPath, ":") || InStr(modelPath, "\\")) ? modelPath : (rootPath "\" modelPath)

        this.ptr := DllCall('RMT_YOLO\YoloeInit',
            'astr', fullPath,
            'astr', classJson,
            'int', useGPU,
            'cdecl ptr')

        if (!this.ptr) {
            throw Error("YOLOE 模型初始化失败，请检查模型文件路径: " fullPath)
        }
    }

    __Delete() => this.ptr && DllCall('RMT_YOLO\YoloeDestroy', 'ptr', this, 'Cdecl')

    /**
     * 执行目标检测
     * @param {Integer} matPtr OpenCV Mat 对象指针（BGR格式，由 CaptureWinMat 返回）
     * @param {Float} confThresh 置信度阈值 (0.0~1.0)，推荐 0.35
     * @param {Float} nmsThresh NMS 阈值 (0.0~1.0)，推荐 0.45
     * @return {Array|null} 检测结果数组，每项包含:
     *   - class_id: 类别ID (整数)
     *   - class_name: 类别名称 (字符串)
     *   - confidence: 置信度 (浮点数)
     *   - x, y, w, h: 边界框坐标和尺寸（相对于原图像素）
     *   失败返回空字符串
     */
    detect(matPtr, confThresh := 0.35, nmsThresh := 0.45) {
        if (!this.ptr || !matPtr)
            return ""

        bufSize := 65536  ; 64KB 输出缓冲区
        resultBuf := Buffer(bufSize)

        count := DllCall('RMT_YOLO\YoloeDetect',
            'ptr', this,
            'ptr', matPtr,
            'float', confThresh,
            'float', nmsThresh,
            'ptr', resultBuf,
            'int', bufSize,
            'cdecl int')

        if (count < 0)
            return ""

        jsonStr := StrGet(resultBuf, "UTF-8")
        return jsonStr == "" ? "" : JSON.Parse(jsonStr)
    }
}
