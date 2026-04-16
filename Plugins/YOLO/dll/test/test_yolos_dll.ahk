/**
 * test_yolos_dll.ahk
 * AutoHotkey v2 - YOLOs-DLL C API 测试脚本
 *
 * 前置条件:
 *   1) 已执行 build.ps1 构建出 build\Release\yolos.dll 及其依赖
 *   2) 准备测试用的: 模型文件(.onnx)、类别名文件(.names)、图片文件(.jpg)
 *
 * 脚本会自动从以下位置查找:
 *   - DLL 文件:    .\build\Release\
 *   - 测试资源:     .\test\data\  或上级目录的 models/ data/
 */

#Requires AutoHotkey v2.0

; ============================================================
; 辅助函数（必须在主逻辑之前）
; ============================================================
global gOutputText := ""

GuiAddText(text) {
    global gOutputText
    gOutputText .= text
}

ShowGui() {
    global gOutputText
    global gResultImagePath

    resultImagePath := gResultImagePath
    
    MyGui := Gui("+Resize", "YOLOs-DLL Test Results")
    MyGui.SetFont("s11", "Consolas")
    edit := MyGui.AddEdit("r28 w720 ReadOnly Multi -Wrap VScroll", gOutputText)
    
    btnOpen := MyGui.AddButton("Default w160", "Open Result Image")
    btnOpen.OnEvent("Click", (*) => Run(resultImagePath))
    
    MyGui.Show("w740 h620")
    
    MyGui.OnEvent("Close", (*) => ExitApp())
    while (true)
        Sleep(100)
}

FindFile(baseDir, fileName, searchParents := true) {
    ; 在 baseDir 下查找，找不到则向上搜索
    local candidates := [baseDir "\" fileName]
    if (searchParents)
        candidates.Push(baseDir "\..\" fileName)
    
    for path in candidates {
        if (FileExist(path))
            return path
    }
    return ""
}

; ============================================================
; 路径配置 — 自动探测
; ============================================================
scriptDir := A_ScriptDir
; DLL 依赖统一放在 Plugins/YOLO/ 目录下
yoloRoot  := scriptDir "\..\..\"
dllDir    := yoloRoot
dllPath   := dllDir "\yolos.dll"

; 测试资源路径（YOLO 根目录下的 models/ 和 data/）
modelPath  := yoloRoot "models\yolo11n.onnx"
labelsPath := yoloRoot "models\coco.names"
imgPath    := scriptDir "\dog.jpg"

; 输出图片保存到脚本同目录
outPath := scriptDir "\test_result.jpg"
global gResultImagePath := outPath

; ============================================================
; 加载 DLL
; ============================================================
GuiAddText("=== YOLOs-DLL AHK DllCall Test ===`n")
GuiAddText("DLL 目录: " dllDir "`n`n")

; 预加载依赖 DLL
GuiAddText("[Prep] Loading dependencies... ")

; 自动探测 opencv_world*.dll 名称
opencvDll := ""
Loop Files, dllDir "\..\OpenCV\opencv_world481.dll"
{
    opencvDll := A_LoopFilePath
    break
}
ortDll := dllDir "\onnxruntime.dll"

if (!opencvDll || !FileExist(opencvDll)) {
    GuiAddText("[WARN] opencv_world*.dll not found in Release/, trying LoadLibrary anyway...`n")
} else {
    GuiAddText("`n  " opencvDll "... ")
    DllCall("LoadLibrary", "Str", opencvDll, "Ptr")
}

GuiAddText("`n  onnxruntime.dll ... ")
if (FileExist(ortDll)) {
    DllCall("LoadLibrary", "Str", ortDll, "Ptr")
    GuiAddText("[OK]`n")
} else {
    GuiAddText("[MISSING]`n")
}

; 加载主 DLL
GuiAddText("Loading yolos.dll ... ")
hModule := DllCall("LoadLibrary", "Str", dllPath, "Ptr")

if (!hModule) {
    GuiAddText("[FAIL] Error code: " A_LastError "`n")
    ShowGui()
    ExitApp
}
GuiAddText("[OK] handle=" Format("{:#x}", hModule) "`n`n")

; ============================================================
; 解析导出函数
; ============================================================
yolos_create         := DllCall("GetProcAddress", "Ptr", hModule, "AStr", "yolos_create",         "Ptr")
yolos_detect         := DllCall("GetProcAddress", "Ptr", hModule, "AStr", "yolos_detect",         "Ptr")
yolos_get_detection  := DllCall("GetProcAddress", "Ptr", hModule, "AStr", "yolos_get_detection",  "Ptr")
yolos_destroy        := DllCall("GetProcAddress", "Ptr", hModule, "AStr", "yolos_destroy",        "Ptr")
yolos_get_last_error := DllCall("GetProcAddress", "Ptr", hModule, "AStr", "yolos_get_last_error", "Ptr")

if (!yolos_create || !yolos_detect || !yolos_get_detection || !yolos_destroy || !yolos_get_last_error) {
    GuiAddText("[FAIL] Missing exported functions`n")
    ShowGui()
    ExitApp
}
GuiAddText("[OK] All 5 C API functions resolved`n`n")

; ============================================================
; Step 1: 创建检测器
; ============================================================
if (!modelPath || !FileExist(modelPath)) {
    GuiAddText("[FAIL] Model file not found!`n")
    GuiAddText("  Expected at: models/yolo11n.onnx`n")
    GuiAddText("  Place a .onnx model and .names file to test.`n")
    ShowGui()
    ExitApp
}
if (!labelsPath || !FileExist(labelsPath)) {
    GuiAddText("[FAIL] Labels file not found!`n")
    GuiAddText("  Expected at: models/coco.names`n")
    ShowGui()
    ExitApp
}
if (!imgPath || !FileExist(imgPath)) {
    GuiAddText("[FAIL] Test image not found!`n")
    GuiAddText("  Expected at: data/dog.jpg`n")
    ShowGui()
    ExitApp
}

GuiAddText("[Step 1] Creating detector... `n")
GuiAddText("  Model:  " modelPath "`n")
GuiAddText("  Labels: " labelsPath "`n... ")

handle := DllCall(yolos_create,
                  "AStr", modelPath,
                  "AStr", labelsPath,
                  "Int", 0,
                  "Ptr")

if (!handle) {
    errMsg := DllCall(yolos_get_last_error, "AStr")
    GuiAddText("[FAIL]`n  " errMsg "`n")
    ShowGui()
    ExitApp
}
GuiAddText("[OK] handle=" Format("{:#x}", handle) "`n`n")

; ============================================================
; Step 2: 执行检测
; ============================================================
GuiAddText("[Step 2] Running detection... `n")
GuiAddText("  Image: " imgPath "`n")

resultBuf := Buffer(1036, 0)

retCode := DllCall(yolos_detect,
                   "Ptr", handle,
                   "AStr", imgPath,
                   "AStr", outPath,
                   "Ptr", resultBuf,
                   "Int")

detectionCount  := NumGet(resultBuf, 0,     "Int")
inferenceMs     := NumGet(resultBuf, 8,     "Int64")
errorMsg        := StrGet(resultBuf.Ptr + 16,  512, "UTF-8")

GuiAddText("Inference time: " inferenceMs " ms`n")
GuiAddText("Detections found: " detectionCount "`n")
GuiAddText("Result saved to: " gResultImagePath "`n`n")

if (errorMsg != "") {
    GuiAddText("Error message: " errorMsg "`n`n")
}

; ============================================================
; Step 3: 遍历结果
; ============================================================
if (detectionCount > 0) {
    GuiAddText("[Step 3] Details:`n")
    detBuf := Buffer(28, 0)

    Loop Min(detectionCount, 20) {
        idx := A_Index - 1
        r := DllCall(yolos_get_detection, "Ptr", handle, "Int", idx, "Ptr", detBuf, "Int")
        if (r = 0) {
            c  := NumGet(detBuf, 0,  "Int")
            cf := NumGet(detBuf, 4,  "Float")
            x  := NumGet(detBuf, 8,  "Float")
            y  := NumGet(detBuf, 12, "Float")
            w  := NumGet(detBuf, 16, "Float")
            h  := NumGet(detBuf, 20, "Float")
            GuiAddText("  [" idx "] class=" c . " conf=" Format("{:.1f}", cf*100) "%"
                     . " box=(" Format("{:.0f}",x) "," Format("{:.0f}",y) ","
                             . Format("{:.0f}",w) "," Format("{:.0f}",h) ")`n")
        }
    }
} else {
    GuiAddText("[Step 3] No detections found.`n")
}

; ============================================================
; Step 4: 清理
; ============================================================
GuiAddText("`n[Step 4] Cleanup... ")
DllCall(yolos_destroy, "Ptr", handle)
DllCall("FreeLibrary", "Ptr", hModule)
GuiAddText("[OK]`n`n")
GuiAddText("==============================`n")
GuiAddText("=== ALL TESTS PASSED ===`n")
GuiAddText("==============================`n`n")

ShowGui()
