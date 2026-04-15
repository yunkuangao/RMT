; YOLOE 目标检测执行工具
; 基于 RMT_YOLO.dll 的 ONNX Runtime 推理引擎

global MyYoloeDetector := ""

; 初始化 YOLOE 检测器（懒加载，首次使用时创建）
InitYoloe(modelPath, classes) {
    if (MyYoloeDetector != "" && IsObject(MyYoloeDetector))
        return true
    try {
        global MyYoloeDetector := YoloE(A_ScriptDir, modelPath, classes, 1)
        return true
    } catch as e {
        ; GPU不可用时尝试CPU模式
        try {
            global MyYoloeDetector := YoloE(A_ScriptDir, modelPath, classes, 0)
            return true
        } catch as e2 {
            return false
        }
    }
}

; 执行一次 YOLOE 检测
YoloeDetectOnce(tableItem, Data, index) {
    ; 获取坐标变量
    HasX1 := TryGetTabVarValue(&X1, tableItem, index, Data.StartPosX)
    HasY1 := TryGetTabVarValue(&Y1, tableItem, index, Data.StartPosY)
    HasX2 := TryGetTabVarValue(&X2, tableItem, index, Data.EndPosX)
    HasY2 := TryGetTabVarValue(&Y2, tableItem, index, Data.EndPosY)
    if (!HasX1 || !HasX2 || !HasY1 || !HasY2)
        return false

    ; 初始化检测器
    if (!InitYoloe(Data.ModelPath, StrSplit(Data.Classes, ",")))
        return false

    ; 截图获取 Mat 指针
    isWin := Data.SearchType == 2
    matPtr := 0

    if (isWin) {
        hwndList := GetHwndList(Data.WinInfo)
        if (hwndList.Length == 0)
            return false
        matPtr := DllCall("RMT_OpenCV.dll\CaptureWinMat", "Int", hwndList[1],
            "Int", X1, "Int", Y1, "Int", (X2 - X1), "Int", (Y2 - Y1), "Cdecl Ptr")
    } else {
        ; 屏幕截图 - 使用窗口截图方式（hwnd=0 表示全屏）
        ; 先截取全屏区域，再裁剪
        tempHwnd := DllCall("GetDesktopWindow", "Ptr")
        matPtr := DllCall("RMT_OpenCV.dll\CaptureWinMat", "Int", tempHwnd,
            "Int", X1, "Int", Y1, "Int", (X2 - X1), "Int", (Y2 - Y1), "Cdecl Ptr")
    }

    if (!matPtr)
        return false

    try {
        confThresh := Data.ConfThresh / 100.0
        nmsThresh := Data.NmsThresh / 100.0
        resultsJson := MyYoloeDetector.detect(matPtr, confThresh, nmsThresh)

        ; 释放 Mat
        DllCall("RMT_OpenCV.dll\ReleaseMat", "ptr", matPtr, "cdecl")

        if (resultsJson == "")
            return false

        results := JSON.Parse(resultsJson)
        if (!results || results.Length == 0)
            return false

        ; 过滤目标类别
        targetResults := []
        for det in results {
            if (Data.TargetClassId < 0 || det.class_id == Data.TargetClassId) {
                targetResults.Push(det)
            }
        }

        if (targetResults.Length == 0)
            return false

        ; 取第一个匹配结果（置信度最高）
        bestDet := targetResults[1]
        centerX := Integer(bestDet.x + bestDet.w / 2)
        centerY := Integer(bestDet.y + bestDet.h / 2)

        ; 处理结果
        CoordMode("Mouse", "Screen")
        SendMode("Event")
        Speed := 100 - Data.Speed

        ; 保存结果变量
        if (Data.ResultToggle) {
            resultInfo := Format("{}|{}|{}|{}", bestDet.class_name, Round(bestDet.confidence * 100),
                centerX, centerY)
            MySetGlobalVariable([Data.ResultSaveName], [resultInfo], false)
        }

        ; 保存坐标变量
        if (Data.CoordToogle) {
            MySetGlobalVariable([Data.CoordXName], [centerX], false)
            MySetGlobalVariable([Data.CoordYName], [centerY], false)
        }

        ; 坐标浮点处理
        posX := GetFloatValue(centerX, MySoftData.CoordXFloat)
        posY := GetFloatValue(centerY, MySoftData.CoordYFloat)

        ; 执行鼠标动作
        DoYoloeMouseAction(Data, posX, posY, isWin, Speed)

        ; 执行成功宏
        if (Data.TrueMacro != "") {
            OnTriggerMacroOnce(tableItem, Data.TrueMacro, index)
        }
        return true

    } catch as e {
        if (matPtr)
            DllCall("RMT_OpenCV.dll\ReleaseMat", "ptr", matPtr, "cdecl")
        return false
    }
}

; YOLOE 循环检测（带搜索次数和间隔）
DoYoloe(tableItem, Data, index) {
    HasCount := TryGetTabVarValue(&count, tableItem, index, Data.SearchCount)

    ; 设置未找到时的默认值
    if (Data.ResultToggle) {
        MySetGlobalVariable([Data.ResultSaveName], [Data.FalseValue], false)
    }

    loop count {
        ; 检查是否被终止
        if (tableItem.KilledArr[index])
            break
        ; 检查暂停
        while (tableItem.PauseArr[index] && !tableItem.KilledArr[index]) {
            Sleep(100)
        }

        found := YoloeDetectOnce(tableItem, Data, index)
        if (found)
            return

        ; 间隔等待
        HasInterval := TryGetTabVarValue(&interval, tableItem, index, Data.SearchInterval)
        FloatInterval := GetFloatTime(interval, MySoftData.PreIntervalFloat)
        Sleep(FloatInterval)
    }

    ; 未找到，执行失败宏
    if (Data.FalseMacro != "")
        OnTriggerMacroOnce(tableItem, Data.FalseMacro, index)
}

; YOLOE 鼠标动作处理
DoYoloeMouseAction(Data, posX, posY, isWin, Speed) {
    switch Data.MouseActionType {
        case 2:  ; 移动至目标
            MouseMove(posX, posY, Speed)
        case 3:  ; 移动至目标并点击
            MouseMove(posX, posY, Speed)
            Click("LButton", Data.ClickCount)
    }
}
