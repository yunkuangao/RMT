#Requires AutoHotkey v2.0

class MacroSettingGui {
    __new() {
        this.Gui := ""
        this.Data := ""
    }

    ShowGui(tableIndex, itemIndex) {
        if (this.Gui != "") {
            this.Gui.Show()
        }
        else {
            this.AddGui()
        }
        this.Init(tableIndex, itemIndex)
        this.OnChangeType()
    }

    Init(tableIndex, itemIndex) {
        
    }

    AddGui() {
        MyGui := Gui(, "宏高级设置")
        this.Gui := MyGui
        MyGui.SetFont("S11 W550 Q2", MySoftData.FontType)

        PosX := 10
        PosY := 15
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), "开始时间：")
        PosX += 80
        this.StartTimeCon := MyGui.Add("DateTime", Format("x{} y{} w150", PosX, PosY - 3), "yyyy-MM-dd HH:mm")


        PosX := 200
        PosY += 40
        con := MyGui.Add("Button", Format("x{} y{} w100 h40", PosX, PosY), "确定")
        con.OnEvent("Click", (*) => this.OnSureBtnClick())
        MyGui.Show(Format("w{} h{}", 525, 150))
    }

    OnChangeType() {
        
    }

    OnSureBtnClick() {

        this.Gui.Hide()
    }
}
