class FreePasteGui {
    __new() {
        ; 初始化缩放比例
        this.scaleFactor := 1.0
        this.minScale := 0.5
        this.maxScale := 3.0
        this.scaleStep := 0.1
    }

    ShowGui() {
        this.AddGui()
    }

    AddGui() {
        ; 检测剪贴板格式
        isImage := DllCall("IsClipboardFormatAvailable", "UInt", 8)  ; CF_DIB = 8
        isText := IsClipboardText()

        if (isImage || isText) {
            ; 创建GUI
            this.curGui := Gui("+AlwaysOnTop +ToolWindow -Caption -Resize -DPIScale")
            this.curGui.MarginX := !isImage && isText ? 10 : 0
            this.curGui.MarginY := !isImage && isText ? 10 : 0
            this.curGui.BackColor := "FFFFFF"  ; 默认背景色
            this.curGui.SetFont("S13 W550 Q2", MySoftData.FontType)

            ; 存储原始尺寸
            this.originalWidth := 0
            this.originalHeight := 0
        }

        if (isImage) {
            CurrentDateTime := FormatTime(, "MM月dd日HH-mm-ss")
            filePath := A_WorkingDir "\Images\FreePaste\" CurrentDateTime ".png"
            SaveClipToBitmap(filePath)
            this.pic := this.curGui.Add("Picture", "", filePath)
            ; 获取实际图片尺寸
            this.pic.GetPos(, , &width, &height)
            this.originalWidth := width
            this.originalHeight := height
        }
        else if (isText) {
            clipText := A_Clipboard
            ; 创建文本控件时不要指定固定大小
            this.textCtrl := this.curGui.Add("Text", "", clipText)
            ; 获取实际文本尺寸
            this.textCtrl.GetPos(, , &textW, &textH)
            width := textW + this.curGui.MarginX * 2
            height := textH + this.curGui.MarginY * 2
            this.originalWidth := width
            this.originalHeight := height
        }

        if (isImage || isText) {
            ; 添加透明覆盖控件（覆盖整个窗口）
            this.overlay := this.curGui.Add("Text", "x0 y0 w" width " h" height " BackgroundTrans +E0x200")
            ; 将事件绑定到覆盖控件
            this.overlay.OnEvent("Click", this.GuiDrag.Bind(this, this.curGui))
            this.overlay.OnEvent("DoubleClick", this.DoubleClick.Bind(this, this.curGui))
            this.curGui.Show("w" width " h" height)
        }
    }

    DoubleClick(gui, *) {
        gui.Destroy()
        gui := ""
    }

    ; 拖动函数
    GuiDrag(gui, *) {
        PostMessage(0xA1, 2, , , gui)
    }
}
