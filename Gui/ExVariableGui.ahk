#Requires AutoHotkey v2.0

class ExVariableGui {
    __new() {
        this.ParentTile := ""
        this.Gui := ""
        this.SureBtnAction := ""
        this.VariableObjArr := []
        this.RemarkCon := ""
        this.SetAreaAction := (x1, y1, x2, y2) => this.OnSetSearchArea(x1, y1, x2, y2)

        this.IsIgnoreExistCon := ""
        this.ToggleConArr := []
        this.VariableConArr := []
        this.SelectToggleCon := ""
        this.ExtractStrCon := ""
        this.ExtractTypeCon := ""
        this.StartPosXCon := ""
        this.StartPosYCon := ""
        this.EndPosXCon := ""
        this.EndPosYCon := ""
        this.SearchCountCon := ""
        this.SearchIntervalCon := ""
        this.OCRTypeCon := ""
        this.ProgressBarTipCon := ""
        this.Data := ""
    }

    ShowGui(cmd) {
        if (this.Gui != "") {
            this.Gui.Show()
        }
        else {
            this.AddGui()
        }

        this.Init(cmd)
        this.ToggleFunc(true)
    }

    AddGui() {
        MyGui := Gui(, this.ParentTile GetLang("变量提取编辑器"))
        this.Gui := MyGui
        MyGui.SetFont("S10 W550 Q2", MySoftData.FontType)

        PosX := 10
        PosY := 10
        this.FocusCon := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 80, 20), GetLang("快捷方式:"))
        PosX += 80
        con := MyGui.Add("Hotkey", Format("x{} y{} w{}", PosX, PosY - 3, 70), "!l")
        con.Enabled := false

        PosX += 90
        btnCon := MyGui.Add("Button", Format("x{} y{} w{}", PosX, PosY - 5, 80), GetLang("执行指令"))
        btnCon.OnEvent("Click", (*) => this.TriggerMacro())

        PosX += 90
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 50), GetLang("备注:"))
        PosX += 50
        this.RemarkCon := MyGui.Add("Edit", Format("x{} y{} w{}", PosX, PosY - 5, 150), "")

        PosY += 30
        PosX := 20
        con := MyGui.Add("Edit", Format("x{} y{} w{}", PosX, PosY, 25), "F1")
        con.Enabled := false

        PosX += 30
        this.SelectToggleCon := MyGui.Add("Checkbox", Format("x{} y{} w{} h{} Left", PosX, PosY, 150, 25),
        GetLang("左键框选搜索范围"))
        this.SelectToggleCon.OnEvent("Click", (*) => this.OnClickSelectToggle())

        PosX += 200
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY + 3, 110), GetLang("文本识别模型:"))
        PosX += 110
        this.OCRTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{} Center", PosX, PosY - 2, 130), GetLangArr([
            "中文",
            "英文"]))
        this.OCRTypeCon.Value := 1

        PosX := 10
        PosY += 30
        MyGui.Add("GroupBox", Format("x{} y{} w{} h{}", PosX, PosY, 310, 90), GetLang("搜索范围:"))

        PosY += 30
        PosX := 20
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 75), GetLang("起始坐标X:"))
        PosX += 75
        this.StartPosXCon := MyGui.Add("Edit", Format("x{} y{} w{} Center", PosX, PosY - 5, 50))

        PosX := 180
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 75), GetLang("起始坐标Y:"))
        PosX += 75
        this.StartPosYCon := MyGui.Add("Edit", Format("x{} y{} w{} Center", PosX, PosY - 5, 50))

        PosX := 350
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 75), GetLang("搜索次数:"))
        PosX += 75
        this.SearchCountCon := MyGui.Add("ComboBox", Format("x{} y{} w{} Center", PosX, PosY - 5, 55))

        PosY += 30
        PosX := 20
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 75), GetLang("终止坐标X:"))
        PosX += 75
        this.EndPosXCon := MyGui.Add("Edit", Format("x{} y{} w{} Center", PosX, PosY - 5, 50))

        PosX := 180
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 75), GetLang("终止坐标Y:"))
        PosX += 75
        this.EndPosYCon := MyGui.Add("Edit", Format("x{} y{} w{} Center", PosX, PosY - 5, 50))

        PosX := 350
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 75), GetLang("每次间隔:"))
        this.SearchIntervalCon := MyGui.Add("Edit", Format("x{} y{} w{} Center", PosX + 75, PosY - 5, 55))

        PosY += 35
        PosX := 10
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 550),
        Format("{}`n{}`n{}", GetLang("提取文本：空内容时，屏幕/剪切板所有文本信息保存到变量中"), GetLang("提取文本：&&x表示数字变量，&&c表示文本变量"), GetLang(
            "提取文本：形如**坐标(&&x,&&x)**可以提取**坐标(10.5,8.6)**中的10.5和8.6到变量1和变量2")))

        PosY += 65
        PosX := 10
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 75), GetLang("提取文本："))
        this.ExtractStrCon := MyGui.Add("Edit", Format("x{} y{} w{}", PosX + 75, PosY - 5, 250), "")
        this.ExtractTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX + 345, PosY - 5, 80), GetLangArr([
            "屏幕",
            "剪切板",
            "进度条"]))
        this.ExtractTypeCon.Value := 1
        this.ExtractTypeCon.OnEvent("Change", (*) => this.OnExtractTypeChange())

        ; 添加进度条提示文本
        PosY += 25
        this.ProgressBarTipCon := MyGui.Add("Text", Format("x{} y{} w{} cRed", PosX, PosY, 550), "")

        PosX := 20
        PosY += 30
        this.IsIgnoreExistCon := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 150), GetLang("变量存在忽略操作"))

        PosX := 20
        PosY += 30
        MyGui.Add("Text", Format("x{} y{} h{}", PosX, PosY, 20), GetLang("开关      变量名"))
        PosX += 260
        MyGui.Add("Text", Format("x{} y{} h{}", PosX, PosY, 20), GetLang("开关      变量名"))

        PosX := 20
        PosY += 20
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY + 3), "1.")
        PosX += 20
        con := MyGui.Add("Checkbox", Format("x{} y{} w{} h{} Center", PosX, PosY + 3, 30, 20), "")
        this.ToggleConArr.Push(con)

        PosX += 35
        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5 Center", PosX, PosY - 2, 100), [])
        this.VariableConArr.Push(con)

        PosX += 200
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY + 3), "2.")
        PosX += 20
        con := MyGui.Add("Checkbox", Format("x{} y{} w{} h{} Center", PosX, PosY + 3, 30, 20), "")
        this.ToggleConArr.Push(con)

        PosX += 35
        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5 Center", PosX, PosY - 2, 100), [])
        this.VariableConArr.Push(con)

        PosX := 20
        PosY += 30
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY + 3), "3.")
        PosX += 20
        con := MyGui.Add("Checkbox", Format("x{} y{} w{} h{} Center", PosX, PosY + 3, 30, 20), "")
        this.ToggleConArr.Push(con)

        PosX += 35
        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5 Center", PosX, PosY - 2, 100), [])
        this.VariableConArr.Push(con)

        PosX += 200
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY + 3), "4.")
        PosX += 20
        con := MyGui.Add("Checkbox", Format("x{} y{} w{} h{} Center", PosX, PosY + 3, 30, 20), "")
        this.ToggleConArr.Push(con)

        PosX += 35
        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5 Center", PosX, PosY - 2, 100), [])
        this.VariableConArr.Push(con)

        PosY += 40
        PosX := 250
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{} Center", PosX, PosY, 100, 40), GetLang("确定"))
        btnCon.OnEvent("Click", (*) => this.OnClickSureBtn())

        MyGui.OnEvent("Close", (*) => this.ToggleFunc(false))
        MyGui.Show(Format("w{} h{}", 600, 460))
    }

    Init(cmd) {
        cmdArr := cmd != "" ? StrSplit(cmd, "_") : []
        this.SerialStr := cmdArr.Length >= 2 ? cmdArr[2] : GetSerialStr("ExVariable")
        this.RemarkCon.Value := cmdArr.Length >= 3 ? cmdArr[3] : ""
        this.Data := this.GetExVariableData(this.SerialStr)

        loop 4 {
            this.ToggleConArr[A_Index].Value := this.Data.ToggleArr[A_Index]
            this.VariableConArr[A_Index].Delete()
            this.VariableConArr[A_Index].Add(RemoveInVariable(this.VariableObjArr))
            this.VariableConArr[A_Index].Text := this.Data.VariableArr[A_Index]
        }
        this.IsIgnoreExistCon.Value := this.Data.IsIgnoreExist
        this.ExtractStrCon.Value := this.Data.ExtractStr
        this.ExtractTypeCon.Value := this.Data.ExtractType
        this.OCRTypeCon.Value := this.Data.OCRType
        this.StartPosXCon.Value := this.Data.StartPosX
        this.StartPosYCon.Value := this.Data.StartPosY
        this.EndPosXCon.Value := this.Data.EndPosX
        this.EndPosYCon.Value := this.Data.EndPosY
        this.SearchCountCon.Delete()
        this.SearchCountCon.Add([GetLang("无限")])
        this.SearchCountCon.Text := this.Data.SearchCount == -1 ? GetLang("无限") : this.Data.SearchCount
        this.SearchIntervalCon.Value := this.Data.SearchInterval
        
        ; 初始化进度条提示状态
        this.OnExtractTypeChange()
    }

    ToggleFunc(state) {
        MacroAction := (*) => this.TriggerMacro()
        if (state) {
            Hotkey("!l", MacroAction, "On")
            Hotkey("F1", (*) => this.OnF1(), "On")
        }
        else {
            Hotkey("!l", MacroAction, "Off")
            Hotkey("F1", (*) => this.OnF1(), "Off")
        }
    }

    OnClickSureBtn() {
        valid := this.CheckIfValid()
        if (!valid)
            return
        this.SaveExVariableData()
        this.ToggleFunc(false)
        CommandStr := this.GetCommandStr()
        action := this.SureBtnAction
        action(CommandStr)
        this.Gui.Hide()
    }

    OnClickSelectToggle() {
        state := this.SelectToggleCon.Value
        if (state == 1)
            TogSelectArea(true, this.SetAreaAction)
        else
            TogSelectArea(false)
    }

    OnF1() {
        this.SelectToggleCon.Value := 1
        TogSelectArea(true, this.SetAreaAction)
    }

    OnSetSearchArea(x1, y1, x2, y2) {
        this.SelectToggleCon.Value := 0
        this.StartPosXCon.Value := x1
        this.StartPosYCon.Value := y1
        this.EndPosXCon.Value := x2
        this.EndPosYCon.Value := y2
    }

    CheckIfValid() {
        if (!InStr(this.ExtractStrCon.Value, "&x") && !InStr(this.ExtractStrCon.Value, "&c")) {
            if (this.ExtractStrCon.Value != "") {
                MsgBox(GetLang("提取文本：不包含&x 或 &c 无法提取内容到变量中"))
                return false
            }
        }

        loop 4 {
            if (this.ToggleConArr[A_Index].Value) {
                if (IsNumber(this.VariableConArr[A_Index].Text)) {
                    MsgBox(Format(GetLang("{}. 变量名不规范：变量名不能是纯数字"), A_Index))
                    return false
                }
            }
        }

        return true
    }

    TriggerMacro() {
        this.SaveExVariableData()
        CommandStr := this.GetCommandStr()
        tableItem := MySoftData.SpecialTableItem
        tableItem.KilledArr[1] := false
        tableItem.PauseArr[1] := 0
        tableItem.ActionCount[1] := 0
        tableItem.VariableMapArr[1] := Map()
        tableItem.index := 1

        this.TestExVariable(this.Data)
    }

    TestExVariable(Data) {
        X1 := Data.StartPosX
        Y1 := Data.StartPosY
        X2 := Data.EndPosX
        Y2 := Data.EndPosY
        if (Data.ExtractType == 1) {
            TextObjs := GetScreenTextObjArr(X1, Y1, X2, Y2, Data.OCRType)
            TextObjs := TextObjs == "" ? [] : TextObjs
        }
        else if (Data.ExtractType == 3) {
            ; 进度条分析
            TextObjs := []
            progressResult := this.ExtractProgressBar(X1, Y1, X2, Y2)
            if (progressResult.percentage >= 0) {
                obj := Object()
                obj.Text := progressResult.percentage
                TextObjs.Push(obj)
            }
        }
        else {
            TextObjs := []
            if (!IsClipboardText())
                return

            obj := Object()
            obj.Text := A_Clipboard
            TextObjs.Push(obj)
        }

        allText := ""
        for _, value in TextObjs {
            allText .= value.text "`n"
        }
        allText := Trim(allText)

        NameArr := []
        ValueArr := []
        ExtractStr := this.GetReplaceVarText(Data.ExtractStr)
        for _, value in TextObjs {
            VariableValueArr := ExtractNumbers(value.Text, ExtractStr)
            VariableValueArr := ExtractStr == "" && allText != "" ? [allText] : VariableValueArr
            if (VariableValueArr == "")
                continue

            loop VariableValueArr.Length {
                if (Data.ToggleArr[A_Index]) {
                    NameArr.Push(Data.VariableArr[A_Index])
                    ValueArr.Push(VariableValueArr[A_Index])
                }
            }
            break
        }

        if (NameArr.Length == 0) {
            MsgBox(GetLang("变量提取失败"))
        }
        else {
            ; 保存变量到全局变量系统
            MySetGlobalVariable(NameArr, ValueArr, Data.IsIgnoreExist)
            
            tipStr := GetLang("已提取以下变量") "`n"
            loop NameArr.Length {
                tipStr .= NameArr[A_Index] " = " ValueArr[A_Index] "`n"
            }
            MsgBox(tipStr)
        }
    }

    GetCommandStr() {
        CommandStr := Format("{}_{}", GetLang("变量提取"), this.Data.SerialStr)
        Remark := CorrectRemark(this.RemarkCon.Value)
        if (Remark != "") {
            CommandStr .= "_" Remark
        }
        return CommandStr
    }

    GetExVariableData(SerialStr) {
        saveStr := IniRead(ExVariableFile, IniSection, SerialStr, "")
        if (!saveStr) {
            data := ExVariableData()
            data.SerialStr := SerialStr
            return data
        }

        data := JSON.parse(saveStr, , false)
        return data
    }

    SaveExVariableData() {
        this.Data.ExtractStr := this.ExtractStrCon.Value
        this.Data.ExtractType := this.ExtractTypeCon.Value
        this.Data.OCRType := this.OCRTypeCon.Value
        this.Data.StartPosX := this.StartPosXCon.Value
        this.Data.StartPosY := this.StartPosYCon.Value
        this.Data.EndPosX := this.EndPosXCon.Value
        this.Data.EndPosY := this.EndPosYCon.Value
        this.Data.SearchCount := this.SearchCountCon.Text == GetLang("无限") ? -1 : this.SearchCountCon.Text
        this.Data.SearchInterval := this.SearchIntervalCon.Value
        this.Data.IsIgnoreExist := this.IsIgnoreExistCon.Value
        loop 4 {
            this.Data.ToggleArr[A_Index] := this.ToggleConArr[A_Index].Value
            this.Data.VariableArr[A_Index] := this.VariableConArr[A_Index].Text
        }

        ; 添加全局变量，方便下拉选取
        loop 4 {
            if (this.Data.ToggleArr[A_Index])
                MySoftData.GlobalVariMap[this.Data.VariableArr[A_Index]] := true
        }

        saveStr := JSON.stringify(this.Data, 0)
        IniWrite(saveStr, ExVariableFile, IniSection, this.Data.SerialStr)
        if (MySoftData.DataCacheMap.Has(this.Data.SerialStr)) {
            MySoftData.DataCacheMap.Delete(this.Data.SerialStr)
        }
    }

    GetReplaceVarText(text) {
        matches := []  ; 初始化空数组
        pos := 1  ; 从字符串开头开始搜索

        while (pos := RegExMatch(text, "\{(.*?)\}", &match, pos)) {
            matches.Push(match[1])  ; 把花括号内的内容存入数组
            pos += match.Len  ; 移动到匹配结束位置，继续搜索
        }

        Content := text
        for index, value in matches {
            hasValue := this.TryGetVariableValue(&variValue, value, false)
            if (hasValue)
                Content := StrReplace(Content, "{" value "}", variValue)
        }
        return Content
    }

    TryGetVariableValue(&Value, variableName, variTip := true) {
        if (IsNumber(variableName)) {
            Value := variableName
            return true
        }

        if (variableName == GetLang("当前鼠标坐标X") || variableName == GetLang("当前鼠标坐标Y")) {
            CoordMode("Mouse", "Screen")
            MouseGetPos &mouseX, &mouseY
            Value := variableName == GetLang("当前鼠标坐标X") ? mouseX : mouseY
            return true
        }

        GlobalVariableMap := MySoftData.VariableMap
        if (GlobalVariableMap.Has(variableName)) {
            Value := GlobalVariableMap[variableName]
            return true
        }

        if (variTip)
            ShowNoVariableTip(variableName)
        return false
    }

    ; 提取类型变化事件处理
    OnExtractTypeChange() {
        extractType := this.ExtractTypeCon.Value
        
        if (extractType == 3) {
            ; 进度条模式，显示提示
            this.ProgressBarTipCon.Value := "进度条：尽量框选最小范围，最好是确定像素，值为0-100"
            ; 禁用OCR选择（进度条不需要OCR）
            this.OCRTypeCon.Enabled := false
            ; 清空提取文本（进度条不需要提取规则）
            this.ExtractStrCon.Value := ""
        } else {
            ; 其他模式，隐藏提示
            this.ProgressBarTipCon.Value := ""
            ; 启用OCR选择
            this.OCRTypeCon.Enabled := true
        }
    }

    ; 进度条提取方法
    ExtractProgressBar(X1, Y1, X2, Y2) {
        try {
            ; 使用全局GDI+实例（已由RMTUtil.ahk初始化）
            
            ; 获取屏幕截图
            hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
            hbm := CreateDIBSection(X2-X1, Y2-Y1, hdc)
            hdcBitmap := DllCall("CreateCompatibleDC", "Ptr", hdc, "Ptr")
            obm := DllCall("SelectObject", "Ptr", hdcBitmap, "Ptr", hbm, "Ptr")
            DllCall("BitBlt", "Ptr", hdcBitmap, "Int", 0, "Int", 0, "Int", X2-X1, "Int", Y2-Y1, "Ptr", hdc, "Int", X1, "Int", Y1, "UInt", 0x00CC0020)
            bitmap := Gdip_CreateBitmapFromHBITMAP(hbm)
            
            ; 清理资源
            DllCall("SelectObject", "Ptr", hdcBitmap, "Ptr", obm)
            DllCall("DeleteObject", "Ptr", hbm)
            DllCall("DeleteDC", "Ptr", hdcBitmap)
            DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
            
            if (!bitmap) {
                return {percentage: -1, error: "无法创建位图"}
            }
            
            ; 调用进度条分析（因为ProgressBarAnalyzer已经在RMT.ahk中包含）
            result := MyAnalyzeProgressBar(bitmap)
            
            ; 清理位图
            Gdip_DisposeImage(bitmap)
            
            return result
            
        } catch as e {
            return {percentage: -1, error: "进度条分析失败: " e.Message}
        }
    }
}
