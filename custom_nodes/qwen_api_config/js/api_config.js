// Qwen API 配置入口 —— 在 BSK_AIText 节点上加「API 设置」按钮，弹窗填写并保存到服务端
import { app } from "../../../scripts/app.js";

const SETTINGS_STYLE_ID = "qwen-api-config-style";

function injectStyle() {
  if (document.getElementById(SETTINGS_STYLE_ID)) return;
  const css = `
  .qapi-mask{position:fixed;inset:0;background:rgba(0,0,0,.65);display:flex;align-items:center;
    justify-content:center;z-index:10000;}
  .qapi-box{background:#222;color:#ddd;border:1px solid #3a3a3a;border-radius:10px;padding:18px 20px;
    width:460px;max-width:92vw;font:13px/1.6 system-ui,"Microsoft YaHei",sans-serif;}
  .qapi-box h3{margin:0 0 4px;font-size:15px;color:#fff;}
  .qapi-tip{color:#888;margin:0 0 14px;font-size:12px;}
  .qapi-row{display:flex;align-items:center;margin:9px 0;gap:10px;}
  .qapi-row label{width:92px;color:#aaa;flex:none;}
  .qapi-row input[type=text],.qapi-row input[type=password],.qapi-row input[type=number]{
    flex:1;background:#171717;border:1px solid #3a3a3a;color:#eee;border-radius:6px;padding:7px 9px;
    font:13px ui-monospace,Consolas,monospace;outline:none;}
  .qapi-row input:focus{border-color:#4b8bf5;}
  .qapi-actions{display:flex;gap:10px;justify-content:flex-end;margin-top:16px;}
  .qapi-btn{border:none;border-radius:6px;padding:8px 16px;cursor:pointer;font-size:13px;color:#fff;}
  .qapi-btn.primary{background:#3b7ddd;}
  .qapi-btn.ghost{background:#3a3a3a;}
  .qapi-btn.test{background:#2e7d5b;}
  .qapi-status{margin-top:12px;font-size:12px;color:#8bc34a;min-height:18px;}
  .qapi-status.err{color:#ef5350;}
  `;
  const s = document.createElement("style");
  s.id = SETTINGS_STYLE_ID;
  s.textContent = css;
  document.head.appendChild(s);
}

async function apiGet(path) {
  const r = await fetch(path, { headers: { "Content-Type": "application/json" } });
  return await r.json();
}
async function apiPost(path, body) {
  const r = await fetch(path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body || {}),
  });
  return await r.json();
}

function field(box, label, opts) {
  const row = document.createElement("div");
  row.className = "qapi-row";
  const lb = document.createElement("label");
  lb.textContent = label;
  const inp = document.createElement("input");
  inp.type = opts.type || "text";
  if (opts.placeholder) inp.placeholder = opts.placeholder;
  if (opts.value !== undefined && opts.value !== null) inp.value = opts.value;
  row.appendChild(lb);
  row.appendChild(inp);
  box.appendChild(row);
  return inp;
}

export async function openApiDialog() {
  injectStyle();
  let cfg = {};
  try {
    cfg = await apiGet("/qwen_api/config");
  } catch (e) {
    cfg = { ok: false };
  }

  const mask = document.createElement("div");
  mask.className = "qapi-mask";

  const box = document.createElement("div");
  box.className = "qapi-box";
  box.innerHTML = `<h3>AI 指令润色 · API 配置</h3>
    <p class="qapi-tip">填一次就行，保存在本机；工作流文件里不会带 Key。</p>`;
  mask.appendChild(box);

  const baseUrl = field(box, "Base URL", { value: cfg.base_url || "https://api.deepseek.com" });
  const model = field(box, "模型", { value: cfg.model || "deepseek-flash" });
  const key = field(box, "API Key", {
    type: "password",
    placeholder: cfg.has_key ? "已保存：" + cfg.api_key_masked + "（留空 = 不修改）" : "sk-...",
  });
  const temp = field(box, "温度", { type: "number", value: cfg.temperature ?? 0.4 });

  const status = document.createElement("div");
  status.className = "qapi-status";

  const actions = document.createElement("div");
  actions.className = "qapi-actions";
  const btnTest = document.createElement("button");
  btnTest.className = "qapi-btn test";
  btnTest.textContent = "测试连接";
  const btnSave = document.createElement("button");
  btnSave.className = "qapi-btn primary";
  btnSave.textContent = "保存";
  const btnClose = document.createElement("button");
  btnClose.className = "qapi-btn ghost";
  btnClose.textContent = "关闭";
  actions.append(btnTest, btnSave, btnClose);
  box.appendChild(actions);
  box.appendChild(status);

  const say = (msg, isErr) => {
    status.textContent = msg || "";
    status.className = "qapi-status" + (isErr ? " err" : "");
  };
  if (cfg.config_path) box.title = "配置文件：" + cfg.config_path;

  btnTest.onclick = async () => {
    say("测试中…");
    btnTest.disabled = true;
    const r = await apiPost("/qwen_api/test", {
      base_url: baseUrl.value.trim(),
      model: model.value.trim(),
      api_key: key.value.trim(),
    });
    btnTest.disabled = false;
    say(r.ok ? `连通 OK（${r.ms} ms，模型 ${r.model}）` : "失败：" + (r.error || "未知错误"), !r.ok);
  };

  btnSave.onclick = async () => {
    say("保存中…");
    const r = await apiPost("/qwen_api/config", {
      base_url: baseUrl.value.trim(),
      model: model.value.trim(),
      api_key: key.value.trim(),
      temperature: parseFloat(temp.value) || 0.4,
      vision: "on",
    });
    if (r.ok) {
      key.value = "";
      key.placeholder = "已保存：" + r.api_key_masked + "（留空 = 不修改）";
      say("已保存，直接 Queue 就生效（不用重启）");
    } else {
      say("保存失败：" + (r.error || "未知错误"), true);
    }
  };

  btnClose.onclick = () => mask.remove();
  mask.onclick = (e) => { if (e.target === mask) mask.remove(); };

  document.body.appendChild(mask);
  key.focus();
  return mask;
}

// 全局兜底：控制台或命令面板里都能调
window.qwenApiConfig = openApiDialog;

app.registerExtension({
  name: "QwenApiConfig.Entry",
  async beforeRegisterNodeDef(nodeType, nodeData) {
    if (nodeData?.name !== "BSK_AIText") return;
    const onCreated = nodeType.prototype.onNodeCreated;
    nodeType.prototype.onNodeCreated = function () {
      onCreated?.apply(this, arguments);
      try {
        this.addWidget("button", "API 设置（点这里填 Key）", null, () => openApiDialog());
      } catch (e) {
        console.warn("[QwenApiConfig] 添加按钮失败", e);
      }
    };
  },

  async setup() {
    // 命令面板（有就注册，没有就跳过）
    try {
      const cmd = app?.extensionManager?.command;
      if (cmd?.registerCommand) {
        cmd.registerCommand({
          id: "QwenApiConfig.OpenDialog",
          label: "打开 AI API 配置",
          function: () => openApiDialog(),
        });
      }
    } catch (e) {
      /* 老版本前端没有命令面板，忽略 */
    }
  },
});
