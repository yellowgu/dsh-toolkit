# ============================================================
#  dsh-toolkit / install.ps1  V1.1.0
#  DeepSeek dsh CLI 安装/配置一键脚本（Windows 11 + PowerShell 5.1）
#  Windows 专用；macOS 请用 install.sh（双平台说明见 README）
#  中国网络环境：npm 走 npmmirror 镜像，Node 走 npmmirror CDN
#  源码仓库：https://gitee.com/yellowgu/dsh-toolkit
#  非官方教程；dsh 本身是 DeepSeek 官方发布的工具。
#  每一步都会先说明再执行。脚本可重入：已完成的步骤会自动跳过。
#  基于 dsh 0.1.1-rc.2 验证（2026-08-27）。
# ============================================================

$RepoUrl = 'https://gitee.com/yellowgu/dsh-toolkit'
$NodeVer = 'v22.23.2'   # npmmirror CDN 固定版本（22 线最新 LTS；失效时换 v24.19.0，URL 结构相同）

function Say($msg)  { Write-Host $msg -ForegroundColor Cyan }
function Step($msg) { Write-Host ("`n[步骤] " + $msg) -ForegroundColor Yellow }
function Ok($msg)   { Write-Host ("  [通过] " + $msg) -ForegroundColor Green }
function Warn($msg) { Write-Host ("  [警告] " + $msg) -ForegroundColor DarkYellow }
function Bad($msg)  { Write-Host ("  [失败] " + $msg) -ForegroundColor Red; Write-Host '  脚本已停止。按提示处理后重跑本脚本即可（可重入，不会重复已完成的步骤）。' -ForegroundColor Red }
function Tip($msg)  { Write-Host ("  [说明] " + $msg) -ForegroundColor Gray }
function Die($msg)  { Bad $msg; exit 1 }

# ---------- 横幅 ----------
Say '================================================================'
Say '  dsh-toolkit V1.1.0 —— DeepSeek dsh 安装/配置脚本（非官方教程）'
Say ('  源码可见：' + $RepoUrl + '  （dsh 为 DeepSeek 官方工具，本脚本仅为国内环境经验分享）')
Say '================================================================'
Tip '本脚本将按顺序执行：环境检测 → 装 Node(如需) → 解除执行策略 → 安装 dsh → allow-scripts 补跑 → API Key 引导 → settings.yaml 配置 → 收尾'
Tip '每一步都会先打印说明再执行；已完成的步骤重跑时会自动跳过。'

# ---------- 1/7 环境检测 ----------
Step '1/7 环境检测'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Tip '当前非管理员窗口。本脚本仅在"需要安装 Node"时才要求管理员。' }

$nodeOk = $false
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($nodeCmd) {
    try {
        $nv = (& node -v 2>$null | Out-String).Trim()
        if ($nv -match '^v(\d+)') {
            if ([int]$Matches[1] -ge 20) { $nodeOk = $true; Ok ('Node.js 已安装：' + $nv) }
            else { Warn ('Node.js 版本过低：' + $nv + '（需要 ≥ 20，脚本将重装）') }
        }
    } catch { Warn 'node 存在但版本获取失败，视为缺失' }
}
if (-not $nodeOk) {
    if (-not $isAdmin) { Die '未检测到可用的 Node.js，而安装 Node 需要管理员权限。请关闭本窗口，右键 PowerShell"以管理员身份运行"，重新执行本脚本。' }
    Tip '未检测到 Node.js ≥ 20，稍后步骤 2/7 将自动安装。'
}

$hasDsh = $null -ne (Get-Command dsh -ErrorAction SilentlyContinue)
if ($hasDsh) {
    try { Ok ('dsh 已检测到：' + ((& dsh --version 2>$null | Out-String).Trim())) }
    catch { Warn 'dsh 命令存在但执行失败（可能已损坏），稍后步骤 4/7 会重装修复。' }
} else {
    Tip '未检测到 dsh 命令，稍后步骤 4/7 将自动安装。'
}

$dshProc = @(Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'dsh' })
if ($dshProc.Count -gt 0) { Warn ('检测到 ' + $dshProc.Count + ' 个 dsh 相关进程正在运行。若稍后需要重装/升级，会先提示关闭。') }

# ---------- 2/7 安装 Node（仅当缺失/过旧）----------
if (-not $nodeOk) {
    Step '2/7 安装 Node.js（npmmirror CDN 直链，静默安装）'
    $msi = Join-Path $env:TEMP ('node-' + $NodeVer + '-x64.msi')
    Tip ('下载 ' + $NodeVer + ' 安装包（约 30MB，来自 npmmirror CDN，国内快）……')
    try {
        Invoke-WebRequest -Uri ('https://cdn.npmmirror.com/binaries/node/' + $NodeVer + '/node-' + $NodeVer + '-x64.msi') -OutFile $msi -UseBasicParsing
        Tip '下载完成，开始静默安装（需要几十秒，请勿关闭本窗口）……'
        Start-Process msiexec.exe -ArgumentList '/i', ('"' + $msi + '"'), '/qn', '/norestart' -Wait
        Tip 'Node 已安装。Windows 的 PATH 是终端启动时快照：请关闭本窗口、重新打开 PowerShell，再重跑本脚本继续（步骤 1-2 会自动跳过）。'
        exit 0
    } catch { Die 'Node 下载或安装失败。请检查网络后重跑；或改 v24.19.0 直链手动下载。' }
} else {
    Step '2/7 安装 Node —— 已跳过（本机已有 Node ≥ 20）'
}

# ---------- 3/7 解除执行策略 ----------
Step '3/7 解除 PowerShell 执行策略拦截'
Tip '症状为"npm : 无法加载文件 ...npm.ps1，因为在此系统上禁止运行脚本"。修复方法：当前用户范围设为 RemoteSigned（不需要管理员）。'
# 进程作用域已是 Bypass（如以 powershell -ExecutionPolicy Bypass 启动）或被组策略锁定时，
# 本行会抛 SecurityException：设置其实已写入，只是提示被更具体作用域覆盖，属正常，静默吞掉。
# 注意 -ErrorAction SilentlyContinue 对此无效（实测仍打印红字），必须 try/catch。
try { Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force -ErrorAction Stop }
catch [System.Security.SecurityException] { }
catch { Warn ('执行策略设置失败：' + $_.Exception.Message) }
# 查【有效】策略而非 CurrentUser 作用域值：被组策略锁定时作用域值照样写成 RemoteSigned，
# 但有效策略仍是 Restricted、npm.ps1 照样被拦——只查作用域会误报"通过"。
$eff = (Get-ExecutionPolicy).ToString()
if ($eff -eq 'RemoteSigned' -or $eff -eq 'Unrestricted' -or $eff -eq 'Bypass') { Ok ('执行策略可用：' + $eff) }
else { Warn ('有效策略为 ' + $eff + '：npm.ps1 可能仍被拦（常见于组策略锁定的公司电脑）。若后续报"禁止运行脚本"，请重开终端重试，或联系 IT。') }

# ---------- 4/7 安装 dsh ----------
Step '4/7 安装 dsh（npm 全局 + npmmirror 镜像）'
if ($hasDsh) {
    Ok '已检测到 dsh 命令，跳过安装。（升级请见 README：升级前关闭所有 dsh 进程）'
} else {
    if ($dshProc.Count -gt 0) { Die '检测到 dsh 相关进程正在运行：重装会报 EBUSY。请关闭所有 dsh 窗口后重跑本脚本。（脚本不会自动强杀进程）' }
    Tip '执行：npm install -g @deepseek-ai/dsh（npmmirror 镜像）……'
    npm install -g @deepseek-ai/dsh --registry=https://registry.npmmirror.com/
    if ($LASTEXITCODE -ne 0) { Die 'npm 安装失败（若报 EBUSY 请关闭所有 dsh 窗口重跑；其他错误请检查网络后重跑，或看 README 故障表）。' }
    try {
        $v = (& dsh --version 2>$null | Out-String).Trim()
        if ($v) { Ok ('安装成功：' + $v) } else { Warn '安装完成但 dsh --version 无输出，请重开终端后再验证。' }
    } catch { Warn 'dsh 命令暂时不可用（PATH 快照问题），重开终端即可。' }
}

# ---------- 5/7 allow-scripts 补跑 ----------
Step '5/7 allow-scripts 补跑（修复 npm 拦截安装脚本的暗病）'
Tip 'npm 默认拦截部分包的安装脚本，不补跑会有暗病（node-pty 原生模块、spawn helper 缺失）。本步骤无条件补跑一次，幂等安全。'
npm install -g @deepseek-ai/dsh --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs --registry=https://registry.npmmirror.com/
if ($LASTEXITCODE -ne 0) { Warn 'allow-scripts 补跑未成功（可能已装好或网络波动）。后续使用中若遇 node-pty 相关报错，请重跑本步骤。' }
else { Ok 'allow-scripts 补跑完成。' }

# ---------- 6/7 API Key 与 settings.yaml ----------
Step '6/7 API Key 与 settings.yaml 配置'

# 6a. DEEPSEEK_API_KEY
$keyUser = [Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY', 'User')
$keyProc = $env:DEEPSEEK_API_KEY
if (-not [string]::IsNullOrWhiteSpace($keyUser)) {
    Ok 'DEEPSEEK_API_KEY 已存在（用户级环境变量），跳过。'
} elseif (-not [string]::IsNullOrWhiteSpace($keyProc)) {
    Tip '检测到当前终端有 DEEPSEEK_API_KEY，但未写入用户级（新终端不生效）。写入用户级环境变量……'
    [Environment]::SetEnvironmentVariable('DEEPSEEK_API_KEY', $keyProc, 'User')
    Ok '已写入用户级环境变量。'
} else {
    Tip '未检测到 DeepSeek API Key。请在 https://platform.deepseek.com 获取，粘贴后回车（输入不回显）：'
    $sec = Read-Host '请输入 DeepSeek API Key'
    $key = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
    if ([string]::IsNullOrWhiteSpace($key)) { Warn '未输入 Key，跳过（之后随时可用本脚本补设）。' }
    else {
        [Environment]::SetEnvironmentVariable('DEEPSEEK_API_KEY', $key.Trim(), 'User')
        Ok '已写入用户级环境变量（仅本地保存，不上传）。新开终端生效。'
    }
}

# 6b. settings.yaml 极简配置
$dshHome = Join-Path $env:USERPROFILE '.dsh'
$settingsPath = Join-Path $dshHome 'settings.yaml'
$minimal = @"
permission:
  defaultPreset: danger-full-access

agent-default-model:
  provider: deepseek-official
  model: deepseek-v4-flash-vision-exp   # 默认模型；纯文本场景可换 deepseek-v4-flash
"@
Say ''
Say '!!! 安全警告（必读） !!!'
Say '上面即将写入的 settings.yaml 使用 defaultPreset: danger-full-access：'
Say '  - 该模式跳过全部权限确认，Agent 的每条命令都会直接执行，不做任何拦截；'
Say '  - 仅建议在单机自用环境使用；在生产/多用户环境请改用普通模式（见下）；'
Say '  - 使用风险由用户自担。'
Say '普通模式对照（把 defaultPreset 一行改掉即可）：'
Say '  - 不写 defaultPreset 或 workspace-write（默认）：命令限工作区写入，每次操作询问确认；'
Say '  - read-only：只读模式，禁止写入，每次操作询问确认。'
Say ''
if (Test-Path $settingsPath) {
    $existing = [System.IO.File]::ReadAllText($settingsPath, [System.Text.Encoding]::UTF8).Trim()
    if ([string]::IsNullOrWhiteSpace($existing)) {
        [System.IO.File]::WriteAllText($settingsPath, $minimal, (New-Object System.Text.UTF8Encoding $false))
        Ok 'settings.yaml 已存在但为空，已写入极简配置（UTF-8）。'
    } else {
        $bak = $settingsPath + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
        Copy-Item $settingsPath $bak -Force
        Tip ('检测到已有 settings.yaml 配置，脚本不改动它（避免覆盖你的自定义配置）。已备份：' + $bak)
        Tip '如需使用上面验证过的极简配置，可手工替换；回滚方法：Copy-Item 备份文件回 settings.yaml。'
        Warn '请自行确认现有配置中 permission.defaultPreset 的值是否符合上面的安全说明。'
    }
} else {
    New-Item -ItemType Directory -Path $dshHome -Force | Out-Null
    [System.IO.File]::WriteAllText($settingsPath, $minimal, (New-Object System.Text.UTF8Encoding $false))
    Ok ('settings.yaml 已创建于 ' + $settingsPath + '（UTF-8 无 BOM）')
    Tip '修改后重启 dsh 生效；如需回滚，删除该文件后重跑本脚本或手工重建。'
}

# ---------- 7/7 收尾 ----------
Step '7/7 收尾验证'
try {
    $v = (& dsh --version 2>$null | Out-String).Trim()
    if ($v) { Ok ('验证通过：dsh ' + $v) } else { Warn 'dsh --version 无输出，请重开终端后再验证一次。' }
} catch { Warn 'dsh 命令不可用，请重开终端后再验证；仍失败请查 README 故障表。' }

Say ''
Say '================================================================'
Say '  全部步骤完成。'
Tip '下一步：'
Tip '  1. 关闭本窗口，重新打开 PowerShell（让环境变量与 PATH 生效）'
Tip '  2. 运行 dsh web（首次运行自动初始化 web profile 并启动浏览器界面）'
Tip '  3. 一次性任务：dsh --profile headless "任务描述"'
Tip '  4. 升级提醒：升级前关闭所有 dsh 进程（否则 EBUSY）'
Tip '  5. 已有 Claude Code 的用户：可安装本仓库 plugin 获得自动化故障修复'
Tip '     /plugin marketplace add yellowgu/dsh-toolkit'
Tip '     /plugin install dsh-toolkit@dsh-toolkit'
Tip ('  故障排查：' + $RepoUrl + ' 的 README 故障表；或提 issue。')
Say '================================================================'
