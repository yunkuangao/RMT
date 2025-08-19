#Requires AutoHotkey v2.0
#Include OperationSubGui.ahk

class OperationGui {
    __new() {
        this.Gui := ""
        this.SureBtnAction := ""
        this.VariableObjArr := []
        this.RemarkCon := ""
        this.Data := ""
        this.OperationSubGui := ""

        this.IsGlobalCon := ""
        this.IsIgnoreExistCon := ""
        this.ToggleConArr := []
        this.NameConArr := []
        this.OperationConArr := []
        this.UpdateNameConArr := []
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

    AddGui() {
        MyGui := Gui(, "运算指令编辑")
        this.Gui := MyGui
        MyGui.SetFont("S10 W550 Q2", MySoftData.FontType)

        PosX := 20
        PosY := 10
        MyGui.Add("Text", Format("x{} y{} w{} h{}", PosX, PosY, 50, 30), "备注:")
        PosX += 50
        this.RemarkCon := MyGui.Add("Edit", Format("x{} y{} w{}", PosX, PosY - 5, 150), "")

        PosX := 10
        PosY += 30
        this.IsGlobalCon := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 110), "创建/更新选项：")

        PosX += 115
        this.IsGlobalCon := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 90), "全局变量")

        PosX += 120
        this.IsIgnoreExistCon := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 150), "变量存在忽略操作")

        PosX := 10
        PosY += 25
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), "开关")
        PosX += 50
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), "选择/输入")
        PosX += 150
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), "运算表达式")
        PosX += 230
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY), " 创建/更新")

        PosY += 25
        PosX := 15
        con := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 30))
        this.ToggleConArr.Push(con)

        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 35, PosY - 3, 120), [])
        this.NameConArr.Push(con)

        con := MyGui.Add("Edit", Format("x{} y{} w{}", PosX + 160, PosY - 3, 200), "")
        con.Enabled := false
        this.OperationConArr.Push(con)

        con := MyGui.Add("Button", Format("x{} y{} w{} Center", PosX + 365, PosY - 4, 50), "编辑")
        con.OnEvent("Click", (*) => this.OnEditVariableBtnClick(1))

        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 425, PosY - 3, 120), [])
        this.UpdateNameConArr.Push(con)

        PosY += 35
        PosX := 15
        con := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 30))
        this.ToggleConArr.Push(con)

        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 35, PosY - 3, 120), [])
        this.NameConArr.Push(con)

        con := MyGui.Add("Edit", Format("x{} y{} w{}", PosX + 160, PosY - 3, 200), "")
        con.Enabled := false
        this.OperationConArr.Push(con)

        con := MyGui.Add("Button", Format("x{} y{} w{} Center", PosX + 365, PosY - 4, 50), "编辑")
        con.OnEvent("Click", (*) => this.OnEditVariableBtnClick(2))

        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 425, PosY - 3, 120), [])
        this.UpdateNameConArr.Push(con)

        PosY += 35
        PosX := 15
        con := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 30))
        this.ToggleConArr.Push(con)

        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 35, PosY - 3, 120), [])
        this.NameConArr.Push(con)

        con := MyGui.Add("Edit", Format("x{} y{} w{}", PosX + 160, PosY - 3, 200), "")
        con.Enabled := false
        this.OperationConArr.Push(con)

        con := MyGui.Add("Button", Format("x{} y{} w{} Center", PosX + 365, PosY - 4, 50), "编辑")
        con.OnEvent("Click", (*) => this.OnEditVariableBtnClick(3))

        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 425, PosY - 3, 120), [])
        this.UpdateNameConArr.Push(con)

        PosY += 35
        PosX := 15
        con := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY, 30))
        this.ToggleConArr.Push(con)

        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 35, PosY - 3, 120), [])
        this.NameConArr.Push(con)

        con := MyGui.Add("Edit", Format("x{} y{} w{}", PosX + 160, PosY - 3, 200), "")
        con.Enabled := false
        this.OperationConArr.Push(con)

        con := MyGui.Add("Button", Format("x{} y{} w{} Center", PosX + 365, PosY - 4, 50), "编辑")
        con.OnEvent("Click", (*) => this.OnEditVariableBtnClick(4))

        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5", PosX + 425, PosY - 3, 120), [])
        this.UpdateNameConArr.Push(con)

        PosY += 40
        PosX := 250
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{}", PosX, PosY, 100, 40), "确定")
        btnCon.OnEvent("Click", (*) => this.OnClickSureBtn())

        MyGui.Show(Format("w{} h{}", 650, 280))
    }

    Init(cmd) {
        cmdArr := cmd != "" ? StrSplit(cmd, "_") : []
        this.SerialStr := cmdArr.Length >= 2 ? cmdArr[2] : GetSerialStr("Operation")
        this.RemarkCon.Value := cmdArr.Length >= 3 ? cmdArr[3] : ""
        this.Data := this.GetOperationData(this.SerialStr)

        this.IsGlobalCon.Value := this.Data.IsGlobal
        this.IsIgnoreExistCon.Value := this.Data.IsIgnoreExist
        loop 4 {
            this.ToggleConArr[A_Index].Value := this.Data.ToggleArr[A_Index]
            this.NameConArr[A_Index].Delete()
            this.NameConArr[A_Index].Add(this.VariableObjArr)
            this.NameConArr[A_Index].Text := this.Data.NameArr[A_Index]
            this.OperationConArr[A_Index].Value := this.Data.OperationArr[A_Index]
            this.UpdateNameConArr[A_Index].Delete()
            this.UpdateNameConArr[A_Index].Add(this.VariableObjArr)
            this.UpdateNameConArr[A_Index].Text := this.Data.UpdateNameArr[A_Index]
        }
    }

    GetCommandStr() {
        hasRemark := this.RemarkCon.Value != ""
        CommandStr := "运算_" this.Data.SerialStr
        if (hasRemark) {
            CommandStr .= "_" this.RemarkCon.Value
        }
        return CommandStr
    }

    OnSureOperationBtnClick(index, command, SymbolArr, ValueArr) {
        con := this.OperationConArr[index]
        con.Value := command
        this.Data.SymbolGroups[index] := SymbolArr
        this.Data.ValueGroups[index] := ValueArr
    }

    OnEditVariableBtnClick(index) {
        if (this.OperationSubGui == "") {
            this.OperationSubGui := OperationSubGui()
        }
        Name := this.NameConArr[index].Text
        if (Name == "" || Name == "空") {
            MsgBox("选择/输入1不可为空")
            return
        }
        SymbolArr := this.Data.SymbolGroups[index]
        ValueArr := this.Data.ValueGroups[index]
        this.OperationSubGui.SureBtnAction := (index, command, SymbolArr, ValueArr) => this.OnSureOperationBtnClick(
            index, command, SymbolArr, ValueArr)
        this.OperationSubGui.ShowGui(index, Name, this.OperationConArr[index].Value, SymbolArr, ValueArr)
    }

    OnClickSureBtn() {
        valid := this.CheckIfValid()
        if (!valid)
            return
        this.SaveOperationData()
        action := this.SureBtnAction
        action(this.GetCommandStr())
        this.Gui.Hide()
    }

    CheckIfValid() {
        return true
    }

    GetOperationData(SerialStr) {
        saveStr := IniRead(OperationFile, IniSection, SerialStr, "")
        if (!saveStr) {
            data := OperationData()
            data.SerialStr := SerialStr
            return data
        }

        data := JSON.parse(saveStr, , false)
        return data
    }

    SaveOperationData() {
        loop 4 {
            this.Data.ToggleArr[A_Index] := this.ToggleConArr[A_Index].Value
            this.Data.NameArr[A_Index] := this.NameConArr[A_Index].Text
            this.Data.OperationArr[A_Index] := this.OperationConArr[A_Index].Value
            this.Data.UpdateNameArr[A_Index] := this.UpdateNameConArr[A_Index].Text
        }
        this.Data.IsGlobal := this.IsGlobalCon.Value
        this.Data.IsIgnoreExist := this.IsIgnoreExistCon.Value

        ; 添加全局变量，方便下拉选取
        if (this.Data.IsGlobal)
            loop 4 {
                if (this.Data.ToggleArr[A_Index])
                    MySoftData.GlobalVariMap[this.Data.UpdateNameArr[A_Index]] := true
            }

        saveStr := JSON.stringify(this.Data, 0)
        IniWrite(saveStr, OperationFile, IniSection, this.Data.SerialStr)
        if (MySoftData.DataCacheMap.Has(this.Data.SerialStr)) {
            MySoftData.DataCacheMap.Delete(this.Data.SerialStr)
        }
    }
}
