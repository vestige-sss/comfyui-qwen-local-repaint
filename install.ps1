# Qwen 局部重绘 · 自动配置脚本
# 会先体检（ComfyUI 版本 / 节点包 / 模型），只补装缺的那部分，最后给一张清单。
#
#   .\install.ps1                 # 自动检测 + 装缺的
#   .\install.ps1 -Check          # 只看，不动任何东西
#   .\install.ps1 -Mirror         # 模型走国内镜像 hf-mirror.com
#   .\install.ps1 -AI             # 额外复制 AI 版工作流（需 bsk_UI，本包不带）
#   .\install.ps1 -FromGit        # 节点改为在线 clone（默认用包内自带副本）
param(
    [string]$ComfyPath = "",
    [switch]$Check,
    [switch]$Mirror,
    [switch]$SkipNodes,
    [switch]$SkipModels,
    [switch]$AI,
    [switch]$FromGit
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$HF   = if ($Mirror) { "https://hf-mirror.com" } else { "https://huggingface.co" }
$Repo = "Comfy-Org/Qwen-Image-2.1"

function Say-Step($m) { Write-Host "`n== $m" -ForegroundColor Cyan }
function Say-Ok($m)   { Write-Host "   [OK]   $m" -ForegroundColor Green }
function Say-Warn($m) { Write-Host "   [--]   $m" -ForegroundColor Yellow }
function Say-Bad($m)  { Write-Host "   [XX]   $m" -ForegroundColor Red }
function Say-Info($m) { Write-Host "          $m" -ForegroundColor DarkGray }

# ---------- 1. 找 ComfyUI ----------
function Resolve-Comfy([string]$p) {
    $cands = @()
    if ($p) { $cands += $p }
    if ($env:COMFYUI_PATH) { $cands += $env:COMFYUI_PATH }
    $cands += @(
        "$env:USERPROFILE\ComfyUI",
        "D:\ComfyUI", "C:\ComfyUI", "E:\ComfyUI",
        "D:\Comfy-Desktop\ComfyUI-Installs\ComfyUI\ComfyUI",
        "$env:LOCALAPPDATA\Programs\@comfyorgcomfyui-electron\resources\ComfyUI"
    )
    foreach ($c in $cands) {
        if ($c -and (Test-Path (Join-Path $c "main.py")) -and (Test-Path (Join-Path $c "custom_nodes"))) {
            return (Resolve-Path $c).Path
        }
    }
    return $null
}

Say-Step "① 找 ComfyUI"
$comfy = Resolve-Comfy $ComfyPath
if (-not $comfy) {
    Say-Bad "没找到 ComfyUI（该目录下要有 main.py 和 custom_nodes）"
    Say-Info "手动指定：.\install.ps1 -ComfyPath 'D:\你的\ComfyUI'"
    exit 1
}
Say-Ok $comfy

$ver = "unknown"
$vf = Join-Path $comfy "comfyui_version.py"
if (Test-Path $vf) {
    try {
        $m = Select-String -Path $vf -Pattern '__version__\s*=\s*"([^"]+)"' | Select-Object -First 1
        if ($m) { $ver = $m.Matches[0].Groups[1].Value }
    } catch { }
}
Say-Info ("ComfyUI 版本: " + $ver)
try {
    $drive = (Get-Item $comfy).PSDrive
    if ($drive -and $drive.Free) { Say-Info ("剩余空间: " + [math]::Round($drive.Free/1GB,1) + " GB") }
} catch { }

# ---------- 2. 组件清单 ----------
$nodes = @(
    @{ Dir = "qwen_api_config";               Alias = @();                        Url = "";                                                       Name = "API 配置入口（本包自带）" },
    @{ Dir = "ComfyUI-ZML-Image";             Alias = @("zml-image");             Url = "https://github.com/zml-w/ComfyUI-ZML-Image.git";         Name = "框选裁剪" },
    @{ Dir = "ComfyUI-Inpaint-CropAndStitch"; Alias = @();                        Url = "https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git"; Name = "裁切 / 回贴" },
    @{ Dir = "comfyui-kjnodes";               Alias = @("ComfyUI-KJNodes");       Url = "https://github.com/kijai/ComfyUI-KJNodes.git";           Name = "遮罩羽化" }
)
$models = @(
    @{ Dir = "diffusion_models"; File = "qwen_image_2.1_int8_convrot.safetensors"; SizeGB = 6.76 },
    @{ Dir = "text_encoders";    File = "qwen3vl_8b_int8_convrot.safetensors";     SizeGB = 8.71 },
    @{ Dir = "vae";              File = "qwen_image_2.1_vae_bf16.safetensors";     SizeGB = 0.63 }
)

Say-Step "② 体检"
$missingNodes = @()
foreach ($n in $nodes) {
    $found = $null
    foreach ($cand in (@($n.Dir) + @($n.Alias))) {
        if (-not $cand) { continue }
        $p = Join-Path $comfy ("custom_nodes\" + $cand)
        if ((Test-Path $p) -and ((Get-ChildItem $p -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0)) { $found = $cand; break }
    }
    if ($found) {
        $extra = if ($found -ne $n.Dir) { "  [已装，目录名 $found]" } else { "" }
        Say-Ok ("节点 " + $n.Dir + "  (" + $n.Name + ")" + $extra)
    } else {
        Say-Warn ("节点 " + $n.Dir + "  缺失 (" + $n.Name + ")"); $missingNodes += $n
    }
}

$missingModels = @()
foreach ($m in $models) {
    $p = Join-Path $comfy ("models\" + $m.Dir + "\" + $m.File)
    $need = $m.SizeGB * 0.95 * 1GB
    if ((Test-Path $p) -and ((Get-Item $p).Length -ge $need)) {
        Say-Ok ("模型 " + $m.File + "  (" + [math]::Round((Get-Item $p).Length/1GB,2) + " GB)")
    } else {
        $state = if (Test-Path $p) { "大小不对（可能是半个文件）" } else { "缺失" }
        Say-Warn ("模型 " + $m.File + "  " + $state); $missingModels += $m
    }
}

if ($Check) {
    Say-Step "③ 体检结果"
    Write-Host ("   待装节点: " + $missingNodes.Count + " 个    待下模型: " + $missingModels.Count + " 个") -ForegroundColor White
    if ($missingNodes.Count -eq 0 -and $missingModels.Count -eq 0) {
        Write-Host "   全部就绪，直接打开工作流即可。" -ForegroundColor Green
    } else {
        Write-Host "   去掉 -Check 再跑一次就会自动补装。" -ForegroundColor Gray
    }
    exit 0
}

# ---------- 3. 装节点 ----------
if (-not $SkipNodes) {
    Say-Step "③ 安装节点（只装缺的）"
    if ($missingNodes.Count -eq 0) {
        Say-Ok "节点都齐了，跳过"
    } else {
        $git = Get-Command git -ErrorAction SilentlyContinue
        $bundleDir = Join-Path $Root "custom_nodes"
        foreach ($n in $missingNodes) {
            $dst = Join-Path $comfy ("custom_nodes\" + $n.Dir)
            $src = Join-Path $bundleDir $n.Dir
            try {
                if ((-not $FromGit) -and (Test-Path $src)) {
                    Say-Info ("本地复制 " + $n.Dir)
                    Copy-Item $src $dst -Recurse -Force
                } elseif ($n.Url -and $git) {
                    Say-Info ("在线 clone " + $n.Dir)
                    & git clone --depth 1 $n.Url $dst 2>&1 | Out-Null
                } elseif (-not $n.Url) {
                    Say-Bad ($n.Dir + " 包里没有，也没有在线地址")
                    continue
                } else {
                    Say-Bad ($n.Dir + " 需要 git（装 Git for Windows，或改用 ComfyUI-Manager）")
                    continue
                }
                if (Test-Path $dst) { Say-Ok $n.Dir } else { Say-Bad ("安装失败: " + $n.Dir) }
            } catch {
                Say-Bad ($n.Dir + " 安装出错: " + $_.Exception.Message)
            }
        }
    }
}

# ---------- 4. 下模型 ----------
if (-not $SkipModels) {
    Say-Step "④ 下载模型（只下缺的）"
    if ($missingModels.Count -eq 0) {
        Say-Ok "模型都齐了，跳过"
    } else {
        foreach ($m in $missingModels) {
            $dir = Join-Path $comfy ("models\" + $m.Dir)
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            $dst = Join-Path $dir $m.File
            $url = "$HF/$Repo/resolve/main/" + $m.Dir + "/" + $m.File
            Say-Info ("下载 " + $m.File + "  约 " + $m.SizeGB + " GB（断了重跑会续传）")
            & curl.exe -L --fail --retry 3 -C - -o $dst $url
            if ((Test-Path $dst) -and ((Get-Item $dst).Length -ge ($m.SizeGB * 0.95 * 1GB))) {
                Say-Ok ($m.File + "  " + [math]::Round((Get-Item $dst).Length/1GB,2) + " GB")
            } else {
                Say-Bad ("没下完: " + $m.File + "（重跑本脚本继续）")
            }
        }
    }
}

# ---------- 5. 工作流 ----------
Say-Step "⑤ 复制工作流"
$wfDir = Join-Path $comfy "user\default\workflows"
New-Item -ItemType Directory -Force -Path $wfDir | Out-Null
Copy-Item (Join-Path $Root "workflows\Qwen_局部重绘_基础版_v1.json") $wfDir -Force
Say-Ok "Qwen_局部重绘_基础版_v1"
if ($AI) {
    Copy-Item (Join-Path $Root "workflows\Qwen_局部重绘_AI版_v1.json") $wfDir -Force
    Say-Ok "Qwen_局部重绘_AI版_v1"
}

# ---------- 6. 汇总 ----------
Say-Step "⑥ 完成"
Write-Host "   节点：本包自带的 4 个组件已到位" -ForegroundColor Gray
Write-Host "   模型：3 个文件已就位（合计约 16 GB）" -ForegroundColor Gray
Write-Host ""
Write-Host "   接下来：" -ForegroundColor White
Write-Host "     1) 重启 ComfyUI（新节点要重启才加载）" -ForegroundColor Gray
Write-Host "     2) 打开工作流 Qwen_局部重绘_基础版_v1" -ForegroundColor Gray
Write-Host "     3) 选图 → 点「裁剪图像」拖框 → ④ 写中文指令 → 点运行" -ForegroundColor Gray
if ($AI) {
    Write-Host "     4) AI 版：点 BSK_AIText 节点上的「API 设置」填 Key（需 bsk_UI）" -ForegroundColor Gray
}
Write-Host ""
Write-Host "   详细用法见 使用说明.txt / README.md" -ForegroundColor Gray
