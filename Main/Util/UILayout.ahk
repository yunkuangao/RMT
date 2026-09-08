#Requires AutoHotkey v2.0
; =====================================================================
; UILayout —— 界面布局原子工具（主进程专属，仅 GlobalUtil.ahk include）
; 依据《deliverables/统一UI管理器设计方案.md》（v2 合并版）组件分级 Atom 层：
;   1. 断点档位：开窗时按主屏工作区 DIP 宽选档（Wide/Normal/Compact）
;   2. 对话框开窗宽度：按档位折算，超屏自动收窄（配合引擎 Viewbox 兜底）
;   3. FormRow / FormRow2：标签+输入 弹性行原子（Grid Auto|* 列）
;      —— 替代 StackPanel 横排 + 固定 Width，消除字体调大/多语言溢出裁切
; 约定：
;   - 绝不进入 Worker 链（Work.ahk / WorkGlobalUtil.ahk）
;   - 行内控件由调用方 .Add() 创建；弹性控件统一用
;     .MaxWidth(上限).HorizontalAlignment("Stretch") 替代 .Width(定值)
; =====================================================================

class UILayout {
    ; ---- 断点档位（主屏工作区 DIP 宽）----
    ; Wide ≥1600｜Normal 1280–1599｜Compact <1280
    static Breakpoint() {
        dpi := DllCall("GetDpiForSystem", "UInt") / 96.0
        w := (dpi > 0) ? (A_ScreenWidth / dpi) : A_ScreenWidth
        return (w >= 1600) ? "Wide" : (w >= 1280) ? "Normal" : "Compact"
    }

    static IsCompact() {
        return this.Breakpoint() = "Compact"
    }

    ; 对话框开窗宽度（DIP）：
    ;   Compact 档整体收 15%（内容靠引擎 Viewbox DownOnly 兜底）；
    ;   任何档位超可用宽（屏宽-64）则钳制，保证不溢出屏幕。
    static DialogWidth(designW) {
        dpi := DllCall("GetDpiForSystem", "UInt") / 96.0
        avail := Floor((dpi > 0 ? A_ScreenWidth / dpi : A_ScreenWidth)) - 64
        w := designW
        if (this.IsCompact())
            w := Floor(designW * 0.85)
        return (w > avail) ? avail : w
    }

    ; ---- 尺寸 token（设计文档 6.1 实测清单提取，禁再写裸定高）----
    ; 语义：Input=输入行 24｜Row=标准行(下拉/勾选) 26｜RowSm=紧凑行 28｜Btn=对话框按钮 30｜BtnLg=大按钮 34
    ; 动态属性（2026-09-08）：每次取值按当前字号缩放（k=字号/15 钳 0.8~1.6，与 S() 同源）——
    ; 大字号构建期控件高不再定死 24/26 裁字（快捷方式行等实证）；调用方 .Height(UILayout.CtrlH.Row) 语法不变。
    ; 引擎 FitControlHeightToFont 仍负责运行期广播平移，双层语义不冲突（原值记录取烘焙值）。
    static CtrlH {
        get {
            return {Input: this.S(24), Row: this.S(26), RowSm: this.S(28), Btn: this.S(30), BtnLg: this.S(34)}
        }
    }
    ; 标题栏高（原 73 处裸字面量的收口；与引擎 CaptionHeight 同源）
    static TitleH := "30"

    ; ---- 结构尺寸字号化（P1.5：侧栏/页签/宏行列宽随主题字号缩放）----
    ; 基准字号 15；比例钳 0.8~1.6，防极端字号把框架拉爆
    static StructScale() {
        fs := (IsObject(MainSoftData) && MainSoftData.HasProp("FontSize")) ? Integer(MainSoftData.FontSize) : 15
        k := fs / 15
        return (k < 0.8) ? 0.8 : (k > 1.6) ? 1.6 : k
    }
    ; 构建期结构尺寸换算：UILayout.S(130) → 字号 15 时 = 130（默认观感不变）
    static S(w) {
        return Round(w * this.StructScale())
    }
    ; 无钳缩放（不做 0.8~1.6 钳制，按实际字号比例）：
    ; 用于整窗尺寸这类需要完整跟随字号的场景（调用方自行用屏幕工作区封顶）
    static StructScaleU() {
        fs := (IsObject(MainSoftData) && MainSoftData.HasProp("FontSize") && MainSoftData.FontSize > 0) ? Integer(MainSoftData.FontSize) : 15
        return fs / 15
    }
    static SU(w) {
        return Round(w * this.StructScaleU())
    }

    ; 输入框样式原子（6.1 #6/#9 提取，替代 55 文件重复的颜色五件套）：
    ;   InputBg/InputText/InputStroke + BorderThickness 1 + Padding "4,0" + 垂直居中；
    ; h>0 时同时 Height/MinHeight 定高。链式返回，调用方继续 .Grid_Column()/.MaxWidth() 等。
    static Input(ctrl, h := 0) {
        ctrl.Style("{DynamicResource InputBoxStyle}")
            .Padding("4,0").VerticalContentAlignment("Center")
        if (h > 0)
            ctrl.Height(h).MinHeight(h)
        return ctrl
    }

    ; ---- 表单行原子 ----
    ; 单字段行：Grid 两列 Auto|*；列0 放标签，返回行容器；
    ; 调用方在返回行上 .Add(控件).Grid_Column(1) 并自行做弹性化。
    static FormRow(parent, rowName, labelText) {
        row := parent.Add("Grid")
        if (rowName != "")
            row.Name(rowName)
        row.Cols("Auto", "*")
        row.Add("TextBlock").Grid_Column(0).Text(labelText)
            .VerticalAlignment("Center").Margin("0,0,4,0")
        return row
    }

    ; 双字段行：Grid 四列 Auto|*|Auto|*；列0/列2 放标签，返回行容器；
    ; 调用方控件放 Grid_Column(1) / Grid_Column(3)。
    static FormRow2(parent, rowName, label1, label2, gap := 12) {
        row := parent.Add("Grid")
        if (rowName != "")
            row.Name(rowName)
        row.Cols("Auto", "*", "Auto", "*")
        row.Add("TextBlock").Grid_Column(0).Text(label1)
            .VerticalAlignment("Center").Margin("0,0,4,0")
        row.Add("TextBlock").Grid_Column(2).Text(label2)
            .VerticalAlignment("Center").Margin(gap ",0,4,0")
        return row
    }

    ; 行尾动作按钮列（如 WinPanel 的「编辑」「浏览」）：Auto 列专用
    ; 返回按钮；调用方 .Grid_Column(尾列) 放置。
    static RowButton(parent, colIndex, btnName, text, width := 64) {
        return parent.Add("Button").Grid_Column(colIndex).Name(btnName)
            .Content(text).MinHeight(UILayout.CtrlH.Input).Height(UILayout.CtrlH.Input).MinWidth(width)
            .Margin("6,0,0,0").Cursor("Hand")
    }
}
