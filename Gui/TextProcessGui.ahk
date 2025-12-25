#Requires AutoHotkey v2.0

class TextProcessGui {
    __new() {
        this.ParentTile := ""
        this.Gui := ""
        this.SureBtnAction := ""
        this.VariableObjArr := []
        this.RemarkCon := ""

        this.ToggleConArr := []
        this.VariableConArr := []
        this.ProcessTypeCon := ""
        this.SplitDelimiterCon := ""
        this.SearchTextCon := ""
        this.ReplaceTextCon := ""
        this.CaseSensitiveCon := ""
        this.RegexCon := ""
        this.ReverseCon := ""
        this.ResultActionCon := ""
        this.SplitParamCon := ""
        this.MaxSplitCountCon := ""
        this.Data := ""
    }

    ShowGui(cmd) {
        if (this.Gui != "") {
            this.Gui.Show()
        }
        else {
            this.AddGui()
        }

        this.Init(cmd)
    }

    AddGui() {
        MyGui := Gui(, this.ParentTile GetLang("文本处理编辑器"))
        this.Gui := MyGui
        MyGui.SetFont("S10 W550 Q2", MySoftData.FontType)

        PosX := 10
        PosY := 10
        this.FocusCon := MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 80, 20), GetLang("快捷方式:"))
        PosX += 80
        con := MyGui.Add("Hotkey", Format("x{} y{} w{}", PosX, PosY - 3, 70), "!t")
        con.Enabled := false

        PosX += 90
        btnCon := MyGui.Add("Button", Format("x{} y{} w{}", PosX, PosY - 5, 80), GetLang("执行指令"))
        btnCon.OnEvent("Click", (*) => this.TriggerMacro())

        PosX += 90
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 50), GetLang("备注:"))
        PosX += 50
        this.RemarkCon := MyGui.Add("Edit", Format("x{} y{} w{}", PosX, PosY - 5, 150), "")

        PosX := 10
        PosY += 40
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 75), GetLang("处理类型:"))
        PosX += 75
        this.ProcessTypeCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY - 5, 120), GetLangArr([
            "文本分割",
            "文本替换",
            "数字提取",
            "字母提取",
            "中文提取",
            "去空格处理",
            "大小写转换",
            "URL编解码",
            "Base64编解码",
            "文本统计",
            "固定长度分割",
            "多字符分割",
            "行过滤",
            "去重处理",
            "排序处理",
            "随机文本",
            "日期时间"]))
        this.ProcessTypeCon.OnEvent("Change", (*) => this.OnProcessTypeChange())

        PosY += 40
        PosX := 10
        MyGui.Add("GroupBox", Format("x{} y{} w{} h{}", PosX, PosY, 550, 220), GetLang("处理参数"))

        ; 第一行：文本来源
        PosY += 25
        PosX := 20
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 75), GetLang("文本来源:"))
        PosX += 75
        this.SourceVariableCon := MyGui.Add("DropDownList", Format("x{} y{} w{} R5", PosX, PosY - 5, 200), [])

        ; 第二行：分割符号
        PosY += 30
        PosX := 20
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 75), GetLang("分割符号:"))
        PosX += 75
        this.SplitDelimiterCon := MyGui.Add("Edit", Format("x{} y{} w{} Center", PosX, PosY - 5, 120), ",")

        ; 第三行放置查找文本和替换文本
        PosY += 30
        PosX := 20
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 75), GetLang("查找文本:"))
        PosX += 75
        this.SearchTextCon := MyGui.Add("Edit", Format("x{} y{} w{}", PosX, PosY - 5, 200), "")

        PosX += 220
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 75), GetLang("替换文本:"))
        PosX += 75
        this.ReplaceTextCon := MyGui.Add("Edit", Format("x{} y{} w{}", PosX, PosY - 5, 200), "")

        ; 第四行：分割参数（用于多字符分割、固定长度分割等）
        PosY += 30
        PosX := 20
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 75), GetLang("分割参数:"))
        PosX += 75
        this.SplitParamCon := MyGui.Add("Edit", Format("x{} y{} w{} Center", PosX, PosY - 5, 120), "")

        PosX += 140
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 75), GetLang("最大分割数:"))
        PosX += 75
        this.MaxSplitCountCon := MyGui.Add("Edit", Format("x{} y{} w{} Center", PosX, PosY - 5, 60), "")

        ; 第四行：高级选项
        PosY += 30
        PosX := 20
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 75), GetLang("处理选项:"))
        PosX += 75
        this.CaseSensitiveCon := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY - 3, 80), GetLang("大小写敏感"))
        
        PosX += 90
        this.RegexCon := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY - 3, 80), GetLang("正则表达式"))
        
        PosX += 90
        this.ReverseCon := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY - 3, 80), GetLang("反向处理"))

        ; 第六行：处理选项
        PosY += 25
        PosX := 20
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 75), GetLang("处理选项:"))
        PosX += 75
        this.CaseSensitiveCon := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY - 3, 80), GetLang("大小写敏感"))
        
        PosX += 90
        this.RegexCon := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY - 3, 80), GetLang("正则表达式"))
        
        PosX += 90
        this.ReverseCon := MyGui.Add("Checkbox", Format("x{} y{} w{}", PosX, PosY - 3, 80), GetLang("反向处理"))

        ; 第七行：结果处理
        PosY += 25
        PosX := 20
        MyGui.Add("Text", Format("x{} y{} w{}", PosX, PosY, 75), GetLang("结果处理:"))
        PosX += 75
        this.ResultActionCon := MyGui.Add("DropDownList", Format("x{} y{} w{}", PosX, PosY - 5, 120), GetLangArr([
            "覆盖变量",
            "追加结果",
            "前置结果"]))

        PosY += 30
        PosX := 20
        MyGui.Add("Text", Format("x{} y{} h{}", PosX, PosY, 20), GetLang("开关      变量名"))
        PosX += 260
        MyGui.Add("Text", Format("x{} y{} h{}", PosX, PosY, 20), GetLang("开关      变量名"))

        PosX := 20
        PosY += 20
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY + 3), "1.")
        PosX += 20
        con := MyGui.Add("Checkbox", Format("x{} y{} w{} h{} Center", PosX, PosY + 3, 30, 20), "")
        this.ToggleConArr.Push(con)

        PosX += 35
        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5 Center", PosX, PosY - 2, 100), [])
        this.VariableConArr.Push(con)

        PosX += 200
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY + 3), "2.")
        PosX += 20
        con := MyGui.Add("Checkbox", Format("x{} y{} w{} h{} Center", PosX, PosY + 3, 30, 20), "")
        this.ToggleConArr.Push(con)

        PosX += 35
        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5 Center", PosX, PosY - 2, 100), [])
        this.VariableConArr.Push(con)

        PosX := 20
        PosY += 30
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY + 3), "3.")
        PosX += 20
        con := MyGui.Add("Checkbox", Format("x{} y{} w{} h{} Center", PosX, PosY + 3, 30, 20), "")
        this.ToggleConArr.Push(con)

        PosX += 35
        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5 Center", PosX, PosY - 2, 100), [])
        this.VariableConArr.Push(con)

        PosX += 200
        MyGui.Add("Text", Format("x{} y{}", PosX, PosY + 3), "4.")
        PosX += 20
        con := MyGui.Add("Checkbox", Format("x{} y{} w{} h{} Center", PosX, PosY + 3, 30, 20), "")
        this.ToggleConArr.Push(con)

        PosX += 35
        con := MyGui.Add("ComboBox", Format("x{} y{} w{} R5 Center", PosX, PosY - 2, 100), [])
        this.VariableConArr.Push(con)

        PosY += 40
        PosX := 250
        btnCon := MyGui.Add("Button", Format("x{} y{} w{} h{} Center", PosX, PosY, 100, 40), GetLang("确定"))
        btnCon.OnEvent("Click", (*) => this.OnClickSureBtn())

        MyGui.OnEvent("Close", (*) => this.Gui.Hide())
        MyGui.Show(Format("w{} h{}", 600, 550))

        ; 初始化界面状态
        this.OnProcessTypeChange()
    }

    Init(cmd) {
        cmdArr := cmd != "" ? StrSplit(cmd, "_") : []
        this.SerialStr := cmdArr.Length >= 2 ? cmdArr[2] : GetSerialStr("TextProcess")
        this.RemarkCon.Value := cmdArr.Length >= 3 ? cmdArr[3] : ""
        this.Data := this.GetTextProcessData(this.SerialStr)

        ; 初始化文本来源变量
        this.SourceVariableCon.Delete()
        
        ; 如果VariableObjArr为空，添加默认的变量
        if (this.VariableObjArr.Length == 0) {
            ; 添加全局变量
            for key in MySoftData.GlobalVariMap {
                this.VariableObjArr.Push(key)
            }
            
            ; 如果仍然为空，添加一些默认变量
            if (this.VariableObjArr.Length == 0) {
                this.VariableObjArr.Push("变量1")
                this.VariableObjArr.Push("变量2")
                this.VariableObjArr.Push("变量3")
            }
        }
        
        this.SourceVariableCon.Add(RemoveInVariable(this.VariableObjArr))
        this.SourceVariableCon.Text := this.Data.SourceVariable
        
        loop 4 {
            this.ToggleConArr[A_Index].Value := this.Data.ToggleArr[A_Index]
            this.VariableConArr[A_Index].Delete()
            this.VariableConArr[A_Index].Add(RemoveInVariable(this.VariableObjArr))
            this.VariableConArr[A_Index].Text := this.Data.VariableArr[A_Index]
        }
        this.ProcessTypeCon.Value := this.Data.ProcessType
        this.SplitDelimiterCon.Value := this.Data.SplitDelimiter
        this.SearchTextCon.Value := this.Data.SearchText
        this.ReplaceTextCon.Value := this.Data.ReplaceText
        this.CaseSensitiveCon.Value := this.Data.CaseSensitive
        this.RegexCon.Value := this.Data.UseRegex
        this.ReverseCon.Value := this.Data.ReverseProcess
        this.ResultActionCon.Value := this.Data.ResultAction
        this.SplitParamCon.Value := this.Data.SplitParam
        this.MaxSplitCountCon.Value := this.Data.MaxSplitCount

        ; 更新界面状态
        this.OnProcessTypeChange()
    }

    OnClickSureBtn() {
        valid := this.CheckIfValid()
        if (!valid)
            return
        this.SaveTextProcessData()
        CommandStr := this.GetCommandStr()
        action := this.SureBtnAction
        action(CommandStr)
        this.Gui.Hide()
    }

    OnProcessTypeChange() {
        processType := this.ProcessTypeCon.Value
        
        ; 默认禁用所有控件
        this.SplitDelimiterCon.Enabled := false
        this.SearchTextCon.Enabled := false
        this.ReplaceTextCon.Enabled := false
        this.SplitParamCon.Enabled := false
        this.MaxSplitCountCon.Enabled := false
        
        switch processType {
            case 1: ; 文本分割
                this.SplitDelimiterCon.Enabled := true
            case 2: ; 文本替换
                this.SearchTextCon.Enabled := true
                this.ReplaceTextCon.Enabled := true
            case 3, 4, 5: ; 数字提取、字母提取、中文提取
                ; 无需额外参数
            case 6: ; 去空格处理
                this.SplitParamCon.Enabled := true ; 去空格方式参数
            case 7: ; 大小写转换
                this.SplitParamCon.Enabled := true ; 转换类型参数
            case 8, 9: ; URL编解码、Base64编解码
                this.SplitParamCon.Enabled := true ; 编码/解码类型
            case 10: ; 文本统计
                this.SplitParamCon.Enabled := true ; 统计类型
            case 11, 12: ; 固定长度分割、多字符分割
                this.SplitDelimiterCon.Enabled := false
                this.SplitParamCon.Enabled := true
                this.MaxSplitCountCon.Enabled := true
            case 13: ; 行过滤
                this.SearchTextCon.Enabled := true
            case 14, 15: ; 去重处理、排序处理
                ; 无需额外参数
            case 16: ; 随机文本
                this.SplitParamCon.Enabled := true ; 随机文本长度
            case 17: ; 日期时间
                this.SplitParamCon.Enabled := true ; 日期格式
        }
    }

    CheckIfValid() {
        loop 4 {
            if (this.ToggleConArr[A_Index].Value) {
                if (IsNumber(this.VariableConArr[A_Index].Text)) {
                    MsgBox(GetLang(A_Index . ". 变量名不规范：变量名不能是纯数字"))
                    return false
                }
            }
        }
        return true
    }

    TriggerMacro() {
        this.SaveTextProcessData()
        CommandStr := this.GetCommandStr()
        tableItem := MySoftData.SpecialTableItem
        tableItem.KilledArr[1] := false
        tableItem.PauseArr[1] := 0
        tableItem.ActionCount[1] := 0
        tableItem.VariableMapArr[1] := Map()
        tableItem.index := 1

        this.TestTextProcess(this.Data)
    }

    TestTextProcess(Data) {
        ; 从指定的文本来源变量中获取源文本
        sourceText := ""
        sourceVariableName := Data.SourceVariable
        
        if (sourceVariableName == "") {
            MsgBox(GetLang("文本处理失败：请指定文本来源变量"))
            return
        }
        
        if (!this.TryGetVariableValue(&sourceText, sourceVariableName, false)) {
            errorText := GetLang("文本处理失败：源变量不存在：") . sourceVariableName
            MsgBox(errorText)
            return
        }
        
        if (sourceText == "") {
            MsgBox(GetLang("文本处理失败：源变量为空"))
            return
        }

        NameArr := []
        ValueArr := []

        ; 处理文本
        switch Data.ProcessType {
            case 1: ; 文本分割
                parts := this.ProcessTextSplit(sourceText, Data)
                partIndex := 1
                loop 4 {
                    if (Data.ToggleArr[A_Index] && partIndex <= parts.Length) {
                        NameArr.Push(Data.VariableArr[A_Index])
                        ValueArr.Push(parts[partIndex])
                        partIndex++
                    }
                }
                
            case 2: ; 文本替换
                processedText := this.ProcessTextReplace(sourceText, Data.SearchText, Data.ReplaceText, Data.CaseSensitive, Data.UseRegex)
                this.SaveSingleResult(Data, NameArr, ValueArr, processedText)
                
            case 3: ; 数字提取
                extractedText := this.ExtractDigits(sourceText)
                this.SaveSingleResult(Data, NameArr, ValueArr, extractedText)
                
            case 4: ; 字母提取
                extractedText := this.ExtractAlphabets(sourceText)
                this.SaveSingleResult(Data, NameArr, ValueArr, extractedText)
                
            case 5: ; 中文提取
                extractedText := this.ExtractChineseChars(sourceText)
                this.SaveSingleResult(Data, NameArr, ValueArr, extractedText)
                
            case 6: ; 去空格处理
                processedText := this.ProcessWhitespace(sourceText, Data.SplitParam)
                this.SaveSingleResult(Data, NameArr, ValueArr, processedText)
                
            case 7: ; 大小写转换
                processedText := this.ProcessCaseConversion(sourceText, Data.SplitParam)
                this.SaveSingleResult(Data, NameArr, ValueArr, processedText)
                
            case 8: ; URL编解码
                processedText := this.ProcessURLEncode(sourceText, Data.SplitParam)
                this.SaveSingleResult(Data, NameArr, ValueArr, processedText)
                
            case 9: ; Base64编解码
                processedText := this.ProcessBase64(sourceText, Data.SplitParam)
                this.SaveSingleResult(Data, NameArr, ValueArr, processedText)
                
            case 10: ; 文本统计
                statsText := this.GetTextStatistics(sourceText, Data.SplitParam)
                this.SaveSingleResult(Data, NameArr, ValueArr, statsText)
                
            case 11: ; 固定长度分割
                length := Data.SplitParam ? Integer(Data.SplitParam) : 10
                maxCount := Data.MaxSplitCount ? Integer(Data.MaxSplitCount) : 0
                parts := this.SplitByLength(sourceText, length, maxCount)
                partIndex := 1
                loop 4 {
                    if (Data.ToggleArr[A_Index] && partIndex <= parts.Length) {
                        NameArr.Push(Data.VariableArr[A_Index])
                        ValueArr.Push(parts[partIndex])
                        partIndex++
                    }
                }
                
            case 12: ; 多字符分割
                delimiters := Data.SplitParam ? Data.SplitParam : ",|;"
                maxCount := Data.MaxSplitCount ? Integer(Data.MaxSplitCount) : 0
                parts := this.SplitByMultipleDelimiters(sourceText, delimiters, maxCount)
                partIndex := 1
                loop 4 {
                    if (Data.ToggleArr[A_Index] && partIndex <= parts.Length) {
                        NameArr.Push(Data.VariableArr[A_Index])
                        ValueArr.Push(parts[partIndex])
                        partIndex++
                    }
                }
                
            case 13: ; 行过滤
                filteredText := this.FilterLines(sourceText, Data.SearchText)
                this.SaveSingleResult(Data, NameArr, ValueArr, filteredText)
                
            case 14: ; 去重处理
                processedText := this.RemoveDuplicates(sourceText)
                this.SaveSingleResult(Data, NameArr, ValueArr, processedText)
                
            case 15: ; 排序处理
                processedText := this.SortText(sourceText, Data.ReverseProcess)
                this.SaveSingleResult(Data, NameArr, ValueArr, processedText)
                
            case 16: ; 随机文本
                length := Data.SplitParam ? Integer(Data.SplitParam) : 10
                randomText := this.GenerateRandomText(length)
                this.SaveSingleResult(Data, NameArr, ValueArr, randomText)
                
            case 17: ; 日期时间
                format := Data.SplitParam ? Data.SplitParam : "yyyy-MM-dd HH:mm:ss"
                dateTimeText := this.GetDateTime(format)
                this.SaveSingleResult(Data, NameArr, ValueArr, dateTimeText)
        }

        if (NameArr.Length == 0) {
            MsgBox(GetLang("文本处理失败"))
        }
        else {
            ; 将结果保存到全局变量
            loop NameArr.Length {
                MySoftData.VariableMap[NameArr[A_Index]] := ValueArr[A_Index]
            }
            
            tipStr := GetLang("已处理以下变量") "`n"
            loop NameArr.Length {
                tipStr .= NameArr[A_Index] " = " ValueArr[A_Index] "`n"
            }
            MsgBox(tipStr)
            
            ; 刷新变量监视器
            if (MyVarListenGui.Gui != "") {
                MyVarListenGui.Refresh()
            }
        }
    }

    GetCommandStr() {
        CommandStr := Format("{}_{}", GetLang("文本处理"), this.Data.SerialStr)
        Remark := CorrectRemark(this.RemarkCon.Value)
        if (Remark != "") {
            CommandStr .= "_" Remark
        }
        return CommandStr
    }

    GetTextProcessData(SerialStr) {
        saveStr := IniRead(TextProcessFile, IniSection, SerialStr, "")
        if (!saveStr) {
            data := TextProcessData()
            data.SerialStr := SerialStr
            return data
        }

        data := JSON.parse(saveStr, , false)
        return data
    }

    SaveTextProcessData() {
        this.Data.SourceVariable := this.SourceVariableCon.Text
        this.Data.ProcessType := this.ProcessTypeCon.Value
        this.Data.SplitDelimiter := this.SplitDelimiterCon.Value
        this.Data.SearchText := this.SearchTextCon.Value
        this.Data.ReplaceText := this.ReplaceTextCon.Value
        this.Data.CaseSensitive := this.CaseSensitiveCon.Value
        this.Data.UseRegex := this.RegexCon.Value
        this.Data.ReverseProcess := this.ReverseCon.Value
        this.Data.ResultAction := this.ResultActionCon.Value
        this.Data.SplitParam := this.SplitParamCon.Value
        this.Data.MaxSplitCount := this.MaxSplitCountCon.Value
        loop 4 {
            this.Data.ToggleArr[A_Index] := this.ToggleConArr[A_Index].Value
            this.Data.VariableArr[A_Index] := this.VariableConArr[A_Index].Text
        }

        ; 添加全局变量，方便下拉选取
        if (this.Data.SourceVariable != "")
            MySoftData.GlobalVariMap[this.Data.SourceVariable] := true
        
        loop 4 {
            if (this.Data.ToggleArr[A_Index])
                MySoftData.GlobalVariMap[this.Data.VariableArr[A_Index]] := true
        }

        saveStr := JSON.stringify(this.Data, 0)
        IniWrite(saveStr, TextProcessFile, IniSection, this.Data.SerialStr)
        if (MySoftData.DataCacheMap.Has(this.Data.SerialStr)) {
            MySoftData.DataCacheMap.Delete(this.Data.SerialStr)
        }
    }

    GetReplaceVarText(text) {
        matches := []  ; 初始化空数组
        pos := 1  ; 从字符串开头开始搜索

        while (pos := RegExMatch(text, "\\{(.*?)\\}", &match, pos)) {
            matches.Push(match[1])  ; 把花括号内的内容存入数组
            pos += match.Len  ; 移动到匹配结束位置，继续搜索
        }

        Content := text
        for index, value in matches {
            hasValue := this.TryGetVariableValue(&variValue, value, false)
            if (hasValue)
                Content := StrReplace(Content, "{" value "}", variValue)
        }
        return Content
    }

    TryGetVariableValue(&Value, variableName, variTip := true) {
        if (IsNumber(variableName)) {
            Value := variableName
            return true
        }

        if (variableName == GetLang("当前鼠标坐标X") || variableName == GetLang("当前鼠标坐标Y")) {
            CoordMode("Mouse", "Screen")
            MouseGetPos &mouseX, &mouseY
            Value := variableName == GetLang("当前鼠标坐标X") ? mouseX : mouseY
            return true
        }

        GlobalVariableMap := MySoftData.VariableMap
        if (GlobalVariableMap.Has(variableName)) {
            Value := GlobalVariableMap[variableName]
            return true
        }

        if (variTip)
            ShowNoVariableTip(variableName)
        return false
    }

    OnClickAddVarNameBtn() {
        ; 追加变量名到查找文本或替换文本
        if (this.SearchTextCon.Enabled) {
            this.SearchTextCon.Value .= this.SourceVariableCon.Text
        } else if (this.ReplaceTextCon.Enabled) {
            this.ReplaceTextCon.Value .= this.SourceVariableCon.Text
        }
    }

    OnClickAddVarValueBtn() {
        ; 追加变量值（带花括号）到查找文本或替换文本
        if (this.SearchTextCon.Enabled) {
            this.SearchTextCon.Value .= "{" this.SourceVariableCon.Text "}"
        } else if (this.ReplaceTextCon.Enabled) {
            this.ReplaceTextCon.Value .= "{" this.SourceVariableCon.Text "}"
        }
    }

    ReverseString(text) {
        ; 反转字符串
        reversed := ""
        for i in StrSplit(text, "") {
            reversed := i . reversed
        }
        return reversed
    }

    ProcessTextReplace(sourceText, searchText, replaceText, caseSensitive, useRegex) {
        ; 文本替换处理
        if (useRegex) {
            ; 正则表达式替换
            flags := caseSensitive ? "" : "i"
            return RegExReplace(sourceText, searchText, replaceText, 1, -1, flags)
        } else {
            ; 普通文本替换
            if (caseSensitive) {
                return StrReplace(sourceText, searchText, replaceText)
            } else {
                ; 大小写不敏感的替换
                return RegExReplace(sourceText, "i)" . this.RegExEscape(searchText), replaceText)
            }
        }
    }

    RegExEscape(text) {
        ; 转义正则表达式特殊字符
        specialChars := ".^$*+?()[]\{}|"
        escaped := text
        for char in StrSplit(specialChars, "") {
            escaped := StrReplace(escaped, char, "\" char)
        }
        return escaped
    }

    ApplyResultAction(originalValue, newValue, action) {
        ; 应用结果处理方式
        switch action {
            case 1: ; 覆盖变量
                return newValue
            case 2: ; 追加结果
                return originalValue . newValue
            case 3: ; 前置结果
                return newValue . originalValue
            default:
                return newValue
        }
    }

    SaveSingleResult(Data, &NameArr, &ValueArr, result) {
        ; 保存单个结果到第一个选中的变量
        loop 4 {
            if (Data.ToggleArr[A_Index]) {
                NameArr.Push(Data.VariableArr[A_Index])
                originalValue := ""
                this.TryGetVariableValue(&originalValue, Data.VariableArr[A_Index], false)
                finalValue := this.ApplyResultAction(originalValue, result, Data.ResultAction)
                ValueArr.Push(finalValue)
                break
            }
        }
    }

    ProcessTextSplit(sourceText, Data) {
        ; 文本分割处理
        if (Data.ReverseProcess) {
            reversedText := this.ReverseString(sourceText)
            parts := StrSplit(reversedText, Data.SplitDelimiter)
            reversedParts := []
            for i in parts {
                reversedParts.InsertAt(1, this.ReverseString(parts[i]))
            }
            return reversedParts
        } else {
            return StrSplit(sourceText, Data.SplitDelimiter)
        }
    }

    ExtractDigits(text) {
        ; 提取所有数字
        numbers := ""
        for char in StrSplit(text, "") {
            if (char >= "0" && char <= "9") {
                numbers .= char
            }
        }
        return numbers
    }

    ExtractAlphabets(text) {
        ; 提取所有字母
        letters := ""
        for char in StrSplit(text, "") {
            if ((char >= "a" && char <= "z") || (char >= "A" && char <= "Z")) {
                letters .= char
            }
        }
        return letters
    }

    ExtractChineseChars(text) {
        ; 提取中文字符
        chinese := ""
        for char in StrSplit(text, "") {
            if (this.IsChineseChar(char)) {
                chinese .= char
            }
        }
        return chinese
    }

    IsChineseChar(char) {
        ; 判断是否为中文字符
        code := Ord(char)
        return (code >= 0x4E00 && code <= 0x9FFF) || (code >= 0x3400 && code <= 0x4DBF)
    }

    ProcessWhitespace(text, mode) {
        ; 处理空格
        switch mode {
            case "1": ; 去除前后空格
                return Trim(text)
            case "2": ; 去除所有空格
                return StrReplace(text, " ", "")
            case "3": ; 去除多余空格
                return RegExReplace(text, "\s+", " ")
            default:
                return Trim(text)
        }
    }

    ProcessCaseConversion(text, mode) {
        ; 大小写转换
        switch mode {
            case "1": ; 全部大写
                return StrUpper(text)
            case "2": ; 全部小写
                return StrLower(text)
            case "3": ; 首字母大写
                return StrUpper(SubStr(text, 1, 1)) . StrLower(SubStr(text, 2))
            default:
                return text
        }
    }

    ProcessURLEncode(text, mode) {
        ; URL编解码
        switch mode {
            case "1": ; URL编码
                encoded := ""
                for char in StrSplit(text, "") {
                    code := Ord(char)
                    if ((code >= 48 && code <= 57) || (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || char == "-" || char == "_" || char == "." || char == "~") {
                        encoded .= char
                    } else {
                        encoded .= "%" . Format("{:02X}", code)
                    }
                }
                return encoded
            case "2": ; URL解码
                decoded := ""
                i := 1
                while (i <= StrLen(text)) {
                    char := SubStr(text, i, 1)
                    if (char == "%") {
                        hex := SubStr(text, i + 1, 2)
                        decoded .= Chr("0x" . hex)
                        i += 3
                    } else {
                        decoded .= char
                        i++
                    }
                }
                return decoded
            default:
                return text
        }
    }

    ProcessBase64(text, mode) {
        ; Base64编解码（简化实现）
        switch mode {
            case "1": ; Base64编码
                return this.Base64Encode(text)
            case "2": ; Base64解码
                return this.Base64Decode(text)
            default:
                return text
        }
    }

    Base64Encode(text) {
        ; 简化的Base64编码
        charset := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        encoded := ""
        i := 1
        while (i <= StrLen(text)) {
            ; 每3个字符处理一次
            b1 := Ord(SubStr(text, i, 1))
            b2 := Ord(SubStr(text, i + 1, 1))
            b3 := Ord(SubStr(text, i + 2, 1))
            
            combined := (b1 << 16) | (b2 << 8) | b3
            
            encoded .= SubStr(charset, (combined >> 18) & 0x3F + 1, 1)
            encoded .= SubStr(charset, (combined >> 12) & 0x3F + 1, 1)
            encoded .= (i + 1 <= StrLen(text)) ? SubStr(charset, (combined >> 6) & 0x3F + 1, 1) : "="
            encoded .= (i + 2 <= StrLen(text)) ? SubStr(charset, combined & 0x3F + 1, 1) : "="
            
            i += 3
        }
        return encoded
    }

    Base64Decode(encoded) {
        ; 简化的Base64解码
        charset := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        decoded := ""
        i := 1
        while (i <= StrLen(encoded)) {
            char1 := SubStr(encoded, i, 1)
            char2 := SubStr(encoded, i + 1, 1)
            char3 := SubStr(encoded, i + 2, 1)
            char4 := SubStr(encoded, i + 3, 1)
            
            v1 := InStr(charset, char1) - 1
            v2 := InStr(charset, char2) - 1
            v3 := (char3 != "=") ? InStr(charset, char3) - 1 : 0
            v4 := (char4 != "=") ? InStr(charset, char4) - 1 : 0
            
            combined := (v1 << 18) | (v2 << 12) | (v3 << 6) | v4
            
            decoded .= Chr((combined >> 16) & 0xFF)
            if (char3 != "=") {
                decoded .= Chr((combined >> 8) & 0xFF)
            }
            if (char4 != "=") {
                decoded .= Chr(combined & 0xFF)
            }
            
            i += 4
        }
        return decoded
    }

    GetTextStatistics(text, mode) {
        ; 文本统计
        switch mode {
            case "1": ; 字符数
                return StrLen(text)
            case "2": ; 单词数
                words := StrSplit(text, [" ", "`t", "`n", "`r"])
                count := 0
                for word in words {
                    if (StrLen(word) > 0) {
                        count++
                    }
                }
                return count
            case "3": ; 行数
                lines := StrSplit(text, ["`n", "`r"])
                return lines.Length
            case "4": ; 中文字符数
                count := 0
                for char in StrSplit(text, "") {
                    if (this.IsChineseChar(char)) {
                        count++
                    }
                }
                return count
            default:
                return StrLen(text)
        }
    }

    SplitByLength(text, length, maxCount) {
        ; 按固定长度分割
        parts := []
        current := 1
        while (current <= StrLen(text)) {
            part := SubStr(text, current, length)
            parts.Push(part)
            current += length
            if (maxCount > 0 && parts.Length >= maxCount) {
                break
            }
        }
        return parts
    }

    SplitByMultipleDelimiters(text, delimiters, maxCount) {
        ; 按多个分隔符分割
        delimiterList := StrSplit(delimiters, "|")
        result := [text]
        
        for delimiter in delimiterList {
            newResult := []
            for part in result {
                subParts := StrSplit(part, delimiter)
                for subPart in subParts {
                    newResult.Push(subPart)
                }
            }
            result := newResult
        }
        
        if (maxCount > 0 && result.Length > maxCount) {
            loop result.Length - maxCount {
                result[maxCount] .= delimiterList[1] . result[maxCount + A_Index]
            }
            while (result.Length > maxCount) {
                result.RemoveAt(result.Length)
            }
        }
        
        return result
    }

    FilterLines(text, filter) {
        ; 过滤行
        if (!filter) {
            return text
        }
        
        lines := StrSplit(text, ["`n", "`r"])
        filtered := []
        
        for line in lines {
            if (InStr(line, filter)) {
                filtered.Push(line)
            }
        }
        
        resultText := ""
        for i, value in filtered {
            if (i > 1) {
                resultText .= "`n"
            }
            resultText .= value
        }
        return resultText
    }

    RemoveDuplicates(text) {
        ; 去重处理
        lines := StrSplit(text, ["`n", "`r"])
        unique := Map()
        result := []
        
        for line in lines {
            key := StrLen(line) > 0 ? line : ""
            if (!unique.Has(key)) {
                unique[key] := true
                result.Push(line)
            }
        }
        
        resultText := ""
        for i, value in result {
            if (i > 1) {
                resultText .= "`n"
            }
            resultText .= value
        }
        return resultText
    }

    SortText(text, reverse) {
        ; 排序处理
        lines := StrSplit(text, ["`n", "`r"])
        lines.Sort()
        
        if (reverse) {
            reversed := []
            loop lines.Length {
                reversed.Push(lines[lines.Length - A_Index + 1])
            }
            lines := reversed
        }
        
        resultText := ""
        for i, value in lines {
            if (i > 1) {
                resultText .= "`n"
            }
            resultText .= value
        }
        return resultText
    }

    GenerateRandomText(length) {
        ; 生成随机文本
        chars := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        randomText := ""
        
        length := length > 0 ? length : 10
        
        Loop length {
            randomIndex := Random(1, StrLen(chars))
            randomText .= SubStr(chars, randomIndex, 1)
        }
        
        return randomText
    }

    GetDateTime(format) {
        ; 获取格式化的日期时间
        now := A_Now
        if (!format) {
            format := "yyyy-MM-dd HH:mm:ss"
        }
        
        ; 简单的格式替换
        result := format
        result := StrReplace(result, "yyyy", FormatTime(now, "yyyy"))
        result := StrReplace(result, "MM", FormatTime(now, "MM"))
        result := StrReplace(result, "dd", FormatTime(now, "dd"))
        result := StrReplace(result, "HH", FormatTime(now, "HH"))
        result := StrReplace(result, "mm", FormatTime(now, "mm"))
        result := StrReplace(result, "ss", FormatTime(now, "ss"))
        
        return result
    }
}