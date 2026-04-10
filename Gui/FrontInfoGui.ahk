#Requires AutoHotkey v2.0

class FrontInfoGui {
    __new() {
        this.Gui := ""
        this.InfoAction := () => this.RefreshMouseInfo()
        this.HideAction := ""
        this.SureAction := ""
        this.winInfoCon := ""
        this.isFront := false   ;前台不支持句柄模式
        this.InfoTogCon := ""
        this.TopTogCon := ""
        this.InfoTogArrCon := []
        this.InfoTextArrCon := []
        this.ChildWinPathCon := ""
    }

    ShowGui(winInfoCon, isFront := false) {
        if (this.Gui != "") {
            this.Gui.Show()
        }
        else {
            this.AddGui()
        }
        this.isFront := isFront
        this.Init(winInfoCon)
        this.ToggleFunc(true)
    }

    Init(winInfoCon) {
        this.winInfoCon := winInfoCon
        this.TopTogCon.Value := true
        infoStr := winInfoCon.Value
        if (InStr(infoStr, "❖")) {
            idStr := StrReplace(infoStr, "❖", "")
            infoArr := [idStr, "", "", "", ""]
        }
        else {
            if (infoStr != "")
                infoArr := StrSplit(infoStr, "⎖")
            if (infoStr == "" || (infoArr.Length != 3 && infoArr.Length != 4))
                infoArr := ["", "", "", "", ""]

            ; 兼容旧的3段格式，插入空的子窗口路径
            if (infoArr.Length == 3)
                infoArr.Push("")

            infoArr.InsertAt(1, "")
        }

        loop 5 {
            this.InfoTogArrCon[A_Index].Value := infoArr[A_Index] != ""
            this.InfoTextArrCon[A_Index].Value := infoArr[A_Index]
        }

        this.ChildWinPathCon := infoArr[5]

        DLVariableArr := GetGuiVarArr()
        this.VariCon.Delete()
        this.VariCon.Add(DLVariableArr)
        this.VariCon.Value := 1
        this.OnTogClick()
    }

    AddGui() {
        MyGui := Gui(, GetLang("前台信息编辑器"))
        this.Gui := MyGui
        MyGui.SetFont("S11 W550 Q2", MySoftData.FontType)
        PosX := 10
        PosY := 10

        PosX := 10
        con := MyGui.Add("Checkbox", Format("x{} y{}", PosX, PosY), GetLang("窗口置顶"))
        con.OnEvent("Click", this.OnTogClick.Bind(this))
        this.TopTogCon := con

        PosX := 160
        con := MyGui.Add("Edit", Format("x{} y{} w{} Center", PosX, PosY - 5, 30), "F1")
        con.Enabled := false
        PosX += 30
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("确定信息"))

        PosX := 400
        Con := MyGui.Add("Button", Format("x{} y{} w30", PosX, PosY - 4), "?")
        Con.OnEvent("Click", this.OnClickTypeHelpBtn.Bind(this))

        PosY += 30
        PosX := 10
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), GetLang("当前鼠标下窗口信息："))

        PosY += 25
        PosX := 10
        this.CurWinInfoCon := MyGui.Add("Text", Format("x{} y{} w800 h90", PosX, PosY))

        PosY += 95
        PosX := 20
        con := MyGui.Add("Checkbox", Format("x{} y{}", PosX, PosY), GetLang("句柄ID"))
        con.OnEvent("Click", this.OnTogClick.Bind(this))
        this.InfoTogArrCon.Push(con)
        PosX := 95
        con := MyGui.Add("Edit", Format("x{} y{} w360", PosX, PosY - 3), "")
        this.InfoTextArrCon.Push(con)

        PosY += 32
        PosX := 175
        this.VarConArr := []
        this.VariTipCon := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 150), GetLang("变量:"))
        this.VarConArr.Push(this.VariTipCon)

        PosX += 45
        this.VariCon := MyGui.Add("DropDownList", Format("x{} y{} w{} R5", PosX, PosY - 3, 130), [])
        this.VarConArr.Push(this.VariCon)

        PosX += 135
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY - 5, 100, 30), GetLang("追加变量值"))
        btnCon.OnEvent("Click", (*) => this.OnClickAddVarValueBtn())
        this.VarConArr.Push(btnCon)

        PosY += 35
        PosX := 20
        con := MyGui.Add("Checkbox", Format("x{} y{}", PosX, PosY), GetLang("标题"))
        con.OnEvent("Click", this.OnTogClick.Bind(this))
        this.InfoTogArrCon.Push(con)
        PosX := 95
        con := MyGui.Add("Edit", Format("x{} y{} w360", PosX, PosY - 3), "")
        this.InfoTextArrCon.Push(con)

        PosY += 35
        PosX := 20
        con := MyGui.Add("Checkbox", Format("x{} y{}", PosX, PosY), GetLang("窗口类"))
        con.OnEvent("Click", this.OnTogClick.Bind(this))
        this.InfoTogArrCon.Push(con)
        PosX := 95
        con := MyGui.Add("Edit", Format("x{} y{} w360", PosX, PosY - 3), "")
        this.InfoTextArrCon.Push(con)

        PosY += 35
        PosX := 20
        con := MyGui.Add("Checkbox", Format("x{} y{}", PosX, PosY), GetLang("进程名"))
        con.OnEvent("Click", this.OnTogClick.Bind(this))
        this.InfoTogArrCon.Push(con)
        PosX := 95
        con := MyGui.Add("Edit", Format("x{} y{} w360", PosX, PosY - 3), "")
        this.InfoTextArrCon.Push(con)

        PosY += 35
        PosX := 20
        con := MyGui.Add("Checkbox", Format("x{} y{}", PosX, PosY), GetLang("子窗口"))
        con.OnEvent("Click", this.OnTogClick.Bind(this))
        this.InfoTogArrCon.Push(con)
        PosX := 95
        con := MyGui.Add("Edit", Format("x{} y{} w250", PosX, PosY - 3), "")
        this.InfoTextArrCon.Push(con)
        PosX += 260
        btnCon := MyGui.Add("Button", Format("x{} y{} w80", PosX, PosY - 3), GetLang("选择"))
        btnCon.OnEvent("Click", (*) => this.OnClickChildWinBtn())

        PosX := 200
        PosY += 40
        con := MyGui.Add("Button", Format("x{} y{} w100 h40", PosX, PosY), GetLang("确定"))
        con.OnEvent("Click", (*) => this.OnSureBtnClick())
        MyGui.OnEvent("Close", this.OnClose.Bind(this))
        MyGui.Show(Format("w{} h{}", 500, 440))
    }

    RefreshMouseInfo() {
        CoordMode("Mouse", "Screen")
        MouseGetPos &mouseX, &mouseY, &winId
        try {
            title := WinGetTitle(winId)
            className := WinGetClass(winId)
            process := WinGetProcessName(winId)
            tipStr := Format("{}{}`n{}{}`n{}{}`n{}{}", GetLang("句柄ID："), winId, GetLang("标题："), title, GetLang("窗口类："),
            className, GetLang("进程名："),
            process)
            this.CurWinInfoCon.Value := tipStr
        }
    }

    OnClose(*) {
        this.ToggleFunc(false)
        if (this.HideAction != "") {
            action := this.HideAction
            action()
            this.HideAction := ""
        }
    }

    ToggleFunc(state) {
        if (state) {
            SetTimer this.InfoAction, 100
            Hotkey("F1", (*) => this.OnF1(), "On")
        }
        else {
            SetTimer this.InfoAction, 0
            Hotkey("F1", (*) => this.OnF1(), "Off")
        }
    }

    CheckIfValid() {
        if (this.InfoTextArrCon[1].Value && this.InfoTextArrCon[1].Value == "") {
            MsgBox(GetLang("勾选句柄ID后，句柄ID内容不能为空"), "", "Owner" this.Gui.Hwnd)
            return false
        }

        if (this.InfoTextArrCon[2].Value && this.InfoTextArrCon[2].Value == "") {
            MsgBox(GetLang("勾选标题后，标题内容不能为空"), "", "Owner" this.Gui.Hwnd)
            return false
        }

        if (this.InfoTextArrCon[3].Value && this.InfoTextArrCon[3].Value == "") {
            MsgBox(GetLang("勾选窗口类后，窗口类内容不能为空"), "", "Owner" this.Gui.Hwnd)
            return false
        }

        if (this.InfoTextArrCon[4].Value && this.InfoTextArrCon[4].Value == "") {
            MsgBox(GetLang("勾选进程名后，进程名内容不能为空"), "", "Owner" this.Gui.Hwnd)
            return false
        }

        if (this.InfoTextArrCon[5].Value && this.InfoTextArrCon[5].Value == "") {
            MsgBox("勾选子窗口后，子窗口路径不能为空", "", "Owner" this.Gui.Hwnd)
            return false
        }

        if (this.isFront && this.InfoTogArrCon[1].Value) {
            if (InStr(this.InfoTextArrCon[1].Value, "{")) {
                MsgBox(GetLang("前台窗口信息句柄ID不能使用变量"), "", "Owner" this.Gui.Hwnd)
                return false
            }
        }

        return true
    }

    GetInfoStr() {
        if (this.InfoTogArrCon[1].Value)
            return "❖" this.InfoTextArrCon[1].Value

        ; 构建 4 段格式：标题⎖类名⎖进程名⎖子窗口路径
        title := this.InfoTogArrCon[2].Value ? this.InfoTextArrCon[2].Value : ""
        className := this.InfoTogArrCon[3].Value ? this.InfoTextArrCon[3].Value : ""
        process := this.InfoTogArrCon[4].Value ? this.InfoTextArrCon[4].Value : ""
        childPath := this.InfoTogArrCon[5].Value ? this.InfoTextArrCon[5].Value : ""

        Str := title "⎖" className "⎖" process "⎖" childPath

        ; 如果全部为空，返回空字符串
        if (Str == "⎖⎖⎖")
            return ""
        return Str
    }

    OnSureBtnClick() {
        isValid := this.CheckIfValid()
        if (!isValid)
            return

        this.winInfoCon.Value := this.GetInfoStr()
        this.ToggleFunc(false)
        this.Gui.Hide()
        this.OnClose()
        if (this.SureAction != "") {
            action := this.SureAction
            action()
            this.SureAction := ""
        }
    }

    OnTogClick(*) {
        if (this.TopTogCon.Value) {
            this.Gui.Opt("+AlwaysOnTop")
        }
        else {
            this.Gui.Opt("-AlwaysOnTop")
        }

        isHwndID := this.InfoTogArrCon[1].Value
        this.InfoTextArrCon[1].Enabled := isHwndID
        loop this.VarConArr.Length {
            con := this.VarConArr[A_Index]
            con.Enabled := isHwndID
        }
        loop 5 {
            if (A_Index == 1)
                continue
            if (isHwndID) {
                this.InfoTogArrCon[A_Index].Value := false
                this.InfoTextArrCon[A_Index].Enabled := false
            }
            else {
                Enable := this.InfoTogArrCon[A_Index].Value
                this.InfoTextArrCon[A_Index].Enabled := Enable
            }
        }
    }

    OnF1() {
        CoordMode("Mouse", "Screen")
        MouseGetPos &mouseX, &mouseY, &winId, &controlHwnd, 2
        try {
            title := WinGetTitle(winId)
            className := WinGetClass(winId)
            process := WinGetProcessName(winId)
            this.InfoTextArrCon[1].Value := winId
            this.InfoTextArrCon[2].Value := title
            this.InfoTextArrCon[3].Value := className
            this.InfoTextArrCon[4].Value := process

            ; 尝试获取子窗口路径
            if (controlHwnd && controlHwnd != winId) {
                classPath := GetChildWindowClassPath(controlHwnd)
                pathStr := SerializeClassPath(classPath)
                if (pathStr != "") {
                    this.InfoTextArrCon[5].Value := pathStr
                    this.InfoTogArrCon[5].Value := 1
                }
            }

            loop 5 {
                ; 句柄ID不勾选，其他根据当前状态保持（不强制改变子窗口）
                if (A_Index == 1)
                    this.InfoTogArrCon[A_Index].Value := 0
                else if (A_Index != 5)
                    this.InfoTogArrCon[A_Index].Value := 1
            }
            this.OnTogClick()
        }
    }

    OnClickTypeHelpBtn(*) {
        str1 := GetLang("优先级：句柄ID > 标题 + 窗口类 + 进程名")
        str2 := GetLang("句柄ID支持多ID任意适配")
        str3 := "子窗口：可选，用于将按键发送到目标窗口的特定子控件（如记事本的文本编辑区）"

        str := Format("{}`n{}`n{}", str1, str2, str3)
        MsgBox(str, GetLang("窗口信息说明"), "Owner" this.Gui.Hwnd)
    }

    OnClickAddVarValueBtn() {
        Symbol := this.InfoTextArrCon[1].Text == "" ? "" : "|"
        VarStr := "{" this.VariCon.Text "}"
        if (this.VariCon.Text == "") {
            MsgBox("请勿添加空字符变量", "", "Owner" this.Gui.Hwnd)
            return
        }
        if (InStr(this.InfoTextArrCon[1].Text, VarStr)) {
            MsgBox("请勿重复添加变量", "", "Owner" this.Gui.Hwnd)
            return
        }

        this.InfoTextArrCon[1].Text .= Symbol VarStr
    }

    OnClickChildWinBtn() {
        ; 从当前编辑的标题/窗口类/进程名中获取进程名作为初始筛选
        initFilter := ""
        if (this.InfoTextArrCon[4].Value != "")
            initFilter := this.InfoTextArrCon[4].Value

        picker := ChildWinPickerGui()
        picker.ShowGui(this, initFilter)
    }

    ; 由 ChildWinPickerGui 的 OnClose 回调
    OnChildWinSelected(pathStr) {
        if (pathStr != "") {
            this.InfoTextArrCon[5].Value := pathStr
            this.InfoTogArrCon[5].Value := 1
            ; 只有在非句柄ID模式下才启用子窗口编辑框
            if (!this.InfoTogArrCon[1].Value) {
                this.InfoTextArrCon[5].Enabled := true
            }
            ; 强制刷新界面
            this.Gui.Show()
        }
    }
}
