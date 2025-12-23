; 进度条分析器 - 集成多种算法的进度条识别模块
; 
; 作者: yun <yun@yka.moe>
; 
; 依赖说明（由RMT.ahk全局引入）：
; - 必需: Gdip_All.ahk (图像处理)
; - 可选: RapidOcr.ahk (OCR文字识别，若缺失会自动降级到颜色分析算法)
; 
; 用于变量提取功能中的进度条识别
; 支持OCR识别、颜色分析、HSV分析、边缘检测等多种算法

; 统一进度条分析器接口
AnalyzeProgressBar(bitmap) {
    ; 算法优先级：OCR -> 优化颜色 -> HSV颜色 -> 边缘检测 -> 原始融合
    
    ; 第一层：OCR识别（最高优先级）
    ocrResult := TryOCRRecognition(bitmap)
    if (ocrResult.success) {
        return {
            method: "OCR",
            percentage: ocrResult.percentage,
            confidence: 95,
            details: ocrResult.text
        }
    }
    
    ; 第二层：优化颜色分析
    colorResult := OptimizedColorAnalysis(bitmap)
    if (colorResult.confidence > 70) {
        return colorResult
    }
    
    ; 第三层：HSV颜色分析
    hsvResult := HSVColorAnalysis(bitmap)
    if (hsvResult.confidence > 75) {
        return hsvResult
    }
    
    ; 第四层：边缘检测
    edgeResult := EdgeDetectionAnalysis(bitmap)
    if (edgeResult.confidence > 65) {
        return edgeResult
    }
    
    ; 第五层：原始算法融合（兜底）
    return OriginalAlgorithmFusion(bitmap)
}

; OCR识别尝试
TryOCRRecognition(bitmap) {
    try {
        ; 使用全局OCR实例，优先使用中文OCR
        ocr := IsSet(MyChineseOcr) ? MyChineseOcr : MyEnglishOcr
        if (!ocr || !ocr.ptr) {
            return {success: false}
        }
        
        ; 保存临时文件
        tempFile := A_Temp "\temp_progress_ocr.png"
        Gdip_SaveBitmapToFile(bitmap, tempFile)
        
        ; 设置OCR参数
        param := RapidOcr.OcrParam()
        param.doAngle := false
        param.maxSideLen := 1024
        param.boxScoreThresh := 0.3
        param.boxThresh := 0.2
        
        result := ocr.ocr_from_file(tempFile, param, true)
        
        ; 清理临时文件
        if (FileExist(tempFile)) {
            FileDelete(tempFile)
        }
        
        if (!result || result.Length == 0) {
            return {success: false}
        }
        
        ; 提取最佳文本
        bestText := FindBestOCRText(result)
        percentage := ExtractPercentage(bestText)
        
        if (percentage >= 0 && percentage <= 100) {
            return {
                success: true,
                percentage: percentage,
                text: bestText
            }
        }
        
        return {success: false}
        
    } catch {
        return {success: false}
    }
}

; 找到最佳OCR文本
FindBestOCRText(results) {
    bestText := ""
    maxConfidence := 0
    
    for textBlock in results {
        ; 优先选择包含数字和斜杠的文本
        if (RegExMatch(textBlock.text, "\d+[,/]\d+")) {
            confidence := textBlock.boxScore * 100
            if (confidence > maxConfidence) {
                maxConfidence := confidence
                bestText := textBlock.text
            }
        }
    }
    
    ; 如果没有找到数字文本，返回第一个
    if (bestText == "" && results.Length > 0) {
        bestText := results[1].text
    }
    
    return bestText
}

; 提取百分比
ExtractPercentage(text) {
    ; 清理文本
    cleanText := RegExReplace(text, "[^\d,/\s]", "")
    
    ; 匹配完整的 "数字/数字" 格式
    if (RegExMatch(cleanText, "(\d+(?:,\d+)*)\s*/\s*(\d+(?:,\d+)*)", &match)) {
        current := StrReplace(match[1], ",", "")
        total := StrReplace(match[2], ",", "")
        
        ; 放宽数字合理性检查
        if (total > 0 && current >= 0 && current <= total * 100) {
            return Round((current / total) * 100)  ; 只取整数
        }
    }
    
    return -1
}

; 优化的颜色分析
OptimizedColorAnalysis(bitmap) {
    width := Gdip_GetImageWidth(bitmap)
    height := Gdip_GetImageHeight(bitmap)
    centerY := height // 2
    
    ; 检测有效区域
    startX := Round(width * 0.1)
    endX := Round(width * 0.9)
    
    ; 采样像素
    pixels := []
    loop (endX - startX) {
        x := startX + A_Index - 1
        color := Gdip_GetPixel(bitmap, x, centerY)
        r := (color >> 16) & 0xFF
        g := (color >> 8) & 0xFF
        b := color & 0xFF
        
        pixels.Push({
            r: r, g: g, b: b,
            brightness: (r + g + b) / 3,
            saturation: GetSaturation(r, g, b)
        })
    }
    
    ; 检测进度条类型
    dominantColor := GetDominantColor(pixels)
    
    if (dominantColor.r > dominantColor.g && dominantColor.r > dominantColor.b) {
        ; 红色系血条
        return AnalyzeRedBar(pixels)
    } else if (dominantColor.b > dominantColor.r && dominantColor.b > dominantColor.g) {
        ; 蓝色系蓝条
        return AnalyzeBlueBar(pixels)
    } else {
        ; 通用分析
        return AnalyzeGenericBar(pixels)
    }
}

; 获取饱和度
GetSaturation(r, g, b) {
    max_val := Max(r, g, b)
    min_val := Min(r, g, b)
    return (max_val == 0) ? 0 : (max_val - min_val) / max_val * 100
}

; 获取主要颜色
GetDominantColor(pixels) {
    totalR := 0, totalG := 0, totalB := 0
    for pixel in pixels {
        totalR += pixel.r
        totalG += pixel.g
        totalB += pixel.b
    }
    return {
        r: totalR / pixels.Length,
        g: totalG / pixels.Length,
        b: totalB / pixels.Length
    }
}

; 分析红色血条
AnalyzeRedBar(pixels) {
    filledPixels := 0
    for pixel in pixels {
        if (pixel.r > 100 && pixel.saturation > 30) {
            filledPixels++
        }
    }
    percentage := (filledPixels / pixels.Length) * 100
    return {method: "RedColorAnalysis", percentage: Round(percentage), confidence: 80}
}

; 分析蓝色蓝条
AnalyzeBlueBar(pixels) {
    filledPixels := 0
    for pixel in pixels {
        if (pixel.b > 100 && pixel.saturation > 30) {
            filledPixels++
        }
    }
    percentage := (filledPixels / pixels.Length) * 100
    return {method: "BlueColorAnalysis", percentage: Round(percentage), confidence: 80}
}

; 通用分析
AnalyzeGenericBar(pixels) {
    filledPixels := 0
    for pixel in pixels {
        if (pixel.saturation > 25) {
            filledPixels++
        }
    }
    percentage := (filledPixels / pixels.Length) * 100
    return {method: "GenericColorAnalysis", percentage: Round(percentage), confidence: 75}
}

; HSV颜色分析
HSVColorAnalysis(bitmap) {
    width := Gdip_GetImageWidth(bitmap)
    height := Gdip_GetImageHeight(bitmap)
    centerY := height // 2
    
    startX := Round(width * 0.1)
    endX := Round(width * 0.9)
    
    ; 采样像素并转换为HSV
    pixels := []
    loop (endX - startX) {
        x := startX + A_Index - 1
        color := Gdip_GetPixel(bitmap, x, centerY)
        r := (color >> 16) & 0xFF
        g := (color >> 8) & 0xFF
        b := color & 0xFF
        
        hsv := RGBtoHSV(r, g, b)
        pixels.Push({
            r: r, g: g, b: b,
            h: hsv.h, s: hsv.s, v: hsv.v
        })
    }
    
    ; 基于HSV特征分析进度
    return AnalyzeHSVProgress(pixels)
}

; RGB转HSV
RGBtoHSV(r, g, b) {
    r := r / 255.0
    g := g / 255.0
    b := b / 255.0
    
    max_val := Max(r, g, b)
    min_val := Min(r, g, b)
    delta := max_val - min_val
    
    ; 计算色相(H)
    if (delta == 0) {
        h := 0
    } else if (max_val == r) {
        h := 60 * (((g - b) / delta) + (g < b ? 6 : 0))
    } else if (max_val == g) {
        h := 60 * (((b - r) / delta) + 2)
    } else {
        h := 60 * (((r - g) / delta) + 4)
    }
    
    ; 计算饱和度(S)
    s := (max_val == 0) ? 0 : (delta / max_val)
    
    ; 计算明度(V)
    v := max_val
    
    return {h: h, s: s * 100, v: v * 100}
}

; 分析HSV进度
AnalyzeHSVProgress(pixels) {
    if (pixels.Length < 5) {
        return {method: "HSVAnalysis", percentage: 50, confidence: 30}
    }
    
    ; 检测主要色相
    dominantHue := GetDominantHue(pixels)
    
    ; 根据色相判断进度条类型
    if (dominantHue >= 200 && dominantHue <= 260) {
        ; 蓝色系 (200-260度)
        return AnalyzeBlueHSV(pixels)
    } else if ((dominantHue >= 0 && dominantHue <= 30) || (dominantHue >= 330 && dominantHue <= 360)) {
        ; 红色系 (0-30度 或 330-360度)
        return AnalyzeRedHSV(pixels)
    } else if (dominantHue >= 60 && dominantHue <= 180) {
        ; 绿色系 (60-180度)
        return AnalyzeGreenHSV(pixels)
    } else {
        ; 其他颜色
        return AnalyzeGenericHSV(pixels)
    }
}

; 获取主要色相
GetDominantHue(pixels) {
    totalH := 0
    validPixels := 0
    
    for pixel in pixels {
        ; 只考虑有颜色的像素（饱和度>10）
        if (pixel.s > 10) {
            totalH += pixel.h
            validPixels++
        }
    }
    
    return (validPixels > 0) ? (totalH / validPixels) : 0
}

; 分析蓝色HSV进度条
AnalyzeBlueHSV(pixels) {
    filledPixels := 0
    
    for pixel in pixels {
        ; 蓝色填充：色相在蓝色范围，饱和度和明度适中
        if (pixel.h >= 200 && pixel.h <= 260 && pixel.s > 30 && pixel.v > 30) {
            filledPixels++
        }
    }
    
    percentage := (filledPixels / pixels.Length) * 100
    return {method: "HSVBlueAnalysis", percentage: Round(percentage), confidence: 85}
}

; 分析红色HSV进度条
AnalyzeRedHSV(pixels) {
    filledPixels := 0
    
    for pixel in pixels {
        ; 红色填充：色相在红色范围，饱和度和明度适中
        isRed := (pixel.h >= 0 && pixel.h <= 30) || (pixel.h >= 330 && pixel.h <= 360)
        if (isRed && pixel.s > 30 && pixel.v > 30) {
            filledPixels++
        }
    }
    
    percentage := (filledPixels / pixels.Length) * 100
    return {method: "HSVRedAnalysis", percentage: Round(percentage), confidence: 85}
}

; 分析绿色HSV进度条
AnalyzeGreenHSV(pixels) {
    filledPixels := 0
    
    for pixel in pixels {
        ; 绿色填充：色相在绿色范围，饱和度和明度适中
        if (pixel.h >= 60 && pixel.h <= 180 && pixel.s > 30 && pixel.v > 30) {
            filledPixels++
        }
    }
    
    percentage := (filledPixels / pixels.Length) * 100
    return {method: "HSVGreenAnalysis", percentage: Round(percentage), confidence: 85}
}

; 通用HSV分析
AnalyzeGenericHSV(pixels) {
    filledPixels := 0
    
    for pixel in pixels {
        ; 有颜色的像素（饱和度>20，明度>20）
        if (pixel.s > 20 && pixel.v > 20) {
            filledPixels++
        }
    }
    
    percentage := (filledPixels / pixels.Length) * 100
    return {method: "HSVGenericAnalysis", percentage: Round(percentage), confidence: 75}
}

; 边缘检测分析
EdgeDetectionAnalysis(bitmap) {
    width := Gdip_GetImageWidth(bitmap)
    height := Gdip_GetImageHeight(bitmap)
    centerY := height // 2
    
    startX := Round(width * 0.1)
    endX := Round(width * 0.9)
    
    maxGradient := 0
    edgePosition := (startX + endX) // 2
    
    loop (endX - startX - 1) {
        x := startX + A_Index
        color1 := Gdip_GetPixel(bitmap, x-1, centerY)
        color2 := Gdip_GetPixel(bitmap, x, centerY)
        gradient := CalculateColorDistance(color1, color2)
        
        if (gradient > maxGradient) {
            maxGradient := gradient
            edgePosition := x
        }
    }
    
    percentage := ((edgePosition - startX) / (endX - startX)) * 100
    confidence := Min(85, 40 + maxGradient / 3)
    
    return {method: "EdgeDetection", percentage: Round(percentage), confidence: Round(confidence)}
}

; 计算颜色距离
CalculateColorDistance(color1, color2) {
    r1 := (color1 >> 16) & 0xFF
    g1 := (color1 >> 8) & 0xFF
    b1 := color1 & 0xFF
    
    r2 := (color2 >> 16) & 0xFF
    g2 := (color2 >> 8) & 0xFF
    b2 := color2 & 0xFF
    
    return Sqrt((r1-r2)**2 + (g1-g2)**2 + (b1-b2)**2)
}

; 原始算法融合（简化版）
OriginalAlgorithmFusion(bitmap) {
    width := Gdip_GetImageWidth(bitmap)
    height := Gdip_GetImageHeight(bitmap)
    centerY := height // 2
    
    startX := Round(width * 0.2)
    endX := Round(width * 0.8)
    
    ; 简化的亮度分析
    totalBrightness := 0
    pixelCount := 0
    
    loop (endX - startX) {
        x := startX + A_Index - 1
        color := Gdip_GetPixel(bitmap, x, centerY)
        r := (color >> 16) & 0xFF
        g := (color >> 8) & 0xFF
        b := color & 0xFF
        brightness := (r + g + b) / 3
        
        totalBrightness += brightness
        pixelCount++
    }
    
    avgBrightness := totalBrightness / pixelCount
    
    ; 基于平均亮度估算进度
    if (avgBrightness > 200) {
        percentage := 0
    } else if (avgBrightness < 80) {
        percentage := 100
    } else {
        percentage := 100 - ((avgBrightness - 80) / 120) * 100
    }
    
    return {method: "OriginalFusion", percentage: Round(Max(0, Min(100, percentage))), confidence: 65}
}