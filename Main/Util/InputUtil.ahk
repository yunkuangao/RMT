#Requires AutoHotkey v2.0

; =====================================================================
; 输入指令统一通信（输入框/按钮条/自定义弹窗）：
; Worker 跨进程请求主进程弹窗（直发 opcode → WorkPool 注册表分发 → 回传 opcode+"R"）；
; 主进程宏经 WorkPool.RequestLocalInput 由主线程异步弹窗（结果写本地槽位）。
; 返回 args 数组（IPR: [ok, value]；IBR: [button]；CMR: [button]）；失败/超时返回 ""
; =====================================================================
InputRequest(opcode, args*) {
    global MyWorkPool
    if (IsSet(workIndex) && workIndex > 0)
        return WorkerInputRequest(opcode, args*)
    ; 主进程宏：交由主线程 WorkPool 弹窗
    if (MyWorkPool != "" && IsObject(MyWorkPool))
        return MyWorkPool.RequestLocalInput(opcode, args*)
    return ""
}

; Worker 跨进程弹窗请求：委托 Thread\WorkUtil.ahk 的统一阻塞代理 WorkerDialog_Request
; （本文件为主/Worker 共享，主进程编译链无 WorkUtil，动态名解析避免裸引用触发 #Warn）
WorkerInputRequest(opcode, args*) {
    fnName := "WorkerDialog_Request"
    if (IsSet(%fnName%)) {
        impl := %fnName%
        return impl(opcode, args*)
    }
    return ""   ; 理论不可达：仅 Worker 进程调用（InputRequest 已判 workIndex>0）
}

InputPopUp(Data, tableItem, index) {
    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_宏控制_暂停所有宏")

    Label := GetLang("变量名：") Data.SaveName
    Content := ""
    if (MySoftData.VariableMap.Has(Data.SaveName))
        Content := MySoftData.VariableMap[Data.SaveName]

    result := InputRequest("IP", Label, Content)
    if (IsObject(result) && result.Length >= 2 && result[1] == "1") {
        MySetGlobalVariable([Data.SaveName], [result[2]], false)
    }

    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_宏控制_恢复所有宏")
}

InputStateValue(Data, tableItem, index) {
    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_宏控制_暂停所有宏")

    result := InputRequest("IB", "1")
    if (IsObject(result) && result[1] == "true")
        MySetGlobalVariable([Data.SaveName], [1], false)
    else if (IsObject(result) && result[1] == "false")
        MySetGlobalVariable([Data.SaveName], [0], false)

    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_宏控制_恢复所有宏")
}

InputContinue(Data, tableItem, index) {
    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_宏控制_暂停所有宏")

    InputRequest("IB", "2")

    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_宏控制_恢复所有宏")
}

InputContinueAndCencel(Data, tableItem, index) {
    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_宏控制_暂停所有宏")

    result := InputRequest("IB", "3")
    if (IsObject(result) && result[1] == "cancel") {
        if (Data.CancelType == "终止当前宏")
            MyStopMacro(tableItem, index)
        if (Data.CancelType == "终止所有宏")
            MyExcuteRMTCMDAction("RMT指令_宏控制_终止所有宏")
    }

    if (Data.PauseType == "暂停所有宏")
        MyExcuteRMTCMDAction("RMT指令_宏控制_恢复所有宏")
}
