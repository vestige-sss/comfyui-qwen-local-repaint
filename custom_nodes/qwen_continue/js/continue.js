// Qwen 继续修改：点一下把本轮成品设为下一轮输入，并清掉旧的框选坐标
// 自带一个可见的提示条（不依赖各套前端主题的 toast API）
import { app } from "../../../scripts/app.js";

const STYLE_ID = "qwen-continue-style";
let styleDone = false;

function injectStyle() {
  if (styleDone || document.getElementById(STYLE_ID)) return;
  styleDone = true;
  const s = document.createElement("style");
  s.id = STYLE_ID;
  s.textContent = `
  .qcont-toast{position:fixed;left:50%;top:14%;transform:translateX(-50%);z-index:10001;
    background:#1f2933;color:#e8f0f7;border:1px solid #3d4a57;border-radius:8px;
    padding:10px 16px;font:13px/1.5 system-ui,"Microsoft YaHei",sans-serif;
    box-shadow:0 8px 24px rgba(0,0,0,.45);max-width:70vw;transition:opacity .25s;}
  .qcont-toast.err{border-color:#a33;background:#2a1414;color:#ffd9d9;}
  `;
  document.head.appendChild(s);
}

function toast(msg, isErr) {
  try {
    injectStyle();
    const el = document.createElement("div");
    el.className = "qcont-toast" + (isErr ? " err" : "");
    el.textContent = msg;
    document.body.appendChild(el);
    setTimeout(() => { el.style.opacity = "0"; }, 2600);
    setTimeout(() => { el.remove(); }, 3000);
  } catch (e) {
    console.log("[Qwen 继续修改] " + msg);
  }
}

function setWidget(node, name, value) {
  const w = (node.widgets || []).find((x) => x.name === name);
  if (!w) return false;
  w.value = value;
  if (typeof w.callback === "function") {
    try { w.callback(value, app.canvas, node); } catch (e) {}
  }
  node.setDirtyCanvas?.(true, true);
  return true;
}

function findNodes() {
  return app.graph?._nodes || app.graph?.nodes || [];
}

async function applyToGraph(node) {
  let filename = "";
  try {
    const r = await fetch(`/qwen_continue/last?id=${node.id}`);
    const j = await r.json();
    filename = (j && j.filename) || "";
  } catch (e) {
    toast("读不到上一轮成品（请求失败）", true);
    return;
  }
  if (!filename) {
    toast("还没有成品：先点一次运行（⑧ 节点是输出节点，会执行）", true);
    return;
  }

  const nodes = findNodes();
  const loaders = nodes.filter((n) => n.type === "LoadImage");
  if (!loaders.length) {
    toast("画布里没有 LoadImage 节点", true);
    return;
  }
  loaders.forEach((n) => setWidget(n, "image", filename));

  const zm = nodes.filter((n) => n.type === "ZML_VisualCropImage");
  zm.forEach((n) => setWidget(n, "crop_data", "{}"));

  app.graph.setDirtyCanvas?.(true, true);
  app.canvas?.draw?.(true, true);
  toast(`已换图：${filename}` + (zm.length ? "（框选已清空，请重新画框）" : ""));
}

app.registerExtension({
  name: "QwenContinue.Button",
  async beforeRegisterNodeDef(nodeType, nodeData) {
    if (nodeData?.name !== "QwenContinue") return;
    const onCreated = nodeType.prototype.onNodeCreated;
    nodeType.prototype.onNodeCreated = function () {
      onCreated?.apply(this, arguments);
      try {
        this.addWidget("button", "▶ 设为下一轮输入", null, () => applyToGraph(this));
      } catch (e) {
        console.warn("[Qwen 继续修改] 加按钮失败", e);
      }
    };
  },
});
