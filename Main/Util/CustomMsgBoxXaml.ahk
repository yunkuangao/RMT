; =============================================================================
; CustomMsgBoxXaml —— XAML 版 CustomMsgBox 实现（主进程专属，勿加入 Worker 编译链）
;
; 从 AssetUtil.ahk 原样迁出（函数体一行未改，仅搬家 + 换壳为 class static 方法），
; 仿 Main\GlobalUtil.ahk「主进程专属 include」先例：本文件仅被 GlobalUtil.ahk
; include（主进程链），Worker（Thread\Work.ahk → AssetUtil.ahk）不加载，
; 因此文件内裸引用 XAMLHost / XamlWin / XAML_Generator / XAML_TEMPLATE 无害。
;
; AssetUtil.ahk 中的 CustomMsgBox 薄分发器经动态名解析（仿 XamlUiDiagDaemon 先例）
; 调用本类：CustomMsgBoxXaml.Show(...)。
;
; 签名与返回语义不变：Buttons 为 "|" 分隔按钮文案，返回命中按钮的 1 基索引；
; 点标题栏 X / 关闭 → 0；Esc：按钮里含「取消」时返回其索引，否则返回 0。
; 调用方（RecordUtil.ahk:588 / SettingMgrGui.ahk:447 / MacroGraphGui.ahk:375 /
; AssetUtil.ahk 内部 2 处）零改动。
;
; 布局要点：
;   - 不用 Topmost（避免 FileSelect 被压的 z-order 问题）；owner 取当前激活窗
;     WinExist("A")，owned 窗自然置顶、关闭后无残留。
;   - 建窗前预计算鼠标所在监视器工作区中心的 DIP Left/Top，以
;     WindowStartupLocation="Manual" 写进 XAML，引擎一次落位，无跳变
;     （参考 MainWindowXaml.ahk 677-696 同款先例）。
;   - 注入模板的 Title 必须经 XmlEsc 转义；经生成器 .Text()/.Content()
;     写入的属性引擎已自动转义，勿二次转义。
; =============================================================================
class CustomMsgBoxXaml {

    ; 估算一行文本宽度（px）：ASCII 按 0.55 倍字号，其余（CJK/全角）按 1 倍字号
    static TextPx(line, fs) {
        px := 0.0
        loop parse line {
            if (Ord(A_LoopField) <= 127)
                px += fs * 0.55
            else
                px += fs
        }
        return px
    }

    ; 按文案估算按钮宽度（DIP）：文案宽 + 左右内边距 24，最小 64，防长按钮被裁切
    static BtnW(text, fs) {
        return Max(64, Round(CustomMsgBoxXaml.TextPx(String(text), fs) + 24))
    }

    ; XAML/XML 转义（&quot; &amp; &lt; &gt;）——用于直接注入模板字符串的 Text/Title
    static XmlEsc(s) {
        s := StrReplace(String(s), "&", "&amp;")
        s := StrReplace(s, "<", "&lt;")
        s := StrReplace(s, ">", "&gt;")
        s := StrReplace(s, '"', "&quot;")
        return s
    }

    ; 估算内容区高度（标题栏以下）：换行后行数 × 1.4 倍行高 + 留白 + 按钮行 + 安全余量
    static EstH(Text, fs, areaW := 360) {
        lines := 0
        loop parse String(Text), "`n" {
            line := StrReplace(A_LoopField, "`r", "")
            seg := Ceil(CustomMsgBoxXaml.TextPx(line, fs) / areaW)
            if (seg < 1)
                seg := 1
            lines += seg
        }
        if (lines < 1)
            lines := 1
        textH := lines * fs * 1.4
        ; 18 上边距 + 文本 + 18 按钮上间距 + 34 按钮高 + 16 下边距 + 8 安全余量
        return Round(18 + textH + 18 + 34 + 16 + 8)
    }

    ; 物理像素 → DIP（AHK 注入 XAML 的 Left/Top/Width/Height 按 DIP 解释，见 MainWindowXaml 先例）
    static PhysToDip(px, scale) {
        return Round(px / scale)
    }

    ; DIP → 物理像素
    static DipToPhys(dip, scale) {
        return Round(dip * scale)
    }

    ; 鼠标所在监视器工作区中心：返回 'WindowStartupLocation="Manual" Left="x" Top="y"'
    ; （物理像素取工作区 → 按系统 DPI 换算 DIP；跨屏不同 DPI 时与 MainWindowXaml 同款偏差，待真机再按 per-monitor 细化）
    static CenterAttr(winW, winH) {
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
        l := CustomMsgBoxXaml.PhysToDip(wl, scale)
        t := CustomMsgBoxXaml.PhysToDip(wt, scale)
        r := CustomMsgBoxXaml.PhysToDip(wr, scale)
        b := CustomMsgBoxXaml.PhysToDip(wb, scale)
        x := l + ((r - l) - winW) // 2
        y := t + ((b - t) - winH) // 2
        if (x < l)
            x := l
        if (y < t)
            y := t
        return 'WindowStartupLocation="Manual" Left="' x '" Top="' y '"'
    }

    ; 关闭弹窗并恢复 owner（幂等：按钮 / Esc / 标题栏 X / Window Closing 多路径可触发）
    static Close(ui, st) {
        if (IsObject(ui))
            try ui.Update("Window", "Close", "")
        if (st.Owner && st.OwnerMine)
            try WinSetEnabled(1, "ahk_id " st.Owner)
        if (st.EscTimer != "")
            try SetTimer(st.EscTimer, 0)
    }

    static Show(Text := "", Title := "", Buttons := "") {
        ; ---- 解析按钮（过滤空文案；无有效按钮直接返回 0，避免无按钮窗挂死调用方） ----
        ButtonArray := StrSplit(Buttons, "|")
        valid := []
        for btnText in ButtonArray {
            if (btnText != "")
                valid.Push(btnText)
        }
        if (valid.Length == 0)
            return 0
        ButtonArray := valid
        ButtonCount := ButtonArray.Length

        ; ---- owner：当前激活窗（owned 窗自然置顶，不用 Topmost） ----
        owner := 0
        try {
            h := WinExist("A")
            if (h)
                owner := h
        }
        st := { Result: -1, Owner: owner, OwnerMine: false, CancelIndex: 0, EscTimer: "" }
        ; 仅当 owner 属于本进程才做禁用循环（避免把外部应用的激活窗置灰）
        try st.OwnerMine := (WinGetPID("ahk_id " owner) == WinGetPID("ahk_id " A_ScriptHwnd))
        try XAMLHost.EnsureDaemonHealthy()

        ; ---- 主题与字体 ----
        fs := XAMLHost.FontSize()
        fontFamily := ""
        try {
            if (IsSet(MainSoftData) && MainSoftData.HasProp("FontType") && MainSoftData.FontType != "")
                fontFamily := MainSoftData.FontType
        }

        ; ---- 尺寸预算：按钮宽自适应 + 文本换行估高（建窗前算好，一次落位不跳变） ----
        titleHeight := UILayout.TitleH
        btnWTotal := 0.0
        loop ButtonCount
            btnWTotal += CustomMsgBoxXaml.BtnW(ButtonArray[A_Index], fs)
        btnWTotal += 12 * (ButtonCount - 1)     ; 按钮间距 12
        winW := Max(400, Round(btnWTotal + 48)) ; 按钮行两侧各留 24
        textAreaW := winW - 36                  ; 正文左右边距 18+18
        winH := 30 + CustomMsgBoxXaml.EstH(Text, fs, textAreaW)

        ; ---- XAML 骨架（对齐 RmtDialog：BgColor + AddTitleBar + 动态 Btn{i} + 主题 DynamicResource） ----
        main := XAML_Generator("Grid").Background("{DynamicResource BgColor}")
        if (fontFamily != "")
            main.TextElement_FontFamily(fontFamily)
        main.TextElement_FontSize(fs)
        main.Rows(titleHeight, "*")

        ; 标题栏：询问图标（Chr 0xE814，Accent 色，同 RmtDialog.Confirm）
        XAMLHost.AddTitleBar(main, Title, titleHeight, "BtnClosePanel", "", Chr(0xE814), "{DynamicResource Accent}")

        panel := main.Add("Border").Grid_Row(1).Background("{DynamicResource BgColor}")
            .Add("StackPanel").Margin("18,18,18,16")

        ; 提示文本（支持多行，居中）
        msgTb := panel.Add("TextBlock").Text(String(Text)).Foreground("{DynamicResource TextMain}").FontSize(fs)
            .HorizontalAlignment("Center").VerticalAlignment("Top")
            .TextAlignment("Center").TextWrapping("Wrap")
            .Width(textAreaW)
        if (fontFamily != "")
            msgTb.FontFamily(fontFamily)

        ; 主按钮模板：填充底 + 悬停/按压换色（同 RmtDialog PrimaryBtnStyle）
        PrimaryBtnStyle := '<Style TargetType="Button"><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="3"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="{DynamicResource ActionHoverBg}"/><Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource ActionHoverStroke}"/></Trigger><Trigger Property="IsPressed" Value="True"><Setter TargetName="bd" Property="Background" Value="{DynamicResource ActionPressBg}"/><Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource ActionHoverStroke}"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>'
        ; Ghost 次级模板：Transparent 底 + InputStroke 描边 + TextMain 字色，悬停 DropdownBg
        GhostBtnStyle := '<Style TargetType="Button"><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="3"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="{DynamicResource DropdownBg}"/><Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource InputStroke}"/></Trigger><Trigger Property="IsPressed" Value="True"><Setter TargetName="bd" Property="Background" Value="{DynamicResource DropdownBg}"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>'

        ; 动态按钮：高 34、间距 12、宽度按文案自适应（最小 64）
        btnRow := panel.Add("StackPanel").Orientation("Horizontal").HorizontalAlignment("Center").Margin("0,18,0,0")
        loop ButtonCount {
            idx := A_Index
            btnText := ButtonArray[idx]
            gap := (idx < ButtonCount) ? "0,0,12,0" : "0"
            isCancelBtn := InStr(btnText, GetLang("取消"))
            btnEl := btnRow.Add("Button").Name("Btn" idx).Content(btnText)
                .Width(CustomMsgBoxXaml.BtnW(btnText, fs)).Height(UILayout.CtrlH.BtnLg).MinHeight(UILayout.CtrlH.BtnLg)
                .Margin(gap).FontSize(fs).Cursor("Hand")
            if (idx == 1 && !isCancelBtn) {
                ; 第一个按钮（且非「取消」系文案）：ActionBg 强调填充 + Bold
                btnEl.Background("{DynamicResource ActionBg}").Foreground("{DynamicResource ActionText}")
                    .BorderBrush("{DynamicResource ActionStroke}").BorderThickness("1").FontWeight("Bold")
                btnEl.InjectResources(PrimaryBtnStyle)
            } else {
                ; 其余按钮统一 Ghost 次级样式：含「取消」文案（如 MacroGraphGui 的
                ; 首位「取消」、SettingMgrGui 的「取消导入」）不长得像主操作；
                ; 中间次级按钮（如「追加到末尾」「自增导入」）也不再裸用 WPF 默认模板
                btnEl.Background("Transparent").Foreground("{DynamicResource TextMain}")
                    .BorderBrush("{DynamicResource InputStroke}").BorderThickness("1")
                btnEl.InjectResources(GhostBtnStyle)
            }
        }

        ; 记录「取消」按钮索引（Esc 语义：按钮文案含「取消」时返回其索引，否则 0）
        loop ButtonCount {
            if (InStr(ButtonArray[A_Index], GetLang("取消")))
                st.CancelIndex := A_Index
        }

        ; ---- 建 XAMLHost：Title 经 XmlEsc 注入模板；Manual + Left/Top 一次落位（无跳变） ----
        tmp := StrReplace(XAML_TEMPLATE, "%CaptionHeight%", titleHeight)
        ui := XAMLHost(StrReplace(tmp, "%app%", main.ToString()), "", owner)
        ui.xaml := StrReplace(ui.xaml, 'Width="940" Height="700"', 'Title="' CustomMsgBoxXaml.XmlEsc(String(Title)) '" ShowInTaskbar="False" Width="' winW '" Height="' winH '" Opacity="0"')
        ui.xaml := StrReplace(ui.xaml, 'WindowStartupLocation="CenterScreen"', CustomMsgBoxXaml.CenterAttr(winW, winH))
        if (fontFamily != "")
        ui.xaml := StrReplace(ui.xaml, 'CornerRadius="{DynamicResource WindowRadius}"', 'CornerRadius="{DynamicResource PanelRadius}"')
        ui.xaml := StrReplace(ui.xaml, '%resources%', '<CornerRadius x:Key="PanelRadius">8</CornerRadius>')

        ; ---- 事件（st 对象共享状态，闭包不捕获标量；Bind 固定 idx 避开循环变量闭包坑） ----
        OnPick(idx, *) {
            if (st.Result == -1)
                st.Result := idx
            CustomMsgBoxXaml.Close(ui, st)
        }

        OnClosePanelClick(*) {
            if (st.Result == -1)
                st.Result := 0
            CustomMsgBoxXaml.Close(ui, st)
        }

        OnWindowClosing(state, ctrl, event) {
            if (st.Result == -1)
                st.Result := 0
            if (st.Owner && st.OwnerMine)
                try WinSetEnabled(1, "ahk_id " st.Owner)
            if (st.EscTimer != "")
                try SetTimer(st.EscTimer, 0)
        }

        OnWindowLoad(state, ctrl, event) {
            XamlWin.OnLoadTheme(ui)
        }

        ; Esc 取消轮询（VoiceGui 同款 30ms，仅窗口激活时）
        CheckEsc() {
            hwnd := (IsObject(ui) && ui.HasProp("wpfHwnd")) ? ui.wpfHwnd : 0
            if (!hwnd || !WinActive("ahk_id " hwnd))
                return
            if (GetKeyState("Esc", "P")) {
                st.Result := (st.CancelIndex > 0) ? st.CancelIndex : 0
                CustomMsgBoxXaml.Close(ui, st)
            }
        }

        st.EscTimer := CheckEsc
        ui.OnEvent("Window", "LoadedHwnd", OnWindowLoad)
        ui.OnEvent("Window", "Closing", OnWindowClosing)
        ui.OnEvent("BtnClosePanel", "Click", OnClosePanelClick)
        loop ButtonCount {
            idx := A_Index
            ui.OnEvent("Btn" idx, "Click", OnPick.Bind(idx))
        }

        ; ---- 开窗并等待结果 ----
        if (!XamlWin.Open(ui, "", owner))
            return 0    ; 开窗失败：按「关闭」语义返回 0，不让调用方挂死
        SetTimer(st.EscTimer, 30)   ; 启动 Esc 轮询（VoiceGui 同款 30ms；按钮/关闭/函数退出路径统一取消）

        ownerDisabled := false
        while (st.Result == -1) {
            if (st.Owner && st.OwnerMine && !ownerDisabled) {
                try WinSetEnabled(0, "ahk_id " st.Owner)
                ownerDisabled := true
            }
            if (!(ui.HasProp("wpfHwnd") && ui.wpfHwnd && WinExist("ahk_id " ui.wpfHwnd)))
                break
            Sleep(50)
        }
        if (st.Result == -1)
            st.Result := 0
        if (st.Owner && st.OwnerMine)
            try WinSetEnabled(1, "ahk_id " st.Owner)
        try SetTimer(st.EscTimer, 0)
        return st.Result
    }
}
