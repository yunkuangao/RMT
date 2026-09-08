#Requires AutoHotkey v2.0

; =====================================================================
; UIManager —— 统一 UI/样式管理器（v2 设计 P0.9 地基）
; 详见《deliverables/统一UI管理器设计方案.md》：
;   - 窗口档案（mode/size/minSize/modal）+ 生命周期状态机 + 模态栈 + 事件通知
;   - UiWindow 基类收编窗口骨架：ShowGui 五步 / 关闭三路径 / 模态恢复 / 防重入
; 约定：
;   - 主进程专属（仅 GlobalUtil.ahk include），严禁进入 Worker 链
;     （Worker 需感知时用动态名解析：fnName := "UIManager" + IsSet(%fnName%)）
;   - 模态栈只做登记与查询（Top/IsOpen）；owner 指派沿用调用方设置 OwnerHwnd 的现状
;   - 字号铁律：字号只由主题字号系统决定，任何窗口不得因拉伸改变字号
; =====================================================================

class UIManager {
    static _registry := Map()   ; name → {win, profile, state}
    static _stack := []         ; 模态栈（z-order = 数组序，栈顶 = 末元素）
    static _listeners := Map()  ; "Name.event" → [handler]

    ; —— 注册（ShowGui 时自动登记；重复 Register 以最新实例为准）——
    static Register(name, win) {
        this._registry[name] := {win: win, profile: win.Profile(), state: "REGISTERED"}
    }

    ; —— 打开（状态机防重入：SHOWING 中拒绝，防连点）——
    static Show(name, params*) {
        e := this._Get(name)
        if (e.state == "SHOWING")
            return false
        e.state := "SHOWING"
        e.win.ShowGui(params*)
        if (e.profile.modal && IsObject(e.win.ui) && !e.win._closed)
            this._stack.Push(e.win)
        e.state := "VISIBLE"
        return true
    }

    static Close(name) {
        this._Get(name).win._CloseWindow()
    }

    static IsOpen(name) {
        if (!this._registry.Has(name))
            return false
        e := this._registry[name]
        return IsObject(e.win.ui) && !e.win._closed
    }

    static Top() {
        return this._stack.Length ? this._stack[this._stack.Length] : ""
    }

    ; —— 断点档位（委派 UILayout，统一入口）——
    static Breakpoint() {
        return UILayout.Breakpoint()
    }

    ; —— 事件观察者（pattern = "Name.event"，closed 事件携带 ""）——
    static On(pattern, handler) {
        if (!this._listeners.Has(pattern))
            this._listeners[pattern] := []
        this._listeners[pattern].Push(handler)
    }

    static _Emit(name, event) {
        pattern := name "." event
        if (!this._listeners.Has(pattern))
            return
        for h in this._listeners[pattern] {
            hh := h   ; AHK 坑：handler 一律局部中转后调用
            hh(name)
        }
    }

    static _Push(win) {
        this._stack.Push(win)
    }

    static _Remove(win) {
        i := 1
        for w in this._stack {
            if (w = win) {
                this._stack.RemoveAt(i)
                return
            }
            i++
        }
    }

    static _Get(name) {
        if (!this._registry.Has(name))
            throw TargetError("UIManager: 窗口未注册 「" name "」")
        return this._registry[name]
    }
}

; =====================================================================
; UiWindow —— 对话框窗口基类（骨架收编）
; 子类只写：Name/Title/Profile/Build/Events/OnInit/AfterShow/OnValidate/OnSave
; 基类实现：ShowGui 五步 / 关闭三路径（系统X·标题栏钮·确定）/ 模态恢复 / 防重入 / 揭盖
; =====================================================================

class UiWindow {
    __new() {
        this.ParentTile := ""
        this.ui := ""
        this.SureBtnAction := ""
        this.OwnerHwnd := ""
        this._closed := true
    }

    ; ---- 子类钩子 ----
    Name() => ""                ; 注册名（事件 pattern 用；"" = 不登记）
    Profile() {
        ; 默认档案（v2.0 方法体禁止单行花括号，块方法统一换行写）
        return {mode: "elastic", size: "700x240", minSize: "", modal: true, breakpoint: true}
    }
    Title() => ""
    Build(body) {
        ; body 已是 Row(1) 的 Grid，业务只往里加内容
    }
    Events() => []              ; 额外事件 [{ctrl, ev, handler}]
    OnInit(cmd) {
        ; 数据回填
    }
    AfterShow() {
        ; 揭盖前的窗口内联动（如类型显隐）
    }
    OnValidate() => true
    OnSave() => ""              ; 确定动作：保存数据并返回 CommandStr
    OnClosed() {
        ; 关闭完成通知（可选）
    }

    ; ---- 骨架（子类不再写）----
    ShowGui(cmd := "") {
        global MainSoftData
        n := this.Name()
        if (n != "")
            UIManager.Register(n, this)
        if (IsObject(this.ui) && !this._closed)
            this._CloseWindow()
        this._BuildAndShow()
        if (this.OwnerHwnd != "" && MainSoftData.IsModalSubGui)
            try SafeGuiFromHwnd(this.OwnerHwnd).Opt("+Disabled")
        this.OnInit(cmd)
        this.AfterShow()
        this._ShowWindow()
    }

    Hwnd() {
        return (IsObject(this.ui) && this.ui.HasProp("wpfHwnd")) ? this.ui.wpfHwnd : 0
    }

    _Profile() {
        p := this.Profile()
        def := {mode: "elastic", size: "700x240", minSize: "", modal: true, breakpoint: true}
        if (IsObject(p))
            for k, v in p.OwnProps()   ; v2.0 普通对象不可直接 for-in，须 OwnProps()
                def.%k% := v
        return def
    }

    _BuildAndShow() {
        global MainSoftData
        this._closed := false
        p := this._Profile()
        title := this.ParentTile this.Title()
        titleHeight := UILayout.TitleH

        main := XAML_Generator("Grid").Background("{DynamicResource BgColor}").TextElement_FontSize(XAMLHost.FontSize())
        main.Rows(titleHeight, "*")
        XAMLHost.AddTitleBar(main, title, titleHeight)

        body := main.Add("Grid").Grid_Row(1).Margin("10,8")
        this.Build(body)

        tmp := StrReplace(XAML_TEMPLATE, "%CaptionHeight%", titleHeight)
        this.ui := XAMLHost(StrReplace(tmp, "%app%", main.ToString()), "", this.OwnerHwnd)
        ; 尺寸/标题统一注入入口（档位折算宽度；Opacity=0 为揭盖前提）
        if (RegExMatch(p.size, "i)^(\d+)x(\d+)$", &m)) {
            w := Integer(m[1]), h := Integer(m[2])
            if (p.breakpoint)
                w := UILayout.DialogWidth(w)
            xaml := this.ui.xaml   ; VarRef 参数不能吃属性表达式，局部变量中转
            XAMLHost.SetWindowSize(&xaml, w, h, this._EscapeXml(title))
            this.ui.xaml := xaml
        }
        this.ui.xaml := StrReplace(this.ui.xaml, '%resources%', '')

        ; 壳级事件：关闭三路径 + 确定
        this.ui.OnEvent("Window", "Closing", ObjBindMethod(this, "OnWindowClosing"))
        this.ui.OnEvent("Window", "LoadedHwnd", ObjBindMethod(this, "OnWindowLoad"))
        this.ui.OnEvent("BtnClosePanel", "Click", ObjBindMethod(this, "OnCancelClick"))
        this.ui.OnEvent("BtnOk", "Click", ObjBindMethod(this, "OnSureClick"))
        for e in this.Events()
            this.ui.OnEvent(e.ctrl, e.ev, e.handler)
    }

    _ShowWindow() {
        if (!XamlWin.Open(this.ui, "", XamlWin.Owner(this))) {
            this._closed := true
            return
        }
        UIManager._Push(this)
    }

    OnWindowLoad(state, ctrl, event) {
        XamlWin.OnLoadTheme(this.ui)
    }

    OnWindowClosing(state, ctrl, event) {
        if (this._closed)
            return
        this._RestoreOwner()
        this.ui := ""
        this._closed := true
        this._AfterClosed()
    }

    OnCancelClick(state, ctrl, event) {
        this._CloseWindow()
    }

    OnSureClick(state, ctrl, event) {
        if (!this.OnValidate())
            return
        cmd := this.OnSave()
        this._CloseWindow()
        action := this.SureBtnAction
        if (action != "")
            action(cmd)
    }

    _CloseWindow() {
        wasOpen := IsObject(this.ui) && !this._closed
        if (IsObject(this.ui))
            try this.ui.Update("Window", "Close", "")
        this._RestoreOwner()
        this.ui := ""
        this._closed := true
        if (wasOpen)
            this._AfterClosed()
    }

    _RestoreOwner() {
        global MainSoftData
        if (this.OwnerHwnd != "" && MainSoftData.IsModalSubGui)
            try SafeGuiFromHwnd(this.OwnerHwnd).Opt("-Disabled")
    }

    _AfterClosed() {
        UIManager._Remove(this)
        n := this.Name()
        if (n != "")
            UIManager._Emit(n, "closed")
        this.OnClosed()
    }

    _EscapeXml(s) {
        s := StrReplace(s, "&", "&amp;")
        s := StrReplace(s, "<", "&lt;")
        s := StrReplace(s, ">", "&gt;")
        s := StrReplace(s, '"', "&quot;")
        return s
    }
}
