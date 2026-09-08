#Requires AutoHotkey v2.0

; =============================================================================
; RMT 通用提示/确认弹窗
; 窗口骨架与主题配置、快捷键编辑一致：XAML_TEMPLATE + 标题栏 + BgColor 内容区。
; =============================================================================
class RmtDialog {
    ; 单按钮提示（确定）
    static Info(msg, title := "") {
        RmtDialog._Trace("Info enter msg=" RmtDialog._Clip(msg))
        try {
            RmtDialog._Show(String(msg), title != "" ? title : GetLang("提示"), [GetLang("确定")], Chr(0xE946), "{DynamicResource TextMain}", true)
        } catch as e {
            RmtDialog._Log("Info", e)
        }
    }

    ; 确定/取消，返回是否点了确定
    static Confirm(msg, title := "") {
        RmtDialog._Trace("Confirm enter msg=" RmtDialog._Clip(msg))
        try {
            btn := RmtDialog._Show(String(msg), title != "" ? title : GetLang("提示"), [GetLang("确定"), GetLang("取消")], Chr(0xE814), "{DynamicResource Accent}", false)
            ok := (btn == GetLang("确定"))
            RmtDialog._Trace("Confirm result ok=" ok " btn=" btn)
            return ok
        } catch as e {
            RmtDialog._Log("Confirm", e)
            return false
        }
    }

    ; 只读正文右键：只换菜单外观（与 AI 助手同色/同结构），不改弹窗正文字号
    static _AttachReadonlyCtxMenu(el) {
        if (!IsObject(el))
            return
        ff := (IsSet(MainSoftData) && MainSoftData.HasProp("FontType") && MainSoftData.FontType != "") ? MainSoftData.FontType : "微软雅黑"
        cm := el.Add("FrameworkElement.ContextMenu").Add("ContextMenu")
            .MinWidth("140").Placement("MousePoint").FontFamily(ff)
            .Background("{DynamicResource DropdownBg}").BorderBrush("{DynamicResource InputStroke}")
            .BorderThickness("1").Foreground("{DynamicResource TextMain}")
        cm.Add("MenuItem").Header(GetLang("复制")).SetMarkup("Command", "Copy")
        cm.Add("Separator")
        cm.Add("MenuItem").Header(GetLang("全选")).SetMarkup("Command", "SelectAll")
    }

    static _LinePx(line, fs) {
        px := 0.0
        loop parse line {
            if (Ord(A_LoopField) <= 127)
                px += fs * 0.55
            else
                px += fs
        }
        return px
    }

    ; 短句按最长行收窗宽，避免左右大块留白；超过 2 行走宽窗 + 边框
    static _MsgLayout(msg, fs := 15) {
        nl := 1
        longest := 0.0
        if (InStr(msg, "`n")) {
            nl := 0
            loop parse msg, "`n" {
                nl++
                w := RmtDialog._LinePx(A_LoopField, fs)
                if (w > longest)
                    longest := w
            }
        } else {
            longest := RmtDialog._LinePx(msg, fs)
        }
        tall := nl > 2
        w := tall ? 460 : Min(340, Max(268, Round(longest + 36)))
        return { Tall: tall, WinW: w, Lines: nl }
    }

    ; 物理像素 → DIP（注入 XAML 的 Left/Top 按 DIP 解释，见 MainWindowXaml/CustomMsgBox 先例）
    static _PhysToDip(px, scale) {
        return Round(px / scale)
    }

    ; 估算整窗高度（建窗前预算，配合 Manual 落位一次到位，误差 ≤80px 可接受）：
    ; 标题栏 30 + 正文区（行数×fs×1.4 + margin；长文案边框 padding 16 + panel margin 24，MaxHeight 340 封顶）
    ; + 按钮行（32 + Margin 0,14,0,4）+ 下 margin 4 + 安全余量 8
    static _EstH(msg, fs, lay, winW) {
        lines := 0
        loop parse String(msg), "`n" {
            line := StrReplace(A_LoopField, "`r", "")
            ; 正文可用宽：短文案 panel margin 24 / 长文案 panel margin 24 + 边框 padding 16
            areaW := lay.Tall ? winW - 40 : winW - 24
            seg := Ceil(RmtDialog._LinePx(line, fs) / areaW)
            if (seg < 1)
                seg := 1
            lines += seg
        }
        if (lines < 1)
            lines := 1
        if (lay.Tall)
            bodyH := Min(lines * fs * 1.4, 340) + 16 + 24
        else
            bodyH := lines * fs * 1.4 + 32
        return Round(30 + bodyH + 50 + 4 + 8)
    }

    ; 鼠标所在监视器工作区中心（DIP），返回 'WindowStartupLocation="Manual" Left="x" Top="y"'
    ; GetCursorPos 物理坐标 → MonitorGetWorkArea 找所在屏 → 按系统 DPI 换算 DIP；
    ; 找不到所在屏（含副屏负坐标遍历失败）回退监视器 1。与 CustomMsgBox_CenterAttr 同款实现，自足不跨文件。
    static _CenterAttr(winW, winH) {
        scale := 1.0
        try scale := DllCall("GetDpiForSystem", "UInt") / 96.0
        if (scale < 1.0)
            scale := 1.0
        ; 鼠标物理坐标（GetCursorPos 返回物理像素，进程 DPI aware）
        pt := Buffer(8, 0)
        try DllCall("GetCursorPos", "Ptr", pt)
        mx := NumGet(pt, 0, "Int")
        my := NumGet(pt, 4, "Int")
        ; 找鼠标所在监视器的工作区（MonitorGetWorkArea 返回物理像素）
        wl := 0, wt := 0, wr := 0, wb := 0
        found := false
        try {
            loop MonitorGetCount() {
                MonitorGetWorkArea(A_Index, &wl, &wt, &wr, &wb)
                if (mx >= wl && mx < wr && my >= wt && my < wb) {
                    found := true
                    break
                }
            }
            if (!found)
                MonitorGetWorkArea(1, &wl, &wt, &wr, &wb)
        }
        l := RmtDialog._PhysToDip(wl, scale)
        t := RmtDialog._PhysToDip(wt, scale)
        r := RmtDialog._PhysToDip(wr, scale)
        b := RmtDialog._PhysToDip(wb, scale)
        x := l + ((r - l) - winW) // 2
        y := t + ((b - t) - winH) // 2
        if (x < l)
            x := l
        if (y < t)
            y := t
        return 'WindowStartupLocation="Manual" Left="' x '" Top="' y '"'
    }

    static _Show(msg, title, buttons, iconChar, iconColor, offsetMsg := false) {
        owner := 0
        try {
            if (IsSet(MyMainWin) && IsObject(MyMainWin) && IsObject(MyMainWin.ui) && MyMainWin.ui.wpfHwnd)
                owner := MyMainWin.ui.wpfHwnd
        }
        try XAMLHost.EnsureDaemonHealthy()

        titleHeight := UILayout.TitleH
        fs := XAMLHost.FontSize()
        lay := RmtDialog._MsgLayout(msg, fs)
        winW := lay.WinW
        ; 建窗前估高并预算落位点：Manual + Left/Top 让引擎一次落位，无开窗后跳变
        winH := RmtDialog._EstH(msg, fs, lay, winW)
        centerAttr := RmtDialog._CenterAttr(winW, winH)
        fontFamily := ""
        try {
            if (IsSet(MainSoftData) && MainSoftData.HasProp("FontType") && MainSoftData.FontType != "")
                fontFamily := MainSoftData.FontType
        }

        main := XAML_Generator("Grid").Background("{DynamicResource BgColor}")
        if (fontFamily != "")
            main.TextElement_FontFamily(fontFamily)
        main.TextElement_FontSize(fs)
        main.Rows(titleHeight, "Auto")

        chrome := XAMLHost.AddTitleBar(main, title, titleHeight, "BtnClosePanel", "", iconChar, iconColor)
        closeBtn := chrome.Close

        body := main.Add("Border").Grid_Row(1).Background("{DynamicResource BgColor}")
        panel := body.Add("StackPanel").Margin(lay.Tall ? "12,12,12,12" : "12,16,12,12")

        if (!lay.Tall) {
            ; 短文案：整段居中，窗宽按最长行收紧
            msgTb := panel.Add("TextBlock").Text(msg).Foreground("{DynamicResource TextMain}").FontSize(fs)
                .HorizontalAlignment("Center").VerticalAlignment("Center")
                .TextAlignment("Center").TextWrapping("Wrap")
                .MaxWidth(winW - 24).Margin("0,4,0,0")
        } else {
            ; 长文案：边框包住只读文本，可框选复制、不可编辑
            roStyle := '<Style TargetType="TextBox"><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="TextBox"><ScrollViewer x:Name="PART_ContentHost" Background="Transparent" Padding="0"/></ControlTemplate></Setter.Value></Setter></Style>'
            box := panel.Add("Border")
                .BorderBrush("{DynamicResource ControlBorder}").BorderThickness("1").CornerRadius("4")
                .Background("{DynamicResource InputBg}").Padding("10,8,6,8")
            msgTb := box.Add("TextBox").Name("DlgMsgText").Text(msg).Foreground("{DynamicResource TextMain}").FontSize(fs)
                .Background("Transparent").BorderThickness("0").Padding("0")
                .IsReadOnly("True").IsReadOnlyCaretVisible("True").AcceptsReturn("True")
                .TextWrapping("Wrap").MaxHeight(340)
                .HorizontalScrollBarVisibility("Disabled").VerticalScrollBarVisibility("Auto")
                .CaretBrush("{DynamicResource TextMain}")
            msgTb.InjectResources(roStyle)
            RmtDialog._AttachReadonlyCtxMenu(msgTb)
        }
        if (fontFamily != "")
            msgTb.FontFamily(fontFamily)

        PrimaryBtnStyle := '<Style TargetType="Button"><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="3"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="{DynamicResource ActionHoverBg}"/><Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource ActionHoverStroke}"/></Trigger><Trigger Property="IsPressed" Value="True"><Setter TargetName="bd" Property="Background" Value="{DynamicResource ActionPressBg}"/><Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource ActionHoverStroke}"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>'
        btnRow := panel.Add("StackPanel").Orientation("Horizontal").HorizontalAlignment("Center").Margin("0,14,0,4")
        okText := GetLang("确定")
        cancelText := GetLang("取消")
        loop buttons.Length {
            idx := A_Index
            btnText := buttons[idx]
            gap := (idx < buttons.Length) ? "0,0,58,0" : "0"
            btnEl := btnRow.Add("Button").Name("Btn" idx).Content(btnText)
                .Background("{DynamicResource ActionBg}").Foreground("{DynamicResource ActionText}")
                .FontWeight("Bold").BorderBrush("{DynamicResource ActionStroke}").BorderThickness("1")
                .FontSize(fs).Cursor("Hand").Width(80).Height(32).Margin(gap)
            if (btnText == okText)
                btnEl.IsDefault("True")
            if (btnText == cancelText)
                btnEl.IsCancel("True")
            btnEl.InjectResources(PrimaryBtnStyle)
        }

        tmp := StrReplace(XAML_TEMPLATE, "%CaptionHeight%", titleHeight)
        ui := XAMLHost(StrReplace(tmp, "%app%", main.ToString()), "", owner)
        ; 走与设置/编辑窗完全一致的管线（字号按 delta 缩放、标题栏补丁统一标题字号与关闭钮、视觉缩放），
        ; 因此不设 skipFontScale：正文声明基准字号→缩放到主题字号，标题由补丁强制为主题字号+2。
        safeTitle := RmtDialog._XmlEsc(title)
        ui.xaml := StrReplace(ui.xaml, 'Width="940" Height="700"', 'Title="' safeTitle '" ShowInTaskbar="False" Width="' winW '" SizeToContent="Height" Topmost="True" Opacity="0"')
        ; 模板自带 WindowStartupLocation="CenterScreen"（落在主屏/光标屏垂直居中偏上），
        ; 换成鼠标所在监视器工作区中心的 Manual Left/Top，与 CustomMsgBox 同款、引擎一次落位。
        ui.xaml := StrReplace(ui.xaml, 'WindowStartupLocation="CenterScreen"', centerAttr)
        if (fontFamily != "")
        ui.xaml := StrReplace(ui.xaml, 'CornerRadius="{DynamicResource WindowRadius}"', 'CornerRadius="{DynamicResource PanelRadius}"')
        ui.xaml := StrReplace(ui.xaml, '%resources%', '<CornerRadius x:Key="PanelRadius">8</CornerRadius>')

        resultObj := { Button: "", Instance: ui }
        ownerDisabled := false

        ui.OnEvent("Window", "Closing", (state, ctrl, event) => RmtDialog._OnClosing(resultObj, owner))
        ui.OnEvent("Window", "LoadedHwnd", (state, ctrl, event) => RmtDialog._OnLoad(ui, owner))
        ui.OnEvent("BtnClosePanel", "Click", (state, ctrl, event) => RmtDialog._OnPick(ui, resultObj, "Closed", owner))
        loop buttons.Length {
            idx := A_Index
            btnText := buttons[idx]
            ui.OnEvent("Btn" idx, "Click", ObjBindMethod(RmtDialog, "_OnPick", ui, resultObj, btnText, owner))
        }

        RmtDialog._Trace("Show start owner=" owner " w=" winW " fs=" fs)
        if (!XamlWin.Open(ui, "", owner)) {
            try {
                dir := A_ScriptDir "\Log"
                if !DirExist(dir)
                    DirCreate(dir)
                FileAppend(ui.xaml, dir "\RmtDialog.last.xaml", "UTF-8")
            }
            throw Error("Dialog window failed to open")
        }

        while (resultObj.Button == "" && WinExist("ahk_id " ui.wpfHwnd)) {
            if (ui.wpfHwnd && owner && !ownerDisabled) {
                try WinSetEnabled(0, "ahk_id " owner)
                ownerDisabled := true
            }
            Sleep(50)
        }
        if (resultObj.Button == "")
            resultObj.Button := "Closed"
        if (owner) {
            try WinSetEnabled(1, "ahk_id " owner)
        }
        RmtDialog._Trace("Show done btn=" resultObj.Button)
        return resultObj.Button
    }

    static _OnLoad(ui, owner, state := "", ctrl := "", event := "") {
        XamlWin.OnLoadTheme(ui)
    }

    static _OnClosing(resultObj, owner, state := "", ctrl := "", event := "") {
        if (resultObj.Button == "")
            resultObj.Button := "Closed"
        if (owner) {
            try WinSetEnabled(1, "ahk_id " owner)
        }
    }

    static _OnPick(ui, resultObj, btnText, owner, state := "", ctrl := "", event := "") {
        resultObj.Button := btnText
        if (owner) {
            try WinSetEnabled(1, "ahk_id " owner)
        }
        try ui.Update("Window", "Close", "")
    }

    static _XmlEsc(s) {
        s := StrReplace(String(s), "&", "&amp;")
        s := StrReplace(s, "<", "&lt;")
        s := StrReplace(s, ">", "&gt;")
        s := StrReplace(s, '"', "&quot;")
        return s
    }

    static _LogPath() {
        dir := A_ScriptDir "\Log"
        if !DirExist(dir)
            DirCreate(dir)
        return dir "\RmtDialog.log"
    }

    static _Trace(msg) {
        try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") "." SubStr(A_TickCount, -2) " " msg "`n", RmtDialog._LogPath(), "UTF-8")
    }

    static _Clip(s, n := 80) {
        s := StrReplace(String(s), "`n", " ")
        return StrLen(s) > n ? SubStr(s, 1, n) "..." : s
    }

    static _Log(where, e) {
        try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " [" where "] " e.Message "`n" e.Stack "`n`n", RmtDialog._LogPath(), "UTF-8")
    }
}
