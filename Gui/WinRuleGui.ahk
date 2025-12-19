#Requires AutoHotkey v2.0

class WinRuleGui {
    __new() {
        this.Gui := ""
        this.WidthCon := ""
        this.HeightCon := ""
        this.RemarkCon := ""
        this.SureAction := ""
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
        MyGui := Gui(, GetLang("窗口规格编辑器"))
        this.Gui := MyGui
        MyGui.SetFont("S11 W550 Q2", MySoftData.FontType)

        PosX := 10
        PosY := 15
        MyGui.Add("Text", Format("x{} y{} w350 h150", PosX, PosY), GetLang("屏幕宽度："))
        PosX += 100
        this.WidthCon := MyGui.Add("Edit", Format("x{} y{} w100", PosX, PosY), A_ScreenWidth)

        PosX := 10
        PosY += 30
        MyGui.Add("Text", Format("x{} y{} w350 h150", PosX, PosY), GetLang("屏幕高度："))
        PosX += 100
        this.HeightCon := MyGui.Add("Edit", Format("x{} y{} w100", PosX, PosY), A_ScreenHeight)

        PosX := 10
        PosY += 30
        MyGui.Add("Text", Format("x{} y{} w350 h150", PosX, PosY), GetLang("备注："))
        PosX += 100
        this.RemarkCon := MyGui.Add("Edit", Format("x{} y{} w100", PosX, PosY), GetLang("全屏"))

        PosY += 40
        PosX := 80
        con := MyGui.Add("Button", Format("x{} y{} w80", PosX, PosY), GetLang("确定"))
        con.OnEvent("Click", (*) => this.OnSureBtnClick())
        MyGui.Show(Format("w{} h{}", 220, 160))
    }

    OnSureBtnClick() {
        if (!IsNumber(this.WidthCon.Value) || !IsNumber(this.HeightCon.Value)) {
            MsgBox(GetLang("屏幕宽高需要输入数字"))
            return
        }

        action := this.SureAction
        if (action != "") {
            RemarkText := Trim(this.RemarkCon.Value)
            RemarkText := Trim(RemarkText, "`n")
            action(this.WidthCon.Value, this.HeightCon.Value, RemarkText)
            this.SureAction := ""
        }
        this.Gui.Hide()
    }
}
