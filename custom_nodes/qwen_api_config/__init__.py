"""Qwen API 配置入口 —— 在 ComfyUI 前端给「AI 指令润色」填 API，不用手改 JSON。

- 后端：读写 ComfyUI/user/default/ai_text_config.json（与 bsk_UI 的 BSK_AIText 共用同一份配置）
- 前端：BSK_AIText 节点上出现「API 设置」按钮；也支持命令面板搜索 "API 设置"
- key 只在服务端落盘，读接口只回脱敏值
"""
import json
import os
import time
import urllib.request
import urllib.error

import folder_paths
from aiohttp import web
from server import PromptServer

BASE_DIR = getattr(folder_paths, "base_path", os.path.abspath("."))
CONFIG_DIR = os.path.join(BASE_DIR, "user", "default")
CONFIG_PATH = os.path.join(CONFIG_DIR, "ai_text_config.json")

WEB_DIRECTORY = "./js"
NODE_CLASS_MAPPINGS = {}
NODE_DISPLAY_NAME_MAPPINGS = {}

DEFAULTS = {
    "provider": "custom",
    "api_key": "",
    "base_url": "https://api.deepseek.com",
    "model": "deepseek-flash",
    "temperature": 0.4,
    "max_tokens": 4096,
    "vision": "on",
}


def load_config():
    cfg = dict(DEFAULTS)
    if os.path.isfile(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
            if isinstance(data, dict):
                cfg.update(data)
        except Exception:
            pass
    return cfg


def save_config(cfg):
    os.makedirs(CONFIG_DIR, exist_ok=True)
    # 必须是 UTF-8 无 BOM（bsk_UI 用 json.load 读）
    with open(CONFIG_PATH, "w", encoding="utf-8", newline="\n") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)


def mask_key(key):
    key = (key or "").strip()
    if len(key) <= 10:
        return "" if not key else "*" * len(key)
    return key[:6] + "***" + key[-4:]


def public(cfg):
    return {
        "base_url": cfg.get("base_url", ""),
        "model": cfg.get("model", ""),
        "temperature": cfg.get("temperature", 0.4),
        "max_tokens": cfg.get("max_tokens", 4096),
        "vision": cfg.get("vision", "on"),
        "has_key": bool((cfg.get("api_key") or "").strip()),
        "api_key_masked": mask_key(cfg.get("api_key", "")),
        "config_path": CONFIG_PATH,
    }


def _opener():
    # 绕过系统代理：Windows 下 urllib 会读注册表代理，代理软件没开时会 10061
    return urllib.request.build_opener(urllib.request.ProxyHandler({}))


@PromptServer.instance.routes.get("/qwen_api/config")
async def get_config(request):
    return web.json_response({"ok": True, **public(load_config())})


@PromptServer.instance.routes.post("/qwen_api/config")
async def set_config(request):
    try:
        data = await request.json()
    except Exception:
        return web.json_response({"ok": False, "error": "请求体不是 JSON"}, status=400)

    cfg = load_config()
    base_url = str(data.get("base_url") or cfg.get("base_url") or "").strip().rstrip("/")
    model = str(data.get("model") or cfg.get("model") or "").strip()
    key = str(data.get("api_key") or "").strip()

    if not base_url.startswith("http"):
        return web.json_response({"ok": False, "error": "Base URL 必须以 http(s):// 开头"}, status=400)
    if not model:
        return web.json_response({"ok": False, "error": "模型名不能为空"}, status=400)

    cfg["provider"] = "custom"
    cfg["base_url"] = base_url
    cfg["model"] = model
    if key:
        cfg["api_key"] = key
    try:
        cfg["temperature"] = float(data.get("temperature", cfg.get("temperature", 0.4)))
    except Exception:
        pass
    try:
        cfg["max_tokens"] = int(data.get("max_tokens", cfg.get("max_tokens", 4096)))
    except Exception:
        pass
    cfg["vision"] = "on" if str(data.get("vision", cfg.get("vision", "on"))) in ("on", "True", "true", "1") else "auto"

    save_config(cfg)
    return web.json_response({"ok": True, **public(cfg)})


@PromptServer.instance.routes.post("/qwen_api/test")
async def test_config(request):
    cfg = load_config()
    try:
        data = await request.json()
    except Exception:
        data = {}
    base_url = str(data.get("base_url") or cfg.get("base_url") or "").rstrip("/")
    model = str(data.get("model") or cfg.get("model") or "")
    key = str(data.get("api_key") or "").strip() or str(cfg.get("api_key") or "").strip()

    if not key:
        return web.json_response({"ok": False, "error": "还没填 API Key"})
    if not base_url.startswith("http"):
        return web.json_response({"ok": False, "error": "Base URL 不对"})

    body = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": "ping"}],
        "max_tokens": 8,
    }).encode("utf-8")
    req = urllib.request.Request(base_url + "/chat/completions", data=body, method="POST",
                                 headers={"Content-Type": "application/json",
                                          "Authorization": "Bearer " + key})
    t0 = time.time()
    try:
        with _opener().open(req, timeout=30) as resp:
            payload = json.loads(resp.read().decode("utf-8", "ignore"))
        ms = int((time.time() - t0) * 1000)
        return web.json_response({"ok": True, "ms": ms,
                                  "model": payload.get("model", model),
                                  "usage": payload.get("usage", {})})
    except urllib.error.HTTPError as e:
        detail = ""
        try:
            detail = e.read().decode("utf-8", "ignore")[:300]
        except Exception:
            pass
        return web.json_response({"ok": False, "error": "HTTP %s：%s" % (e.code, detail or e.reason)})
    except Exception as e:
        return web.json_response({"ok": False, "error": "%s: %s" % (type(e).__name__, e)})


print("[Qwen API 配置] 已注册路由 /qwen_api/config /qwen_api/test —— 配置文件: %s" % CONFIG_PATH)
