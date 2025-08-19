#Requires AutoHotkey v2.0

class RMTCMDGui {
    __new() {
        this.Gui := ""
        this.SureBtnAction := ""
        this.CmdStrArr := ["截图", "截图提取文本", "自由贴",
            "开启指令显示", "关闭指令显示", "启用键鼠", "禁用键鼠", "休眠", "终止所有宏", "重载"]
        this.OperTypeCon := ""
    }

    ShowGui(cmd) {
        if (this.Gui != "") {
            this.Gui.Show()
        }
        else {
            this.AddGui()
        }

        this.Init(cmd)
    }

    Init(cmd) {
        cmdArr := cmd != "" ? StrSplit(cmd, "_") : []
        cmdStr := cmdArr.Length >= 2 ? cmdArr[2] : "截图"
        loop this.CmdStrArr.Length {
            if (this.CmdStrArr[A_Index] == cmdStr) {
                this.OperTypeCon.Value := A_Index
                break
            }
        }
    }

    AddGui() {
        MyGui := Gui(, "RMT指令编辑器")
        this.Gui := MyGui
        MyGui.SetFont("S11 W550 Q2", MySoftData.FontType)

        PosX := 15
        PosY := 15
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), "操作类型：")
        PosX += 80
        this.OperTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w160", PosX, PosY - 3), this.CmdStrArr)

        PosX := 100
        PosY += 40
        con := MyGui.Add("Button", Format("x{} y{} w100 h40", PosX, PosY), "确定")
        con.OnEvent("Click", (*) => this.OnSureBtnClick())
        MyGui.Show(Format("w{} h{}", 300, 120))
    }

    OnSureBtnClick() {
        isValid := this.CheckIfValid()
        if (!isValid)
            return

        CommandStr := "RMT指令_" this.OperTypeCon.Text
        action := this.SureBtnAction
        action(CommandStr)
        this.Gui.Hide()
    }

    CheckIfValid() {
        if (this.OperTypeCon.Text == "禁用键鼠") {
            tipStr := (
                "此操作将 立即禁用键盘和鼠标输入，您将无法通过键鼠操作计算机！`n"
                "重要须知：`n"
                "- 以管理员身份运行本软件，否则该指令无效。`n"
                "- 多线程下，宏按键会被屏蔽。要宏按键生效，多线程数请设置成0。`n"
                '- 务必后续执行 "启用键鼠"，否则输入设备将保持禁用状态！`n'
                "是否确认禁用？"
            )
            result := MsgBox(tipStr, "禁用键鼠（需管理员权限）", "4")
            if (result == "No")
                return false
        }

        if (this.OperTypeCon.Text == "启用键鼠") {
            tipStr := (
                "- 必须 以管理员身份运行本软件，否则该指令无效。`n"
            )
            MsgBox(tipStr, "启用键鼠（需管理员权限）")
        }

        return true
    }
}
