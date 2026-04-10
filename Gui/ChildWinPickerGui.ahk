#Requires AutoHotkey v2.0
#Warn All, Off

class ChildWinPickerGui {
    __New() {
        this.Gui := ""
        this.TreeView := ""
        this.WindowData := []
        this.SelectedPath := ""
        this.OwnerGui := ""
    }

    ShowGui(ownerGui, initFilter := "") {
        this.OwnerGui := ownerGui
        this.SelectedPath := ""
        if (this.Gui != "") {
            this.FilterEdit.Value := initFilter
            this.Refresh()
            this.Gui.Show()
            return
        }
        this._initFilter := initFilter
        this.BuildGui()
    }

    BuildGui() {
        MyGui := Gui("+Resize", "子窗口选择器")
        this.Gui := MyGui
        MyGui.SetFont("S10", MySoftData.FontType)
        MyGui.OnEvent("Close", (*) => this.OnClose())
        MyGui.OnEvent("Size", (*) => this.OnResize())

        MyGui.Add("Text", "x10 y8 w80", "筛选进程:")
        this.FilterEdit := MyGui.Add("Edit", "x90 y5 w200 vFilter", this._initFilter)
        this.FilterEdit.OnEvent("Change", (*) => this.Refresh())

        btnRefresh := MyGui.Add("Button", "x300 y5 w80", "刷新")
        btnRefresh.OnEvent("Click", (*) => this.Refresh())
        btnSelect := MyGui.Add("Button", "x390 y5 w80", "选择子窗口")
        btnSelect.OnEvent("Click", (*) => this.OnSelect())

        this.InfoLabel := MyGui.Add("Text", "x490 y8 w400", "")

        this.TreeView := MyGui.Add("TreeView", "x10 y35 w860 h500 -HScroll Lines WantF2")
        this.TreeView.OnEvent("Click", ObjBindMethod(this, "OnTreeClick"))

        MyGui.Show("w880 h545")
        this.Refresh()

        ; 注册 F1 热键：获取鼠标位置子窗口
        HotIfWinActive("ahk_id " MyGui.Hwnd)
        Hotkey("F1", (*) => this.OnPickFromMouse())
        Hotkey("Escape", (*) => this.Gui.Hide())
        HotIfWinActive()
    }

    Refresh() {
        filter := ""
        try
            filter := this.FilterEdit.Value

        this.TreeView.Delete()
        this.WindowData := []

        allWindows := EnumAllWindows()
        for winInfo in allWindows {
            procName := winInfo["process"]
            title := winInfo["title"]

            if (filter != "" && !InStr(procName, filter) && !InStr(title, filter))
                continue

            displayText := "[" procName "] " (title != "" ? title : "(无标题)") " [" winInfo["hwnd"] "]"
            parentId := this.TreeView.Add(displayText, , "Bold")
            this.WindowData.Push(Map("id", parentId, "hwnd", winInfo["hwnd"], "type", "top"))

            this.AddChildNodes(parentId, winInfo["children"], 1)
        }
    }

    AddChildNodes(parentId, children, depth) {
        if (depth > 5 || !children || children.Length == 0)
            return

        for child in children {
            cls := child["class"]
            title := child["title"]
            if (cls == "")
                continue

            displayText := cls
            if (title != "")
                displayText .= " [" title "]"

            childId := this.TreeView.Add(displayText, parentId)
            this.WindowData.Push(Map("id", childId, "hwnd", child["hwnd"], "type", "child"))

            if (child.Has("children") && child["children"].Length > 0) {
                this.AddChildNodes(childId, child["children"], depth + 1)
            }
        }
    }

    OnTreeClick(GuiCtrl, ItemID) {
        if (!ItemID)
            return

        for item in this.WindowData {
            if (item["id"] == ItemID) {
                hwnd := item["hwnd"]
                type := item["type"]
                try {
                    cls := WinGetClass(hwnd)
                    title := WinGetTitle(hwnd)
                    this.InfoLabel.Value := "hwnd: " hwnd " | 类名: " cls " | 标题: [" title "] | 类型: " (type == "top" ? "顶层窗口" : "子窗口")
                } catch {
                    this.InfoLabel.Value := "hwnd: " hwnd " (已失效)"
                }
                return
            }
        }
    }

    OnSelect() {
        selectedId := this.TreeView.GetSelection()
        if (!selectedId) {
            this.InfoLabel.Value := "请先在树中选择一个子窗口"
            return
        }

        for item in this.WindowData {
            if (item["id"] == selectedId) {
                hwnd := item["hwnd"]
                type := item["type"]

                if (type == "top") {
                    this.InfoLabel.Value := "请选择子窗口，而不是顶层窗口"
                    return
                }

                classPath := GetChildWindowClassPath(hwnd)
                pathStr := SerializeClassPath(classPath)

                if (classPath.Length == 0) {
                    this.InfoLabel.Value := "无法获取该窗口的类名路径"
                    return
                }

                try {
                    cls := WinGetClass(hwnd)
                    this.InfoLabel.Value := "已选择: " cls " | 路径: " pathStr
                    this.SelectedPath := pathStr
                    this.OnClose()
                } catch as e {
                    this.InfoLabel.Value := "选择失败: " e.Message
                }
                return
            }
        }
    }

    OnClose() {
        this.Gui.Hide()
        if (this.SelectedPath != "" && this.OwnerGui) {
            this.OwnerGui.OnChildWinSelected(this.SelectedPath)
        }
    }

    OnResize(*) {
        try {
            ctrlW := this.Gui.ClientW - 20
            ctrlH := this.Gui.ClientH - 45
            this.TreeView.Move(, , ctrlW, ctrlH > 100 ? ctrlH : 100)
        }
    }

    ; 获取鼠标位置下的子窗口
    OnPickFromMouse() {
        MouseGetPos(&mouseX, &mouseY, &hwnd, &controlHwnd, 2)

        if (!hwnd) {
            this.InfoLabel.Value := "鼠标位置未找到窗口"
            return
        }

        ; 如果 controlHwnd 是子窗口，用它；否则用顶层窗口
        targetHwnd := controlHwnd ? controlHwnd : hwnd

        try {
            cls := WinGetClass(targetHwnd)
            title := WinGetTitle(targetHwnd)
        } catch {
            this.InfoLabel.Value := "无法获取窗口信息"
            return
        }

        ; 检查是否是子窗口（有父窗口）
        parentHwnd := DllCall("User32\GetParent", "ptr", targetHwnd, "ptr")
        if (!parentHwnd) {
            this.InfoLabel.Value := "鼠标位置是顶层窗口，请选择子窗口 | 类名: " cls
            return
        }

        ; 获取类名路径
        classPath := GetChildWindowClassPath(targetHwnd)
        pathStr := SerializeClassPath(classPath)

        if (classPath.Length == 0) {
            this.InfoLabel.Value := "无法获取该窗口的类名路径"
            return
        }

        this.InfoLabel.Value := "已选择: " cls " | 路径: " pathStr
        this.SelectedPath := pathStr
        this.OnClose()
    }
}
