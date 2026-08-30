---
name: dsh-install
description: >
  在 Windows 或 macOS 上安装与配置 DeepSeek 官方 dsh CLI(@deepseek-ai/dsh,npm 全局版,中国网络 npmmirror 镜像)。
  触发场景: "安装 dsh"、"DeepSeek Harness 安装"、`dsh` 命令无法识别、首次 `dsh web` 初始化、settings.yaml
  配置(agent-default-model、permission 预设、视觉模型)、headless 用法、npm 安装脚本被拦截(allow-scripts);
  macOS:`npm install -g` 报 EACCES、npm 全局目录修复、Key 写 ~/.zshrc、sudo 安装 Node pkg。
  2026-08-27 实战验证 @deepseek-ai/dsh@0.1.1-rc.2(Windows);macOS 步骤按学员实战方案编写,真机首装实录待补。
license: MIT
metadata:
  version: "1.1"
  category: dev-environment
---

# DeepSeek dsh 安装与配置(Windows / macOS + npm 全局 + 中国网络)

> 2026-08-27 实战验证(0.1.1-rc.2,Windows);macOS 按 2026-08-29 学员实战方案编写。dsh = DeepSeek Harness 的 profile 启动器:管理 web/headless 等 profile。
> 相关 skill:[[claude-install]](Node 前置与平台拦截问题共用其第 0、1 节)。

## 0. 前置

**Windows**:

- Node.js ≥ 20(见 [[claude-install]] 第 0 节;PowerShell 执行策略报错见其第 1 节)
- DeepSeek API key 写入用户级环境变量后**重开终端**:

```powershell
[Environment]::SetEnvironmentVariable("DEEPSEEK_API_KEY", "sk-xxx", "User")
```

**macOS**:

- Node.js ≥ 20(见 [[claude-install]] 第 0 节 macOS 部分:pkg + `sudo installer` 静默装)
- npm 全局目录修复(根治 EACCES,见 [[claude-install]] 第 1 节 macOS 部分)
- DeepSeek API key 写入 `~/.zshrc`(幂等去重,新终端自动生效):

```bash
{ grep -v '^export DEEPSEEK_API_KEY=' ~/.zshrc 2>/dev/null; echo "export DEEPSEEK_API_KEY='sk-xxx'"; } > ~/.zshrc.tmp && mv ~/.zshrc.tmp ~/.zshrc
source ~/.zshrc
```

- 注意:Key 写在 RC 文件(登录 shell 生效);GUI 启动/定时任务等非交互进程读不到 RC 变量,需自行 source。

## 1. 安装

```bash
npm install -g @deepseek-ai/dsh --registry=https://registry.npmmirror.com/
```

**必做一步**:npm 默认拦截部分包的安装脚本,不处理会有暗病(node-pty 原生模块、spawn helper 缺失)。装完后看到 `allowScripts` 警告就补跑(Windows PowerShell / macOS zsh 同一命令):

```bash
npm install -g @deepseek-ai/dsh --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs --registry=https://registry.npmmirror.com/
```

验证:`dsh --version` 输出版本号即成功。

## 2. 首次初始化 profile

```bash
dsh web                      # 首次运行自动初始化 web profile 到 ~/.dsh/profiles/web,并启动浏览器 UI
dsh --profile headless "任务描述"   # 一次性会话,打印最终答案后退出
```

- `web` / `headless` 首次使用自动初始化;**其他 profile 必须用 `dsh plugin` 创建**。
- 运行目录 = workspace 根;launcher 不认识的第一个 token 之后的参数全部透传给应用(`dsh --profile web --port 8080`)。

## 3. settings.yaml 配置(极简版,验证过)

文件:`~/.dsh/settings.yaml`(Windows `C:\Users\<用户>\.dsh\settings.yaml`,**UTF-8**;两平台路径相同)。

0.1.1-rc.2+ 官方适配器(llm-deepseek)**内置视觉支持**,默认模型目录自带 `deepseek-v4-flash-vision-exp`(`inputModalities: [text, image]`),无需任何第三方适配器。最小配置:

```yaml
permission:
  defaultPreset: danger-full-access

agent-default-model:
  provider: deepseek-official
  model: deepseek-v4-flash-vision-exp   # 默认模型;纯文本场景可换 deepseek-v4-flash
```

> 安全提示:`danger-full-access` 跳过全部权限确认,仅建议单机自用;普通模式对照:不写 `defaultPreset`(默认 `workspace-write`,每次操作询问)或 `read-only`(只读)。

要点:

- provider 固定写 `deepseek-official`(新版的官方 provider id)。
- API key 走 `DEEPSEEK_API_KEY` 环境变量(适配器默认,无需在 yaml 里声明)。
- 内置默认值:上下文 1M、输出上限 256K、图片预算 640K px / 1MB——不用像旧版那样手工配 maxTokens。
- 修改后重启 dsh 生效;`dsh --profile web --dump-config` 可看结构树(注意:它不反映 settings.yaml 快照,最终以启动后 UI 模型选择器为准)。

## 4. 常用命令速查

| 命令 | 用途 |
|---|---|
| `dsh web` | 启动 web 界面(`--profile web` 别名) |
| `dsh --profile headless "任务"` | 一次性无头会话,打印结果退出 |
| `dsh --profile <name>` | 启动指定 profile |
| `dsh plugin --profile <name> <pnpm args>` | 管理 profile 插件(转发给 pnpm) |
| `dsh --dump-config` / `--dump-default-config` | 打印配置结构树(不反映 settings 快照) |
| `dsh --help` | launcher 自身帮助 |

## 5. 故障速查

**Windows**:

- `dsh` 无法识别 → npm 全局目录 `C:\Users\<用户>\AppData\Roaming\npm` 必须在 PATH,`dsh.cmd` 应存在。
- 启动报配置错误 → settings.yaml 缩进(两空格)与 UTF-8 编码;provider 必须是 `deepseek-official`。
- 模型不可用 → 确认 `DEEPSEEK_API_KEY` 已设且终端重开过。
- 发图报错 → 低于 0.1.1-rc.2 的旧版官方适配器只支持文本,需升级(旧版要绕 pi-ai 路由,已废弃)。
- 升级失败 EBUSY → 关闭所有 dsh 进程(`Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object { $_.CommandLine -match 'dsh' }`)再装。

**macOS**:

- `dsh` 无法识别 → `~/.npm-global/bin` 不在 PATH;`source ~/.zprofile` 或重开终端,`~/.npm-global/bin/dsh` 符号链接应存在。
- `npm install -g` 报 EACCES → npm 全局目录归 root;prefix 修复(见第 0 节 / [[claude-install]] 第 1 节)。
- 模型不可用 → `~/.zshrc` 已写 Key 但终端未重开;`echo $DEEPSEEK_API_KEY` 验证,或 `source ~/.zshrc`。
- 升级失败 EBUSY → `pgrep -f '[d]sh'` 检查(方括号防自匹配),关闭所有 dsh 窗口再装;禁 `killall node`。
