#Requires AutoHotkey v2.0

; =================================================================
; 语音触发配置窗口（VoiceGui）—— XAML 迁移版
; 为单条宏配置「语音唤醒关键词」（VoiceKeywordsArr[index]）。
; 启用/禁用由主界面的「禁用」开关控制（ForbidArr），此处不再提供开关。
; 识别与触发由 Main\Util\VoiceUtil.ahk 交给可替换的底层引擎（默认 sherpa-onnx KWS）。
;
; 公开接口保持：ShowGui(tableItem, index, isUpdate := false)
;               / SureBtnAction / edKeywords(.Value) / Cancel(*)
;               / OnSureClick(*) / _DoSure / _LoadToFields / _ReadFields / _ApplyToModel
; edKeywords 为值代理（.Value 读写转发到 XAML TextBox），外部/内部读写方式不变
; =================================================================

#Include ..\Main\Util\JsonUtil.ahk

class VoiceGui {
    __New() {
        this.Gui := ""          ; 兼容字段（XAML 版窗口句柄经 this.ui.wpfHwnd 访问）
        this.hasGui := false    ; 窗口是否存活
        this.ui := ""           ; XAMLHost 实例
        this.tableItem := ""
        this.index := 0
        this.SureBtnAction := ""
        this.edKeywords := _VoiceKeywordValue(this)   ; .Value 读写代理，接口与原 Edit 控件一致
        this._keyTimer := ""
        this._closed := true
    }

    ; ShowGui(tableItem, index)
    ShowGui(tableItem, index, isUpdate := false) {
        if (!CheckIsItemTable(GetTableIndexByID(tableItem.ID)))
            return
        this.tableItem := tableItem
        this.index := index

        ; 读取当前关键词（对象字段，容错）
        curKeywords := ""
        item := tableItem.Items[index]
        if (item)
            curKeywords := item.VoiceKeywords

        ; 复用已存在窗口则刷新（单实例模式）
        if (this.hasGui && IsObject(this.ui) && this.ui.HasProp("wpfHwnd") && this.ui.wpfHwnd) {
            this._LoadToFields(curKeywords)
            return
        }
        this._BuildAndShow()
        this._LoadToFields(curKeywords)
    }

    _EscapeXml(s) {
        s := StrReplace(s, "&", "&amp;")
        s := StrReplace(s, "<", "&lt;")
        s := StrReplace(s, ">", "&gt;")
        s := StrReplace(s, '"', "&quot;")
        return s
    }

    _BuildAndShow() {
        global MainSoftData
        this._closed := false
        title := GetLang("语音关键词")
        this._title := title
        titleHeight := UILayout.TitleH

        main := XAML_Generator("Grid").Background("{DynamicResource BgColor}").TextElement_FontSize(XAMLHost.FontSize())
        main.Rows(titleHeight, "*")

        ; === 标题栏 ===
        XAMLHost.AddTitleBar(main, title, titleHeight)

        ; === 内容区 ===
        body := main.Add("Grid").Grid_Row(1).Margin("16,12,16,14")
        body.Rows("Auto", "Auto", "*", "Auto", "Auto")

        ; 说明文案
        body.Add("TextBlock").Grid_Row(0).Text(GetLang("说出以下关键词即可触发该宏。支持多个关键词，用英文逗号 , 分隔。"))
            .TextWrapping("Wrap").Foreground("{DynamicResource TextMain}")

        ; 关键词输入
        body.Add("TextBlock").Grid_Row(1).Text(GetLang("唤醒关键词："))
            .Foreground("{DynamicResource TextMain}").Margin("0,12,0,4")
        body.Add("TextBox").Name("KeywordInput").Grid_Row(2)
            .AcceptsReturn("True").TextWrapping("Wrap").VerticalScrollBarVisibility("Auto")
            .VerticalContentAlignment("Top").Height("120")
            .Background("{DynamicResource InputBg}").BorderBrush("{DynamicResource InputStroke}")
            .Foreground("{DynamicResource InputText}")

        ; 示例提示
        body.Add("TextBlock").Grid_Row(3).Text(GetLang("示例：开始攻击, 暂停, 保存进度（每个关键词之间用英文逗号分隔）"))
            .TextWrapping("Wrap").Foreground("{DynamicResource TextSub}").Margin("0,8,0,0")

        ; 按钮（BtnSure IsDefault：焦点在多行 TextBox 内时 Enter 换行（TextBox 吞掉 Return），
        ; 焦点在其他位置时 Enter 触发确定——与原 AHK Default 按钮语义一致，替代 AHK 侧 Enter 轮询）
        btnRow := body.Add("StackPanel").Grid_Row(4).Orientation("Horizontal")
            .HorizontalAlignment("Center").Margin("0,14,0,0")
        btnRow.Add("Button").Name("BtnSure").Content(GetLang("确定")).Width("100").Height(UILayout.CtrlH.BtnLg).MinHeight(UILayout.CtrlH.BtnLg).IsDefault("True")
        btnRow.Add("Button").Name("BtnCancel").Content(GetLang("取消")).Width("100").Height(UILayout.CtrlH.BtnLg).MinHeight(UILayout.CtrlH.BtnLg).Margin("12,0,0,0")

        ; === 创建 XAMLHost ===
        tmp := StrReplace(XAML_TEMPLATE, "%CaptionHeight%", titleHeight)
        this.ui := XAMLHost(StrReplace(tmp, "%app%", main.ToString()), "", 0)
        this.ui.xaml := StrReplace(this.ui.xaml, 'Width="940" Height="700"'
            , 'Title="' this._EscapeXml(title) '" Width="470" Height="380" Opacity="0"')
        this.ui.xaml := StrReplace(this.ui.xaml, '%resources%', '')

        ; === 事件 ===
        this.ui.OnEvent("Window", "Closing", ObjBindMethod(this, "OnWindowClosing"))
        this.ui.OnEvent("Window", "LoadedHwnd", ObjBindMethod(this, "OnWindowLoad"))
        this.ui.OnEvent("BtnClosePanel", "Click", ObjBindMethod(this, "OnClosePanelClick"))
        this.ui.OnEvent("BtnSure", "Click", ObjBindMethod(this, "OnSureClick"))
        this.ui.OnEvent("BtnCancel", "Click", ObjBindMethod(this, "OnCancelClick"))

        ; Esc 取消轮询（仅窗口激活时；Enter 由 BtnSure IsDefault 原生处理，见上方按钮注释）
        this._keyTimer := this.CheckHotKey.Bind(this)

        mainGui := IsObject(MainSoftData.MyGui) ? MainSoftData.MyGui.Hwnd : ""
        this.OwnerHwnd := mainGui
        if (!XamlWin.Open(this.ui, "", XamlWin.Owner(this))) {
            this._closed := true
            this.ui := ""
            return
        }
        this.hasGui := true
        SetTimer(this._keyTimer, 30)
    }

    OnWindowLoad(state, ctrl, event) {
        XamlWin.OnLoadTheme(this.ui)
        ; 初始焦点落在输入框（等价原 AHK Gui 默认聚焦首个可聚焦控件）
        try this.ui.Update("KeywordInput", "Focus", "1")
    }

    OnWindowClosing(state, ctrl, event) {
        this.ui := ""
        this.hasGui := false
        this._closed := true
        if (this._keyTimer != "")
            SetTimer(this._keyTimer, 0)
    }

    _LoadToFields(keywords) {
        if (IsObject(this.ui) && this.ui.HasProp("wpfHwnd") && this.ui.wpfHwnd) {
            this.ui.Update("KeywordInput", "Text", String(keywords))
            try WinActivate("ahk_id " this.ui.wpfHwnd)
        }
    }

    ; Esc 取消（仅窗口激活时轮询）；Enter 由 BtnSure IsDefault 原生处理（焦点在
    ; KeywordInput 多行 TextBox 内时为换行，焦点在其他位置时触发确定），不再轮询
    CheckHotKey() {
        hwnd := (IsObject(this.ui) && this.ui.HasProp("wpfHwnd")) ? this.ui.wpfHwnd : 0
        if (!hwnd || !WinActive("ahk_id " hwnd))
            return
        if (GetKeyState("Esc", "P"))
            this.Cancel()
    }

    ; 收集界面值写回模型
    _ReadFields() {
        keywords := Trim(this.edKeywords.Value)
        keywords := Trim(keywords, "，, ")
        ; 统一关键词内分隔符为英文逗号（兼容中文逗号输入）
        keywords := StrReplace(keywords, "，", ",")
        ; 清理空项与多余空格
        parts := []
        for p in StrSplit(keywords, ",") {
            p := Trim(p)
            if (p != "")
                parts.Push(p)
        }
        clean := ""
        for i, p in parts {
            if (i > 1)
                clean .= ","
            clean .= p
        }
        return clean
    }

    ; 写回表格模型（供语音引擎读取）
    _ApplyToModel(keywords) {
        global MyVoiceEngine, MyHotReloadBus
        tableItem := this.tableItem
        index := this.index
        item := tableItem.Items[index]
        if (!item)
            return
        item.VoiceKeywords := keywords
        ; 启用/禁用由主界面「禁用」开关（Forbid）控制；此处仅保证该行语音字段有效

        ; §18 热重载：广播「本行配置已变更」+ 即时落盘，VoiceEngine 订阅者空闲时重建关键词集（不阻塞 UI）
        HotReloadPublish(GetTableIndexByID(tableItem.ID), index)
    }

    OnSureClick(*) {
        this._DoSure()
    }

    _DoSure() {
        keywords := this._ReadFields()
        this._ApplyToModel(keywords)
        ; 刷新主界面表格，让关键词列立即显示新值
        if (IsSet(MyMainWin) && IsObject(MyMainWin))
            MyMainWin.RenderTab(this.tableItem)
        this.Cancel()
        if (IsObject(this.SureBtnAction))
            this.SureBtnAction.Call()
    }

    OnCancelClick(state, ctrl, event) {
        this.Cancel()
    }

    OnClosePanelClick(state, ctrl, event) {
        this.Cancel()
    }

    Cancel(*) {
        if (this._keyTimer != "")
            SetTimer(this._keyTimer, 0)
        if (this.hasGui) {
            if (IsObject(this.ui))
                try this.ui.Update("Window", "Close", "")
            this.ui := ""
            this.hasGui := false
        }
        this._closed := true
    }
}

; =================================================================
; edKeywords 值代理：保持原 Edit 控件 .Value 读写用法
; 读 = Query("KeywordInput")，写 = Update("KeywordInput", "Text", ...)
; =================================================================
class _VoiceKeywordValue {
    __New(owner) {
        this._owner := owner
    }

    Value {
        get {
            o := this._owner
            if (IsObject(o.ui) && o.ui.HasProp("wpfHwnd") && o.ui.wpfHwnd)
                return o.ui.Query("KeywordInput")
            return ""
        }
        set {
            o := this._owner
            if (IsObject(o.ui) && o.ui.HasProp("wpfHwnd") && o.ui.wpfHwnd)
                o.ui.Update("KeywordInput", "Text", String(value))
        }
    }
}
