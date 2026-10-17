"""Qwen 继续修改 —— 把本轮成品一键设为下一轮输入。

★ 本节点是 OUTPUT_NODE（终端节点）：ComfyUI 会"跳过输出没人用的节点"，
   所以它必须自己就是输出端，才会在每次运行时被执行。

运行：把进来的图写到 input/qwen_iter_HHMMSS.png，并记住文件名
前端：节点上按钮「▶ 设为下一轮输入」→ 查本节点最近的文件名 →
      把画布上 LoadImage 换成它，并清空 ZML 的 crop_data（旧坐标）
"""
import os
import time

import numpy as np
from PIL import Image

import folder_paths
from aiohttp import web
from server import PromptServer

WEB_DIRECTORY = "./js"
NODE_CLASS_MAPPINGS = {}
NODE_DISPLAY_NAME_MAPPINGS = {}

_LAST = {}


def _to_pil(image):
    arr = image[0].detach().cpu().numpy()
    arr = np.clip(arr * 255.0, 0, 255).astype(np.uint8)
    if arr.ndim == 2:
        return Image.fromarray(arr, "L").convert("RGB")
    if arr.shape[2] == 4:
        return Image.fromarray(arr, "RGBA").convert("RGB")
    return Image.fromarray(arr, "RGB")


class QwenContinue:
    """把输入图存到 input 目录，供下一轮直接使用。"""

    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "image": ("IMAGE",),
                "文件名前缀": ("STRING", {"default": "qwen_iter"}),
            },
            "hidden": {"unique_id": "UNIQUE_ID"},
        }

    RETURN_TYPES = ()
    RETURN_NAMES = ()
    FUNCTION = "save_for_next"
    CATEGORY = "QwenRepaint"
    OUTPUT_NODE = True          # ★ 关键：作为终端节点，保证被执行

    def save_for_next(self, image, 文件名前缀="qwen_iter", unique_id=None):
        text = ""
        try:
            in_dir = folder_paths.get_input_directory()
            os.makedirs(in_dir, exist_ok=True)
            prefix = (文件名前缀 or "qwen_iter").strip() or "qwen_iter"
            name = "%s_%s.png" % (prefix, time.strftime("%H%M%S"))
            _to_pil(image).save(os.path.join(in_dir, name))
            _LAST[str(unique_id or "0")] = name
            text = "已写入 input: " + name
            print("[Qwen 继续修改] " + text)
        except Exception as e:
            text = "保存失败: %r" % (e,)
            print("[Qwen 继续修改] " + text)
        return {"ui": {"text": [text]}}


@PromptServer.instance.routes.get("/qwen_continue/last")
async def last_saved(request):
    nid = str(request.rel_url.query.get("id", "0"))
    return web.json_response({"filename": _LAST.get(nid, ""), "all": _LAST})


NODE_CLASS_MAPPINGS["QwenContinue"] = QwenContinue
NODE_DISPLAY_NAME_MAPPINGS["QwenContinue"] = "Qwen 继续修改（设为下一轮输入）"
print("[Qwen 继续修改] 已加载（OUTPUT_NODE），路由 /qwen_continue/last")
