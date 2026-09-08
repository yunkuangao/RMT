#Requires AutoHotkey v2.0

SelfCheckMissingFiles() {
    ; 带 F 后缀的测试版（如 1.2F23）无对应资源 tag，不提供自动下载
    if (RegExMatch(RMT_VERSION, "i)\d+\.\d+F")) {
        RmtDialog.Info(GetLang("带 F 后缀的测试版本不支持文件校验自动下载") "`n"
            . GetLang("资源仓库仅对应正式版本 tag（如 v1.2_x64）"), GetLang("RMT 资源自检"))
        return
    }

    version := RMT_VERSION  ; 使用完整版本名，不做 *.* 截断（如 1.3.5 -> tag v1.3.5_x64）
    arch := A_PtrSize == 8 ? "x64" : "x86"
    bitArch := A_PtrSize == 8 ? "64bit" : "32bit"
    tag := "v" version "_" arch
    baseUrl := "https://gh-proxy.com/https://github.com/zclucas/RMTAssets/releases/download/" tag "/"

    criticalMap := Map(
        "Plugins\RMT\RMT.dll", "RMT.dll",
        "Plugins\IbInputSimulator.dll", "IbInputSimulator.dll",
        "Audio\Start.wav", "Start.wav",
        "Audio\End.wav", "End.wav",
        "Plugins\ViGEm\ViGEmWrapper.dll", "ViGEmWrapper.dll",
        "Joy\ViGEmBus.exe", "ViGEmBus.exe",
        "Joy\Xbox按键映射.png", "Xbox.png",
        "Plugins\AHK-XAML\lib\dep\ahk-xaml.dll", "ahk-xaml.dll",
        "Plugins\AHK-XAML\lib\dep\WpfAnimatedGif\WpfAnimatedGif.dll", "WpfAnimatedGif.dll",
        "Plugins\OpenCV\" arch "\RMT_OpenCV.dll", "RMT_OpenCV.dll",
        "Plugins\OpenCV\" arch "\opencv_world481.dll", "opencv_world481.dll",
        "Plugins\Voice\" arch "\VoiceDll.dll", "VoiceDll.dll",
        "Plugins\Voice\" arch "\sherpa-onnx-c-api.dll", "sherpa-onnx-c-api.dll",
        "Plugins\Voice\" arch "\onnxruntime.dll", "onnxruntime.dll",
        "Plugins\Voice\" arch "\onnxruntime_providers_shared.dll", "onnxruntime_providers_shared.dll",
        "Plugins\Voice\models\kws\decoder-epoch-13-avg-2-chunk-16-left-64.onnx", "kws_decoder.onnx",
        "Plugins\Voice\models\kws\encoder-epoch-13-avg-2-chunk-16-left-64.int8.onnx", "kws_encoder.int8.onnx",
        "Plugins\Voice\models\kws\joiner-epoch-13-avg-2-chunk-16-left-64.int8.onnx", "kws_joiner.int8.onnx",
        "Plugins\Voice\models\kws\tokens.txt", "kws_tokens.txt",
        "Plugins\RapidOcr\" bitArch "\RapidOcrOnnx.dll", "RapidOcrOnnx.dll",
        "Plugins\ScreenCapture\ScreenCapture.exe", "ScreenCapture.exe",
        "Plugins\AhiDriver\AutoHotInterception.dll", "AutoHotInterception.dll",
        "Plugins\AhiDriver\" arch "\interception.dll", "interception_" arch ".dll",
        "Plugins\AhiDriver\installer\install.ps1", "install.ps1",
        "Plugins\AhiDriver\installer\安装卸载.bat", "InstallUninstall.bat",
        "Plugins\AhiDriver\installer\install-interception.exe", "install-interception.exe",
        "Plugins\RapidOcr\ch_models\ch_PP-OCRv6_det.onnx", "ch_PP-OCRv6_det.onnx",
        "Plugins\RapidOcr\ch_models\ch_PP-OCRv6_rec.onnx", "ch_PP-OCRv6_rec.onnx",
        "Plugins\RapidOcr\ch_models\ppocrv6_tiny_dict.txt", "ppocrv6_tiny_dict.txt",
        "Lang\中文.txt", "chinese.txt",
        "Lang\English.txt", "English.txt",
        "Thread\Work.exe", "Work.exe",
        "index.html", "index.html")

    optionalMap := Map(
        "Plugins\MouseControl.dll", "MouseControl.dll",
        "MinTool\PlayAudio.vbs", "PlayAudio.vbs",
        "MinTool\CountDown.exe", "CountDown.exe",
        "Plugins\AhiDriver\installer\使用说明.txt", "InstallReadme.txt")

    icoFileList := ["Arr.png", "Condition.png", "Control.png", "Extract.png", "False.png",
        "FileIO.png", "GreenColor.png", "IcoPause.ico", "If.png", "IfPro.png",
        "Input.png", "Interval.png", "Key.png", "KeyCheck.png", "Loop.png",
        "LoopBody.png", "LoopCount.png", "Mouse.png", "Move.png", "MovePro.png",
        "Operation.png", "Output.png", "RedColor.png", "Run.png", "Search.png",
        "SearchPro.png", "Sub.png", "Target.png", "TextOps.png", "True.png",
        "Var.png", "WeiXin.png", "WindowManage.png", "YellowColor.png",
        "ZhiFuBao.png", "rabit.ico", "rabit.png", "Comment.png", "ScreenShot.png"]

    missingCritical := []
    missingOptional := []
    needIcoZip := false
    for localPath, assetName in criticalMap {
        fullPath := A_WorkingDir "\" localPath
        if (!FileExist(fullPath))
            missingCritical.Push([localPath, assetName])
    }
    for localPath, assetName in optionalMap {
        fullPath := A_WorkingDir "\" localPath
        if (!FileExist(fullPath))
            missingOptional.Push([localPath, assetName])
    }
    icoDir := A_WorkingDir "\Images\Soft"
    for fileName in icoFileList {
        if (!FileExist(icoDir "\" fileName)) {
            needIcoZip := true
            break
        }
    }

    allMissing := []
    for item in missingCritical
        allMissing.Push(item)
    for item in missingOptional
        allMissing.Push(item)
    if (needIcoZip)
        allMissing.Push(["Images\Soft\_ico_bundle", "ico.zip"])

    totalMissing := allMissing.Length
    if (totalMissing == 0) {
        RmtDialog.Info(GetLang("资源文件校验通过，未发现缺失文件"), GetLang("RMT 资源自检"))
        return
    }

    fileListStr := ""
    showCount := Min(allMissing.Length, 5)
    loop showCount
        fileListStr .= "  · " allMissing[A_Index][2] "`n"
    if (allMissing.Length > 5)
        fileListStr .= "  ... 等 " allMissing.Length " 个文件"

    detailStr := ""
    if (missingCritical.Length > 0)
        detailStr .= "⚠ 关键文件 (" missingCritical.Length ")`n"
    if (missingOptional.Length > 0)
        detailStr .= "可选文件 (" missingOptional.Length ")"
    tipMsg := "检测到 " totalMissing " 个资源文件缺失`n" detailStr "`n`n" fileListStr "`n版本：" tag "`n点击【确定】从 GitHub 自动下载，点击【取消】跳过（部分功能可能不可用）"

    if (!RmtDialog.Confirm(tipMsg, "RMT 资源自检")) {
        if (missingCritical.Length > 0) {
            criticalNames := ""
            for item in missingCritical
                criticalNames .= item[2] "`n"
            RmtDialog.Info("以下关键文件缺失，软件可能无法正常运行：`n`n" criticalNames "`n`n请在QQ群 837661891 或者项目仓库寻求帮助", "RMT 警告")
        }
        return
    }

    ; 下载进度窗（XAML 迁移版）：pg["StatusText"].Value 等调用语法经 facade 保持不变
    pg := _RmtDownloadProgress(totalMissing)

    global _dlCancelled := false

    successCount := 0
    failList := []
    total := allMissing.Length

    for idx, item in allMissing {
        if (_dlCancelled)
            break

        localPath := item[1]
        assetName := item[2]
        fullPath := A_WorkingDir "\" localPath
        downloadUrl := baseUrl assetName

        pg["StatusText"].Value := "(" idx "/" total ") 正在下载：" assetName
        pg["DetailText"].Value := ""
        pg["ProgressBar"].Value := idx - 1

        downloaded := false

        if (assetName == "ico.zip") {
            zipPath := A_ScriptDir "\_rmt_temp_ico.zip"
            targetDir := A_WorkingDir "\Images\Soft"
            downloaded := DownloadAndUnzipIco(downloadUrl, zipPath, targetDir, icoFileList, &pg)
            if (downloaded == "cancel")
                break
        } else {
            SplitPath(fullPath, &outName, &outDir)
            if (outDir != "" && !DirExist(outDir))
                DirCreate(outDir)
            if (FileExist(fullPath))
                FileDelete(fullPath)

            result := DownloadAsync(downloadUrl, fullPath, 120, &pg)
            if (result == "cancel")
                break
            downloaded := (result == "ok")
        }

        if (downloaded) {
            successCount++
            pg["DetailText"].Value := "✓ 下载完成"
        } else {
            failList.Push(assetName)
            pg["DetailText"].Value := "✗ 下载失败"
        }

        pg["ProgressBar"].Value := idx
    }

    pg.Destroy()
    ToolTip()

    if (_dlCancelled) {
        stillCritical := false
        for item in missingCritical {
            fullPath := A_WorkingDir "\" item[1]
            if (!FileExist(fullPath)) {
                stillCritical := true
                break
            }
        }

        cancelMsg := "下载已取消。`n已成功下载 " successCount "/" total " 个文件。`n可再次点击「文件校验」继续下载。"
        if (stillCritical)
            cancelMsg .= "`n`n存在关键文件未下载完成，软件可能无法正常工作。`n`n请在QQ群 837661891 或者项目仓库寻求帮助"
        RmtDialog.Info(cancelMsg, "RMT 资源自检")
        return
    }

    if (failList.Length > 0) {
        failStr := ""
        stillCritical := false
        for name in failList {
            failStr .= name "`n"
            for item in missingCritical {
                if (item[2] == name)
                    stillCritical := true
            }
        }
        RmtDialog.Info("下载完成：成功 " successCount "/" total "`n`n以下文件下载失败（可能是网络问题）：`n" failStr, "RMT 资源自检")

        if (stillCritical) {
            RmtDialog.Info("存在关键文件下载失败，软件可能无法正常工作。`n`n请检查网络连接后重启软件重试。`n`n如仍无法解决，请在QQ群 837661891 或者项目仓库寻求帮助", "RMT 警告")
        }
    }
}

DownloadAsync(url, savePath, timeoutSec, &pgGui) {
    maxRetry := 3
    Loop maxRetry {
        if (_dlCancelled)
            return "cancel"

        if (A_Index > 1)
            pgGui["DetailText"].Value := Format("重试 ({}/{})...", A_Index - 1, maxRetry - 1)

        result := DownloadOnce(url, savePath, timeoutSec, &pgGui)
        if (result == "ok")
            return "ok"
        if (result == "cancel")
            return "cancel"
        if (FileExist(savePath))
            FileDelete(savePath)

        if (A_Index < maxRetry)
            Sleep(1000)
    }
    return "fail"
}

DownloadOnce(url, savePath, timeoutSec, &pgGui) {
    try {
        req := ComObject("Msxml2.XMLHTTP")
        req.open("GET", url, true)
        req.send()

        startTime := A_TickCount
        Loop {
            if (_dlCancelled)
                return "cancel"

            if (req.readyState == 4)
                break

            elapsed := (A_TickCount - startTime) / 1000
            if (elapsed > timeoutSec)
                return "timeout"

            pgGui["DetailText"].Value := "下载中... (" Round(elapsed, 1) "s)"
            Sleep(200)
        }

        if (req.status == 200) {
            stream := ComObject("ADODB.Stream")
            stream.Type := 1
            stream.Open()
            stream.Write(req.responseBody)
            stream.SaveToFile(savePath, 2)
            stream.Close()
            return "ok"
        }
        return "fail"
    } catch as e {
        pgGui["DetailText"].Value := "✗ 下载异常: " e.Message
        return "fail"
    }
}

DownloadAndUnzipIco(downloadUrl, zipPath, targetDir, expectedFiles, &pgGui) {
    try {
        if (FileExist(zipPath))
            FileDelete(zipPath)

        SplitPath(targetDir, , &parentDir)
        if (parentDir && !DirExist(parentDir))
            DirCreate(parentDir)
        if !DirExist(targetDir)
            DirCreate(targetDir)

        pgGui["StatusText"].Value := "正在下载: ico.zip"
        dlResult := DownloadAsync(downloadUrl, zipPath, 120, &pgGui)
        if (dlResult != "ok")
            return dlResult == "cancel" ? "cancel" : false

        pgGui["StatusText"].Value := "正在解压: ico.zip"
        pgGui["DetailText"].Value := ""

        shell := ComObject("Shell.Application")
        zipNamespace := shell.NameSpace(zipPath)
        destNamespace := shell.NameSpace(targetDir)
        if (!(zipNamespace && destNamespace)) {
            pgGui["DetailText"].Value := "✗ Shell.NameSpace 获取失败"
            return false
        }
        destNamespace.CopyHere(zipNamespace.Items(), 16 | 4 | 1024)

        foundCount := 0
        lastFoundCount := 0
        stableCount := 0
        stableNeed := 5
        loop 120 {
            if (_dlCancelled)
                return "cancel"
            foundCount := 0
            for fn in expectedFiles {
                if (FileExist(targetDir "\" fn))
                    foundCount++
            }
            pgGui["DetailText"].Value := "已解压 " foundCount "/" expectedFiles.Length " 个文件"
            if (foundCount == lastFoundCount && foundCount > 0) {
                stableCount++
                if (stableCount >= stableNeed)
                    break
            } else {
                stableCount := 0
                lastFoundCount := foundCount
            }
            Sleep(500)
        }

        if (foundCount < expectedFiles.Length) {
            loop Files, targetDir "\*" "D" {
                if (A_LoopFileName == "." || A_LoopFileName == "..")
                    continue
                subDir := A_LoopFileFullPath
                subCount := 0
                for fn in expectedFiles {
                    if (FileExist(subDir "\" fn)) {
                        try FileMove(subDir "\" fn, targetDir "\" fn, 1)
                        if (FileExist(targetDir "\" fn))
                            subCount++
                    }
                }
                if (subCount > 0) {
                    foundCount := 0
                    for fn in expectedFiles {
                        if (FileExist(targetDir "\" fn))
                            foundCount++
                    }
                    break
                }
            }
        }

        try FileDelete(zipPath)
        return foundCount == expectedFiles.Length
    } catch as e {
        pgGui["DetailText"].Value := "✗ 异常: " e.Message
        try FileDelete(zipPath)
        return false
    }
}

; =====================================================================
; 下载进度窗 —— XAML 迁移版（原传统 Gui + AddProgress）
; facade 保持原调用语法：pg["StatusText"].Value := ... / pg["ProgressBar"].Value
;                       / pg.Destroy()
; 窗口仅在主界面（XAML 框架已就绪）触发「文件校验」时出现，可安全用 XAMLHost
; =====================================================================

class _RmtDownloadProgress {
    __New(total) {
        this.ui := ""
        this._BuildAndShow(total)
    }

    __Item[name] {
        get => _RmtDownloadCtrl(this.ui, name)
    }

    _BuildAndShow(total) {
        global MainSoftData
        title := GetLang("RMT 资源下载")
        titleHeight := UILayout.TitleH

        main := XAML_Generator("Grid").Background("{DynamicResource BgColor}").TextElement_FontSize(XAMLHost.FontSize())
        main.Rows(titleHeight, "*")

        ; === 标题栏 ===
        XAMLHost.AddTitleBar(main, title, titleHeight)

        ; === 内容区 ===
        body := main.Add("Grid").Grid_Row(1).Margin("16,12,16,14")
        body.Rows("Auto", "Auto", "Auto", "Auto")
        body.Add("TextBlock").Name("StatusText").Grid_Row(0)
            .Text(GetLang("准备下载...")).TextWrapping("Wrap")
            .Foreground("{DynamicResource TextMain}")
        body.Add("ProgressBar").Name("ProgressBar").Grid_Row(1)
            .Minimum("0").Maximum(String(total)).Value("0")
            .Height("18").Margin("0,10,0,0")
        body.Add("TextBlock").Name("DetailText").Grid_Row(2)
            .Text("").TextWrapping("Wrap")
            .Foreground("{DynamicResource TextSub}").Margin("0,8,0,0")
        btnRow := body.Add("StackPanel").Grid_Row(3).Orientation("Horizontal")
            .HorizontalAlignment("Right").Margin("0,14,0,0")
        btnRow.Add("Button").Name("BtnCancelDownload")
            .Content(GetLang("取消下载")).Width("100").Height(UILayout.CtrlH.Btn).MinHeight(UILayout.CtrlH.Btn)

        ; === 创建 XAMLHost（+AlwaysOnTop → Topmost，居中显示）===
        tmp := StrReplace(XAML_TEMPLATE, "%CaptionHeight%", titleHeight)
        this.ui := XAMLHost(StrReplace(tmp, "%app%", main.ToString()), "", 0)
        this.ui.xaml := StrReplace(this.ui.xaml, 'Width="940" Height="700"'
            , 'Title="' title '" Width="420" Height="220" Topmost="True" Opacity="0"')
        this.ui.xaml := StrReplace(this.ui.xaml, '%resources%', '')

        ; === 事件 ===
        this.ui.OnEvent("Window", "Closing", ObjBindMethod(this, "OnWindowClosing"))
        this.ui.OnEvent("Window", "LoadedHwnd", ObjBindMethod(this, "OnWindowLoad"))
        this.ui.OnEvent("BtnCancelDownload", "Click", ObjBindMethod(this, "OnCancelClick"))

        XamlWin.Open(this.ui, "", "", true)
    }

    OnWindowLoad(state, ctrl, event) {
        XamlWin.OnLoadTheme(this.ui)
    }

    ; 手动关闭窗口 = 取消下载（原版关窗会令后续赋值抛异常，这里做成优雅取消）
    OnWindowClosing(state, ctrl, event) {
        global _dlCancelled
        _dlCancelled := true
        this.ui := ""
    }

    OnCancelClick(state, ctrl, event) {
        global _dlCancelled
        _dlCancelled := true
    }

    Destroy() {
        if (IsObject(this.ui))
            try this.ui.Update("Window", "Close", "")
        this.ui := ""
    }
}

; 控件值代理：TextBlock → Text，ProgressBar → Value；读取走 Query
class _RmtDownloadCtrl {
    __New(ui, name) {
        this._ui := ui
        this._name := name
    }

    Value {
        get {
            ui := this._ui
            if (IsObject(ui) && ui.HasProp("wpfHwnd") && ui.wpfHwnd)
                return ui.Query(this._name)
            return ""
        }
        set {
            ui := this._ui
            if (!IsObject(ui))
                return
            prop := (this._name == "ProgressBar") ? "Value" : "Text"
            ui.Update(this._name, prop, String(value))
        }
    }
}
