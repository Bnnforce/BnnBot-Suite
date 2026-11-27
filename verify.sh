#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# verify.sh — BnnBot 套组验收（只读，不改任何东西）
#
# 用法：
#   bash verify.sh
#   bash verify.sh --workspace /sdcard/DSH --data-root /sdcard/DSH/Bot/dshqqbot
#
# 退出码：0 = 全过；1 = 有失败项
#
# 判据原则：**能跑才算过，文件存在不算。**
# ═══════════════════════════════════════════════════════════════════════════
set -uo pipefail

if [ -t 1 ]; then
  R='\033[31m'; G='\033[32m'; Y='\033[33m'; B='\033[36m'; N=''; BOLD='\033[1m'
else
  R=''; G=''; Y=''; B=''; N=''; BOLD=''
fi
ok()   { printf "${G}  ✅ %s${N}\n" "$*"; }
warn() { printf "${Y}  ⚠️  %s${N}\n" "$*"; }
no()   { printf "${R}  ❌ %s${N}\n" "$*"; }
sec()  { printf "\n${BOLD}%s${N}\n" "$*"; }

PASS=0; FAIL=0; WARN=0
vok()  { ok "$*";   PASS=$((PASS+1)); }
vwarn(){ warn "$*"; WARN=$((WARN+1)); }
vno()  { no "$*";   FAIL=$((FAIL+1)); }

while [ $# -gt 0 ]; do
  case "$1" in
    --workspace) BNN_WORKSPACE="${2:-}"; shift 2 ;;
    --data-root) BNN_DATA_ROOT="${2:-}"; shift 2 ;;
    --profile)   BNN_PROFILE="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
BNN_PROFILE="${BNN_PROFILE:-${DSH_PROFILE:-web}}"
PROFILE_DIR="${DSH_PROFILE_DIR:-$DSH_HOME/profiles/$BNN_PROFILE}"
BNN_WORKSPACE="${BNN_WORKSPACE:-$HOME/bnnbot}"
BNN_DATA_ROOT="${BNN_DATA_ROOT:-$BNN_WORKSPACE/Bot/dshqqbot}"
PATCH_FILE="$PROFILE_DIR/cordis.patch.yml"

printf "${BOLD}═══ BnnBot 套组 · 验收 ═══${N}\n"
printf "profile: %s\n" "$PROFILE_DIR"
printf "工作区 : %s\n" "$BNN_WORKSPACE"
printf "数据根 : %s\n" "$BNN_DATA_ROOT"

# ── ① 环境 ────────────────────────────────────────────────
sec "① 环境"
if command -v node >/dev/null 2>&1; then
  NV="$(node --version | sed 's/^v//')"
  NM="${NV%%.*}"
  [ "${NM:-0}" -ge 24 ] && vok "node $NV" || vno "node $NV（DSH 需要 >= 24.9.0）"
else
  vno "node 未安装"
fi
command -v pnpm >/dev/null 2>&1 && vok "pnpm $(pnpm --version)" || vno "pnpm 未安装"
command -v dsh  >/dev/null 2>&1 && vok "dsh $(dsh --version 2>/dev/null | head -1)" || vwarn "dsh 命令不在 PATH（App 内常见）"

# ── ② 组件 ────────────────────────────────────────────────
sec "② 组件"
# 梗指南（可选但强烈建议）：不装她就不会查网络梗
MEME_DIR="$PROFILE_DIR/node_modules/dsh-memewiki"
if [ -d "$MEME_DIR" ]; then
  MEME_V="$(node -e "try{console.log(require('$MEME_DIR/package.json').version)}catch(e){console.log('?')}" 2>/dev/null)"
  vok "梗指南 dsh-memewiki $MEME_V"
else
  vwarn "没装梗指南 —— 她遇到网络梗只会说不知道（装法：pnpm add dsh-memewiki）"
fi
QDIR="$PROFILE_DIR/node_modules/@zaofan/dsh-qqbot"
if [ -d "$QDIR" ]; then
  QV="$(node -e "try{console.log(require('$QDIR/package.json').version)}catch(e){console.log('?')}" 2>/dev/null)"
  vok "通道 @zaofan/dsh-qqbot $QV"

  # 上游修复（1.13.29 起补丁已上游化；查功能，不查私有标记）
  UPMISS=0
  _upneed() {
    if grep -q "$2" "$QDIR/$1" 2>/dev/null; then :; else
      vno "上游修复缺失：$3（$1）"; UPMISS=$((UPMISS+1)); fi
  }
  _upneed 'dist/features/botplay.js' 'clickerId ?? triggererId' '卡片点击者身份'
  _upneed 'dist/features/botplay.js' 'async safeReply(target, text, mention)' '卡片提示 @ 触发人'
  _upneed 'dist/features/face-tags.js' '图片表情' '图片表情中性输出'
  _upneed 'dist/commands/session.js' 'caps?.replyTarget' '会话命令上下文兜底'
  _upneed 'dist/commands/session.js' 'FORK_TIMEOUT' '/bot-new 超时'
  _upneed 'dist/transport/tool-presenter.js' "name === 'web_search' || name === 'web_fetch'" '联网工具错误静默'
  if [ "$UPMISS" = "0" ]; then
    vok "上游 6 项修复全部在位"
  else
    vwarn "  修复缺失项见上；先核对版本是否 $PINNED_QQBOT_VERSION"
  fi
else
  vno "通道未安装"
fi

# 插件：必须真的 import
if [ -d "$PROFILE_DIR/node_modules" ]; then
  OUT="$( cd "$PROFILE_DIR" && node --input-type=module -e "
    try {
      const m = await import('dsh-bnnbotbox');
      console.log('OK|' + m.name + '|' + Object.keys(m.Config.dict).length);
    } catch (e) { console.log('ERR|' + String(e.message).slice(0,120)); }
  " 2>&1 )"
  case "$OUT" in
    OK\|bnnbotbox\|52) vok "插件可导入，配置 52 字段" ;;
    OK\|bnnbotbox\|*)  vno "插件可导入但配置字段 = ${OUT##*|})（应 52，可能是老版本）" ;;
    *) vno "插件导入失败：$(echo "$OUT" | head -1)" ;;
  esac
else
  vno "profile node_modules 不存在"
fi

# ── ③ 扩展包 ──────────────────────────────────────────────
sec "③ 扩展包"
EXT="$BNN_DATA_ROOT/extension-packs/bnn-custom"
if [ -f "$EXT/qqbot-pack.json" ]; then
  vok "扩展包已就位"
  ( cd "$EXT" && node scripts/check-syntax.mjs >/dev/null 2>&1 ) \
    && vok "扩展包语法通过" || vno "扩展包语法有问题（跑 node scripts/check-syntax.mjs 看）"
  ( cd "$EXT" && node scripts/doctor.mjs >/dev/null 2>&1 ) \
    && vok "doctor 通过（必需目录齐全）" || vwarn "doctor 有提示（跑 node scripts/doctor.mjs 看）"
else
  vwarn "扩展包未安装（只需要人格+记忆的话可以忽略）"
fi

# 卡片：真的 import
BOTPLAY="$BNN_DATA_ROOT/.qqbot-extensions/botplay"
if [ -d "$BOTPLAY" ]; then
  CR="$( cd "$BOTPLAY" && node --input-type=module -e "
    import fs from 'node:fs';
    let ok=0; const bad=[];
    for (const f of fs.readdirSync('.').filter(x=>x.endsWith('.mjs'))) {
      try { await import('file://' + process.cwd() + '/' + f + '?v=' + Date.now()); ok++; }
      catch { bad.push(f); }
    }
    console.log(ok + '/' + (ok+bad.length));
  " 2>&1 | tail -1 )"
  case "$CR" in
    13/13) vok "卡片 13/13 可加载" ;;
    *)     vno "卡片 $CR 可加载（应 13/13）" ;;
  esac
else
  vwarn "卡片运行时目录不存在（重启 DSH 后会自动同步）"
fi

# ── ④ 配置 ────────────────────────────────────────────────
sec "④ 配置"
if [ -f "$PATCH_FILE" ]; then
  if command -v dsh >/dev/null 2>&1; then
    if dsh --profile "$BNN_PROFILE" --dump-config 2>/dev/null | grep -q "id: bnnbotbox"; then
      vok "组合配置含 bnnbotbox 行"
    else
      vno "组合配置缺 bnnbotbox 行"
    fi
  else
    vwarn "没有 dsh 命令，跳过组合校验"
  fi
  grep -q "id: *im-qqbot"  "$PATCH_FILE" 2>/dev/null && vok "配置含 qqbot 通道段" || vno "配置缺 qqbot 通道段"

  if grep -qP "^\t" "$PATCH_FILE" 2>/dev/null; then
    vno "配置有 tab 缩进（YAML 不允许）"
  else
    vok "配置无 tab 缩进"
  fi

  # 占位符未填
  if grep -qE "app(Id|Secret): *'<" "$PATCH_FILE" 2>/dev/null; then
    vno "appId/appSecret 还是占位符，必须填真值"
  else
    grep -q "dataRoot: *'" "$PATCH_FILE" 2>/dev/null && vok "dataRoot 已配置" || vwarn "没找到 dataRoot，可能会用默认值"
  fi
else
  vno "配置文件不存在：$PATCH_FILE"
fi

# ── ⑤ 人格 ────────────────────────────────────────────────
sec "⑤ 人格"
PDIR="$BNN_WORKSPACE/Bot/人格"
if [ -d "$PDIR/角色卡" ] && [ -n "$(ls "$PDIR/角色卡"/*.md 2>/dev/null)" ]; then
  vok "人格卡：$(ls "$PDIR/角色卡"/*.md 2>/dev/null | xargs -n1 basename 2>/dev/null | tr '\n' ' ')"
  if [ -f "$PDIR/persona-config.json" ]; then
    DEF="$(node -e "try{console.log(require('$PDIR/persona-config.json').defaultPersona||'')}catch(e){console.log('')}" 2>/dev/null)"
    if [ -n "$DEF" ] && [ -f "$PDIR/角色卡/$DEF.md" ]; then
      vok "defaultPersona = $DEF（卡存在）"
    elif [ -n "$DEF" ]; then
      vno "defaultPersona = $DEF 但找不到 $DEF.md"
    else
      vwarn "persona-config.json 没设 defaultPersona"
    fi
  else
    vwarn "persona-config.json 不存在（重启后会自动铺）"
  fi
else
  vwarn "人格卡还没生成（重启 DSH 后会自动铺「小忆」）"
fi

# ── ⑥ 运行时状态 ──────────────────────────────────────────
sec "⑥ 运行时状态"
VG="$BNN_DATA_ROOT/.qqbot-extensions/data/version-guard.json"
if [ -f "$VG" ]; then
  if grep -q '"status": *"ok"' "$VG" 2>/dev/null; then
    vok "version-guard status = ok"
  elif grep -q '"changed"' "$VG" 2>/dev/null; then
    vwarn "version-guard 检测到扩展文件有变动（重启或 /tools-reload 后消失）"
  else
    vno "version-guard 状态异常：$(head -c 160 "$VG")"
  fi
else
  vwarn "version-guard.json 不存在（DSH 还没启动过 / 插件没加载）"
fi

WD="$BNN_DATA_ROOT/.qqbot-extensions/data/workspace-dirs.json"
[ -f "$WD" ] && vok "workspace-dirs.json 存在" || vwarn "workspace-dirs.json 不存在"

# 出站投递
DL="$BNN_DATA_ROOT/.qqbot/ext-deliver.log"
if [ -f "$DL" ]; then
  RECENT="$(tail -20 "$DL" 2>/dev/null | grep -c "ok=false" || true)"
  [ "${RECENT:-0}" -eq 0 ] && vok "出站投递近期无失败" || vwarn "出站日志有 $RECENT 条失败（可能是平台主动消息限制）"
fi

# ── 汇总 ──────────────────────────────────────────────────
printf "\n${BOLD}═══════════════════════════${N}\n"
printf "${BOLD}通过 %d / 警告 %d / 失败 %d${N}\n" "$PASS" "$WARN" "$FAIL"
printf "${BOLD}═══════════════════════════${N}\n"

if [ "$FAIL" -eq 0 ]; then
  printf "\n${G}全部通过。${N}\n"
  printf "如果群里 @ 她还是没反应 → 查 QQ 平台「沙箱配置」有没有加这个群。\n"
  exit 0
else
  printf "\n${R}有 %d 项失败。${N}\n" "$FAIL"
  printf "排障手册：https://github.com/Bnnforce/BnnBot-Suite/blob/main/docs/06-排障.md\n"
  exit 1
fi
