# dsh-toolkit — DeepSeek Harness (dsh) 安装/配置工具箱

> 面向国内 Windows 与 macOS 用户的一键安装与配置工具（dsh = DeepSeek Harness，DeepSeek 官方 Agent 工具）：npmmirror 镜像安装、allow-scripts 暗病修复、API Key 引导、settings.yaml 极简配置、视觉模型。
> **非官方教程**；DeepSeek Harness (dsh) 本身是 DeepSeek 官方发布的工具。
> **本文基于 dsh 0.1.1-rc.2 验证（2026-08-27）**。dsh 处于快速迭代期，出入以 `dsh --help` 为准。

[![Gitee](https://img.shields.io/badge/Gitee-yellowgu%2Fdsh--toolkit-red)](https://gitee.com/yellowgu/dsh-toolkit)
[![GitHub](https://img.shields.io/badge/GitHub-yellowgu%2Fdsh--toolkit-blue)](https://github.com/yellowgu/dsh-toolkit)
[![License](https://img.shields.io/badge/License-MIT-green)](./LICENSE)

## 适合谁

| 你的情况 | 用哪个 |
|---|---|
| 完全小白：没装过 Node / dsh（DeepSeek Harness） | 下面"一条命令安装"（Windows / macOS 各一条） |
| 已有 dsh，但配置报错 / 发图失败 / 模型不可用 | 一条命令安装（脚本自动检测+配置，按你的系统选命令），或装 Plugin 让修复自动化 |
| 只想看文档手动操作 | "手动安装步骤" + "常见故障表" |

## 一条命令安装（唯一推荐入口）

### Windows（Windows 11 + PowerShell 5.1）

> ⚠️ **不要下载脚本后双击运行**：双击 .ps1 会因执行策略拦截或窗口跑完即关而"闪退"，看起来像脚本坏了。也不要右键"使用 PowerShell 运行"。**唯一正确姿势 = 打开 PowerShell 窗口，粘贴下面这一条命令。**

打开 PowerShell（Win+X → 终端），粘贴整行回车（会先下载脚本到当前目录，再以放行模式执行；新电脑默认的 Restricted 执行策略拦不住）：

```powershell
irm https://gitee.com/yellowgu/dsh-toolkit/raw/main/install.ps1 -OutFile install.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
```

- 脚本第 3 步会把执行策略修成 RemoteSigned，之后重跑可用简写：`.\install.ps1`
- 帮别人现场装？把这条命令发给他即可（不要发脚本文件让人双击）

### macOS（macOS 13+，zsh 默认终端）

> ⚠️ **不要 `curl ... | bash`**：管道会占用标准输入，脚本的 Key 交互询问与结尾暂停会被自动跳过（等于静默跑完）。**也不要双击 .sh 文件**（默认用编辑器打开或无可见窗口，等于"闪退"）。**唯一正确姿势 = 打开「终端」App（Finder → 应用程序 → 实用工具），粘贴下面这一条命令。**

```bash
curl -fsSL https://gitee.com/yellowgu/dsh-toolkit/raw/main/install.sh -o install.sh && bash install.sh
```

与 Windows 同构：先下载到当前目录（可先打开文件审源码），再执行；装 Node 时会弹 sudo 密码提示（输入不回显是正常的），脚本只用 sudo 装 Node，其余步骤不需要管理员。

- 支持 macOS 13+（Apple Silicon / Intel 均支持，Node 官方 pkg 通用）
- macOS 的 API Key 持久化在 `~/.zshrc`（脚本自动按 `$SHELL` 选择 RC 文件，幂等去重）；GUI 启动/定时任务等非交互进程读不到 RC 变量，需自行 `source`（见 FAQ）
- 铁律重申：脚本**绝不** `killall node` / 强杀进程；报 EBUSY 时按提示手动关闭 dsh 窗口后重跑
- Gatekeeper：curl 下载不触发隔离检疫
- 无人值守/远程装机：`DEEPSEEK_API_KEY='sk-你的key' bash install.sh`（自动跳过询问）
- 脚本来自本仓库源码，**不放心的同学可先在网页查看 install.sh 源码**，再下载运行（两轨一致）

## 平台适用声明

| 平台 | 状态 |
|---|---|
| Windows 11 + PowerShell 5.1 | 完全支持（沙盒实测，输出示例见下） |
| macOS 13+ | 支持（脚本按学员实战方案编写，真机首装实录完成后将补示例；如遇问题请提 issue） |
| Linux | 不支持（install.sh 会直接退出并提示） |

## 脚本会做这些事（**每一步都会先打印说明再执行**）

Windows（install.ps1，7 步）：

1. 环境检测（Node / dsh / API Key / 运行中的进程）
2. 装 Node 22 LTS（仅当缺失，npmmirror CDN 直链；Node 门槛 ≥20，脚本装 v22.23.2 同时满足 Claude Code 的 ≥22 要求）
3. 解除 PowerShell 执行策略拦截
4. 安装 dsh（npm npmmirror 镜像）
5. allow-scripts 补跑（修复 npm 拦截安装脚本的暗病，幂等）
6. API Key 引导（输入不回显，只写本地用户级环境变量，不上传）+ settings.yaml 极简配置（**已有时自动备份且不覆盖**）
7. 收尾验证

macOS（install.sh，7 步，同构）：步骤 2 = pkg 下载 + sudo 静默安装；步骤 3 = npm 全局目录修复（根治 EACCES）；步骤 6 = Key 写 RC 文件（幂等去重）+ settings.yaml 同 Windows；其余步骤文案一致。

**注意事项**：

- 脚本**可重入**：装 Node / 设环境变量后提示重开终端，重跑即可继续，已完成步骤自动跳过
- 装 Node 需要**管理员权限**（Windows：右键 PowerShell"以管理员身份运行"后重跑；macOS：sudo 密码提示，输入不回显是正常的）
- 检测到 dsh 进程运行时，重装场景会**提示关闭后重跑**，绝不强杀进程
- 供应链说明：本脚本是"下载即执行"，请自行判断信任。所有下载地址均为固定版本

## ⚠️ 关于 danger-full-access（必读）

脚本生成的极简配置默认使用 `permission.defaultPreset: danger-full-access`：

- **含义**：跳过全部权限确认，Agent 的每条命令都会**直接执行，不做任何拦截**
- **免责声明**：该模式风险由用户自担；仅建议**单机自用**环境使用；多用户/生产环境请勿使用
- **普通模式对照**（改 settings.yaml 里 `defaultPreset` 一行即可）：

| preset | 效果 | 权限确认 |
|---|---|---|
| （不写或删掉该行） | `workspace-write`（官方默认）：命令限工作区写入 | 每次操作询问 |
| `workspace-write` | 同上 | 每次操作询问 |
| `read-only` | 只读，禁止写入 | 每次操作询问 |
| `danger-full-access` | 无限制 | **绝不询问** |

## 预期输出示例（Windows · 节选）

> 2026-08-28 沙盒实测录制：脚本 V1.0.0 + dsh 0.1.1-rc.2，已装场景（步骤 4 跳过安装）。
> 全新安装时步骤 4 会显示 npm 安装输出；`added` 包数、Node 版本随环境浮动，`[通过]` 标记是校验重点。
> V1.1.0 输出同构（差异仅：版本横幅、步骤 3 文案），下方为历史实录。

```powershell
================================================================
  dsh-toolkit V1.0.0 —— DeepSeek dsh 安装/配置脚本（非官方教程）
  源码可见：https://gitee.com/yellowgu/dsh-toolkit  （dsh 为 DeepSeek 官方工具，本脚本仅为国内环境经验分享）
================================================================
  [说明] 本脚本将按顺序执行：环境检测 → 装 Node(如需) → 解除执行策略 → 安装 dsh → allow-scripts 补跑 → API Key 引导 → settings.yaml 配置 → 收尾

[步骤] 1/7 环境检测
  [通过] Node.js 已安装：v26.7.0
  [通过] dsh 已检测到：0.1.1-rc.2
  [警告] 检测到 1 个 dsh 相关进程正在运行。若稍后需要重装/升级，会先提示关闭。

[步骤] 2/7 安装 Node —— 已跳过（本机已有 Node ≥ 20）

[步骤] 3/7 解除 PowerShell 执行策略拦截
  [通过] 执行策略可用：RemoteSigned

[步骤] 4/7 安装 dsh（npm 全局 + npmmirror 镜像）
  [通过] 已检测到 dsh 命令，跳过安装。（升级请见 README：升级前关闭所有 dsh 进程）

[步骤] 5/7 allow-scripts 补跑（修复 npm 拦截安装脚本的暗病）
  [说明] npm 默认拦截部分包的安装脚本，不补跑会有暗病（node-pty 原生模块、spawn helper 缺失）。本步骤无条件补跑一次，幂等安全。
  added 452 packages in 28s
  [通过] allow-scripts 补跑完成。

[步骤] 6/7 API Key 与 settings.yaml 配置
  [通过] DEEPSEEK_API_KEY 已存在（用户级环境变量），跳过。

!!! 安全警告（必读） !!!
上面即将写入的 settings.yaml 使用 defaultPreset: danger-full-access：
  - 该模式跳过全部权限确认，Agent 的每条命令都会直接执行，不做任何拦截；
  - 仅建议在单机自用环境使用；在生产/多用户环境请改用普通模式（见下）；
  - 使用风险由用户自担。

  [通过] settings.yaml 已创建于 C:\Users\<用户>\.dsh\settings.yaml（UTF-8 无 BOM）

[步骤] 7/7 收尾验证
  [通过] 验证通过：dsh 0.1.1-rc.2

================================================================
  全部步骤完成。
  [说明] 下一步：
  [说明]   1. 关闭本窗口，重新打开 PowerShell（让环境变量与 PATH 生效）
  [说明]   2. 运行 dsh web（首次运行自动初始化 web profile 并启动浏览器界面）
  [说明]   3. 一次性任务：dsh --profile headless "任务描述"
```

对照说明：

- 第 3 步通过时显示的策略名以终端实际为准（`RemoteSigned` / `Bypass` 都算通过）
- 首次运行无 API Key 时，步骤 6 会先询问并引导输入（输入不回显，只写用户级环境变量）
- `settings.yaml` 已存在时自动备份不覆盖（安全警告横幅每次都会完整显示）
- macOS 输出同构，差异仅：步骤 2 = pkg + sudo 安装、步骤 3 = prefix 修复提示、步骤 6 = Key 写 RC 文件；不伪造未真机实录的 macOS 示例

## 已有 Claude Code？装 Plugin 让修复自动化

在 Claude Code 会话里：

```
/plugin marketplace add yellowgu/dsh-toolkit
/plugin install dsh-toolkit@dsh-toolkit
```

安装后，当你描述 dsh 故障（如"dsh 配置报错"）时，修复 skill 会自动触发。
（注意：这里的 plugin 是 Claude Code 的插件机制，与 dsh 自带的 `dsh plugin --profile <name>` 是两码事——后者是 dsh 的 profile 插件管理。）

## 手动安装步骤

脚本每一步对应的命令（不想用脚本就照抄）：

### Windows

```powershell
# 0. Node ≥ 20（无则下载安装，npmmirror CDN 直链，装完必须重开终端）
Invoke-WebRequest -Uri "https://cdn.npmmirror.com/binaries/node/v22.23.2/node-v22.23.2-x64.msi" -OutFile "$env:TEMP\node-v22.23.2-x64.msi"
Start-Process msiexec.exe -ArgumentList '/i', "$env:TEMP\node-v22.23.2-x64.msi", '/qn', '/norestart' -Wait   # 需管理员

# 1. 解除执行策略拦截
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

# 2. 设置 DeepSeek API Key（在 platform.deepseek.com 获取；设完必须重开终端）
[Environment]::SetEnvironmentVariable("DEEPSEEK_API_KEY", "sk-你的key", "User")

# 3. 安装 dsh
npm install -g @deepseek-ai/dsh --registry=https://registry.npmmirror.com/

# 4. 必做：allow-scripts 补跑（否则有 node-pty 原生模块等暗病）
npm install -g @deepseek-ai/dsh --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs --registry=https://registry.npmmirror.com/

# 5. 验证
dsh --version   # 输出版本号（本文基于 0.1.1-rc.2）
```

### macOS

```bash
# 0. Node ≥ 20（npmmirror CDN pkg + sudo 静默安装，装完必须重开终端）
curl -L -o "$HOME/Downloads/node-v22.23.2.pkg" "https://cdn.npmmirror.com/binaries/node/v22.23.2/node-v22.23.2.pkg"
sudo installer -pkg "$HOME/Downloads/node-v22.23.2.pkg" -target /   # 密码输入不回显是正常的

# 1. 修复 npm 全局目录（根治 EACCES；仅当 npm config get prefix 落在 /usr/local 等 root 目录时需要）
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.zprofile
source ~/.zprofile

# 2. 设置 DeepSeek API Key（写入 ~/.zshrc，幂等去重；GUI/定时任务读不到需自行 source）
{ grep -v '^export DEEPSEEK_API_KEY=' ~/.zshrc 2>/dev/null; echo "export DEEPSEEK_API_KEY='sk-你的key'"; } > ~/.zshrc.tmp && mv ~/.zshrc.tmp ~/.zshrc
source ~/.zshrc

# 3. 安装 dsh
npm install -g @deepseek-ai/dsh --registry=https://registry.npmmirror.com/

# 4. 必做：allow-scripts 补跑（否则有 node-pty 原生模块等暗病）
npm install -g @deepseek-ai/dsh --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs --registry=https://registry.npmmirror.com/

# 5. 验证
dsh --version   # 输出版本号（本文基于 0.1.1-rc.2）
```

### settings.yaml 极简配置（8 行）

文件：`~/.dsh/settings.yaml`（Windows `C:\Users\<用户>\.dsh\settings.yaml`，两平台同路径；UTF-8；缩进两空格）：

```yaml
permission:
  defaultPreset: danger-full-access   # 安全说明见上文"关于 danger-full-access"

agent-default-model:
  provider: deepseek-official
  model: deepseek-v4-flash-vision-exp   # 默认模型；纯文本场景可换 deepseek-v4-flash
```

要点：

- provider 固定写 `deepseek-official`（新版的官方 provider id）
- API key 走 `DEEPSEEK_API_KEY` 环境变量（适配器默认，无需在 yaml 里声明）
- 0.1.1-rc.2+ 官方适配器（llm-deepseek）**内置视觉支持**，默认模型目录自带 `deepseek-v4-flash-vision-exp`（`inputModalities: [text, image]`），无需任何第三方适配器
- 修改后重启 dsh 生效

## 常用命令速查

| 命令 | 用途 |
|---|---|
| `dsh web` | 启动 web 界面（`--profile web` 别名） |
| `dsh --profile headless "任务"` | 一次性无头会话，打印结果退出 |
| `dsh --profile <name>` | 启动指定 profile |
| `dsh plugin --profile <name> <pnpm args>` | 管理 profile 插件（转发给 pnpm） |
| `dsh --dump-config` / `--dump-default-config` | 打印配置结构树（不反映 settings 快照） |
| `dsh --help` | launcher 自身帮助 |

## 常见故障表

### Windows

| 症状 | 原因 | 修复 |
|---|---|---|
| `dsh` 无法识别 | npm 全局目录 `C:\Users\<用户>\AppData\Roaming\npm` 不在 PATH，或 `dsh.cmd` 缺失 | 检查 PATH / 重装 |
| 启动报配置错误 | settings.yaml 缩进（两空格）与 UTF-8 编码；provider 必须 `deepseek-official` | 对照上文极简配置 |
| 模型不可用 | `DEEPSEEK_API_KEY` 未设或终端未重开 | 设环境变量 + 重开终端 |
| 发图报错 | 低于 0.1.1-rc.2 的旧版官方适配器只支持文本 | 升级 dsh（旧版要绕 pi-ai 第三方路由的方案已废弃，勿用） |
| 升级失败 EBUSY | dsh 进程在跑 | 关闭所有 dsh 进程（`Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object { $_.CommandLine -match 'dsh' }`）再装 |
| node-pty / spawn helper 报错 | npm 拦截了安装脚本 | 补跑 allow-scripts（见手动步骤第 4 步） |

### macOS

| 症状 | 原因 | 修复 |
|---|---|---|
| `npm install -g` 报 **EACCES** | npm 全局目录归 root 所有 | 脚本步骤 3 自动切 ~/.npm-global；手动命令见"手动安装步骤" macOS |
| `dsh: command not found` | ~/.npm-global/bin 不在 PATH | `source ~/.zprofile` 或重开终端 |
| 模型不可用（macOS） | Key 已写 ~/.zshrc 但终端未重开 | `source ~/.zshrc` 或重开终端；`echo $DEEPSEEK_API_KEY` 验证 |
| 升级失败 EBUSY（macOS） | dsh 进程在跑 | `pgrep -f '[d]sh'` 检查（方括号防自匹配），关闭所有 dsh 窗口再装（禁 `killall node`） |

## FAQ

**为什么用 npmmirror？** npm 官方源在国内慢/易失败，npmmirror 是国内同步镜像。

**web 和 headless 区别？** `dsh web` 是浏览器交互界面（持久会话）；`dsh --profile headless "任务"` 是一次性会话，打印结果就退出。两者首次使用都会自动初始化 profile。

**怎么升级？** 升级前关闭所有 dsh 进程（EBUSY 同理），然后：
`npm install -g @deepseek-ai/dsh@latest --registry=https://registry.npmmirror.com/`，再补跑一次 allow-scripts。

**怎么卸载？** `npm uninstall -g @deepseek-ai/dsh`（配置目录 `~/.dsh` 需手动删除）。

**dsh 版本迭代快，本文过时了怎么办？** README 显著标注了验证版本（0.1.1-rc.2）；出入以 `dsh --help` 与官方文档为准，也可提 issue 提醒更新。

**macOS 的 Key 写在哪？** `~/.zshrc`（脚本按 `$SHELL` 自动选择 `~/.zshrc` 或 `~/.bash_profile`），幂等去重不会重复追加。注意边界：GUI 启动/定时任务等非交互进程读不到 RC 变量，需自行 `source`。

**macOS 为什么不用 `curl | bash`？** 管道会占用标准输入，脚本的 Key 交互询问与结尾暂停会被自动跳过；且直接执行无法先审源码。本仓库命令先下载再执行，可先打开文件查看。

**prefix 修复是什么？** pkg 装的 Node 归 root 所有，`npm install -g` 必报 EACCES。把 npm 全局目录切到用户目录（~/.npm-global）是根治方案（官方不建议 `sudo npm install -g`）。

## 关于

- 作者：yellowgu（[Gitee](https://gitee.com/yellowgu) / [GitHub](https://github.com/yellowgu)）
- forge-ai 开源系列项目
- 反馈问题请提 [Issues](https://gitee.com/yellowgu/dsh-toolkit/issues)
- License: MIT
