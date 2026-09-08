#Requires AutoHotkey v2.0

; =====================================================================
; 等待编辑器（§16）—— UiWindow 基类迁移版（P0.9 验证窗口）
; 详见《deliverables/统一UI管理器设计方案.md》：
;   - 骨架（ShowGui 五步 / 关闭三路径 / 模态恢复 / 防重入）由 UiWindow 提供
;   - 子类只写：Name/Title/Build/Events/OnInit/AfterShow/OnValidate/OnSave
; 公开接口保持：ShowGui(cmd) / SureBtnAction / OwnerHwnd / ParentTile
; 19 种等待类型共用「检测间隔 + 轮询」骨架，参数区按类型显隐
; =====================================================================

class WaitGui extends UiWindow {
    __new() {
        super.__new()
        this.Data := ""
        this.SerialStr := ""
        this.DLVariableArr := []
        ; 类型中文键（执行端 WaitData.WaitType 数字对应）
        this.WaitTypeKeys := ["等待变量值", "等待按键按下", "等待按键松开", "等待屏幕变化", "等待鼠标移动",
            "等待鼠标停止移动", "等待剪切板变化", "等待进程存在", "等待进程关闭", "等待窗口存在",
            "等待窗口激活", "等待窗口屏幕变化", "等待窗口大小变化", "等待窗口关闭", "等待窗口最小化",
            "等待文件存在", "等待文件删除", "等待文件变化", "等待日期"]
    }

    ; ---- 基类钩子实现 ----
    Name() => "WaitGui"
    Title() => GetLang("等待编辑器")

    Events() {
        return [
            {ctrl: "WaitTypeCon", ev: "SelectionChanged", handler: ObjBindMethod(this, "OnTypeChange")},
            {ctrl: "BtnWinEdit", ev: "Click", handler: ObjBindMethod(this, "OnClickWinEdit")},
            {ctrl: "BtnFileBrowse", ev: "Click", handler: ObjBindMethod(this, "OnClickFileBrowse")}
        ]
    }

    Build(body) {
        ; body 已由基类建好：Row(1) Grid + Margin("10,8")，业务只往里加内容
        body.Rows("34", "Auto", "40")
        body.Cols("*")

        ; 行0：备注 + 等待类型（弹性：备注输入吸收余宽，防长文本/大字号溢出）
        row0 := body.Add("Grid").Grid_Row(0).VerticalAlignment("Center")
        row0.Cols("Auto", "*", "Auto", "Auto")
        row0.Add("TextBlock").Grid_Column(0).Text(GetLang("备注：")).VerticalAlignment("Center").Margin("0,0,4,0")
        UILayout.Input(row0.Add("TextBox").Name("RemarkCon").Grid_Column(1)
            .MaxWidth("240").HorizontalAlignment("Stretch"), UILayout.CtrlH.Input)
        row0.Add("TextBlock").Grid_Column(2).Text(GetLang("等待类型：")).VerticalAlignment("Center").Margin("16,0,4,0")
        wt := row0.Add("ComboBox").Name("WaitTypeCon").Grid_Column(3).Width(160)
            .Height(UILayout.CtrlH.Row).MinHeight(UILayout.CtrlH.Row)
        for t in GetLangArr(this.WaitTypeKeys)
            wt.Add("ComboBoxItem").Content(t)

        ; 行1：参数 GroupBox（各类型面板显隐切换）
        pg := body.Add("GroupBox").Grid_Row(1).Header(GetLang("等待参数："))
            .BorderBrush("{DynamicResource ControlBorder}").BorderThickness("1").Foreground("{DynamicResource TextMain}").Margin("0,6,0,2")
        pStack := pg.Add("StackPanel").Margin("10,8")

        ; 变量值面板：变量名 + 期望值（双字段弹性行）
        vp := UILayout.FormRow2(pStack, "VarPanel", GetLang("变量名："), GetLang("期望值："))
        vp.Add("ComboBox").Name("VarNameCon").Grid_Column(1).Height(UILayout.CtrlH.Input).MinHeight(UILayout.CtrlH.Input)
            .MaxWidth("240").HorizontalAlignment("Stretch").IsEditable("True")
        vp.Add("ComboBox").Name("VarValCon").Grid_Column(3).Height(UILayout.CtrlH.Input).MinHeight(UILayout.CtrlH.Input)
            .MaxWidth("240").HorizontalAlignment("Stretch").IsEditable("True")

        ; 按键面板
        kp := UILayout.FormRow(pStack, "KeyPanel", GetLang("按键：")).Visibility("Collapsed")
        UILayout.Input(kp.Add("TextBox").Name("KeyCon").Grid_Column(1)
            .MaxWidth("260").HorizontalAlignment("Stretch"), UILayout.CtrlH.Input)

        ; 范围面板：起始X/Y、终止X/Y（两行双字段）
        rp := pStack.Add("Grid").Name("RangePanel").Visibility("Collapsed")
        rp.Rows("Auto", "Auto")
        rangeRowA := UILayout.FormRow2(rp, "", GetLang("起始坐标X："), GetLang("起始坐标Y："), 12)
        rangeRowA.Grid_Row(0)
        rangeRowA.Add("ComboBox").Name("StartPosX").Grid_Column(1).Height(UILayout.CtrlH.Input).MinHeight(UILayout.CtrlH.Input)
            .MaxWidth("200").HorizontalAlignment("Stretch").IsEditable("True")
        rangeRowA.Add("ComboBox").Name("StartPosY").Grid_Column(3).Height(UILayout.CtrlH.Input).MinHeight(UILayout.CtrlH.Input)
            .MaxWidth("200").HorizontalAlignment("Stretch").IsEditable("True")
        rangeRowB := UILayout.FormRow2(rp, "", GetLang("终止坐标X："), GetLang("终止坐标Y："), 12)
        rangeRowB.Grid_Row(1).Margin("0,6,0,0")
        rangeRowB.Add("ComboBox").Name("EndPosX").Grid_Column(1).Height(UILayout.CtrlH.Input).MinHeight(UILayout.CtrlH.Input)
            .MaxWidth("200").HorizontalAlignment("Stretch").IsEditable("True")
        rangeRowB.Add("ComboBox").Name("EndPosY").Grid_Column(3).Height(UILayout.CtrlH.Input).MinHeight(UILayout.CtrlH.Input)
            .MaxWidth("200").HorizontalAlignment("Stretch").IsEditable("True")

        ; 进程面板
        pp := UILayout.FormRow(pStack, "ProcPanel", GetLang("进程名：")).Visibility("Collapsed")
        UILayout.Input(pp.Add("TextBox").Name("ProcCon").Grid_Column(1)
            .MaxWidth("320").HorizontalAlignment("Stretch"), UILayout.CtrlH.Input)

        ; 窗口面板：信息 + 编辑按钮
        wp := pStack.Add("Grid").Name("WinPanel").Visibility("Collapsed")
        wp.Cols("Auto", "*", "Auto")
        wp.Add("TextBlock").Grid_Column(0).Text(GetLang("窗口信息：")).VerticalAlignment("Center").Margin("0,0,4,0")
        UILayout.Input(wp.Add("TextBox").Name("WinInfoCon").Grid_Column(1), UILayout.CtrlH.Input)
        UILayout.RowButton(wp, 2, "BtnWinEdit", GetLang("编辑"))

        ; 文件面板：路径 + 浏览按钮
        fp := pStack.Add("Grid").Name("FilePanel").Visibility("Collapsed")
        fp.Cols("Auto", "*", "Auto")
        fp.Add("TextBlock").Grid_Column(0).Text(GetLang("文件路径：")).VerticalAlignment("Center").Margin("0,0,4,0")
        UILayout.Input(fp.Add("TextBox").Name("FilePathCon").Grid_Column(1), UILayout.CtrlH.Input)
        UILayout.RowButton(fp, 2, "BtnFileBrowse", GetLang("浏览"))

        ; 日期面板：值 + 单位
        dp := pStack.Add("Grid").Name("DatePanel").Visibility("Collapsed")
        dp.Cols("Auto", "*", "Auto", "Auto")
        dp.Add("TextBlock").Grid_Column(0).Text(GetLang("日期值：")).VerticalAlignment("Center").Margin("0,0,4,0")
        UILayout.Input(dp.Add("TextBox").Name("DateValCon").Grid_Column(1), UILayout.CtrlH.Input)
        dp.Add("TextBlock").Grid_Column(2).Text(GetLang("单位：")).VerticalAlignment("Center").Margin("12,0,4,0")
        dunit := dp.Add("ComboBox").Name("DateUnitCon").Grid_Column(3).Width(110)
            .Height(UILayout.CtrlH.Input).MinHeight(UILayout.CtrlH.Input)
        for t in GetLangArr(["分钟", "小时", "天", "具体时间", "时间变量"])
            dunit.Add("ComboBoxItem").Content(t)

        ; 行2：检测间隔 + 确定（确定由基类壳级事件 BtnOk 接管）
        btnRow := body.Add("StackPanel").Grid_Row(2).Orientation("Horizontal").HorizontalAlignment("Center").VerticalAlignment("Center")
        btnRow.Add("TextBlock").Text(GetLang("检测间隔(ms)：")).VerticalAlignment("Center")
        UILayout.Input(btnRow.Add("TextBox").Name("IntervalCon").Width(80).Margin("4,0,0,0"), UILayout.CtrlH.Input)
            .TextAlignment("Center")
        btnRow.Add("Button").Name("BtnOk").Content(GetLang("确定")).Width(100)
            .Height(UILayout.CtrlH.Btn).MinHeight(UILayout.CtrlH.Btn).Margin("16,0,0,0")
    }

    _SetCombo(comboName, items, text) {
        if (!IsObject(this.ui))
            return
        this.ui.Update(comboName, "ClearItems", "")
        for it in items {
            if (it == "")
                continue
            this.ui.Update(comboName, "AddItem", it)
        }
        this.ui.Update(comboName, "Text", text)
    }

    _TypeValue() {
        v := IsObject(this.ui) ? this.ui.Query("WaitTypeCon>SelectedIndex") : ""
        return IsNumber(v) ? Integer(v) + 1 : 1
    }

    ; ---- 数据回填（基类 OnInit 钩子委托）----
    OnInit(cmd) {
        this.Init(cmd)
    }

    Init(cmd) {
        cmdArr := cmd != "" ? SplitCommand(cmd) : []
        this.SerialStr := cmdArr.Length >= 1 ? cmdArr[1] : GetCMDSerialStr("等待")
        this.Data := GetMacroCMDData(this.SerialStr)
        this.DLVariableArr := GetGuiVarArr(1)

        batch := []
        batch.Push({ControlName: "RemarkCon", PropertyName: "Text", Value: cmdArr.Length >= 2 ? cmdArr[2] : ""})
        batch.Push({ControlName: "WaitTypeCon", PropertyName: "SelectedIndex", Value: String(this.Data.WaitType - 1)})
        batch.Push({ControlName: "IntervalCon", PropertyName: "Text", Value: this.Data.Interval})
        batch.Push({ControlName: "VarNameCon", PropertyName: "Text", Value: this.Data.Param1})
        batch.Push({ControlName: "VarValCon", PropertyName: "Text", Value: this.Data.Param2})
        batch.Push({ControlName: "KeyCon", PropertyName: "Text", Value: this.Data.Param1})
        batch.Push({ControlName: "ProcCon", PropertyName: "Text", Value: this.Data.Param1})
        batch.Push({ControlName: "WinInfoCon", PropertyName: "Text", Value: this.Data.Param1})
        batch.Push({ControlName: "FilePathCon", PropertyName: "Text", Value: this.Data.Param1})
        batch.Push({ControlName: "DateValCon", PropertyName: "Text", Value: this.Data.Param1})
        this.ui.BatchUpdate(batch)
        ; 坐标与下拉数据
        this._SetCombo("StartPosX", GetGuiVarArr(), this.Data.StartPosX)
        this._SetCombo("StartPosY", GetGuiVarArr(), this.Data.StartPosY)
        this._SetCombo("EndPosX", GetGuiVarArr(), this.Data.EndPosX)
        this._SetCombo("EndPosY", GetGuiVarArr(), this.Data.EndPosY)
        this._SetCombo("VarNameCon", this.DLVariableArr, this.Data.Param1)
        this._SetCombo("VarValCon", this.DLVariableArr, this.Data.Param2)
        ; 日期单位（Param2 存中文键）
        unitKey := GetLangKey(this.Data.Param2)
        unitIdx := 0
        for k, key in ["分钟", "小时", "天", "具体时间", "时间变量"] {
            if (key == unitKey) {
                unitIdx := k - 1
                break
            }
        }
        if (IsObject(this.ui))
            this.ui.Update("DateUnitCon", "SelectedIndex", String(unitIdx))
    }

    ; ---- 揭盖前联动（基类 AfterShow 钩子）：按类型显隐参数面板 ----
    AfterShow() {
        this.OnTypeChange()
    }

    OnTypeChange(state := "", ctrl := "", event := "") {
        if (!IsObject(this.ui))
            return
        t := this._TypeValue()
        panelMap := Map(
            1, "VarPanel", 2, "KeyPanel", 3, "KeyPanel", 4, "RangePanel",
            5, "", 6, "", 7, "",
            8, "ProcPanel", 9, "ProcPanel",
            10, "WinPanel", 11, "WinPanel", 12, "WinPanel", 13, "WinPanel", 14, "WinPanel", 15, "WinPanel",
            16, "FilePanel", 17, "FilePanel", 18, "FilePanel",
            19, "DatePanel"
        )
        show := panelMap.Has(t) ? panelMap[t] : ""
        batch := []
        for name in ["VarPanel", "KeyPanel", "RangePanel", "ProcPanel", "WinPanel", "FilePanel", "DatePanel"] {
            batch.Push({ControlName: name, PropertyName: "Visibility", Value: (name == show) ? "Visible" : "Collapsed"})
        }
        this.ui.BatchUpdate(batch)
    }

    OnClickWinEdit(state := "", ctrl := "", event := "") {
        global MainSoftData
        if (MainSoftData.IsModalSubGui && this.ui != "") {
            MyFrontInfoGui.OwnerHwnd := this.Hwnd()
        }
        else {
            MyFrontInfoGui.OwnerHwnd := ""
        }
        MyFrontInfoGui.ShowGui(XamlValueBridge(this.ui, "WinInfoCon"))
    }

    OnClickFileBrowse(state := "", ctrl := "", event := "") {
        path := FileSelect(1, this.ui.Query("FilePathCon"), GetLang("选择文件"))
        if (path != "")
            this.ui.Update("FilePathCon", "Text", path)
    }

    GetCommandStr() {
        textOnly := RegExReplace(this.Data.SerialStr, "\d+")
        numbersOnly := RegExReplace(this.Data.SerialStr, "\D+")
        CommandStr := Format("{}{}", GetLang(textOnly), numbersOnly)
        CommandStr := CorrectRemark(CommandStr, this.ui.Query("RemarkCon"))
        return CommandStr
    }

    OnValidate() {
        return this.CheckIfValid()
    }

    OnSave() {
        this.SaveWaitData()
        return this.GetCommandStr()
    }

    CheckIfValid() {
        t := this._TypeValue()
        switch t {
            case 1:    ; 变量值
                if (!CheckVarNameIfValid(this.ui.Query("VarNameCon")))
                    return false
            case 2, 3:    ; 按键
                if (this.ui.Query("KeyCon") == "") {
                    MsgBox(GetLang("请输入等待的按键"))
                    return false
                }
            case 8, 9:    ; 进程
                if (this.ui.Query("ProcCon") == "") {
                    MsgBox(GetLang("请输入进程名"))
                    return false
                }
            case 10, 11, 12, 13, 14, 15:    ; 窗口
                if (this.ui.Query("WinInfoCon") == "") {
                    MsgBox(GetLang("目标窗口信息不能为空"))
                    return false
                }
            case 16, 17, 18:    ; 文件
                if (this.ui.Query("FilePathCon") == "") {
                    MsgBox(GetLang("请输入文件路径"))
                    return false
                }
            case 19:    ; 日期
                if (this.ui.Query("DateValCon") == "") {
                    MsgBox(GetLang("请输入日期值"))
                    return false
                }
        }
        interval := this.ui.Query("IntervalCon")
        if (!IsNumber(interval) || Number(interval) <= 0) {
            MsgBox(GetLang("检测间隔请输入大于0的数字（毫秒）"))
            return false
        }
        return true
    }

    SaveWaitData() {
        this.Data.WaitType := this._TypeValue()
        this.Data.Interval := this.ui.Query("IntervalCon")
        t := this._TypeValue()
        switch t {
            case 1:    ; 变量值
                this.Data.Param1 := GetVarName(this.ui.Query("VarNameCon"))
                this.Data.Param2 := GetLangKey(this.ui.Query("VarValCon"))
            case 2, 3:
                this.Data.Param1 := this.ui.Query("KeyCon")
                this.Data.Param2 := ""
            case 4:
                this.Data.StartPosX := this.ui.Query("StartPosX")
                this.Data.StartPosY := this.ui.Query("StartPosY")
                this.Data.EndPosX := this.ui.Query("EndPosX")
                this.Data.EndPosY := this.ui.Query("EndPosY")
                this.Data.Param1 := ""
                this.Data.Param2 := ""
            case 5, 6, 7:
                this.Data.Param1 := ""
                this.Data.Param2 := ""
            case 8, 9:
                this.Data.Param1 := this.ui.Query("ProcCon")
                this.Data.Param2 := ""
            case 10, 11, 12, 13, 14, 15:
                this.Data.Param1 := this.ui.Query("WinInfoCon")
                this.Data.Param2 := ""
            case 16, 17, 18:
                this.Data.Param1 := this.ui.Query("FilePathCon")
                this.Data.Param2 := ""
            case 19:
                this.Data.Param1 := this.ui.Query("DateValCon")
                this.Data.Param2 := GetLangKey(this.ui.Query("DateUnitCon"))
        }
        SaveMacroCMDData(this.Data)
    }
}
