#Requires AutoHotkey v2.0

ItemDataArr := []
ItemConPoolArr := []

LoadTabItem(tableItem, itemIndex) {
    MyGui := MySoftData.MyGui
    TabPosX := MySoftData.TabPosX
    tableIndex := tableItem.Index
    isMacro := CheckIsMacroTable(tableIndex)
    isNormal := CheckIsNormalTable(tableIndex)
    isTriggerStr := CheckIsStringMacroTable(tableIndex)
    isTiming := CheckIsTimingMacroTable(tableIndex)
    isMenu := CheckIsMenuMacroTable(tableIndex)
    isSubMacro := CheckIsSubMacroTable(tableIndex)
    isNoTriggerKey := CheckIsNoTriggerKey(tableIndex)

    ;颜色
    colorCon := MyGui.Add("Pic", Format("x{} y{} w{} h27", TabPosX + 20, -1000, 29),
    "Images\Soft\GreenColor.png")
    colorCon.Visible := false

    ;序号
    IndexCon := MyGui.Add("Text", Format("x{} y{} w{} +BackgroundTrans", TabPosX + 20, -1000, 30), 0 ".")

    ;备注
    RemarkCon := MyGui.Add("Edit", Format("x{} y{} w180", TabPosX + 60, -1000), "")

    ;触发按键
    btnStr := isTiming ? GetLang("定时") : GetLang("编辑")
    TKBtnCon := MyGui.Add("Button", Format("x{} y{} w100 h29", TabPosX + 250, -1000), btnStr)
    TKBtnCon.Enabled := !isSubMacro && !isMenu

    ;触发类型
    TriggerTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", TabPosX + 360, -1000, 70),
    GetLangArr(["按下", "松开", "松止", "开关", "长按"]))
    TriggerTypeCon.Enabled := isNormal

    ;循环次数
    LoopCon := MyGui.Add("ComboBox", Format("x{} y{} w60 R5 center", TabPosX + 440, -1000), GetLangArr(["无限"]))
    LoopCon.Text := GetLang("无限")
    LoopCon.Enabled := isMacro

    con := MyGui.Add("Button", Format("x{} y{} w60 h29", TabPosX + 510, -1000), GetLang("设置"))

    ;编辑
    con := MyGui.Add("Button", Format("x{} y{} w60 h29", TabPosX + 580, -1000 - 1), GetLang("编辑"))

    ;上
    con := MyGui.Add("Button", Format("x{} y{} w20 h28", TabPosX + 700, -1000), "↑")

    ;下
    con := MyGui.Add("Button", Format("x{} y{} w20 h28", TabPosX + 725, -1000), "↓")

    ;禁用
    ForbidCon := MyGui.Add("Checkbox", Format("x{} y{}", TabPosX + 755, -1000), GetLang("禁用"))

    ;删除
    DelCon := MyGui.Add("Button", Format("x{} y{} w60 h29", TabPosX + 810, -1000), GetLang("删除"))
    DelCon.Enabled := !isMenu

    ;分割线
    if (MySoftData.ShowSplitLine) {
        LineCon := MyGui.Add("Text", Format("x{} y{} w870 h1 0x10", TabPosX + 20, -1000), "") ; SS_ETCHEDHORZ
    }

    tableItem.ColorStateArr.InsertAt(itemIndex, 0)
    tableItem.ColorConArr.InsertAt(itemIndex, colorCon)
    tableItem.IndexConArr.InsertAt(itemIndex, IndexCon)
    tableItem.RemarkConArr.InsertAt(itemIndex, RemarkCon)
    tableItem.TKConArr.InsertAt(itemIndex, TKBtnCon)
    tableItem.TriggerTypeConArr.InsertAt(itemIndex, TriggerTypeCon)
    tableItem.LoopCountConArr.InsertAt(itemIndex, LoopCon)
    tableItem.ForbidConArr.InsertAt(itemIndex, ForbidCon)
}
