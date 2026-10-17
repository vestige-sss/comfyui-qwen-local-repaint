# 一键填写 AI（视觉模型）API 配置 —— 不用手改 JSON
# 用法（任选一种）：
#   powershell -ExecutionPolicy Bypass -File .\设置API.ps1
#   .\设置API.ps1 -Key "sk-xxx" -Model deepseek-flash -BaseUrl "https://api.deepseek.com" -Test
#   .\设置API.ps1 -DryRun          # 只检查现有配置，不写文件
param(
    [string]$ComfyPath = "",
    [string]$Key = "",
    [string]$Model = "deepseek-flash",
    [string]$BaseUrl = "https://api.deepseek.com",
    [double]$Temperature = 0.4,
    [int]$MaxTokens = 4096,
    [switch]$Test,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Resolve-Comfy([string]$p) {
    $cands = @()
    if ($p) { $cands += $p }
    if ($env:COMFYUI_PATH) { $cands += $env:COMFYUI_PATH }
    $cands += @(
        "$env:USERPROFILE\ComfyUI",
        "D:\ComfyUI", "C:\ComfyUI", "E:\ComfyUI",
        "D:\Comfy-Desktop\ComfyUI-Installs\ComfyUI\ComfyUI"
    )
    foreach ($c in $cands) {
        if ($c -and (Test-Path (Join-Path $c "main.py")) -and (Test-Path (Join-Path $c "custom_nodes"))) {
            return (Resolve-Path $c).Path
        }
    }
    return $null
}

Write-Host "`n== 定位 ComfyUI" -ForegroundColor Cyan
$comfy = Resolve-Comfy $ComfyPath
if (-not $comfy) {
    Write-Host "   没找到 ComfyUI，请用 -ComfyPath 指定，例如 -ComfyPath 'D:\ComfyUI'" -ForegroundColor Red
    exit 1
}
Write-Host "   $comfy" -ForegroundColor Green

$cfgDir  = Join-Path $comfy "user\default"
$cfgPath = Join-Path $cfgDir "ai_text_config.json"

# ---------- 显示现有配置（key 打码） ----------
if (Test-Path $cfgPath) {
    Write-Host "`n== 现有配置: $cfgPath" -ForegroundColor Cyan
    try {
        $old = Get-Content $cfgPath -Raw -Encoding utf8 | ConvertFrom-Json
        $k = [string]$old.api_key
        $masked = if ($k.Length -gt 10) { $k.Substring(0,6) + "..." + $k.Substring($k.Length-4) } else { "（未设置）" }
        Write-Host ("   provider : " + $old.provider)
        Write-Host ("   base_url : " + $old.base_url)
        Write-Host ("   model    : " + $old.model)
        Write-Host ("   api_key  : " + $masked)
        Write-Host ("   vision   : " + $old.vision)
    } catch {
        Write-Host "   （文件存在但解析失败，会被覆盖）" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n== 还没有配置过（文件不存在）" -ForegroundColor Yellow
}

if ($DryRun) { Write-Host "`n-DryRun：不写文件，结束。`n" -ForegroundColor Gray; exit 0 }

# ---------- 采集 ----------
Write-Host "`n== 填写 API（直接回车 = 保持默认/原值）" -ForegroundColor Cyan
if (-not $Key) {
    $hint = "粘贴你的 API Key（sk- 开头），回车确认（输入会显示在屏幕上）"
    $Key = Read-Host $hint
}
if (-not $Key -or $Key.Trim().Length -lt 8) {
    Write-Host "   key 看起来不对，已退出（没改任何东西）" -ForegroundColor Red
    exit 1
}
$Model   = if ($Model)   { $Model }   else { "deepseek-flash" }
$BaseUrl = if ($BaseUrl) { $BaseUrl } else { "https://api.deepseek.com" }

# ---------- 可选：连通性测试 ----------
if ($Test) {
    Write-Host "`n== 测试连接" -ForegroundColor Cyan
    $body = @{
        model    = $Model
        messages = @(@{ role = "user"; content = "ping" })
        max_tokens = 8
    } | ConvertTo-Json -Depth 5 -Compress
    try {
        $r = Invoke-RestMethod -Uri ($BaseUrl.TrimEnd('/') + "/chat/completions") -Method Post `
             -Headers @{ "Authorization" = "Bearer $Key"; "Content-Type" = "application/json" } `
             -Body $body -TimeoutSec 30
        Write-Host ("   OK 模型可用: " + $r.model) -ForegroundColor Green
    } catch {
        Write-Host ("   测试失败: " + $_.Exception.Message) -ForegroundColor Yellow
        Write-Host "   仍会写入配置，你可以稍后再跑 -Test 复核" -ForegroundColor Gray
    }
}

# ---------- 写文件（UTF-8 无 BOM，Python json 才能直接读） ----------
$json = [ordered]@{
    provider    = "custom"
    api_key     = $Key.Trim()
    base_url    = $BaseUrl.TrimEnd('/')
    model       = $Model
    temperature = $Temperature
    max_tokens  = $MaxTokens
    vision      = "on"
} | ConvertTo-Json -Depth 5

New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
[System.IO.File]::WriteAllText($cfgPath, $json, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "`n== 已写入" -ForegroundColor Cyan
Write-Host "   $cfgPath" -ForegroundColor Green
Write-Host "   模型: $Model   地址: $BaseUrl" -ForegroundColor Gray
Write-Host "   回到 ComfyUI 直接 Queue 即可（配置在每次运行时读取，不用重启）" -ForegroundColor Gray
Write-Host "   AI 版工作流里把「④'-7 用 AI 润色？」保持 true；关掉就用手写指令。`n" -ForegroundColor Gray
