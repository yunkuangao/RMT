; YOLO 目标检测执行工具
; 基于 yolos.dll (ONNX Runtime + OpenCV) 简化 API
; 导出函数: YoloCreate / YoloDetectScreen / YoloDestroy
;
; 初始化由 RMTUtil.PluginInit() 统一完成（LoadLibrary + SetDllDirectory）

global MyYoloeHandle := 0
global _fnYoloCreate := 0
global _fnYoloDetectScreen := 0
global _fnYoloDestroy := 0

; 获取 YOLO 函数指针（仅一次）
GetYoloFuncs() {
    if (_fnYoloCreate)
        return true
    
    hModule := DllCall("GetModuleHandle", "Str", "yolos.dll", "Ptr")
    if (!hModule)
        return false
    
    global _fnYoloCreate := DllCall("GetProcAddress", "Ptr", hModule, "AStr", "YoloCreate", "Ptr")
    global _fnYoloDetectScreen := DllCall("GetProcAddress", "Ptr", hModule, "AStr", "YoloDetectScreen", "Ptr")
    global _fnYoloDestroy := DllCall("GetProcAddress", "Ptr", hModule, "AStr", "YoloDestroy", "Ptr")
    
    return (_fnYoloCreate && _fnYoloDetectScreen && _fnYoloDestroy)
}

; 初始化 YOLO 检测器（懒加载，首次使用时创建）
InitYoloe(modelPath, classesCsv) {
    if (MyYoloeHandle)
        return true
    try {
        if (!GetYoloFuncs())
            throw Error("无法获取 YOLO 导出函数")

        fullPath := (InStr(modelPath, ":") || InStr(modelPath, "\")) ? modelPath : (A_ScriptDir "\" modelPath)

        global MyYoloeHandle := DllCall(_fnYoloCreate,
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
YoloeDetectOnce(tableItem, Data, index) {
    HasX1 := TryGetTabVarValue(&X1, tableItem, index, Data.StartPosX)
    HasY1 := TryGetTabVarValue(&Y1, tableItem, index, Data.StartPosY)
    HasX2 := TryGetTabVarValue(&X2, tableItem, index, Data.EndPosX)
    HasY2 := TryGetTabVarValue(&Y2, tableItem, index, Data.EndPosY)

    if (!HasX1 || !HasX2 || !HasY1 || !HasY2) {
        MsgBox("坐标变量获取失败")
        return false
    }

    if (!InitYoloe(Data.ModelPath, Data.Classes))
        return false

    screenX := X1
    screenY := Y1
    screenW := X2 - X1
    screenH := Y2 - Y1

    try {
        confThresh := Data.ConfThresh / 100.0
        nmsThresh := Data.NmsThresh / 100.0

        centerX := 0, centerY := 0
        ret := DllCall(_fnYoloDetectScreen,
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

        CoordMode("Mouse", "Screen")
        SendMode("Event")
        Speed := 100 - Data.Speed

        if (Data.ResultToggle) {
            resultInfo := Format("{}|{}|{}", centerX, centerY)
            MySetGlobalVariable([Data.ResultSaveName], [resultInfo], false)
        }

        if (Data.CoordToogle) {
            MySetGlobalVariable([Data.CoordXName], [centerX], false)
            MySetGlobalVariable([Data.CoordYName], [centerY], false)
        }

        posX := GetFloatValue(centerX, MySoftData.CoordXFloat)
        posY := GetFloatValue(centerY, MySoftData.CoordYFloat)

        DoYoloeMouseAction(Data, posX, posY, Speed)

        if (Data.TrueMacro != "") {
            OnTriggerMacroOnce(tableItem, Data.TrueMacro, index)
        }
        return true

    } catch as e {
        MsgBox("检测异常: " e.Message)
        return false
    }
}

DoYoloe(tableItem, Data, index) {
    HasCount := TryGetTabVarValue(&count, tableItem, index, Data.SearchCount)

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

    if (Data.FalseMacro != "")
        OnTriggerMacroOnce(tableItem, Data.FalseMacro, index)
}

DoYoloeMouseAction(Data, posX, posY, Speed) {
    switch Data.MouseActionType {
        case 2:
            MouseMove(posX, posY, Speed)
        case 3:
            MouseMove(posX, posY, Speed)
            Click("LButton", Data.ClickCount)
    }
}

DestroyYoloe() {
    if (MyYoloeHandle) {
        try {
            DllCall(_fnYoloDestroy, 'ptr', MyYoloeHandle)
        } catch {
        }
        global MyYoloeHandle := 0
    }
}
