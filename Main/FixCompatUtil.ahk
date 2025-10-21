#Requires AutoHotkey v2.0

;1.0.8F4到新版本兼容
Compat1_0_8F4FlodInfo(FoldInfo) {
    if (FoldInfo == "" || ObjHasOwnProp(FoldInfo, "FrontInfoArr"))
        return

    FoldInfo.FrontInfoArr := []
    loop FoldInfo.RemarkArr.Length {
        FoldInfo.FrontInfoArr.Push("")
    }
}
