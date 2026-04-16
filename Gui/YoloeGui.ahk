#Requires AutoHotkey v2.0
#Include MacroEditGui.ahk
#Include WinRuleGui.ahk
#Include ..\Main\Util\YoloeUtil.ahk

class YoloeGui {
    __new() {
        this.ParentTile := ""
        this.Gui := ""
        this.SureBtnAction := ""
        this.RemarkCon := ""
        this.PosAction := () => this.RefreshMouseInfo()
        this.F1Action := (x1, y1, x2, y2) => this.OnF1SetAreaAction(x1, y1, x2, y2)
        this.CheckClipboardAction := () => this.CheckClipboard()
        this.Data := ""
        this.MacroGui := ""

        this.CountTogArr := []
        this.MouseSpeedArr := []
        this.MouseClickArr := []
        this.ResultTogArr := []
        this.CoordTogArr := []
        this.FalseConArr := []
    }

    ShowGui(cmd) {
        if (this.Gui != "") {
            this.Gui.Show()
        } else {
            this.AddGui()
        }
        this.Init(cmd)
        this.ToggleFunc(true)
    }


    AddGui() {
        MyGui := Gui(, this.ParentTile GetLang("YOLOE检测编辑器"))
        this.Gui := MyGui
        MyGui.SetFont("S10 W550 Q2", MySoftData.FontType)

        ; Row 1: shortcut keys
        PosX := 10
        PosY := 10
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 80), GetLang("快捷方式："))
        PosX += 80
        con := MyGui.Add("Hotkey", Format("x{} y{} w{}", PosX, PosY - 3, 70), "!l")
        con.Enabled := false

        PosX += 90
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY - 5, 80, 27), GetLang("执行指令"))
        btnCon.OnEvent("Click", (*) => this.TriggerMacro())

        PosX += 90
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 50), GetLang("备注："))
        PosX += 50
        this.RemarkCon := MyGui.Add("Edit", Format("x{} y{} w{}", PosX, PosY - 5, 150), "")

        ; Row 2: F1 / checkbox / mouse coords
        PosY += 35
        PosX := 10
        con := MyGui.Add("Edit", Format("x{} y{} w{}", PosX, PosY, 25), "F1")
        con.Enabled := false

        PosX += 30
        this.SelectToggleCon := MyGui.Add("Checkbox", Format("x{} y{} w{} h{} Left", PosX, PosY, 150, 25),
            GetLang("左键框选搜索范围"))
        this.SelectToggleCon.OnEvent("Click", (*) => this.OnClickSelectToggle())

        PosX += 160
        this.MousePosCon := MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 170, 22), GetLang("屏幕坐标：0,0"))
        PosX += 170
        this.MouseWinPosCon := MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 170, 22), GetLang("窗口坐标：0,0"))

        ; === Left column: Model Config GroupBox ===
        PosY += 35
        SplitPosY := PosY
        PosX := 10
        MyGui.Add("GroupBox", Format("x{} y{} w{} h{}", PosX, PosY, 340, 115), GetLang("模型配置"))

        PosY += 22
        PosX := 15
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("模型文件："))
        PosX += 65
        this.ModelPathCon := MyGui.Add("Edit", Format("x{} y{} Center", PosX, PosY - 3, 180))
        PosX += 185
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY - 5, 55, 27), GetLang("浏览"))
        btnCon.OnEvent("Click", (*) => this.OnClickModelBrowseBtn())

        PosY += 30
        PosX := 15
        ; 目标类别 ID：-1=全部, 0=person, 2=car, ... (对应 coco.names 行号)
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("目标类别ID："))
        PosX += 80
        this.TargetClassIdCon := MyGui.Add("Edit", Format("x{} y{} Center", PosX, PosY - 3, 60), "-1")

        ; === Right column: Detection Params GroupBox ===
        PosX := 360
        PosY := SplitPosY
        MyGui.Add("GroupBox", Format("x{} y{} w{} h{}", PosX, PosY, 330, 115), GetLang("检测参数"))

        PosY += 22
        PosX := 365
        this.ConfThreshCon := MyGui.Add("Edit", Format("x{} y{} Center", PosX, PosY - 3, 60), "35")

        ; NMS 阈值隐藏，使用内部默认值 0.45

        PosY += 32
        PosX := 365
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 75), GetLang("搜索类型："))
        PosX += 75
        this.SearchTypeCon := MyGui.Add("DropDownList", Format("x{} y{} Center", PosX, PosY - 3, 120),
            GetLangArr(["屏幕检测", "窗口检测"]))
        this.SearchTypeCon.OnEvent("Change", (*) => this.OnChangeSearchType())
        this.SearchTypeCon.Value := 1

        PosY += 32
        PosX := 365
        this.WinInfoLabelCon := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 75), GetLang("窗口信息:"))
        PosX += 78
        this.WinInfoCon := MyGui.Add("Edit", Format("x{} y{}", PosX, PosY - 3, 155), "")
        PosX += 158
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY - 5, 45, 27), GetLang("编辑"))
        btnCon.OnEvent("Click", (*) => this.OnClickWinEditBtn())

        ; === Left column: Search Area GroupBox ===
        PosY := SplitPosY + 125
        PosX := 10
        MyGui.Add("GroupBox", Format("x{} y{} w{} h{}", PosX, PosY, 340, 72), GetLang("搜索范围"))

        PosY += 22
        PosX := 15
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("起始坐标X："))
        PosX += 80
        this.StartPosXCon := MyGui.Add("ComboBox", Format("x{} y{} Center", PosX, PosY - 3, 80))

        PosX := 175
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("起始坐标Y："))
        PosX += 80
        this.StartPosYCon := MyGui.Add("ComboBox", Format("x{} y{} Center", PosX, PosY - 3, 80))

        PosY += 30
        PosX := 15
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("终止坐标X："))
        PosX += 80
        this.EndPosXCon := MyGui.Add("ComboBox", Format("x{} y{} Center", PosX, PosY - 3, 80))

        PosX := 175
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("终止坐标Y："))
        PosX += 80
        this.EndPosYCon := MyGui.Add("ComboBox", Format("x{} y{} Center", PosX, PosY - 3, 80))

        ; === Right column: Search Settings GroupBox ===
        PosY := SplitPosY + 125
        PosX := 360
        MyGui.Add("GroupBox", Format("x{} y{} w{} h{}", PosX, PosY, 330, 72), GetLang("搜索设置"))

        PosY += 22
        PosX := 365
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 80), GetLang("搜索次数："))
        PosX += 82
        this.SearchCountCon := MyGui.Add("ComboBox", Format("x{} y{} Center", PosX, PosY - 3, 80))

        PosX += 88
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 80), GetLang("每次间隔："))
        this.CountTogArr.Push(this.SearchCountCon)
        PosX += 68
        this.SearchIntervalCon := MyGui.Add("Edit", Format("x{} y{} Center", PosX, PosY - 3, 60), "1000")
        this.CountTogArr.Push(this.SearchIntervalCon)

        PosY += 30
        PosX := 365
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 80), GetLang("鼠标动作："))
        PosX += 82
        this.MouseActionTypeCon := MyGui.Add("DropDownList", Format("x{} y{} Center", PosX, PosY - 3, 140),
            GetLangArr(["无动作", "移动至目标", "移动至目标点击"]))
        this.MouseActionTypeCon.Value := 1
        this.MouseActionTypeCon.OnEvent("Change", (*) => this.OnChangeMouseAction())
        PosX += 230
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 50), GetLang("速度："))
        PosX += 48
        this.SpeedCon := MyGui.Add("Edit", Format("x{} y{} Center", PosX, PosY - 3, 40), "90")
        this.MouseSpeedArr.Push(this.SpeedCon)
        PosX += 48
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 50), GetLang("次数："))
        PosX += 46
        this.ClickCountCon := MyGui.Add("Edit", Format("x{} y{} Center", PosX, PosY - 3, 40), "1")
        this.MouseClickArr.Push(this.ClickCountCon)

        ; === Left column: Found macro ===
        PosY := SplitPosY + 205
        PosX := 10
        MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 170, 20), GetLang("找到后的指令：（可选）"))
        PosX += 180
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY - 5, 50, 25), GetLang("编辑"))
        btnCon.OnEvent("Click", (*) => this.OnEditFoundMacroBtnClick())
        PosY += 20
        PosX := 10
        this.TrueMacroCon := MyGui.Add("Edit", Format("x{} y{} w{} h{}", PosX, PosY, 330, 55), "")

        ; === Left column: Target Point Save GroupBox ===
        PosY += 62
        PosX := 10
        MyGui.Add("GroupBox", Format("x{} y{} w{} h{}", PosX, PosY, 340, 75), GetLang("目标点保存"))

        PosY += 20
        PosX := 15
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("开关"))
        PosX += 36
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("坐标X变量名"))
        this.CoordTogArr.Push(MyGui.Add("Text", Format("x{} y{}", PosX, PosY)))
        PosX += 95
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("坐标Y变量名"))
        this.CoordTogArr.Push(MyGui.Add("Text", Format("x{} y{}", PosX, PosY)))

        PosY += 25
        PosX := 18
        this.CoordToogleCon := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 30))
        this.CoordToogleCon.OnEvent("Click", (*) => this.OnChangeCoordToggle())
        this.CoordXNameCon := MyGui.Add("ComboBox", Format("x{} y{} R5", PosX + 34, PosY - 3, 90), [])
        this.CoordTogArr.Push(this.CoordXNameCon)
        this.CoordYNameCon := MyGui.Add("ComboBox", Format("x{} y{} R5", PosX + 130, PosY - 3, 90), [])
        this.CoordTogArr.Push(this.CoordYNameCon)

        ; === Right column: Not Found macro ===
        PosY := SplitPosY + 205
        PosX := 360
        MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 170, 20), GetLang("未找到后的指令：（可选）"))
        PosX += 180
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY - 5, 50, 25), GetLang("编辑"))
        btnCon.OnEvent("Click", (*) => this.OnEditUnFoundMacroBtnClick())
        PosY += 20
        PosX := 360
        this.FalseMacroCon := MyGui.Add("Edit", Format("x{} y{} w{} h{}", PosX, PosY, 330, 55), "")
        this.FalseConArr.Push(this.FalseMacroCon)

        ; === Right column: Result Save GroupBox ===
        PosY := SplitPosY + 267
        PosX := 360
        MyGui.Add("GroupBox", Format("x{} y{} w{} h{}", PosX, PosY, 330, 75), GetLang("结果保存"))

        PosY += 20
        PosX := 365
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("开关"))
        PosX += 42
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("变量名"))
        this.ResultTogArr.Push(MyGui.Add("Text", Format("x{} y{}", PosX, PosY)))
        PosX += 105
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("真值"))
        this.ResultTogArr.Push(MyGui.Add("Text", Format("x{} y{}", PosX, PosY)))
        PosX += 62
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("假值"))
        this.ResultTogArr.Push(MyGui.Add("Text", Format("x{} y{}", PosX, PosY)))

        PosY += 25
        PosX := 370
        this.ResultToggleCon := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 30))
        this.ResultToggleCon.OnEvent("Click", (*) => this.OnChangeResultToggle())
        this.ResultSaveNameCon := MyGui.Add("ComboBox", Format("x{} y{} R5", PosX + 33, PosY - 3, 110), [])
        this.ResultTogArr.Push(this.ResultSaveNameCon)
        this.TrueValueCon := MyGui.Add("Edit", Format("x{} y{} Center", PosX + 148, PosY - 4, 55), "1")
        this.ResultTogArr.Push(this.TrueValueCon)
        this.FalseValueCon := MyGui.Add("Edit", Format("x{} y{} Center", PosX + 210, PosY - 4, 55), "0")
        this.ResultTogArr.Push(this.FalseValueCon)

        ; === OK Button ===
        PosY := SplitPosY + 357
        PosX := 300
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY, 100, 40), GetLang("确定"))
        btnCon.OnEvent("Click", (*) => this.OnClickSureBtn())
        MyGui.OnEvent("Close", (*) => this.ToggleFunc(false))
        MyGui.Show(Format("w{} h{}", 700, 640))
    }

    Init(cmd) {
        cmdArr := cmd != "" ? StrSplit(cmd, "_") : []
        this.SerialStr := cmdArr.Length >= 1 ? cmdArr[1] : GetCMDSerialStr("YOLOE检测")
        this.RemarkCon.Value := cmdArr.Length >= 2 ? cmdArr[2] : ""
        this.Data := GetMacroCMDData(this.SerialStr)
        this.DLVariableArr := GetGuiVarArr()
        if (!this.CheckIfDataValid())
            return

        ; 初始化变量下拉框
        this.InitVariableDLs()

        ; 加载数据
        this.ModelPathCon.Value := this.Data.ModelPath
        this.ConfThreshCon.Value := this.Data.ConfThresh
        ; NMS 阈值隐藏，使用默认值
        ; GPU 默认使用 CPU
        this.SearchTypeCon.Value := this.Data.SearchType
        this.WinInfoCon.Value := this.Data.WinInfo

        ; 加载目标类别 ID
        this.TargetClassIdCon.Value := this.Data.TargetClassId
        this.StartPosXCon.Text := this.Data.StartPosX
        this.StartPosYCon.Text := this.Data.StartPosY
        this.EndPosXCon.Text := this.Data.EndPosX
        this.EndPosYCon.Text := this.Data.EndPosY
        this.SearchCountCon.Text := this.Data.SearchCount == -1 ? GetLang("无限") : this.Data.SearchCount
        this.SearchIntervalCon.Value := this.Data.SearchInterval
        this.MouseActionTypeCon.Value := this.Data.MouseActionType
        this.SpeedCon.Value := this.Data.Speed
        this.ClickCountCon.Value := this.Data.ClickCount
        this.TrueMacroCon.Value := GetLangMacro(this.Data.TrueMacro, 1)
        this.FalseMacroCon.Value := GetLangMacro(this.Data.FalseMacro, 1)
        this.ResultToggleCon.Value := this.Data.ResultToggle
        this.ResultSaveNameCon.Text := this.Data.ResultSaveName
        this.TrueValueCon.Value := this.Data.TrueValue
        this.FalseValueCon.Value := this.Data.FalseValue
        this.CoordToogleCon.Value := this.Data.CoordToogle
        this.CoordXNameCon.Text := this.Data.CoordXName
        this.CoordYNameCon.Text := this.Data.CoordYName

        this.OnChangeSearchType()
        this.OnChangeMouseAction()
    }

    InitVariableDLs() {
        dlArr := this.DLVariableArr
        this.StartPosXCon.Delete()
        this.StartPosXCon.Add(dlArr)
        this.StartPosYCon.Delete()
        this.StartPosYCon.Add(dlArr)
        this.EndPosXCon.Delete()
        this.EndPosXCon.Add(dlArr)
        this.EndPosYCon.Delete()
        this.EndPosYCon.Add(dlArr)
        this.SearchCountCon.Delete()
        this.SearchCountCon.Add([GetLang("无限"), dlArr*])
        this.ResultSaveNameCon.Delete()
        this.ResultSaveNameCon.Add(dlArr)
        this.CoordXNameCon.Delete()
        this.CoordXNameCon.Add(dlArr)
        this.CoordYNameCon.Delete()
        this.CoordYNameCon.Add(dlArr)
    }

    UpdateTargetClassDL() {
        ; 保留接口供 ClassesCon Change 事件调用（当前为空实现）
    }

    GetCommandStr() {
        textOnly := RegExReplace(this.Data.SerialStr, "\d+")
        numbersOnly := RegExReplace(this.Data.SerialStr, "\D+")
        CommandStr := Format("{}{}", GetLang(textOnly), numbersOnly)
        CommandStr := CorrectRemark(CommandStr, this.RemarkCon.Value)
        return CommandStr
    }

    CheckIfDataValid() {
        if (!ObjHasOwnProp(this.Data, "ModelPath")) {
            MsgBox(GetLang("这条指令不完整，请删除"))
            return false
        }
        return true
    }

    CheckIfValid() {
        if (this.ModelPathCon.Value == "" || !FileExist(this.ModelPathCon.Value)) {
            MsgBox(GetLang("请选择有效的模型文件"))
            return false
        }

        confVal := this.ConfThreshCon.Value
        if (!IsNumber(confVal) || confVal < 0 || confVal > 100) {
            MsgBox(GetLang("置信度阈值必须在0~100之间"))
            return false
        }

        isWin := this.SearchTypeCon.Value == 2
        if (isWin && Trim(this.WinInfoCon.Value) == "") {
            MsgBox(GetLang("窗口检测模式下，窗口信息不能为空"))
            return false
        }

        countStr := this.SearchCountCon.Text
        if (countStr != GetLang("无限") && (!IsNumber(countStr) || Number(countStr) <= 0)) {
            MsgBox(GetLang("搜索次数必须大于0"))
            return false
        }

        if (this.ResultToggleCon.Value && !CheckVarNameIfValid(this.ResultSaveNameCon.Text))
            return false
        if (this.CoordToogleCon.Value && !CheckVarNameIfValid(this.CoordXNameCon.Text))
            return false

        return true
    }

    ToggleFunc(state) {
        MacroAction := (*) => this.TriggerMacro()
        if (state) {
            SetTimer this.PosAction, 100
            Hotkey("!l", MacroAction, "On")
            Hotkey("F1", (*) => this.OnF1(), "On")
            Hotkey("F2", (*) => this.OnScreenShotBtnClick(), "On")
        } else {
            SetTimer this.PosAction, 0
            Hotkey("!l", MacroAction, "Off")
            Hotkey("F1", (*) => this.OnF1(), "Off")
            Hotkey("F2", (*) => this.OnScreenShotBtnClick(), "Off")
        }
    }

    RefreshMouseInfo() {
        CoordMode("Mouse", "Screen")
        MouseGetPos &mouseX, &mouseY
        this.MousePosCon.Value := Format("{}{},{}", GetLang("屏幕坐标："), mouseX, mouseY)
        PosArr := GetCurWinPos()
        this.MouseWinPosCon.Value := Format("{}{},{}", GetLang("窗口坐标："), PosArr[1], PosArr[2])
    }

    OnClickModelBrowseBtn(*) {
        path := FileSelect(1, , GetLang("选择YOLOE模型文件"), "ONNX Files (*.onnx)")
        if (path != "") {
            this.ModelPathCon.Value := path
            this.Data.ModelPath := path
        }
    }

    OnClickWinEditBtn(*) {
        MyFrontInfoGui.HideAction := () => this.ToggleFunc(true)
        MyFrontInfoGui.ShowGui(this.WinInfoCon)
    }

    OnClickSureBtn() {
        valid := this.CheckIfValid()
        if (!valid) {
            return
        }
        this.SaveData()
        action := this.SureBtnAction
        action(this.GetCommandStr())
        this.ToggleFunc(false)
        this.Gui.Hide()
    }

    TriggerMacro() {
        valid := this.CheckIfValid()
        if (!valid) {
            return
        }
        this.SaveData()
        OnTriggerSepcialItemMacro(this.GetCommandStr())
    }

    OnChangeSearchType(*) {
        isWin := this.SearchTypeCon.Value == 2
        this.WinInfoLabelCon.Visible := isWin
        this.WinInfoCon.Visible := isWin
        ; 找到 WinInfoCon 右侧的按钮（通过遍历查找）
        for ctrl in this.Gui {
            if (ctrl == this.WinInfoCon)
                continue
        }
    }

    OnChangeMouseAction(*) {
        hasMove := this.MouseActionTypeCon.Value != 1
        this.SetConArrState(this.MouseSpeedArr, hasMove)
        hasClick := this.MouseActionTypeCon.Value == 3
        this.SetConArrState(this.MouseClickArr, hasClick)
    }

    OnChangeResultToggle(*) {
        this.SetConArrState(this.ResultTogArr.Slice(1), this.ResultToggleCon.Value)
    }

    OnChangeCoordToggle(*) {
        this.SetConArrState(this.CoordTogArr.Slice(1), this.CoordToogleCon.Value)
    }

    SetConArrState(ConArr, state) {
        for Value in ConArr {
            Value.Enabled := state
        }
    }

    OnClickSelectToggle() {
        state := this.SelectToggleCon.Value
        if (state == 1)
            TogSelectArea(true, this.F1Action)
        else
            TogSelectArea(false)
    }

    OnF1() {
        this.SelectToggleCon.Value := 1
        TogSelectArea(true, this.F1Action)
    }

    OnF1SetAreaAction(x1, y1, x2, y2) {
        this.SelectToggleCon.Value := 0
        curType := this.SearchTypeCon.Value
        isWin := curType == 2
        Point1 := isWin ? GetWinPos(x1, y1) : [x1, y1]
        Point2 := isWin ? GetWinPos(x2, y2) : [x2, y2]
        this.StartPosXCon.Text := Point1[1]
        this.StartPosYCon.Text := Point1[2]
        this.EndPosXCon.Text := Point2[1]
        this.EndPosYCon.Text := Point2[2]
    }

    OnSetSearchArea(x1, y1, x2, y2) {
        this.SelectToggleCon.Value := 0
        this.StartPosXCon.Text := x1
        this.StartPosYCon.Text := y1
        this.EndPosXCon.Text := x2
        this.EndPosYCon.Text := y2
    }

    OnScreenShotBtnClick() {
        ; 截图功能暂不用于YOLOE，保留接口
    }

    CheckClipboard() {
        if DllCall("IsClipboardFormatAvailable", "uint", 8) {
            CurrentDateTime := FormatTime(, "HHmmss")
            filePath := A_WorkingDir "\Setting\" MySoftData.CurSettingName "\Images\ScreenShot\" CurrentDateTime ".png"
            SaveClipToBitmap(filePath)
        }
    }

    OnEditFoundMacroResult(CommandStr) {
        CommandStr := GetLangMacro(CommandStr, 1)
        this.TrueMacroCon.Value := CommandStr
    }

    OnEditUnFoundMacroBtnClick(CommandStr) {
        CommandStr := GetLangMacro(CommandStr, 1)
        this.FalseMacroCon.Value := CommandStr
    }

    OnEditFoundMacroBtnClick() {
        if (this.MacroGui == "") {
            this.MacroGui := MacroEditGui()
            this.MacroGui.DLVariableArr := this.DLVariableArr
            this.MacroGui.SureFocusCon := this.MousePosCon
            ParentTile := StrReplace(this.Gui.Title, GetLang("编辑器"), "")
            this.MacroGui.ParentTile := ParentTile "-"
        }
        this.MacroGui.SureBtnAction := (command) => this.OnEditFoundMacroResult(command)
        this.MacroGui.ShowGui(this.TrueMacroCon.Value, false)
    }

    SaveData() {
        data := this.Data
        data.ModelPath := this.ModelPathCon.Value
        ; 目标类别 ID：直接读取数字
        data.TargetClassId := Integer(this.TargetClassIdCon.Value)
        ; 从 .names 文件自动加载类别列表（替代硬编码）
        data.Classes := LoadClassNamesFromModel(data.ModelPath)
        if (data.Classes == "")
            data.Classes := "person,car"  ; 兜底默认值
        data.ConfThresh := this.ConfThreshCon.Value
        ; NMS 阈值隐藏，使用默认值 45
        data.NmsThresh := 45
        ; GPU 默认使用 CPU
        data.UseGPU := 0
        data.SearchType := this.SearchTypeCon.Value
        data.WinInfo := this.WinInfoCon.Value
        data.StartPosX := this.StartPosXCon.Text
        data.StartPosY := this.StartPosYCon.Text
        data.EndPosX := this.EndPosXCon.Text
        data.EndPosY := this.EndPosYCon.Text
        data.SearchCount := this.SearchCountCon.Text == GetLang("无限") ? -1 : this.SearchCountCon.Text
        data.SearchInterval := this.SearchIntervalCon.Value
        data.MouseActionType := this.MouseActionTypeCon.Value
        data.Speed := this.SpeedCon.Value
        data.ClickCount := this.ClickCountCon.Value
        data.TrueMacro := GetLangMacro(this.TrueMacroCon.Value, 2)
        data.FalseMacro := GetLangMacro(this.FalseMacroCon.Value, 2)
        data.ResultToggle := this.ResultToggleCon.Value
        data.ResultSaveName := GetVarName(this.ResultSaveNameCon.Text)
        data.TrueValue := this.TrueValueCon.Value
        data.FalseValue := this.FalseValueCon.Value
        data.CoordToogle := this.CoordToogleCon.Value
        data.CoordXName := this.CoordXNameCon.Text
        data.CoordYName := this.CoordYNameCon.Text

        if (data.ResultToggle)
            MySoftData.GlobalVariMap[data.ResultSaveName] := true
        if (data.CoordToogle) {
            MySoftData.GlobalVariMap[data.CoordXName] := true
            MySoftData.GlobalVariMap[data.CoordYName] := true
        }

        SaveMacroCMDData(data)
    }
}
