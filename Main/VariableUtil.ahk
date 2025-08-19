#Requires AutoHotkey v2.0

SetGlobalVar() {
    VariableMap := Map()
    visitMap := Map()
    loop MySoftData.TabNameArr.Length {
        tableItem := MySoftData.TableInfo[A_Index]
        tableIndex := A_Index
        for index, value in tableItem.ModeArr {
            if (tableItem.MacroArr.Length < index || tableItem.MacroArr[index] == "")
                continue

            macroStr := tableItem.MacroArr[index]
            GetMacroStrGlobalVar(macroStr, VariableMap, visitMap)
        }
    }
    MySoftData.GlobalVariMap := VariableMap
}

GetMacroStrGlobalVar(macroStr, VariableMap, visitMap) {
    cmdArr := SplitMacro(macroStr)
    loop cmdArr.Length {
        paramArr := StrSplit(cmdArr[A_Index], "_")
        if (paramArr.Length >= 2 && visitMap.Has(paramArr[2]))
            continue

        IsVariable := StrCompare(paramArr[1], "变量", false) == 0
        IsExVariable := StrCompare(paramArr[1], "变量提取", false) == 0
        IsIf := StrCompare(paramArr[1], "如果", false) == 0
        IsOpera := StrCompare(paramArr[1], "运算", false) == 0
        IsSearch := StrCompare(paramArr[1], "搜索", false) == 0
        IsSearchPro := StrCompare(paramArr[1], "搜索Pro", false) == 0

        if (IsVariable) {
            saveStr := IniRead(VariableFile, IniSection, paramArr[2], "")
            Data := JSON.parse(saveStr, , false)
            if (!Data.IsGlobal)
                continue
            loop 4 {
                if (Data.ToggleArr[A_Index])
                    VariableMap[Data.VariableArr[A_Index]] := true
            }
        }
        else if (IsExVariable) {
            saveStr := IniRead(ExVariableFile, IniSection, paramArr[2], "")
            Data := JSON.parse(saveStr, , false)
            if (!Data.IsGlobal)
                continue
            loop 4 {
                if (Data.ToggleArr[A_Index])
                    VariableMap[Data.VariableArr[A_Index]] := true
            }
        }
        else if (IsIf) {
            saveStr := IniRead(CompareFile, IniSection, paramArr[2], "")
            Data := JSON.parse(saveStr, , false)
            if (!Data.IsGlobal)
                continue
            if (Data.SaveToggle) {
                VariableMap[Data.SaveName] := true
            }
        }
        else if (IsOpera) {
            saveStr := IniRead(OperationFile, IniSection, paramArr[2], "")
            Data := JSON.parse(saveStr, , false)
            if (!Data.IsGlobal)
                continue
            loop 4 {
                if (Data.ToggleArr[A_Index])
                    VariableMap[Data.UpdateNameArr[A_Index]] := true
            }
        }

        TrueMacro := ""
        FalseMacro := ""
        if (IsIf) {
            saveStr := IniRead(CompareFile, IniSection, paramArr[2], "")
            Data := JSON.parse(saveStr, , false)

            TrueMacro := Data.TrueMacro
            FalseMacro := Data.FalseMacro
        }
        else if (IsSearch || IsSearchPro) {
            FileName := IsSearch ? SearchFile : SearchProFile
            saveStr := IniRead(FileName, IniSection, paramArr[2], "")
            Data := JSON.parse(saveStr, , false)

            TrueMacro := Data.TrueMacro
            FalseMacro := Data.FalseMacro
        }

        if (TrueMacro != "" || FalseMacro != "") {
            visitMap[paramArr[2]] := true
            GetMacroStrGlobalVar(TrueMacro, VariableMap, visitMap)
            GetMacroStrGlobalVar(TrueMacro, VariableMap, visitMap)
        }

    }
}

GetLocalVar(macroStr) {
    VariableMap := Map()
    visitMap := Map()
    GetMacroStrVar(macroStr, VariableMap, visitMap)
    return VariableMap
}

GetMacroStrVar(macroStr, VariableMap, visitMap) {
    cmdArr := SplitMacro(macroStr)
    loop cmdArr.Length {
        paramArr := StrSplit(cmdArr[A_Index], "_")
        if (visitMap.Has(paramArr[2]))
            continue

        IsVariable := StrCompare(paramArr[1], "变量", false) == 0
        IsExVariable := StrCompare(paramArr[1], "变量提取", false) == 0
        IsIf := StrCompare(paramArr[1], "如果", false) == 0
        IsOpera := StrCompare(paramArr[1], "运算", false) == 0
        IsSearch := StrCompare(paramArr[1], "搜索", false) == 0
        IsSearchPro := StrCompare(paramArr[1], "搜索Pro", false) == 0

        if (IsVariable) {
            saveStr := IniRead(VariableFile, IniSection, paramArr[2], "")
            Data := JSON.parse(saveStr, , false)
            loop 4 {
                if (Data.ToggleArr[A_Index])
                    VariableMap[Data.VariableArr[A_Index]] := true
            }
        }
        else if (IsExVariable) {
            saveStr := IniRead(ExVariableFile, IniSection, paramArr[2], "")
            Data := JSON.parse(saveStr, , false)
            loop 4 {
                if (Data.ToggleArr[A_Index])
                    VariableMap[Data.VariableArr[A_Index]] := true
            }
        }
        else if (IsIf) {
            saveStr := IniRead(CompareFile, IniSection, paramArr[2], "")
            Data := JSON.parse(saveStr, , false)
            if (Data.SaveToggle) {
                VariableMap[Data.SaveName] := true
            }
        }
        else if (IsSearch || IsSearchPro) {
            FileName := IsSearch ? SearchFile : SearchProFile
            saveStr := IniRead(FileName, IniSection, paramArr[2], "")
            Data := JSON.parse(saveStr, , false)
            if (Data.ResultToggle) {
                VariableMap[Data.ResultSaveName] := true
            }

            if (Data.CoordToogle) {
                VariableMap[Data.CoordXName] := true
                VariableMap[Data.CoordXName] := true
            }
        }
        else if (IsOpera) {
            saveStr := IniRead(OperationFile, IniSection, paramArr[2], "")
            Data := JSON.parse(saveStr, , false)
            loop 4 {
                if (Data.ToggleArr[A_Index])
                    VariableMap[Data.UpdateNameArr[A_Index]] := true
            }
        }

        TrueMacro := ""
        FalseMacro := ""
        if (IsIf) {
            saveStr := IniRead(CompareFile, IniSection, paramArr[2], "")
            Data := JSON.parse(saveStr, , false)

            TrueMacro := Data.TrueMacro
            FalseMacro := Data.FalseMacro
        }
        else if (IsSearch || IsSearchPro) {
            FileName := IsSearch ? SearchFile : SearchProFile
            saveStr := IniRead(FileName, IniSection, paramArr[2], "")
            Data := JSON.parse(saveStr, , false)

            TrueMacro := Data.TrueMacro
            FalseMacro := Data.FalseMacro
        }

        if (TrueMacro != "" || FalseMacro != "") {
            visitMap[paramArr[2]] := true
            GetMacroStrGlobalVar(TrueMacro, VariableMap, visitMap)
            GetMacroStrGlobalVar(TrueMacro, VariableMap, visitMap)
        }
    }
}

GetGuiVariableObjArr(curMacroStr, VariableObjArr) {
    ResultArr := []
    ResultMap := GetLocalVar(curMacroStr)
    for index, Value in VariableObjArr {
        ResultMap[Value] := true
    }

    for Key, Value in ResultMap {
        ResultArr.Push(Key)
    }
    ResultArr.Push("当前循环次数")
    ResultArr.Push("当前鼠标坐标X")
    ResultArr.Push("当前鼠标坐标Y")

    for Key, Value in MySoftData.GlobalVariMap {
        if (!ResultMap.Has(Key))
            ResultArr.Push(Key)
    }

    return ResultArr
}
