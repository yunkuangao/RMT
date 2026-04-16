"""
YOLO 模型导出为 ONNX

用法: python export_onnx.py <模型.pt> [类别1 类别2 ...]
示例: python export_onnx.py yolo26n.pt person car bus
"""

import os, sys

def main():
    args = sys.argv[1:]
    if not args or "-h" in args or "--help" in args:
        print(__doc__)
        return
    model_path = args[0]
    classes = args[1:] if len(args) > 1 else ["object"]

    from ultralytics import YOLO
    print(f"加载 {model_path} ...")
    model = YOLO(model_path)
    
    out_name = os.path.splitext(os.path.basename(model_path))[0] + ".onnx"
    out_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "models", out_name)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    print(f"导出 -> {out_path}")
    model.export(format="onnx", nms=False, imgsz=640, simplify=True)
    
    if os.path.exists(out_path):
        print(f"完成 ({os.path.getsize(out_path) / 1024 / 1024:.1f} MB)")
        print(f"类别: {classes}")
    else:
        # 搜索实际输出
        for f in os.listdir(os.path.dirname(out_path)):
            if f.endswith(".onnx"):
                print(f"完成: models/{f}")

if __name__ == "__main__":
    main()
