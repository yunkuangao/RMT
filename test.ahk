;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; WGC (Windows Graphics Capture) 后台窗口截图 - 测试工具
; 使用 thqby/ahk2_lib 的 wincapture 库
; 适用于 Win10 1903 (>=18362) 及硬件加速窗口
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#Requires AutoHotkey v2.0
#SingleInstance Force
#Include "wincapture\wincapture.ahk"

saveDir := A_ScriptDir "\"
DirCreate(saveDir)

; ====== 全局状态 ======
global gWgcCount := 0, gWgcTotalMs := 0, gWgcMinMs := 0, gWgcMaxMs := 0
global gInitMemBase := 0
global gWgcInitialized := false, gWgcObj := 0

gInitMemBase := GetProcessMemory()

; ====== GUI ======
MyGui := Gui("+AlwaysOnTop", "WGC 截图测试工具")
MyGui.SetFont("s10")

; 顶部控件
MyGui.Add("Text",, "目标窗口:")
edtHwnd := MyGui.Add("Edit", "vEdtHwnd w200 ReadOnly")
MyGui.Add("Text", "xm", "标题:")
lblTitle := MyGui.Add("Text", "vLblTitle w200")

btnBind := MyGui.Add("Button", "w100 Default", "绑定窗口 (F1)")
btnRun := MyGui.Add("Button", "wp", "测试截图 (F5)")
btnRun50 := MyGui.Add("Button", "wp", "连续50次 (F6)")
btnReset := MyGui.Add("Button", "wp", "重置统计")
btnOpen := MyGui.Add("Button", "wp", "打开文件夹")
btnRelease := MyGui.Add("Button", "wp", "释放资源")

; 分隔线
MyGui.Add("Text", "xm h2 w440 BackgroundGray")

; 结果区域
MyGui.SetFont("Bold")
MyGui.Add("Text", "xm y+8 w440 Center", "--- WGC 截图结果 ---")
MyGui.SetFont()

lblInit := MyGui.Add("Text", "xm w430 vLblInit",
    Format("基线: {:.1f}MB`n状态: 未初始化", gInitMemBase))

lblResult := MyGui.Add("Text", "xm y+4 w430 r8 Border vLblResult", "等待 F5 测试...")

btnBind.OnEvent("Click", OnBind)
btnRun.OnEvent("Click", OnRun)
btnRun50.OnEvent("Click", OnRun50)
btnReset.OnEvent("Click", OnReset)
btnOpen.OnEvent("Click", (*) => Run('explorer.exe "' saveDir '"'))
btnRelease.OnEvent("Click", OnRelease)
MyGui.OnEvent("Close", (*) => ExitApp)
MyGui.Show()

; 快捷键
F1:: OnBind()
F5:: OnRun()
F6:: OnRun50()


; ==================== 按钮事件 ====================

OnBind(*) {
    global gWgcInitialized, gWgcObj
    MouseGetPos ,, &hwnd
    title := WinGetTitle("ahk_id " hwnd)
    edtHwnd.Value := hwnd
    lblTitle.Value := title

    if (!gWgcInitialized) {
        计时()
        try {
            gWgcObj := wincapture.WGC(hwnd)
            elapsed := Round(计时())
            gWgcInitialized := true
            initMem := GetProcessMemory() - gInitMemBase
            lblInit.Value := Format("基线: {:.1f}MB`n已绑定: {}`nWGC 初始化 (+{:.1f}MB) 预热耗时: {}ms",
                gInitMemBase, title, initMem, elapsed)
        } catch as e {
            lblInit.Value := Format("基线: {:.1f}MB`n初始化失败: {}", gInitMemBase, e.Message)
        }
    } else {
        ; 已有实例，重新创建（旧实例会自动释放）
        gWgcObj := ""
        try {
            gWgcObj := wincapture.WGC(hwnd)
            lblInit.Value := Format("基线: {:.1f}MB`n已绑定: {}`nWGC 已切换", gInitMemBase, title)
        } catch as e {
            lblInit.Value := Format("基线: {:.1f}MB`n切换失败: {}", gInitMemBase, e.Message)
        }
    }
}

OnRun(*) {
    global gWgcCount, gWgcTotalMs, gWgcMinMs, gWgcMaxMs
    global gWgcInitialized, gWgcObj

    if (!gWgcInitialized) {
        lblResult.Value := "请先绑定窗口 (F1)"
        return
    }

    mem1 := GetProcessMemory()
    t1 := A_TickCount

    bb := gWgcObj.capture()

    t2 := A_TickCount
    ms := t2 - t1
    mem2 := GetProcessMemory()

    ; 保存截图到文件
    if (bb) {
        fileName := FormatTime(A_Now, "yyyyMMdd_HHmmss") "_wgc.png"
        SaveHBITMAPToFile(bb.HBITMAP().ptr, saveDir fileName)
    }

    ; 累计统计
    gWgcCount++
    gWgcTotalMs += ms
    gWgcMinMs := (gWgcMinMs == 0 || ms < gWgcMinMs) ? ms : gWgcMinMs
    gWgcMaxMs := (ms > gWgcMaxMs) ? ms : gWgcMaxMs

    avg := Round(gWgcTotalMs / gWgcCount, 1)

    lblResult.Value := Format(
        "#{} 本次: {}ms | 内存: +{:.1f}MB | 尺寸: {}x{} | 已保存图片`n--- 统计 ---`n次数: {}  平均: {}ms`n最小: {}ms  最大: {}ms",
        gWgcCount, ms, mem2-mem1, bb.width, bb.height,
        gWgcCount, avg, gWgcMinMs, gWgcMaxMs)
}

OnRun50(*) {
    global gWgcCount, gWgcTotalMs, gWgcMinMs, gWgcMaxMs
    global gWgcObj

    if (!gWgcInitialized) {
        lblResult.Value := "请先绑定窗口 (F1)"
        return
    }

    totalStart := A_TickCount
    Loop 50 {
        bb := gWgcObj.capture()
    }
    totalElapsed := A_TickCount - totalStart
    avg := Round(totalElapsed / 50, 1)

    ; 更新统计
    gWgcCount += 50
    gWgcTotalMs += totalElapsed
    gWgcMinMs := (gWgcMinMs == 0 || avg < gWgcMinMs) ? avg : gWgcMinMs
    gWgcMaxMs := (totalElapsed > gWgcMaxMs) ? totalElapsed : gWgcMaxMs

    overallAvg := Round(gWgcTotalMs / gWgcCount, 1)

    lblResult.Value := Format(
        "连续50次完成 | 总耗时: {}ms | 平均: {}ms/帧 | 尺寸: {}x{}`n--- 累计统计 ---`n次数: {}  平均: {}ms`n最小: {}ms  最大: {}ms",
        totalElapsed, avg, bb.width, bb.height,
        gWgcCount, overallAvg, gWgcMinMs, gWgcMaxMs)
}

OnReset(*) {
    global gWgcCount, gWgcTotalMs, gWgcMinMs, gWgcMaxMs
    gWgcCount := 0, gWgcTotalMs := 0, gWgcMinMs := 0, gWgcMaxMs := 0
    lblResult.Value := "等待 F5 测试..."
}

OnRelease(*) {
    global gWgcInitialized, gWgcObj
    gWgcObj := ""
    gWgcInitialized := false
    lblInit.Value := Format("基线: {:.1f}MB`n状态: 已释放", gInitMemBase)
}


; ==================== 辅助函数 ====================

SaveHBITMAPToFile(hBitmap, filePath) {
    static pToken := 0, init := false
    if !init {
        si := Buffer(A_PtrSize == 8 ? 24 : 16, 0)
        NumPut("UChar", 1, si)
        DllCall("gdiplus\GdiplusStartup", "ptr*", &pToken, "ptr", si.ptr, "ptr", 0)
        init := true
    }
    pBitmap := 0
    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hBitmap, "ptr", 0, "ptr*", &pBitmap)
    enc := Buffer(16, 0), GUID := "{557CF400-1A04-11D3-9A73-0000F81EF32E}"
    DllCall("ole32\CLSIDFromString", "wstr", GUID, "ptr", enc.ptr)
    DllCall("gdiplus\GdipSaveImageToFile", "ptr", pBitmap, "wstr", filePath, "ptr", enc.ptr, "ptr", 0)
    DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
}

GetProcessMemory() {
    static wmiSvc := ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
    pid := ProcessExist()
    for proc in wmiSvc.ExecQuery('SELECT * FROM Win32_Process WHERE ProcessId=' . pid)
        return proc.WorkingSetSize / 1024 / 1024
    return 0
}

计时() {
    static 开始 := 0, 频率 := 0, 耗时 := 0, 结束 := 0
    if !开始 {
        DllCall("QueryPerformanceFrequency", "Int64*", &频率)
        DllCall("QueryPerformanceCounter", "Int64*", &开始)
    } else {
        DllCall("QueryPerformanceCounter", "Int64*", &结束)
        耗时 := (结束 - 开始) / 频率 * 1000
        开始 := 0
    }
    return 耗时
}
