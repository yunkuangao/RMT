#Requires AutoHotkey v2.0

class TargetGui {
    __new() {
        this.Gui := ""
    }

    ShowGui() {
        if (this.Gui != "") {
            this.Gui.Show()
        }
        else {
            this.AddGui()
        }
    }

    AddGui() {
        this.Gui := Gui("+AlwaysOnTop +ToolWindow -Caption -Resize -DPIScale")
        this.Gui.MarginX := 0
        this.Gui.MarginY := 0
        this.Gui.Add("Pic", Format("w{} h{}", 50, 50), "Images\Soft\Target.png")
        this.Gui.Show("w50 h50")
    }
}
