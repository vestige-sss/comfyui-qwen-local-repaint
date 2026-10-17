# 第三方组件与许可

本包**只包含工作流 JSON、文档与安装脚本**（作者原创，MIT）。运行所需的节点包与模型权重均**不随包分发**，
由 `install.ps1` 从各自的官方地址获取，版权与许可归各自作者。

## 节点包

| 包 | 仓库 | 许可 |
|---|---|---|
| ComfyUI-ZML-Image | https://github.com/zml-w/ComfyUI-ZML-Image | MIT（Copyright 2025 zml-w） |
| ComfyUI-Inpaint-CropAndStitch | https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch | 见仓库（Copyright 2024-2026 Luis Quesada Torres） |
| ComfyUI-KJNodes | https://github.com/kijai/ComfyUI-KJNodes | GPL-3.0 |
| ComfyUI-bsk_UI（**仅 AI 版需要，不随包分发**） | 作者 B站 @灰暗x（https://space.bilibili.com/26779709） | AGPL-3.0 |

> 关于 bsk_UI：其 README 明确为 AGPL-3.0，且只在其 B 站空间发布。本包不复制、不打包它的任何代码；
> AI 版工作流只是"在运行时调用"该插件提供的节点（相当于用户自行安装的依赖）。

## 模型

| 文件 | 来源 | 许可 |
|---|---|---|
| qwen_image_2.1_int8_convrot.safetensors | https://huggingface.co/Comfy-Org/Qwen-Image-2.1 | 见该模型卡（Qwen-Image 系列，Apache-2.0 为主） |
| qwen3vl_8b_int8_convrot.safetensors | 同上 | 同上 |
| qwen_image_2.1_vae_bf16.safetensors | 同上 | 同上 |

## ComfyUI 本体

需要 ComfyUI ≥ 0.36（本包在 0.37.0 实测）。`TextEncodeQwenImage21` / `QwenImage21Cache` /
`ModelAttentionBackend` / `MaskComposite` / `ImageStitch` / `EmptyImage` / `SaveText` 等节点均来自 ComfyUI 本体：
https://github.com/comfyanonymous/ComfyUI （GPL-3.0）

## 使用建议

- 商用前请自行核对上述各仓库与模型卡的最新许可条款。
- 若你修改并再分发本包，请保留本文件与 README 的署名信息。
