#Requires AutoHotkey v2.0

class TargetGui {
    __new() {
        this.Gui := ""
        this.ColorCon := ""
        this.CoordCon := ""
        this.ColorConMap := Map()
        this.OverlayCon := ""

        this.ColorValue := "F0F0F0"
        this.CoordX := 1920
        this.CoordY := 1080

        this.RowColorNum := 11
        this.ColColorNum := 15
        this.GuiWidth := 220
        this.GuiHeight := 150

        this.SureAction := ""
    }

    ShowGui() {
        if (this.Gui != "") {
            this.Gui.Show()
        }
        else {
            this.AddGui()
        }
        this.RefreshMapImage()
    }

    AddGui() {
        this.Gui := Gui("+AlwaysOnTop +ToolWindow -Caption -Resize -DPIScale")
        this.Gui.Title := "RMT-Target"
        this.Gui.SetFont("S13 W550 Q2", MySoftData.FontType)
        this.Gui.MarginX := 0
        this.Gui.MarginY := 0
        this.Gui.BackColor := "EEAA99" ; 这个颜色必须设置，但具体是什么颜色不重要
        this.Gui.Add("Pic", Format("w{} h{}", 96, 96), "Images\Soft\Target.png")

        StartPosX := 60
        StartPosY := 5
        loop this.RowColorNum {
            RowValue := A_Index
            loop this.ColColorNum {
                ColValue := A_Index
                if (RowValue == 6 && ColValue == 8)
                    continue
                PosX := StartPosX + (ColValue - 1) * 10
                PosY := StartPosY + (RowValue - 1) * 10
                Con := this.Gui.Add("Text", Format("x{} y{} w{} h{} Background{}", PosX, PosY, 10, 10, "FF0000"), "")
                this.ColorConMap.Set(Format("{}-{}", ColValue, RowValue), Con)
            }
        }
        CenterBoxPosX := 128
        CenterBoxPosY := 53
        Con := this.Gui.Add("Text", Format("x{} y{} w{} h{} Background{}", CenterBoxPosX, CenterBoxPosY, 14, 14,
            "FFFFFF"), "")
        this.ColorConMap.Set(Format("{}-{}", 0, 0), Con)

        CenterPosX := 130
        CenterPosY := 55
        Con := this.Gui.Add("Text", Format("x{} y{} w{} h{} Background{}", CenterPosX, CenterPosY, 10, 10,
            "FFFFFF"), "")
        this.ColorConMap.Set(Format("{}-{}", 8, 6), Con)

        this.ColorCon := this.Gui.Add("Text", Format("x{} y{} w{} h{} Background{}", 5, 95, 50, 50, "FF0000"), "")
        this.CoordCon := this.Gui.Add("Text", Format("x{} y{} w{}", 60, 115, 100, "FF0000"), "1920,1080")

        this.OverlayCon := this.Gui.Add("Text", "x0 y0 w" this.GuiWidth " h" this.GuiHeight " BackgroundTrans")
        this.OverlayCon.OnEvent("Click", this.GuiDrag.Bind(this))
        this.OverlayCon.OnEvent("DoubleClick", this.GuiDoubleClick.Bind(this))
        this.Gui.Show(Format("w{} h{}", this.GuiWidth, this.GuiHeight))
    }

    ; 拖动函数
    GuiDrag(*) {
        PostMessage(0xA1, 2, , , this.Gui)
        this.RefreshCoord()
    }

    ;双击确定关闭
    GuiDoubleClick(*) {
        if (this.Gui == "")
            return
        style := WinGetStyle(this.Gui.Hwnd)
        isVisible := (style & 0x10000000)  ; 0x10000000 = WS_VISIBLE
        if (!isVisible)
            return

        this.Gui.Hide()
        if (this.SureAction == "")
            return
        action := this.SureAction
        action(this.CoordX, this.CoordY, this.ColorValue)
    }

    OnLButtonUp(*) {
        if (this.Gui == "")
            return
        style := WinGetStyle(this.Gui.Hwnd)
        isVisible := (style & 0x10000000)  ; 0x10000000 = WS_VISIBLE
        if (!isVisible)
            return

        this.RefreshCoord()
        this.RefreshMapImage()
    }

    OnEnterUp(*) {
        if (this.Gui == "")
            return
        style := WinGetStyle(this.Gui.Hwnd)
        isVisible := (style & 0x10000000)  ; 0x10000000 = WS_VISIBLE
        if (!isVisible)
            return

        this.Gui.Hide()
        if (this.SureAction == "")
            return
        action := this.SureAction
        action(this.CoordX, this.CoordY, this.ColorValue)
    }

    OnArrowKeyDown(key) {
        if (this.Gui == "")
            return
        style := WinGetStyle(this.Gui.Hwnd)
        isVisible := (style & 0x10000000)  ; 0x10000000 = WS_VISIBLE
        if (!isVisible)
            return

        this.Gui.GetPos(&x, &y, &w, &h)
        if (key == "left")
            x -= 1
        if (key == "right")
            x += 1
        if (key == "up")
            y -= 1
        if (key == "down")
            y += 1

        this.Gui.Move(x, y)
        this.RefreshCoord()
        this.RefreshMapImage()
    }

    RefreshCoord() {
        this.Gui.GetPos(&x, &y, &w, &h)

        this.CoordX := x - 1
        this.CoordY := y - 1
        this.CoordCon.Text := Format("{},{}", this.CoordX, this.CoordY)
    }

    RefreshMapImage() {
        this.Gui.GetPos(&x, &y, &w, &h)
        this.Gui.Move(-1000, -1000)
        ColorValueMap := GetPixelColorMap(x - 1, y - 1, this.RowColorNum, this.ColColorNum)
        this.Gui.Move(x, y)

        CoordMode("Pixel", "Screen")

        loop this.RowColorNum {
            RowValue := A_Index
            loop this.ColColorNum {
                ColValue := A_Index
                Key := Format("{}-{}", ColValue, RowValue)
                Con := this.ColorConMap[Key]
                ColorValue := ColorValueMap[Key]
                Con.Opt("Background" ColorValue)
                Con.Redraw()
            }
        }

        Key := Format("{}-{}", Integer((this.ColColorNum + 1) / 2), Integer((this.RowColorNum + 1) / 2))
        this.ColorValue := ColorValueMap[Key]
        this.ColorCon.Opt("Background" this.ColorValue)
        this.ColorCon.Redraw()
    
        CenterBoxKey := Format("{}-{}", 0, 0)
        CenterBoxCon := this.ColorConMap[CenterBoxKey]
        ColorValue := this.GetInvertedColor(this.ColorValue)
        CenterBoxCon.Opt("Background" ColorValue)
        CenterBoxCon.Redraw() 
    }

    GetInvertedColor(color) {
        ; 去除可能的前缀（如0x）
        if (SubStr(color, 1, 2) = "0x") {
            color := SubStr(color, 3)
        }

        ; 确保颜色值是6位十六进制
        if (StrLen(color) = 6) {
            ; 将十六进制转换为RGB分量
            red := Integer("0x" SubStr(color, 1, 2))
            green := Integer("0x" SubStr(color, 3, 2))
            blue := Integer("0x" SubStr(color, 5, 2))

            ; 计算反色
            invertedRed := 255 - red
            invertedGreen := 255 - green
            invertedBlue := 255 - blue

            ; 将RGB分量转换回十六进制
            invertedColor := Format("0x{:02X}{:02X}{:02X}", invertedRed, invertedGreen, invertedBlue)

            return invertedColor
        }
        return "0xFFFFFF"
    }
}
