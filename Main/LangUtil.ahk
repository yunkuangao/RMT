#Requires AutoHotkey v2.0
LangKeyMap := Map()
LangInitSetting() {
    LangMap := Map("中文", 1)   ;确保存在中文
    if (DirExist(LangDir)) {
        loop files, LangDir "\*.txt" {
            SplitPath A_LoopFileName, &OutFileName, &OutDir, &OutExtension, &OutNameNoExt, &OutDrive
            LangMap[OutNameNoExt] := 1
        }
    }

    for Key, Value in LangMap {
        MySoftData.LangArr.Push(Key)
    }

    if (MySoftData.Lang == "无语言") {
        ChineseMap := Map("7804", 1, "0004", 1, "0804", 1, "1004", 1, "7C04", 1, "0C04", 1, "1404", 1, "0404", 1)
        if (ChineseMap.Has(A_Language))
            MySoftData.Lang := "中文"
        else {
            MySoftData.Lang := "English"
        }
    }
}

LangKeysInit() {
    if (MySoftData.Lang == "中文")  ;中文就不用做处理了
        return

    LangFilePath := Format("{}\{}.txt", LangDir, MySoftData.Lang)
    if (!FileExist(LangFilePath))
        return

    try {
        ; 以 UTF-8 编码打开文件
        file := FileOpen(LangFilePath, "r", "UTF-8")

        while !file.AtEOF {
            line := file.ReadLine()
            if (line = "")  ; 跳过空行
                continue

            LineStrArr := StrSplit(line, "=")
            if (LineStrArr.Length == 2) {
                LangKeyMap[Trim(LineStrArr[1])] := Trim(LineStrArr[2])
            }
        }

        file.Close()
    } catch as e {
        MsgBox GetLang("读取文件失败:") e.Message
    }
}

LangRemoveRepeat() {
    LangFilePath := Format("{}\{}.txt", LangDir, "中文")
    NewLangFilePath := Format("{}\{}.txt", LangDir, "New中文")
    file := FileOpen(LangFilePath, "r", "UTF-8")
    ResultArr := []
    KeyMap := Map()
    while !file.AtEOF {
        line := file.ReadLine()
        if (line = "")  ; 跳过空行
            continue
        key := Trim(line)
        if (!KeyMap.Has(key)) {
            KeyMap[key] := 1
            ResultArr.Push(key)
        }
    }
    file.Close()

    ; FileDelete(LangFilePath)
    for value in ResultArr {
        FileAppend(value "`n", NewLangFilePath, "UTF-8")
    }
    MsgBox("中文Key去重成功")
}

GetLang(Key) {
    ;中文或者LangKeyMap不存在时 直接返回key就行
    if (MySoftData.Lang == "中文" || LangKeyMap.Count == 0)
        return key

    if (LangKeyMap.Has(Key))
        return LangKeyMap[Key]

    return Key
}

GetLangArr(KeyArr) {
    ResArr := []
    for Value in KeyArr {
        ResArr.Push(GetLang(Value))
    }
    return ResArr
}
