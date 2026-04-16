; YOLO 目标检测执行工具
; 基于 yolos.dll (ONNX Runtime + OpenCV) 简化 API
; 导出函数: YoloCreate / YoloDetectScreen / YoloDestroy
; 特点: 截屏+推理+过滤+选最佳目标 全部在 DLL 内完成，不依赖 RMT_OpenCV.dll

global MyYoloeHandle := 0
global MyYoloeModule := 0

; 初始化 YOLO 检测器（懒加载，首次使用时创建）
InitYoloe(modelPath, classesCsv) {
    if (MyYoloeHandle)
        return true
    try {
        fullPath := (InStr(modelPath, ":") || InStr(modelPath, "\")) ? modelPath : (A_ScriptDir "\" modelPath)

        global MyYoloeHandle := DllCall('yolos\YoloCreate',
            'astr', fullPath,
            'astr', classesCsv,
            'int', 0,
            'ptr')

        if (!MyYoloeHandle)
            throw Error("YOLO 初始化失败`n模型: " fullPath)
        return true
    } catch as e {
        MsgBox("YOLO 初始化异常: " e.Message "`n模型: " modelPath)
        return false
    }
}

; 从 .names 文件加载类别列表
LoadClassNamesFromModel(modelPath) {
    namesPath := StrReplace(modelPath, ".onnx", ".names")
    classes := []
    
    if (FileExist(namesPath)) {
        try {
            file := FileOpen(namesPath, "r", "UTF-8")
            if (file) {
                while (!file.AtEOF) {
                    line := file.ReadLine()
                    line := Trim(line)
                    if (line != "")
                        classes.Push(line)
                }
                file.Close()
            }
        } catch {
        }
    }
    
    classCsv := ""
    for i, name in classes
        classCsv .= (i > 1 ? ", " : "") name
    return classCsv
}

; 执行一次 YOLO 检测（返回最佳目标中心坐标）
; 使用新的 YoloDetectScreen API：截屏+检测一步完成
YoloeDetectOnce(tableItem, Data, index) {
    ; 获取坐标变量
    HasX1 := TryGetTabVarValue(&X1, tableItem, index, Data.StartPosX)
    HasY1 := TryGetTabVarValue(&Y1, tableItem, index, Data.StartPosY)
    HasX2 := TryGetTabVarValue(&X2, tableItem, index, Data.EndPosX)
    HasY2 := TryGetTabVarValue(&Y2, tableItem, index, Data.EndPosY)

    if (!HasX1 || !HasX2 || !HasY1 || !HasY2) {
        MsgBox("坐标变量获取失败")
        return false
    }

    ; 初始化检测器
    if (!InitYoloe(Data.ModelPath, Data.Classes))
        return false

    ; 计算截图区域
    screenX := X1
    screenY := Y1
    screenW := X2 - X1
    screenH := Y2 - Y1

    try {
        confThresh := Data.ConfThresh / 100.0
        nmsThresh := Data.NmsThresh / 100.0

        ; 调用新 API：截屏 + 推理 + 返回最佳目标中心坐标
        ; saveResult=0: RMT 项目不需要保存图片，跳过绘图开销
        centerX := 0, centerY := 0
        ret := DllCall('yolos\YoloDetectScreen',
            'ptr', MyYoloeHandle,
            'int', screenX, 'int', screenY, 'int', screenW, 'int', screenH,
            'astr', "",
            'float', confThresh,
            'float', nmsThresh,
            'int', Data.TargetClassId,
            'int', 0,
            'int*', &centerX,
            'int*', &centerY,
            'int')

        if (ret != 1)
            return false

        ; 处理结果
        CoordMode("Mouse", "Screen")
        SendMode("Event")
        Speed := 100 - Data.Speed

        ; 保存结果变量
        if (Data.ResultToggle) {
            resultInfo := Format("{}|{}|{}", centerX, centerY)
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
        DoYoloeMouseAction(Data, posX, posY, Speed)

        ; 执行成功宏
        if (Data.TrueMacro != "") {
            OnTriggerMacroOnce(tableItem, Data.TrueMacro, index)
        }
        return true

    } catch as e {
        MsgBox("检测异常: " e.Message)
        return false
    }
}

; YOLO 循环检测（带搜索次数和间隔）
DoYoloe(tableItem, Data, index) {
    HasCount := TryGetTabVarValue(&count, tableItem, index, Data.SearchCount)

    ; 设置未找到时的默认值
    if (Data.ResultToggle) {
        MySetGlobalVariable([Data.ResultSaveName], [Data.FalseValue], false)
    }

    loop count {
        if (tableItem.KilledArr[index])
            break
        while (tableItem.PauseArr[index] && !tableItem.KilledArr[index]) {
            Sleep(100)
        }

        found := YoloeDetectOnce(tableItem, Data, index)
        if (found)
            return

        HasInterval := TryGetTabVarValue(&interval, tableItem, index, Data.SearchInterval)
        FloatInterval := GetFloatTime(interval, MySoftData.PreIntervalFloat)
        Sleep(FloatInterval)
    }

    ; 未找到，执行失败宏
    if (Data.FalseMacro != "")
        OnTriggerMacroOnce(tableItem, Data.FalseMacro, index)
}

; YOLO 鼠标动作处理
DoYoloeMouseAction(Data, posX, posY, Speed) {
    switch Data.MouseActionType {
        case 2:  ; 移动至目标
            MouseMove(posX, posY, Speed)
        case 3:  ; 移动至目标并点击
            MouseMove(posX, posY, Speed)
            Click("LButton", Data.ClickCount)
    }
}

; 销毁 YOLO 检测器（程序退出时调用）
DestroyYoloe() {
    if (MyYoloeHandle) {
        try {
            DllCall('yolos\YoloDestroy', 'ptr', MyYoloeHandle)
        } catch {
        }
        global MyYoloeHandle := 0
    }
}
