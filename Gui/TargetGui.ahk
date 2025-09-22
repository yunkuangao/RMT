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

        this.RowColorNum := 9
        this.ColColorNum := 13
        this.GuiWidth := 200
        this.GuiHeight := 130
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
        this.Gui.SetFont("S13 W550 Q2", MySoftData.FontType)
        this.Gui.MarginX := 0
        this.Gui.MarginY := 0
        this.Gui.BackColor := "EEAA99" ; 这个颜色必须设置，但具体是什么颜色不重要
        this.Gui.Add("Pic", Format("w{} h{}", 96, 96), "Images\Soft\Target.png")

        StartPosX := 60
        StartPosY := 2
        loop this.RowColorNum {
            RowValue := A_Index
            loop this.ColColorNum {
                ColValue := A_Index
                PosX := StartPosX + (ColValue - 1) * 10
                PosY := StartPosY + (RowValue - 1) * 10
                Con := this.Gui.Add("Text", Format("x{} y{} w{} h{} Background{}", PosX, PosY, 15, 15, "FF0000"), "")
                this.ColorConMap.Set(Format("{}-{}", ColValue, RowValue), Con)
            }
        }

        this.ColorCon := this.Gui.Add("Text", Format("x{} y{} w{} h{} Background{}", 5, 75, 50, 50, "FF0000"), "")
        this.CoordCon := this.Gui.Add("Text", Format("x{} y{} w{}", 60, 100, 100, "FF0000"), "1920,1080")

        this.OverlayCon := this.Gui.Add("Text", "x0 y0 w" this.GuiWidth " h" this.GuiHeight " BackgroundTrans")
        this.OverlayCon.OnEvent("Click", this.GuiDrag.Bind(this))
        this.Gui.Show(Format("w{} h{}", this.GuiWidth, this.GuiHeight))
    }

    ; 拖动函数
    GuiDrag(*) {
        PostMessage(0xA1, 2, , , this.Gui)
        this.RefreshInfo()
    }

    RefreshInfo() {
        this.Gui.GetPos(&x, &y, &w, &h)

        this.CoordX := x - 1
        this.CoordY := y - 1
        this.CoordCon.Text := Format("{},{}", this.CoordX, this.CoordY)

        CoordMode("Pixel", "Screen")
        this.ColorValue := PixelGetColor(x - 1, y - 1)
        this.ColorCon.Opt("Background" this.ColorValue)
        this.ColorCon.Redraw()

        this.RefreshMapImage()
    }

    RefreshMapImage() {
        this.Gui.GetPos(&x, &y, &w, &h)
        ColorValueMap := GetPixelColorMap(x - 1, y - 1, 9, 13)
        x := x - 1 - (this.ColColorNum - 1) / 2
        y := y - 1 - (this.RowColorNum - 1) / 2

        CoordMode("Pixel", "Screen")
        loop this.RowColorNum {
            RowValue := A_Index
            loop this.ColColorNum {
                ColValue := A_Index
                ; ColorValue := PixelGetColor(x + ColValue - 1, y + RowValue - 1)
                Key := Format("{}-{}", ColValue, RowValue)
                Con := this.ColorConMap[Key]
                ColorValue := ColorValueMap[Key]
                Con.Opt("Background" ColorValue)
                Con.Redraw()
            }
        }
    }
}
