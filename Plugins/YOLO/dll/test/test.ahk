#Requires AutoHotkey v2.0

#SingleInstance Force

scriptDir  := A_ScriptDir
yoloRoot   := scriptDir "\..\.."
dllPath    := yoloRoot "\dll\yolos.dll"

argModel   := A_Args.Has(1) ? A_Args[1] : ""
argClasses := A_Args.Has(2) ? A_Args[2] : ""

class TestApp {
    __New() {
        this.logs := []
        this.results := {}
        this.resultImagePath := ""
        
        if (!argModel || !FileExist(argModel)) {
            this.ShowConfigWindow()
        } else {
            classesCsv := A_Args.Has(2) ? A_Args[2] : "person"
            this.RunTest(argModel, classesCsv)
        }
    }

    ShowConfigWindow() {
        this.cfgGui := Gui("+Owner +AlwaysOnTop", "YOLOs-DLL 测试配置")
        this.cfgGui.SetFont("s10", "Segoe UI")

        this.cfgGui.AddText("x20 y15 w600 h24 Center", "YOLOs-DLL 测试配置")

        this.cfgGui.AddText("x20 y50 w100 h22 Right", "模型文件:")
        this.modelEdit := this.cfgGui.AddEdit("x125 y48 w400 h26 vModelPath", 
            FileExist(yoloRoot "\models\YOLOv11n_voc.onnx") ? yoloRoot "\models\YOLOv11n_voc.onnx" : "")
        this.modelEdit.OnEvent("Change", (*) => this.OnModelPathChanged())
        this.cfgGui.AddButton("x535 y47 w60 h26", "浏览").OnEvent("Click", (*) => this.OnBrowseModel())

        this.cfgGui.AddText("x20 y85 w100 h22 Right", "类别列表:")
        this.classEdit := this.cfgGui.AddEdit("x125 y83 w400 h26 vClasses ReadOnly", "")
        
        this.cfgGui.AddText("x20 y120 w100 h22 Right", "目标类别:")
        this.targetCombo := this.cfgGui.AddComboBox("x125 y118 w250 vTargetClass", ["-1|全部"])

        this.cfgGui.AddText("x400 y120 w60 h22 Right", "置信度:")
        this.confEdit := this.cfgGui.AddEdit("x465 y118 w80 h26 Center vConfThresh", "0.25")

        this.startBtn := this.cfgGui.AddButton("x240 y155 w140 h32 Default", "开始测试")
        this.startBtn.OnEvent("Click", (*) => this.OnStartTest())

        cancelBtn := this.cfgGui.AddButton("x400 y155 w140 h32", "取消")
        cancelBtn.OnEvent("Click", (*) => this.cfgGui.Destroy())

        this.cfgGui.Show("w640 h205")
        
        this.LoadClassNames(this.modelEdit.Value)
    }

    OnBrowseModel() {
        path := FileSelect(1, , "选择 ONNX 模型", "ONNX Files (*.onnx)")
        if (path)
            this.modelEdit.Value := path
    }

    OnModelPathChanged() {
        this.LoadClassNames(this.modelEdit.Value)
    }

    LoadClassNames(modelPath) {
        if (!modelPath || !FileExist(modelPath)) {
            this.classEdit.Value := ""
            this.targetCombo.Delete()
            this.targetCombo.Add(["-1|全部"])
            this.targetCombo.Choose(1)
            return
        }
        
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
        this.classEdit.Value := classCsv
        
        options := ["-1|全部"]
        for i, name in classes
            options.Push(i - 1 "|" name)
        
        this.targetCombo.Delete()
        this.targetCombo.Add(options)
        this.targetCombo.Choose(1)
    }

    OnStartTest() {
        modelPath := this.modelEdit.Value
        classesCsv := this.classEdit.Value
        selectedIndex := this.targetCombo.Value
        selectedText := this.targetCombo.Text
        targetId := Integer(StrSplit(selectedText, "|")[1])
        confThresh := Float(this.confEdit.Value)
        this.cfgGui.Destroy()
        this.RunTest(modelPath, classesCsv, targetId, confThresh)
    }

    AddLog(text) {
        this.logs.Push({text: text, time: A_Now})
        if (this.resultGui && this.logEdit) {
            this.logEdit.Value .= "[" SubStr(A_Now, 9) "] " text "`n"
            textLen := StrLen(this.logEdit.Value)
            this.logEdit.SelectionStart := textLen
            this.logEdit.SelectionEnd := textLen
        }
    }

    UpdateProgress(step, status) {
        if (this.resultGui && this.progressBar) {
            this.progressBar.Value := (step / 3) * 100
            this.stepLabel.Value := "步骤 " step "/3: " status
        }
    }

    RunTest(modelPath, classesCsv, targetClassId := -1, confThresh := 0.25) {
        this.ShowResultWindow()
        
        this.AddLog("=== YOLOs-DLL 测试开始 ===")
        this.AddLog("DLL: " dllPath)
        this.AddLog("模型: " modelPath)
        this.AddLog("类别: " classesCsv)
        this.AddLog("目标ID: " targetClassId)
        this.AddLog("置信度: " confThresh)

        this.UpdateProgress(1, "加载依赖 DLL")
        this.AddLog("[1/3] 加载依赖 DLL...")

        opencvDll := "C:\opencv\build\x64\vc16\bin\opencv_world481.dll"
        ortDll := "C:\onnxruntime\lib\onnxruntime.dll"

        if (FileExist(opencvDll)) {
            DllCall("LoadLibrary", "Str", opencvDll, "Ptr")
            this.AddLog("  [OK] opencv_world481.dll")
        } else {
            this.AddLog("  [FAIL] opencv_world481.dll 不存在: " opencvDll)
        }

        if (FileExist(ortDll)) {
            DllCall("LoadLibrary", "Str", ortDll, "Ptr")
            this.AddLog("  [OK] onnxruntime.dll")
        } else {
            this.AddLog("  [FAIL] onnxruntime.dll 不存在: " ortDll)
        }

        this.AddLog("  正在加载 yolos.dll...")
        hModule := DllCall("LoadLibrary", "Str", dllPath, "Ptr")
        if (!hModule) {
            this.AddLog("  [FAIL] 加载失败! 错误: " A_LastError)
            this.Finalize(false)
            return
        }
        this.AddLog("  [OK] 句柄: 0x" Format("{:X}", hModule))

        this.UpdateProgress(2, "解析函数 & 创建检测器")
        this.AddLog("[2/3] 创建检测器...")

        fnCreate       := DllCall("GetProcAddress", "Ptr", hModule, "AStr", "YoloCreate",       "Ptr")
        fnDetectScreen := DllCall("GetProcAddress", "Ptr", hModule, "AStr", "YoloDetectScreen","Ptr")
        fnDestroy      := DllCall("GetProcAddress", "Ptr", hModule, "AStr", "YoloDestroy",      "Ptr")

        if (!fnCreate || !fnDetectScreen || !fnDestroy) {
            this.AddLog("  [FAIL] 导出函数缺失!")
            this.Finalize(false)
            return
        }

        handle := DllCall(fnCreate, "AStr", modelPath, "AStr", classesCsv, "Int", 0, "Ptr")
        if (!handle) {
            this.AddLog("  [FAIL] 创建检测器失败!")
            this.Finalize(false)
            return
        }
        this.AddLog("  [OK] 检测器就绪")

        this.UpdateProgress(3, "执行检测")
        this.AddLog("[3/3] 截屏+检测...")

        timestamp := Format("{:04}{:02}{:02}_{:02}{:02}{:02}", 
            SubStr(A_Now, 1, 4), SubStr(A_Now, 5, 2), SubStr(A_Now, 7, 2),
            SubStr(A_Now, 9, 2), SubStr(A_Now, 11, 2), SubStr(A_Now, 13, 2))
        outputPath := scriptDir "\test_result_" timestamp ".jpg"

        centerX := 0, centerY := 0

        ret := DllCall(fnDetectScreen,
            "Ptr", handle,
            "Int", 0, "Int", 0, "Int", 1920, "Int", 1080,
            "AStr", outputPath,
            "Float", confThresh, "Float", 0.45,
            "Int", targetClassId,
            "Int", 1,
            "Int*", &centerX, "Int*", &centerY, "Int")

        this.AddLog("  返回值=" ret ", 中心=(" centerX "," centerY ")")
        this.AddLog("  结果图: " outputPath)

        if (ret = 1) {
            this.AddLog("  [PASS] 检测成功!")
            this.results.success := true
            this.results.x := centerX
            this.results.y := centerY
            this.resultImagePath := outputPath
        } else if (ret = 0) {
            this.AddLog("  [INFO] 未检测到目标")
            this.results.success := false
            this.resultImagePath := outputPath
        } else {
            this.AddLog("  [ERROR] 错误码: " ret)
            this.results.success := false
        }

        this.AddLog("")
        this.AddLog("清理资源...")
        DllCall(fnDestroy, "Ptr", handle)
        DllCall("FreeLibrary", "Ptr", hModule)
        this.AddLog("  [OK] 完成")

        if (this.resultImagePath)
            this.UpdateImageDisplay()

        this.Finalize(true)
    }

    ShowResultWindow() {
        this.resultGui := Gui("+Resize", "YOLOs-DLL 测试结果")
        this.resultGui.SetFont("s10", "Consolas")

        this.resultGui.AddText("x10 y10 w780 h28 Center", "YOLOs-DLL 测试工具")

        this.stepLabel := this.resultGui.AddText("x20 y50 w300 h18", "步骤 0/3: 初始化")
        this.progressBar := this.resultGui.AddProgress("x20 y70 w760 h18", "0")

        this.logEdit := this.resultGui.AddEdit("x20 y95 w760 h260 ReadOnly Multi -Wrap VScroll")

        this.statusPanel := this.resultGui.AddText("x20 y365 w760 h28 Center", "")
        
        this.imagePanel := this.resultGui.AddPicture("x20 y400 w760 h120 Border", "")
        
        btnY := 535
        this.openResultBtn := this.resultGui.AddButton("x220 y" btnY " w150 h28", "打开结果图片")
        this.openResultBtn.OnEvent("Click", (*) => this.OpenResultImage())
        
        this.rerunBtn := this.resultGui.AddButton("x410 y" btnY " w150 h28", "重新测试")
        this.rerunBtn.OnEvent("Click", (*) => this.RerunTest())

        this.closeBtn := this.resultGui.AddButton("x600 y" btnY " w130 h28 Default", "关闭")
        this.closeBtn.OnEvent("Click", (*) => this.resultGui.Destroy())

        this.resultGui.OnEvent("Close", (*) => this.resultGui.Destroy())
        this.resultGui.Show("w800 h590")
    }

    UpdateImageDisplay() {
        if (this.resultImagePath && FileExist(this.resultImagePath)) {
            try {
                this.imagePanel.Value := this.resultImagePath
            } catch {
            }
        }
    }

    OpenResultImage() {
        if (this.resultImagePath && FileExist(this.resultImagePath))
            Run(this.resultImagePath)
    }

    RerunTest() {
        this.resultGui.Destroy()
        this.ShowConfigWindow()
    }

    Finalize(success) {
        this.progressBar.Value := 100
        
        if (success && this.results.success) {
            this.statusPanel.Value := "检测成功!  (" this.results.x ", " this.results.y ")"
        } else if (this.resultImagePath) {
            this.statusPanel.Value := "测试完成 - 点击查看结果图"
        } else {
            this.statusPanel.Value := "测试失败"
        }
        
        this.AddLog("==============================")
        this.AddLog("测试完成")
        this.AddLog("==============================")
    }
}

app := TestApp()
