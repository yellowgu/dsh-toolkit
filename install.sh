#!/bin/bash
# ============================================================
#  dsh-toolkit / install.sh  V1.1.0
#  DeepSeek dsh CLI 安装/配置一键脚本（macOS 13+，bash 3.2 兼容）
#  中国网络环境：npm 走 npmmirror 镜像，Node 走 npmmirror CDN
#  源码仓库：https://gitee.com/yellowgu/dsh-toolkit
#  非官方教程；dsh 本身是 DeepSeek 官方发布的工具。
#  每一步都会先说明再执行。脚本可重入：已完成的步骤会自动跳过。
#  铁律：本脚本绝不强杀任何进程（无 kill/killall 调用）。
#  基于 dsh 0.1.1-rc.2 验证（2026-08-27）。
#  DRY_RUN=1 可预演全流程（不产生任何写入）。
# ============================================================

REPO_URL='https://gitee.com/yellowgu/dsh-toolkit'
NODE_VER='v22.23.2'   # npmmirror CDN 固定版本（22 线最新 LTS；失效时换 v24.19.0，URL 结构相同）
NODE_MIN=20
PKG_URL="https://cdn.npmmirror.com/binaries/node/$NODE_VER/node-$NODE_VER.pkg"
DRY_RUN="${DRY_RUN:-0}"

# ---------- 输出与错误兜底 ----------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  CY='\033[36m'; YE='\033[33m'; GR='\033[32m'; RE='\033[31m'; GRY='\033[90m'; RS='\033[0m'
else
  CY=''; YE=''; GR=''; RE=''; GRY=''; RS=''
fi
say()  { printf "${CY}%s${RS}\n" "$1"; }
step() { printf "\n${YE}[步骤] %s${RS}\n" "$1"; }
ok()   { printf "${GR}  [通过] %s${RS}\n" "$1"; }
warn() { printf "${YE}  [警告] %s${RS}\n" "$1"; }
bad()  { printf "${RE}  [失败] %s${RS}\n" "$1"; printf "${RE}  脚本已停止。按提示处理后重跑本脚本即可（可重入，不会重复已完成的步骤）。${RS}\n"; }
tip()  { printf "${GRY}  [说明] %s${RS}\n" "$1"; }
die()  { bad "$1"; exit 1; }
on_err() { bad "脚本在第 $1 行出错已停止。按提示处理后重跑本脚本即可（可重入，不会重复已完成的步骤）。"; exit 1; }
# 只兜底"未显式处理的失败"；不用 set -e（if 条件与 || 路径不触发 ERR，可控）
trap 'on_err $LINENO' ERR
set -o pipefail 2>/dev/null || true

# DRY_RUN 模拟执行：只打印说明，不真正执行
run() {
  local desc="$1"; shift
  if [ "$DRY_RUN" = "1" ]; then tip "[DRY_RUN 模拟] $desc"; return 0; fi
  "$@"
}

# 把值安全地塞进单引号（RC 文件 export 写法）：' -> '\''
escape_rc_value() {
  local v="$1" out='' i=0 ch
  while [ "$i" -lt "${#v}" ]; do
    ch=${v:$i:1}
    if [ "$ch" = "'" ]; then out="${out}'\\''"; else out="${out}${ch}"; fi
    i=$((i+1))
  done
  printf '%s' "$out"
}

# ---------- 平台守卫 ----------
[ "$(uname -s)" = "Darwin" ] || [ "$DRY_RUN" = "1" ] || die '本脚本仅支持 macOS。Windows 请用 install.ps1（见 README）。'
if command -v sw_vers >/dev/null 2>&1; then
  SWVER=$(sw_vers -productVersion 2>/dev/null | tr -d '[:space:]') || SWVER=''
  SWMAJOR=${SWVER%%.*}
  case "$SWMAJOR" in
    ''|*[!0-9]*) ;;
    *) if [ "$SWMAJOR" -lt 13 ]; then warn "macOS 13+ 为实战验证范围，当前版本（${SWVER}）未经实测，可能失败。"; fi ;;
  esac
fi
HAS_PGREP=0; command -v pgrep >/dev/null 2>&1 && HAS_PGREP=1

# ---------- 横幅 ----------
say '================================================================'
say '  dsh-toolkit V1.1.0 —— DeepSeek dsh 安装/配置脚本（非官方教程，macOS）'
say "  源码可见：$REPO_URL  （dsh 为 DeepSeek 官方工具，本脚本仅为国内环境经验分享）"
say '================================================================'
tip '本脚本将按顺序执行：环境检测 → 装 Node(如需) → 修复 npm 全局目录(EACCES) → 安装 dsh → allow-scripts 补跑 → API Key 引导 → settings.yaml 配置 → 收尾'
tip '每一步都会先打印说明再执行；已完成的步骤重跑时会自动跳过。'

# ---------- 1/7 环境检测 ----------
step '1/7 环境检测'

nodeOk=0
if command -v node >/dev/null 2>&1; then
  NV=$(node -v 2>/dev/null | tr -d '[:space:]') || NV=''
  NV=${NV#v}
  MAJOR=${NV%%.*}
  case "$MAJOR" in
    ''|*[!0-9]*)
      warn 'node 存在但版本获取失败，视为缺失。' ;;
    *)
      if [ "$MAJOR" -ge "$NODE_MIN" ]; then nodeOk=1; ok "Node.js 已安装：v$NV"; else warn "Node.js 版本过低：v$NV（需要 ≥ $NODE_MIN，脚本将重装）"; fi ;;
  esac
fi
if [ "$nodeOk" = "0" ]; then tip "未检测到 Node.js ≥ $NODE_MIN，稍后步骤 2/7 将自动安装。"; fi

hasDsh=0
command -v dsh >/dev/null 2>&1 && hasDsh=1
if [ "$hasDsh" = "1" ]; then
  DV=$(dsh --version 2>/dev/null | head -n 1) || DV=''
  if [ -n "$DV" ]; then ok "dsh 已检测到：$DV"; else warn 'dsh 命令存在但执行失败（可能已损坏），稍后步骤 4/7 会重装修复。'; fi
else
  tip '未检测到 dsh 命令，稍后步骤 4/7 将自动安装。'
fi

DSH_PIDS=''
if [ "$HAS_PGREP" = "1" ]; then
  # [d]sh 防自匹配 + 排除自身/父进程；脚本路径含 dsh-toolkit 时会匹配自身，必须排除
  DSH_PIDS=$(pgrep -f '[d]sh' 2>/dev/null | grep -vE "^($$|${PPID:-0})$" || true)
  if [ -n "$DSH_PIDS" ]; then warn "检测到 dsh 相关进程正在运行（PID：$(printf '%s' "$DSH_PIDS" | tr '\n' ' ')）。若稍后需要重装/升级，会先提示关闭。"; fi
else
  warn '本机无 pgrep：跳过进程检测（macOS 自带 pgrep，此处为降级提示）。'
fi

# RC 文件探测（API Key 持久化位置）
case "$SHELL" in
  *zsh*) RC="$HOME/.zshrc" ;;
  *bash*) RC="$HOME/.bash_profile" ;;
  *) RC="$HOME/.zshrc" ;;
esac

SUDO_OK=0
if command -v sudo >/dev/null 2>&1; then
  sudo -n true 2>/dev/null && SUDO_OK=1
fi

# ---------- 2/7 安装 Node（仅当缺失/过旧）----------
if [ "$nodeOk" = "0" ]; then
  step '2/7 安装 Node.js（npmmirror CDN 直链，sudo 静默安装）'
  if [ "$DRY_RUN" = "1" ]; then
    tip '[DRY_RUN 模拟] 下载并安装 Node pkg。'
  else
    if [ "$SUDO_OK" = "1" ]; then tip '已通过 sudo 缓存校验，可能不再弹密码；若弹出，输入开机密码（不回显是正常的）。'
    else tip '接下来会弹出 sudo 密码提示（输入不回显是正常的）；本脚本只用 sudo 装 Node，其余步骤都不需要管理员。'; fi
    run '下载 Node pkg（约 70MB，来自 npmmirror CDN，国内快）' curl -fL "$PKG_URL" -o "$HOME/node-$NODE_VER.pkg" || die 'Node 下载失败。请检查网络后重跑；或改 v24.19.0 直链手动下载。'
    run 'sudo 静默安装 Node pkg（约 1 分钟，请勿关闭本窗口）' sudo installer -pkg "$HOME/node-$NODE_VER.pkg" -target / || die 'Node 安装失败（sudo 密码错误或网络）。重跑本脚本即可。'
    rm -f "$HOME/node-$NODE_VER.pkg"
    hash -r
    if command -v node >/dev/null 2>&1; then
      ok 'Node 已安装。'
    else
      tip 'Node 已安装但当前终端 PATH 未刷新：请重开终端后重跑本脚本继续（步骤 1-2 会自动跳过）。'
      exit 0
    fi
  fi
else
  step "2/7 安装 Node —— 已跳过（本机已有 Node ≥ $NODE_MIN）"
fi

# ---------- 3/7 修复 npm 全局目录（根治 EACCES）----------
step '3/7 修复 npm 全局目录（根治 EACCES；macOS 版"平台拦截解除"）'
PREFIX=$(npm config get prefix 2>/dev/null | tr -d '[:space:]') || PREFIX=''
case "$PREFIX" in
  /usr/local*|/usr/*)
    warn "npm 全局目录属于 root（$PREFIX）：npm install -g 会报 EACCES。官方不建议 sudo npm -g；改为用户目录根治。"
    run '创建 ~/.npm-global' mkdir -p "$HOME/.npm-global"
    run 'npm config set prefix ~/.npm-global' npm config set prefix "$HOME/.npm-global"
    if grep -qF '.npm-global/bin' "$HOME/.zprofile" 2>/dev/null; then
      tip '~/.zprofile 已有 .npm-global/bin，跳过追加。'
    elif [ "$DRY_RUN" = "1" ]; then
      tip '[DRY_RUN 模拟] 追加 export PATH 到 ~/.zprofile'
    else
      echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.zprofile"
      tip '已追加 PATH 到 ~/.zprofile（新终端自动生效）。'
    fi
    export PATH="$HOME/.npm-global/bin:$PATH"
    ok '已切换 npm 全局目录到 ~/.npm-global（新终端自动生效，当前会话已生效）。'
    PREFIX="$HOME/.npm-global"
    ;;
  *)
    ok "npm 全局目录可写：$PREFIX（不动用户现有配置）。" ;;
esac

# ---------- 4/7 安装 dsh ----------
step '4/7 安装 dsh（npm 全局 + npmmirror 镜像）'
if [ "$hasDsh" = "1" ]; then
  ok '已检测到 dsh 命令，跳过安装。（升级请见 README：升级前关闭所有 dsh 进程）'
else
  if [ -n "$DSH_PIDS" ]; then die '检测到 dsh 相关进程正在运行：重装会报 EBUSY。请关闭所有 dsh 窗口后重跑本脚本。（脚本不会自动强杀进程）'; fi
  run '执行 npm install -g @deepseek-ai/dsh（npmmirror 镜像）' npm install -g @deepseek-ai/dsh --registry=https://registry.npmmirror.com/ || die 'npm 安装失败（若报 EBUSY 请关闭所有 dsh 窗口重跑；其他错误请检查网络后重跑，或看 README 故障表）。'
  hash -r
  DV=$(dsh --version 2>/dev/null | head -n 1) || DV=''
  if [ -n "$DV" ]; then ok "安装成功：$DV"; else warn '安装完成但 dsh --version 无输出，请重开终端后再验证。'; fi
fi

# ---------- 5/7 allow-scripts 补跑 ----------
step '5/7 allow-scripts 补跑（修复 npm 拦截安装脚本的暗病）'
tip 'npm 默认拦截部分包的安装脚本，不补跑会有暗病（node-pty 原生模块、spawn helper 缺失）。本步骤无条件补跑一次，幂等安全。'
if run 'allow-scripts 补跑' npm install -g @deepseek-ai/dsh --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs --registry=https://registry.npmmirror.com/; then
  ok 'allow-scripts 补跑完成。'
else
  warn 'allow-scripts 补跑未成功（可能已装好或网络波动）。后续使用中若遇 node-pty 相关报错，请重跑本步骤。'
fi

# ---------- 6/7 API Key 与 settings.yaml ----------
step '6/7 API Key 与 settings.yaml 配置'

# 6a. DEEPSEEK_API_KEY（macOS 持久化 = RC 文件 export，幂等去重）
KEY_SHELL="${DEEPSEEK_API_KEY:-}"
if grep -q '^export DEEPSEEK_API_KEY=' "$RC" 2>/dev/null; then
  ok "DEEPSEEK_API_KEY 已存在于 $RC，跳过。"
elif [ -n "$KEY_SHELL" ]; then
  tip "检测到当前终端有 DEEPSEEK_API_KEY，但未写入 $RC（新终端不生效）。写入……"
  if [ "$DRY_RUN" = "1" ]; then
    tip "[DRY_RUN 模拟] 写入 $RC"
  else
    key_esc=$(escape_rc_value "$KEY_SHELL")
    { grep -v '^export DEEPSEEK_API_KEY=' "$RC" 2>/dev/null; echo "export DEEPSEEK_API_KEY='${key_esc}'"; } > "$RC.tmp" && mv "$RC.tmp" "$RC"
    ok "已写入 $RC（新终端自动生效）。"
  fi
  export DEEPSEEK_API_KEY="$KEY_SHELL"
else
  if [ -t 0 ]; then
    tip '未检测到 DeepSeek API Key。请在 https://platform.deepseek.com 获取，粘贴后回车（输入不回显）：'
    IFS= read -r -s key || key=''
    echo ''
    key=$(printf '%s' "$key" | tr -d '[:space:]')
    if [ -z "$key" ]; then
      warn '未输入 Key，跳过（之后随时可用本脚本补设）。'
    else
      if [ "$DRY_RUN" = "1" ]; then
        tip "[DRY_RUN 模拟] 写入 $RC"
      else
        key_esc=$(escape_rc_value "$key")
        { grep -v '^export DEEPSEEK_API_KEY=' "$RC" 2>/dev/null; echo "export DEEPSEEK_API_KEY='${key_esc}'"; } > "$RC.tmp" && mv "$RC.tmp" "$RC"
      fi
      export DEEPSEEK_API_KEY="$key"
      ok "已写入 $RC（仅本地保存，不上传）。新开终端生效。"
    fi
  else
    warn '无交互终端且未预置 DEEPSEEK_API_KEY：跳过（之后随时用本脚本补设）。'
  fi
fi

# 6b. settings.yaml 极简配置
DSH_HOME="$HOME/.dsh"
SETTINGS_Y="$DSH_HOME/settings.yaml"
MINIMAL='permission:
  defaultPreset: danger-full-access

agent-default-model:
  provider: deepseek-official
  model: deepseek-v4-flash-vision-exp   # 默认模型；纯文本场景可换 deepseek-v4-flash'
say ''
say '!!! 安全警告（必读） !!!'
say '上面即将写入的 settings.yaml 使用 defaultPreset: danger-full-access：'
say '  - 该模式跳过全部权限确认，Agent 的每条命令都会直接执行，不做任何拦截；'
say '  - 仅建议在单机自用环境使用；在生产/多用户环境请改用普通模式（见下）；'
say '  - 使用风险由用户自担。'
say '普通模式对照（把 defaultPreset 一行改掉即可）：'
say '  - 不写 defaultPreset 或 workspace-write（默认）：命令限工作区写入，每次操作询问确认；'
say '  - read-only：只读模式，禁止写入，每次操作询问确认。'
say ''
if [ -f "$SETTINGS_Y" ] && [ -s "$SETTINGS_Y" ]; then
  if [ "$DRY_RUN" = "1" ]; then
    tip '[DRY_RUN 模拟] 备份 settings.yaml（不改动）'
  else
    TS2=$(date +%Y%m%d-%H%M%S)
    cp "$SETTINGS_Y" "$SETTINGS_Y.bak-$TS2"
    tip "检测到已有 settings.yaml 配置，脚本不改动它（避免覆盖你的自定义配置）。已备份：$SETTINGS_Y.bak-$TS2"
    tip '如需使用上面验证过的极简配置，可手工替换；回滚方法：cp 备份文件回 settings.yaml。'
    warn '请自行确认现有配置中 permission.defaultPreset 的值是否符合上面的安全说明。'
  fi
else
  if [ "$DRY_RUN" = "1" ]; then
    tip '[DRY_RUN 模拟] 创建 settings.yaml（UTF-8 无 BOM，两空格缩进）'
  else
    mkdir -p "$DSH_HOME"
    printf '%s\n' "$MINIMAL" > "$SETTINGS_Y"
    if [ -s "$SETTINGS_Y" ]; then
      ok "settings.yaml 已创建于 $SETTINGS_Y（UTF-8 无 BOM）"
    else
      warn 'settings.yaml 写入失败，请检查磁盘权限。'
    fi
    tip '修改后重启 dsh 生效；如需回滚，删除该文件后重跑本脚本或手工重建。'
  fi
fi

# ---------- 7/7 收尾 ----------
step '7/7 收尾验证'
DV=$(dsh --version 2>/dev/null | head -n 1) || DV=''
if [ -n "$DV" ]; then ok "验证通过：dsh $DV"; else warn 'dsh --version 无输出，请重开终端后再验证一次。'; fi

say ''
say '================================================================'
say '  全部步骤完成。'
tip '下一步：'
tip '  1. 关闭本窗口，重新打开「终端」（让 PATH 与环境生效）'
tip '  2. 运行 dsh web（首次运行自动初始化 web profile 并启动浏览器界面）'
tip '  3. 一次性任务：dsh --profile headless "任务描述"'
tip '  4. 升级提醒：升级前关闭所有 dsh 进程（否则 EBUSY）'
tip '  5. 已有 Claude Code 的用户：可安装本仓库 plugin 获得自动化故障修复'
tip '     /plugin marketplace add yellowgu/dsh-toolkit'
tip '     /plugin install dsh-toolkit@dsh-toolkit'
tip "  故障排查：$REPO_URL 的 README 故障表；或提 issue。"
say '================================================================'

# 防闪退：仅真交互终端暂停，管道/CI 不挂死
if [ "$DRY_RUN" != "1" ] && [ -t 0 ]; then printf '\n按回车键退出……'; IFS= read -r _ || true; fi
exit 0
