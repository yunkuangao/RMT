#Requires AutoHotkey v2.0

class CMDTipGui {
    __new() {
        this.Gui := ""
        this.SureBtnAction := ""
        this.Data := ""
        this.isLoadParams := false
        this.ShowCMDArr := []
        this.TextCtrl := ""
    }

    ShowGui(CMDStr) {
        if (!this.isLoadParams) {
            this.isLoadParams := true
            this.LoadParams()
        }

        if (this.Gui == "") {
            this.AddGui()
        }
        else {
            style := WinGetStyle(this.Gui.Hwnd)
            isVisible := (style & 0x10000000)  ; 0x10000000 = WS_VISIBLE
            if (!isVisible)
                this.Gui.Show(Format("NoActivate x{} y{} w{} h{}", this.PosX, this.PosY, this.Width, this.Height))
        }

        this.AddCMD(CMDStr)
    }

    LoadParams() {
        this.PosX := MySoftData.CMDPosX
        this.PosY := MySoftData.CMDPosY
        this.Width := MySoftData.CMDWidth
        this.Height := MySoftData.CMDHeight
        this.BGColor := MySoftData.CMDBGColor
        this.Transparency := (Integer)(MySoftData.CMDTransparency * 2.55)
        this.FontSize := MySoftData.CMDFontSize
        this.FontColor := MySoftData.CMDFontColor
        this.LineNum := MySoftData.CMDLineNum
    }

    AddGui() {
        MyGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
        this.Gui := MyGui
        MyGui.BackColor := this.BGColor
        MyGui.SetFont(Format("S{} W550 Q2 C{}", this.FontSize, this.FontColor), MySoftData.FontType)
        MyGui.Opt("+E0x20")  ; 点击穿透
        WinSetTransparent(this.Transparency, MyGui)  ; 设置透明度

        ; 添加文本控件（宽度和高度匹配窗口，自动换行）
        this.TextCtrl := MyGui.Add("Text", Format("x5 y5 w{} h{} r{}", this.Width - 5, this.Height - 5, this.LineNum),
        "")

        ; 显示窗口（固定宽高）
        MyGui.Show(Format("NoActivate  x{} y{} w{} h{}", this.PosX, this.PosY, this.Width, this.Height))
    }

    AddCMD(CMDStr) {
        if (this.ShowCMDArr.Length >= this.LineNum) {
            this.ShowCMDArr.RemoveAt(1)
        }
        this.ShowCMDArr.Push(CMDStr)
        CurContent := ""
        loop this.ShowCMDArr.Length {
            CurContent .= this.ShowCMDArr[A_Index] "`n"
        }
        this.TextCtrl.Value := CurContent
    }
}
