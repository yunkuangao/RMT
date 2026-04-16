# YOLOs-DLL

将 [YOLOs-CPP](https://github.com/Geekgineer/YOLOs-CPP) 编译为**独立 DLL**，提供 C 风格 API，可从 AutoHotkey调用。

> **这是一个打包工具** — 不包含 YOLOs-CPP 源码。使用者自行克隆 YOLOs-CPP 仓库后，用本工具一键编译出 DLL。

---

## 快速开始

### 1. 准备 YOLOs-CPP 源码

在同级目录

```
YOLO
├── YOLOs-CPP

└── dll
```


```bash
git clone https://github.com/Geekgineer/YOLOs-CPP.git
```

### 2. 准备 OpenCV / ONNX Runtime / Build Tools + C++ 桌面开发

OpenCV: 下载并解压 [OpenCV](https://github.com/opencv/opencv/releases/tag/4.8.1) （如 `opencv-4.8.1-windows.exe`）,设置环境变量:`$env:OpenCV_DIR = "C:\opencv\build"`

ONNX Runtime: 下载并解压 [ONNX Runtime](https://github.com/microsoft/onnxruntime/releases/tag/v1.24.4)（如 v1.24.4）,设置环境变量:`$env:ONNXRUNTIME_DIR = "C:\onnxruntime"`

Build Tools C++ 桌面开发: 安装[Build Tools C++ 桌面开发](https://visualstudio.microsoft.com/zh-hans/visual-cpp-build-tools/)，选择"使用C++的桌面开发"，安装即可

### 3. 运行打包脚本

```powershell
cd dll

# 基本用法
.\build.ps1
```

### 4. 输出文件

编译完成后 `dll/` 目录下包含：

```
dll/
├── yolos.dll              # DLL
```

将这些文件复制到YOLO目录即可使用。