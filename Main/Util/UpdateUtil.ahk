; RMT 在线更新 —— 宿主侧只有这么多代码。
;
; 真正的活在 Plugins\Update\RMT.Update.exe（C#，独立进程）里：查 Release、下载、校验、
; 等进程退出、备份替换、重启。这里只负责拉起它、读它写的结果、用自己的对话框问用户。
; 这样 RMT 退出后更新照样能跑完，换语言 / 换平台也只需要换那个 exe。
;
; 文案不走 Lang 文件：更新器的窗口文案在它自己那边（strings 表），
; 设置页的标签走 GetLang，宿主弹窗的键留在代码里省得每次改都动语言包。

class RmtUpdater
{
    ; 同一时间只允许一次检查，避免用户连点
    static _ctx := ""

    ; 轮询计时器的回调。SetTimer 不收「类静态方法的裸引用」（RmtUpdater._Tick 的
    ; Type 虽是 Func，但没绑定类，会被判成 Invalid callback function），必须包成
    ; BoundFunc；而且开 / 关要用同一个对象，所以只建一次存这里。
    ; 名字不能叫 _tick：类里方法名和属性名共用同一命名空间且大小写不敏感，
    ; 会和下面的 _Tick() 撞车。
    static _tickFn := 0

    ; ---------- 路径与参数 ----------

    ; 更新信息全部来自 GitHub Release 本身（tag / body / assets），
    ; 发布侧不再产出额外清单文件。
    static Repo() {
        return "zclucas/RMT"
    }

    ; API 走 gh-proxy：它给请求注入了自己的 token（5000 次/小时），比匿名直连的
    ; 60 次/小时稳，也顺带解决国内直连 api.github.com 的问题。
    static ApiBase() {
        return "https://gh-proxy.com/https://api.github.com"
    }

    ; Release 里的 browser_download_url 是 github.com 的，下载同样套这个前缀
    static ProxyPrefix() {
        return "https://gh-proxy.com/"
    }

    ; 测试版通道：1.3F4 / 1.4F1 这类预览版
    static IsBeta() {
        try return !!(MainSoftData.HasProp("UpdateBeta") && MainSoftData.UpdateBeta)
        return false
    }

    ; 启动时自动检查（设置页可关）
    static AutoCheck() {
        try return !!(MainSoftData.HasProp("UpdateCheck") && MainSoftData.UpdateCheck)
        return false
    }

    static ExePath() {
        return AppRootDir "\Plugins\Update\RMT.Update.exe"
    }

    static CacheDir() {
        return AppRootDir "\Cache\Update"
    }

    static ResultFile() {
        return RmtUpdater.CacheDir() "\check.json"
    }

    static LogFile() {
        return AppRootDir "\Log\Update.log"
    }

    static Arch() {
        return A_PtrSize == 8 ? "x64" : "x86"
    }

    static Lang() {
        ; 更新器只认 zh / en，其余语言先按中文处理
        code := ""
        try code := GetClientLanguageCode()
        return (SubStr(StrLower(code), 1, 2) == "en") ? "en" : "zh"
    }

    ; ---------- 检查更新 ----------

    ; 异步：拉起 exe 的 check 子命令，结果写到 Cache\Update\check.json。
    ; OnDone(result) 里的 result 是 Map（JSON.parse 产物）；失败时传 ""。
    static Check(OnDone) {
        if (RmtUpdater._ctx != "")
            return false

        exe := RmtUpdater.ExePath()
        if (!FileExist(exe))
            return false

        try DirCreate(RmtUpdater.CacheDir())
        outFile := RmtUpdater.ResultFile()
        try FileDelete(outFile)

        beta := RmtUpdater.IsBeta()
        cmd := '"' exe '" check --repo ' RmtUpdater.Repo()
            . ' --current ' RMT_VERSION
            . ' --arch ' RmtUpdater.Arch()
            . ' --lang ' RmtUpdater.Lang()
            . ' --channel ' (beta ? "test" : "stable")
            . ' --api "' RmtUpdater.ApiBase() '"'
            . ' --proxy "' RmtUpdater.ProxyPrefix() '"'
            . ' --timeout 10'
            . ' --out "' outFile '"'

        try Run(cmd, , "Hide", &pid)
        catch
            return false

        RmtUpdater._ctx := {pid: pid, out: outFile, start: A_TickCount, cb: OnDone}
        if (!RmtUpdater._tickFn)
            RmtUpdater._tickFn := ObjBindMethod(RmtUpdater, "_Tick")
        SetTimer(RmtUpdater._tickFn, 250)
        return true
    }

    static _Tick(*) {
        ctx := RmtUpdater._ctx
        if (ctx == "")
            return

        ; 超时当失败，静默收场（启动检查不该打扰用户）。
        ; 更新器那边最多 3 次 × --timeout 10 秒，这里留点余量。
        if (A_TickCount - ctx.start > 35000) {
            RmtUpdater._Finish("")
            return
        }

        if (!FileExist(ctx.out)) {
            if (!ProcessExist(ctx.pid))
                RmtUpdater._Finish("")
            return
        }

        ; 文件可能刚创建还没写完：读不到 / 解析不了就继续等下一轮
        try text := FileRead(ctx.out, "UTF-8")
        catch
            return
        if (Trim(text) == "")
            return

        try res := JSON.parse(text)
        catch
            return

        RmtUpdater._Finish(res)
    }

    static _Finish(res) {
        ctx := RmtUpdater._ctx
        RmtUpdater._ctx := ""
        if (RmtUpdater._tickFn)
            SetTimer(RmtUpdater._tickFn, 0)
        if (!IsObject(ctx))
            return
        ; 不能写 ctx.cb(res)：v2 把「属性 + 括号」当成方法调用，会额外把 ctx 当
        ; this 传进去，目标函数收到两个参数就报 Too many parameters。
        cb := ctx.cb
        cb(res)
    }

    static IsBusy() {
        return RmtUpdater._ctx != ""
    }

    ; 上一次检查的结果（设置页显示「最新版本」用），没有就返回 ""
    static LastResult() {
        try {
            text := FileRead(RmtUpdater.ResultFile(), "UTF-8")
            if (Trim(text) == "")
                return ""
            return JSON.parse(text)
        }
        return ""
    }

    ; ---------- 安装 ----------

    ; 调用后本进程应当退出（更新器会等 wait-pid 消失再动文件）。
    ; 参数直接取 check 的结果：url / sha256 都是当时那个 Release 的，
    ; 所以 install 阶段不用再联网，也不会出现「检查看到 A、装成 B」。
    static Install(res) {
        exe := RmtUpdater.ExePath()
        if (!FileExist(exe))
            return false

        if (!IsObject(res))
            return false
        url := res.Has("url") ? res["url"] : ""
        if (url == "")
            return false
        latest := res.Has("latest") ? res["latest"] : ""
        sha := res.Has("sha256") ? res["sha256"] : ""

        cmd := '"' exe '" install --target "' AppRootDir '"'
            . ' --url "' url '"'
            . ' --version "' latest '"'
            . (sha != "" ? ' --sha256 "' sha '"' : "")
            . ' --arch ' RmtUpdater.Arch()
            . ' --lang ' RmtUpdater.Lang()
            . ' --wait-pid ' ProcessExist()
            . ' --log "' RmtUpdater.LogFile() '"'
        ; 编译版才知道重启哪个 exe；开发模式（.ahk 直跑）不代启动，
        ; 不加 --no-launch 的话更新器会退而启动包里那个编译版 exe，把开发机带偏
        if (A_IsCompiled)
            cmd .= ' --launch "' A_ScriptFullPath '"'
        else
            cmd .= ' --no-launch'

        try Run(cmd, AppRootDir, "Normal", &pid)
        catch
            return false
        return true
    }

    ; ---------- 永久关闭提示 ----------

    ; 用户选「取消」不是「跳过这个版本」，而是彻底不再自动提示（永久）。
    ; 只有这一个开关，不记版本号：想改回来去 设置 → 更新 重新勾上。
    ; 立刻落盘，别等用户想起来按「应用并保存」——否则重启又弹一次。
    static Suppress() {
        MainSoftData.UpdateCheck := false
        ; 段名与 MainSettings 的默认值一致；SettingFile 是 super-global，直接用
        try CfgWrite(false, SettingFile, "UserSettings", "UpdateCheck")
    }

    ; ---------- 用户交互 ----------

    ; 有更新时问一次；用户点「取消」就永久不再自动提示。
    static Prompt(res) {
        latest := res.Has("latest") ? res["latest"] : ""
        notes := res.Has("notes") ? res["notes"] : ""
        size := res.Has("size") ? res["size"] : 0

        msg := RmtUpdater.T("new_version") " " latest
        ; 体积按语言换括号，别让英文界面里冒出中文全角括号
        if (size > 0) {
            mb := Round(size / 1048576)
            msg .= (RmtUpdater.Lang() == "en") ? Format(" (~{} MB)", mb) : Format("（约 {} MB）", mb)
        }
        msg .= "`n"
        if (notes != "")
            msg .= "`n" notes "`n"
        msg .= "`n" RmtUpdater.T("restart_tip")
        msg .= "`n" RmtUpdater.T("suppress_tip")

        if (!RmtDialog.Confirm(msg, RmtUpdater.T("title"))) {
            RmtUpdater.Suppress()
            return false
        }

        if (!RmtUpdater.Install(res)) {
            RmtDialog.Info(RmtUpdater.T("start_failed"), RmtUpdater.T("title"))
            return false
        }

        ; 给更新器一点时间把窗口摆出来，再关自己，避免中间空屏
        SetTimer(() => ExitApp(), -400)
        return true
    }

    static T(key) {
        en := RmtUpdater.Lang() == "en"
        if (key == "title")
            return en ? "RMT Update" : "RMT 在线更新"
        if (key == "new_version")
            return en ? "A new version is available:" : "发现新版本"
        if (key == "restart_tip")
            return en ? "RMT will close and restart automatically after the update."
                : "更新过程中 RMT 会关闭，完成后自动重新启动。"
        if (key == "suppress_tip")
            return en ? "Choosing Cancel stops automatic update prompts. You can re-enable them in Settings - Update."
                : "点「取消」后不再自动提示更新，之后可在 设置 → 更新 里重新开启。"
        if (key == "start_failed")
            return en ? "Failed to start the updater." : "无法启动更新程序，请手动下载完整包。"
        return key
    }
}

; 启动后延迟调用：静默检查，有更新才弹一次。
RmtUpdateStartupCheck() {
    if (!RmtUpdater.AutoCheck())
        return
    RmtUpdater.Check(RmtUpdateOnCheckDone)
}

RmtUpdateOnCheckDone(res) {
    if (!IsObject(res))
        return
    ; Map 取不存在的键会抛，先 Has 再取
    ok := res.Has("ok") ? res["ok"] : 0
    hasUpdate := res.Has("has_update") ? res["has_update"] : 0
    if (ok != 1 || hasUpdate != 1)
        return

    RmtUpdater.Prompt(res)
}
