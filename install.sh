#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# install.sh — BnnBot 套组一键安装
#
# 用法：
#   bash install.sh                         # 交互式，会问你要路径和凭证
#   bash install.sh --yes                   # 尽量不交互（凭证仍需提供）
#   bash install.sh --workspace /sdcard/DSH --data-root /sdcard/DSH/Bot/dshqqbot
#
# 环境变量（可替代参数）：
#   BNN_WORKSPACE     工作区根（默认 $HOME/bnnbot）
#   BNN_DATA_ROOT     qqbot 数据根（默认 $BNN_WORKSPACE/Bot/dshqqbot）
#   BNN_PROFILE       DSH profile 名（默认 $DSH_PROFILE 或 web）
#   QQBOT_APP_ID      QQ 机器人 AppID
#   QQBOT_APP_SECRET  QQ 机器人 AppSecret
#   BNN_SKIP_EXT      1 = 不装玩法扩展包
#   BNN_NO_CONFIG     1 = 只装不写配置
#   QQBOT_PLUGIN_VERSION  通道插件版本（默认 = 本套组适配过的版本，见下方常量）
#   BNN_LATEST_PLUGIN 1 = 装通道插件的最新版（不推荐：上游可能改契约/默认值）
#   BNN_NO_PATCH      1 = 不给通道打补丁（一般不用；打了才是完整功能）
#   BNN_OWNER_OPENID  主人的 QQ openid（决定「仅主人」类功能对谁开放；不填 = 所有主人校验放行）
#
# 它做什么：
#   ① 检查环境（node/pnpm/dsh）
#   ② 装通道 @zaofan/dsh-qqbot（★ 精确锁定到适配版本）
#   ②b 给通道打 4 个补丁（上游 1.13.20 的真 bug，随套组分发）
#   ③ 装插件 dsh-bnnbotbox（clone + pnpm install + link）
#   ④ 放扩展包 bnn-custom（可选）
#   ⑤ 生成配置片段（不覆盖已有配置，只追加）
#   ⑥ 跑验收
#
# 它绝不做什么：
#   · 不删你的文件
#   · 不覆盖已有配置（只追加，且先备份）
#   · 不经手你的 AppSecret 到任何网络位置（只写本地配置文件）
# ═══════════════════════════════════════════════════════════════════════════
set -uo pipefail

# ── 颜色（终端不支持就退化）─────────────────────────────────────────────
if [ -t 1 ]; then
  R='\033[31m'; G='\033[32m'; Y='\033[33m'; B='\033[36m'; N='\033[0m'; BOLD='\033[1m'
else
  R=''; G=''; Y=''; B=''; N=''; BOLD=''
fi
ok()   { printf "${G}✅ %s${N}\n" "$*"; }
info() { printf "${B}→ %s${N}\n" "$*"; }
warn() { printf "${Y}⚠️  %s${N}\n" "$*"; }
err()  { printf "${R}❌ %s${N}\n" "$*"; }
die()  { err "$*"; echo; err "安装中止。修好上面这条再重跑本脚本。"; exit 1; }
hr()   { printf '%s\n' "────────────────────────────────────────────"; }

# ══════════════════════════════════════════════════════════════════════════
# ★ 通道插件「适配版本」——唯一真源
#
# 为什么不装最新版：
#   上游只声明 minPluginVersion（下限），**没有上限机制**，而真实风险是向上不兼容。
#   实测 @zaofan/dsh-qqbot 1.13.21~1.13.23：
#     · 把本套组打过补丁的 4 个 dist 文件全改了 ⇒ 补丁冲突，功能静默失效
#     · outboundLastCtxFallback 默认改成 false（拒发）
#       ⇒ 扩展包 outbound/60-split-bubbles 里不传 target 的 ctx.send() 全部失败
#       ⇒ 多段回复只有第一段能发出去
#
# 所以默认精确安装这个版本。想用最新版：加 --latest-plugin，
# 但要自己承担上面那些风险（装完先跑 verify.sh 看 compat 状态）。
#
# 改这里之前先确认：扩展包 qqbot-pack.json 的 testedWithPlugin 也改了。
PINNED_QQBOT_VERSION="${QQBOT_PLUGIN_VERSION:-1.13.20}"
LATEST_PLUGIN="${BNN_LATEST_PLUGIN:-0}"

YES=0
for a in "$@"; do
  case "$a" in
    --yes|-y) YES=1 ;;
  esac
done
# 解析 --key value
while [ $# -gt 0 ]; do
  case "$1" in
    --workspace)  BNN_WORKSPACE="${2:-}"; shift 2 ;;
    --data-root)  BNN_DATA_ROOT="${2:-}"; shift 2 ;;
    --profile)    BNN_PROFILE="${2:-}"; shift 2 ;;
    --app-id)     QQBOT_APP_ID="${2:-}"; shift 2 ;;
    --app-secret) QQBOT_APP_SECRET="${2:-}"; shift 2 ;;
    --skip-ext)   BNN_SKIP_EXT=1; shift ;;
    --latest-plugin) LATEST_PLUGIN=1; shift ;;
    --no-patch)   BNN_NO_PATCH=1; shift ;;
    --owner-openid) OWNER_OPENID="${2:-}"; shift 2 ;;
    --plugin-version) PINNED_QQBOT_VERSION="$2"; shift 2 ;;
    --no-config)  BNN_NO_CONFIG=1; shift ;;
    *) shift ;;
  esac
done

hr
printf "${BOLD}BnnBot 套组 · 一键安装${N}\n"
hr

# ══════════════════════════════════════════════════════════════════════════
# ⓪ 环境检查
# ══════════════════════════════════════════════════════════════════════════
info "检查环境…"

command -v node >/dev/null 2>&1 || die "找不到 node。DSH 要求 Node >= 24.9.0，请先装。"
NODE_V="$(node --version 2>/dev/null | sed 's/^v//')"
NODE_MAJOR="${NODE_V%%.*}"
# DSH 要求 >= 24.9.0
if [ "${NODE_MAJOR:-0}" -lt 24 ]; then
  die "Node 版本 $NODE_V 太低。DSH 需要 >= 24.9.0。"
fi
ok "node $NODE_V"

command -v pnpm >/dev/null 2>&1 || die "找不到 pnpm。请先：npm i -g pnpm（或用 corepack enable）"
ok "pnpm $(pnpm --version 2>/dev/null)"

if command -v git >/dev/null 2>&1; then
  ok "git $(git --version 2>/dev/null | awk '{print $3}')"
else
  die "找不到 git。"
fi

if command -v dsh >/dev/null 2>&1; then
  ok "dsh $(dsh --version 2>/dev/null | head -1)"
else
  warn "找不到 dsh 命令（可能是 Android App 内跑，PATH 里没有）。继续用目录推断。"
fi

# ══════════════════════════════════════════════════════════════════════════
# ① 确定路径
# ══════════════════════════════════════════════════════════════════════════
hr
info "确定安装路径…"

DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
BNN_PROFILE="${BNN_PROFILE:-${DSH_PROFILE:-web}}"
PROFILE_DIR="${DSH_PROFILE_DIR:-$DSH_HOME/profiles/$BNN_PROFILE}"

if [ -z "${BNN_WORKSPACE:-}" ]; then
  if [ "$YES" -eq 1 ]; then
    BNN_WORKSPACE="$HOME/bnnbot"
  else
    printf "工作区（放人格/曲库的地方）[%s]: " "$HOME/bnnbot"
    read -r _ans || true
    BNN_WORKSPACE="${_ans:-$HOME/bnnbot}"
  fi
fi

if [ -z "${BNN_DATA_ROOT:-}" ]; then
  BNN_DATA_ROOT="$BNN_WORKSPACE/Bot/dshqqbot"
fi

ok "DSH_HOME     = $DSH_HOME"
ok "PROFILE      = $BNN_PROFILE"
ok "PROFILE_DIR  = $PROFILE_DIR"
ok "WORKSPACE    = $BNN_WORKSPACE"
ok "DATA_ROOT    = $BNN_DATA_ROOT"

[ -d "$PROFILE_DIR" ] || die "profile 目录不存在：$PROFILE_DIR
   先启动一次 DSH 让它生成 profile，或用 --profile 指定正确的名字。"

mkdir -p "$BNN_WORKSPACE/Bot" || die "建不了工作区：$BNN_WORKSPACE"
mkdir -p "$BNN_DATA_ROOT/extension-packs" || die "建不了 dataRoot：$BNN_DATA_ROOT"

# ══════════════════════════════════════════════════════════════════════════
# ② 装通道 @zaofan/dsh-qqbot
# ══════════════════════════════════════════════════════════════════════════
hr
QDIR="$PROFILE_DIR/node_modules/@zaofan/dsh-qqbot"
CUR_V=""
if [ -f "$QDIR/package.json" ]; then
  CUR_V="$(node -e "try{console.log(require('$QDIR/package.json').version)}catch(e){console.log('')}" 2>/dev/null)"
fi

# 要装哪个版本
if [ "$LATEST_PLUGIN" = "1" ]; then
  TARGET_SPEC="@zaofan/dsh-qqbot"
  TARGET_DESC="最新版（--latest-plugin，未验证）"
  warn "你选择了最新版通道插件。上游若改了扩展点契约或默认值，本套组可能静默失效。"
  warn "装完务必看 verify.sh 的 compat 结果。"
else
  TARGET_SPEC="@zaofan/dsh-qqbot@$PINNED_QQBOT_VERSION"
  TARGET_DESC="钉住版本 $PINNED_QQBOT_VERSION（本套组适配过的）"
fi

info "目标：$TARGET_DESC"

if [ -n "$CUR_V" ] && [ "$LATEST_PLUGIN" != "1" ] && [ "$CUR_V" = "$PINNED_QQBOT_VERSION" ]; then
  ok "已装 $CUR_V，正是钉住的版本，跳过"
else
  if [ -n "$CUR_V" ]; then
    warn "当前已装 $CUR_V → 要换成 $PINNED_QQBOT_VERSION"
    [ "$LATEST_PLUGIN" = "1" ] && warn "  注意：最新版的契约变化可能导致扩展包功能静默失效"
  fi
  ( cd "$PROFILE_DIR" && pnpm add "$TARGET_SPEC" ) \
    || die "装通道失败（网络？）。手动重试：cd $PROFILE_DIR && pnpm add $TARGET_SPEC"
  NEW_V="$(node -e "try{console.log(require('$QDIR/package.json').version)}catch(e){console.log('')}" 2>/dev/null)"
  ok "通道已装：$NEW_V"

  # ★ 登记进 bundles（不登记 = DSH 不加载，且不报错）
  case "$(add_bundle @zaofan/dsh-qqbot)" in
    added)   ok "已登记 @zaofan/dsh-qqbot 到 profile bundles" ;;
    already) ok "@zaofan/dsh-qqbot 已在 profile bundles 里" ;;
    *)       warn "登记 bundles 失败 —— 请手动在 dsh.profile.bundles 里加 @zaofan/dsh-qqbot" ;;
  esac

  # 装完立刻校验版本真的对上了（pnpm 有可能按原有 ^ 范围解到别的版本）
  if [ "$LATEST_PLUGIN" != "1" ] && [ "$NEW_V" != "$PINNED_QQBOT_VERSION" ]; then
    err "期望 $PINNED_QQBOT_VERSION，实际装成了 $NEW_V"
    err "常见原因：profile 里原有 ^ 范围声明，pnpm 按范围解了。手动钉死："
    err "  cd $PROFILE_DIR && pnpm add @zaofan/dsh-qqbot@$PINNED_QQBOT_VERSION --save-exact"
    die "通道版本没锁住"
  fi
fi

# ══════════════════════════════════════════════════════════════════════════
# ②b 给通道打补丁（上游 1.13.20 的 4 个真 bug）
#
# 为什么必须打：这 4 个补丁修的是上游 bug，不打会直接影响 BnnBot ——
#   · botplay 点击者身份缺失 → 抽奖图鉴记错人、小店归属错、权限判断失效（最严重）
#   · 图片表情被当成经典表情 → 群友发贴纸她一律理解成「微笑」
#   · 会话命令 scope 兜底 → /子会话、/会话列表 在 web 上下文抛 TypeError
#   · 群内不展示联网工具凭据/错误
# 补丁是 diff（不分发整文件），许可说明见 patches/qqbot-<版本>/LICENSE-NOTICE.md
# ══════════════════════════════════════════════════════════════════════════
PATCH_MARKERS="QQBotLocalPatch:face-type-image QQBotLocalPatch:session-cmd-context QQBotSecurityPatch:botplay-clicker-id QQBotSecurityPatch:safe-reply-fallback QQBotSecurityPatch:safe-reply-mention QQBotSecurityPatch:web-tool-error-silent"

count_patch_markers() {
  local pkg="$1"
  local hit=0
  for m in $PATCH_MARKERS; do
    if grep -q "$m" "$pkg/dist/features/botplay.js" "$pkg/dist/features/face-tags.js" \
         "$pkg/dist/commands/session.js" "$pkg/dist/transport/tool-presenter.js" 2>/dev/null; then
      hit=$((hit+1))
    fi
  done
  echo "$hit"
}

if [ "${BNN_NO_PATCH:-0}" = "1" ]; then
  warn "跳过通道补丁（--no-patch）—— 卡片点击者身份等修复不会生效"
else
  info "②b 给通道打补丁 …"
  QPKG="$PROFILE_DIR/node_modules/@zaofan/dsh-qqbot"
  if [ ! -d "$QPKG" ]; then
    warn "通道未安装，跳过补丁"
  else
    HIT="$(count_patch_markers "$QPKG")"
    if [ "$HIT" = "6" ]; then
      ok "补丁已在位（6/6 marker），跳过"
    elif [ "$HIT" != "0" ]; then
      err "补丁状态不明：6 个 marker 只有 $HIT 个在位"
      err "可能是半途打坏或上游版本不符。手动处理："
      err "  cd \"$QPKG\" && git checkout -- . 2>/dev/null || pnpm add @zaofan/dsh-qqbot@$PINNED_QQBOT_VERSION --force"
      die "补丁状态异常，已停下（不硬打，避免把文件打坏）"
    else
      # 拿补丁：优先用本脚本同目录的 patches/，否则 clone 套组仓库
      PATCH_ROOT=""
      HERE_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo '')"
      if [ -n "$HERE_DIR" ] && [ -d "$HERE_DIR/patches/qqbot-$PINNED_QQBOT_VERSION" ]; then
        PATCH_ROOT="$HERE_DIR/patches/qqbot-$PINNED_QQBOT_VERSION"
      else
        SUITE_DIR="$SRC_DIR/BnnBot-Suite"
        if [ ! -d "$SUITE_DIR/.git" ]; then
          info "拉取套组仓库以获取补丁…"
          git clone --depth 1 https://github.com/Bnnforce/BnnBot-Suite.git "$SUITE_DIR" >/dev/null 2>&1 \
            || warn "拉取套组仓库失败，将跳过补丁"
        fi
        [ -d "$SUITE_DIR/patches/qqbot-$PINNED_QQBOT_VERSION" ] && PATCH_ROOT="$SUITE_DIR/patches/qqbot-$PINNED_QQBOT_VERSION"
      fi

      if [ -z "$PATCH_ROOT" ]; then
        warn "找不到 patches/qqbot-$PINNED_QQBOT_VERSION，跳过补丁"
        warn "（不打补丁也能跑，但卡片点击者身份等 4 个修复不生效）"
      elif ! command -v patch >/dev/null 2>&1; then
        warn "系统没有 patch 命令，跳过补丁（可用 git apply 手动打）"
      else
        APPLIED=0
        for pf in "$PATCH_ROOT"/*.patch; do
          [ -f "$pf" ] || continue
          if ( cd "$QPKG" && patch -p1 --forward --silent < "$pf" ); then
            APPLIED=$((APPLIED+1))
          else
            warn "补丁未应用（可能已打过）：$(basename "$pf")"
          fi
        done
        HIT2="$(count_patch_markers "$QPKG")"
        if [ "$HIT2" = "6" ]; then
          ok "通道补丁完成（$APPLIED 个文件，marker 6/6）"
        else
          err "补丁后 marker 只有 $HIT2/6 —— 可能上游版本不符"
          die "补丁未完全生效。核对：pnpm ls @zaofan/dsh-qqbot 应为 $PINNED_QQBOT_VERSION"
        fi
      fi
    fi
  fi
fi

# ══════════════════════════════════════════════════════════════════════════
# ②c 把包装进 profile 的 bundle 列表
#
# 为什么单独一步（这是个真断点）：
#   pnpm add link:<dir> 只改 dependencies，**不写 dsh.profile.bundles**；
#   而 DSH 是**按 bundles 列表**加载的。只 add 不登记 = 装好了但完全不生效，
#   而且没有任何报错 —— 对新手就是「我按步骤做了，怎么没反应」。
# ══════════════════════════════════════════════════════════════════════════
add_bundle() {
  local pkg="$1"
  node -e '
    const fs = require("fs");
    const f = process.argv[1];
    const pkg = process.argv[2];
    const j = JSON.parse(fs.readFileSync(f, "utf8"));
    j.dsh = j.dsh || {};
    j.dsh.profile = j.dsh.profile || {};
    j.dsh.profile.bundles = Array.isArray(j.dsh.profile.bundles) ? j.dsh.profile.bundles : [];
    if (j.dsh.profile.bundles.includes(pkg)) { console.log("already"); process.exit(0); }
    j.dsh.profile.bundles.push(pkg);
    fs.writeFileSync(f, JSON.stringify(j, null, 2) + "\n");
    console.log("added");
  ' "$PROFILE_DIR/package.json" "$pkg"
}

# ══════════════════════════════════════════════════════════════════════════
# ③ 装插件 dsh-bnnbotbox
# ══════════════════════════════════════════════════════════════════════════
hr
info "③ 装插件 dsh-bnnbotbox …"

SRC_DIR="${BNN_SRC_DIR:-$HOME/bnnbot-src}"
mkdir -p "$SRC_DIR"

PLUGIN_DIR="$SRC_DIR/dsh-bnnbotbox"
if [ -d "$PLUGIN_DIR/.git" ] || [ -f "$PLUGIN_DIR/package.json" ]; then
  info "已存在 $PLUGIN_DIR，跳过 clone"
else
  git clone --depth 1 https://github.com/Bnnforce/dsh-bnnbotbox.git "$PLUGIN_DIR" \
    || die "clone dsh-bnnbotbox 失败（仓库是否已公开？或网络问题）"
fi
ok "插件源码：$PLUGIN_DIR"

( cd "$PLUGIN_DIR" && pnpm install --prod=false ) || die "装插件依赖失败"
ok "插件依赖已装"

# 挂进 profile（用 link:）
CUR_DEP="$(node -e "try{console.log(require('$PROFILE_DIR/package.json').dependencies['dsh-bnnbotbox']||'')}catch(e){console.log('')}" 2>/dev/null)"
if [ -n "$CUR_DEP" ]; then
  ok "profile 已声明（$CUR_DEP），重装链接"
fi
( cd "$PROFILE_DIR" && pnpm add "link:$PLUGIN_DIR" ) || die "挂载插件到 profile 失败"
ok "插件已挂进 profile"
# ★ 登记进 bundles（只 add 不登记 = 加载不到，且不报错）
case "$(add_bundle dsh-bnnbotbox)" in
  added)   ok "已登记 dsh-bnnbotbox 到 profile bundles" ;;
  already) ok "dsh-bnnbotbox 已在 profile bundles 里" ;;
  *)       warn "登记 bundles 失败 —— 请在 $PROFILE_DIR/package.json 的 dsh.profile.bundles 里手动加 dsh-bnnbotbox" ;;
esac

# 真验证：import 一遍
info "验证插件能加载（不是看文件存在）…"
IMPORT_OUT="$( cd "$PROFILE_DIR" && node --input-type=module -e "
  const m = await import('dsh-bnnbotbox');
  const n = Object.keys(m.Config.dict).length;
  console.log(m.name + '|' + n + '|' + m.inject.join(','));
" 2>&1 )"
case "$IMPORT_OUT" in
  bnnbotbox\|52\|*)
    ok "导入成功：$IMPORT_OUT"
    ;;
  *)
    err "插件导入失败或版本不对："
    echo "$IMPORT_OUT" | head -8
    die "插件没装好。常见原因：没跑 pnpm install，或仓库版本过旧（配置字段应为 52）。"
    ;;
esac

# ══════════════════════════════════════════════════════════════════════════
# ②d 安装 QQ 群聊预设（preset: qqbot）
#
# 为什么必须装（第二个真断点）：
#   下面的配置会写 `preset: qqbot`，但那不是 DSH 自带的 —— 它由
#   @local/dsh-qqbot-suite 这个 bundle 提供（声明「QQ 会话由哪些插件组成」）。
#   不装它，配置就指向一个不存在的预设，会话创建会异常或悄悄回落默认形态
#   （于是 shell / 手机控制 / 插件管理这些能力会直接暴露给群聊）。
# ══════════════════════════════════════════════════════════════════════════
PRESET_DIR="$BNN_WORKSPACE/presets/qqbot-suite"
if [ -f "$PRESET_DIR/package.json" ]; then
  ok "预设已存在：$PRESET_DIR"
else
  mkdir -p "$PRESET_DIR"
  # 优先用套组自带的（脚本同目录 / 已 clone 的套组仓库）
  SRC_PRESET=""
  HERE_DIR_P="$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo "")"
  for cand in "$HERE_DIR_P/presets/qqbot-suite" "$SRC_DIR/BnnBot-Suite/presets/qqbot-suite"; do
    [ -f "$cand/package.json" ] && SRC_PRESET="$cand" && break
  done
  if [ -n "$SRC_PRESET" ]; then
    cp "$SRC_PRESET/package.json" "$SRC_PRESET/cordis.patch.yml" "$PRESET_DIR/" \
      || die "复制预设失败"
    ok "预设已从 $SRC_PRESET 复制"
  else
    warn "找不到预设源，将跳过 —— preset: qqbot 会指向不存在的预设"
    warn "可手动从套组仓库复制 presets/qqbot-suite/ 到 $PRESET_DIR"
  fi
fi

if [ -f "$PRESET_DIR/package.json" ]; then
  ( cd "$PROFILE_DIR" && pnpm add "link:$PRESET_DIR" ) >/dev/null 2>&1 \
    || warn "挂载预设到 profile 失败"
  case "$(add_bundle @local/dsh-qqbot-suite)" in
    added)   ok "已登记 @local/dsh-qqbot-suite 到 profile bundles" ;;
    already) ok "@local/dsh-qqbot-suite 已在 profile bundles 里" ;;
    *)       warn "登记预设 bundles 失败" ;;
  esac
fi

# ══════════════════════════════════════════════════════════════════════════
# ④ 放扩展包（可选）
# ══════════════════════════════════════════════════════════════════════════
hr
if [ "${BNN_SKIP_EXT:-0}" = "1" ]; then
  warn "跳过扩展包（--skip-ext 或 BNN_SKIP_EXT=1）"
else
  info "④ 放玩法扩展包 bnn-custom …"
  EXT_SRC="$SRC_DIR/dsh-qqbot-bnn-custom"
  if [ -d "$EXT_SRC/.git" ]; then
    info "已存在 $EXT_SRC，跳过 clone"
  else
    git clone --depth 1 https://github.com/Bnnforce/dsh-qqbot-bnn-custom.git "$EXT_SRC" \
      || die "clone 扩展包失败（仓库是否已公开？）"
  fi

  EXT_DST="$BNN_DATA_ROOT/extension-packs/bnn-custom"
  if [ -d "$EXT_DST" ]; then
    warn "目标已存在：$EXT_DST（覆盖更新）"
    rm -rf "$EXT_DST"
  fi
  cp -r "$EXT_SRC" "$EXT_DST" || die "复制扩展包失败"
  ok "扩展包已就位：$EXT_DST"

  # 自检
  info "扩展包自检…"
  ( cd "$EXT_DST" && node scripts/check-syntax.mjs 2>&1 | tail -1 )
  ( cd "$EXT_DST" && node scripts/doctor.mjs --fix 2>&1 | tail -3 )
  ( cd "$EXT_DST" && node scripts/sync-botplay.mjs 2>&1 | tail -1 )
fi

# ══════════════════════════════════════════════════════════════════════════
# ⑤ 配置
# ══════════════════════════════════════════════════════════════════════════
hr
PATCH_FILE="$PROFILE_DIR/cordis.patch.yml"

if [ "${BNN_NO_CONFIG:-0}" = "1" ]; then
  warn "跳过配置生成（--no-config）。记得手动改 $PATCH_FILE"
else
  info "⑤ 生成配置…"

  APP_ID="${QQBOT_APP_ID:-}"
  APP_SECRET="${QQBOT_APP_SECRET:-}"

  if [ -z "$APP_ID" ] && [ "$YES" -eq 0 ]; then
    printf "QQ 机器人 AppID（可留空，之后再填）: "
    read -r APP_ID || true
  fi
  if [ -z "$APP_SECRET" ] && [ "$YES" -eq 0 ]; then
    printf "QQ 机器人 AppSecret（可留空，输入不回显）: "
    if command -v stty >/dev/null 2>&1; then
      stty -echo 2>/dev/null || true
      read -r APP_SECRET || true
      stty echo 2>/dev/null || true
      echo
    else
      read -r APP_SECRET || true
    fi
  fi

  if [ -z "$APP_ID" ] || [ -z "$APP_SECRET" ]; then
    warn "没拿到完整凭证 —— 配置里会留占位符，装完你必须自己填："
    warn "  $PATCH_FILE"
    APP_ID="${APP_ID:-<在此填 AppID>}"
    APP_SECRET="${APP_SECRET:-<在此填 AppSecret>}"
  fi

  # 备份
  if [ -f "$PATCH_FILE" ]; then
    BAK="$PATCH_FILE.bak-bnnbot-$(date +%Y%m%d-%H%M%S)"
    cp "$PATCH_FILE" "$BAK" && ok "已备份原配置：$(basename "$BAK")"
    if grep -q "id: *bnnbotbox" "$PATCH_FILE" 2>/dev/null; then
      warn "配置里已有 bnnbotbox 段 —— 不自动改，避免破坏你手写的配置"
      warn "请手动核对 $PATCH_FILE 里的 bnnbotbox / dsh-qqbot 两段"
      SKIP_APPEND=1
    fi
  fi

  # 主人白名单：决定「仅主人」类检查对谁开放。
  # ⚠️ qqbot 的 owners 为空时 = **不校验**（所有主人检查放行），
  #    因为它只从 config.groupAdmin.owners 读（caps.owners / ctx.isOwner 同源）。
  OWNER_OPENID="${OWNER_OPENID:-${BNN_OWNER_OPENID:-}}"
  if [ -n "$OWNER_OPENID" ]; then
    OWNER_YAML="        groupAdmin:
          owners:
            - '$OWNER_OPENID'"
    ok "主人白名单：$OWNER_OPENID"
  else
    OWNER_YAML=""
    warn "未指定 --owner-openid：groupAdmin.owners 为空 = 所有「仅主人」检查都会放行"
  fi

  if [ "${SKIP_APPEND:-0}" != "1" ]; then
    cat >> "$PATCH_FILE" <<YAML

# ── BnnBot 套组（由 install.sh 生成 $(date +%Y-%m-%d %H:%M)）──────────────
#
# 【为什么这么写】DSH 的 loader patch 有两种写法，别搞混：
#   · insert: [行]        → 新增一行
#   · id + 无 insert      → 覆盖已存在的同名行（config 是**整体替换**，不是深合并）
#
# @zaofan/dsh-qqbot 和 dsh-bnnbotbox 都是「bundle」：DSH 会加载它们自带的
# cordis.patch.yml 自动插入基础行（qqbot 那行叫 im-qqbot、读环境变量；
# bnnbotbox 那行叫 bnnbotbox、config 只有 3 个字段）。
# 所以我们：
#   · qqbot  → 新增一行 im-qqbot-2 配自己的凭证（不去动 bundle 那行）
#   · bnnbotbox → 按 id 覆盖它的 config（不能 insert，否则 id 重复）
#
- insert:
    - id: im-qqbot-2
      name: '@zaofan/dsh-qqbot'
      config:
        appId: '${APP_ID}'
        appSecret: '${APP_SECRET}'
        settingsNs: 'im-qqbot-2'
${OWNER_YAML}
        preset: 'qqbot'
        cwd: '${BNN_WORKSPACE}/Bot'
        dataRoot: '${BNN_DATA_ROOT}'
        # 会话 4 小时不回收（默认 30 分钟太短，"主动说话"会因会话没了而失败）
        sessionIdleTimeout: 14400000
        requireMention: false
        historyLimit: 50
        behavior:
          # 默认 60 秒冷却会让回复看起来很慢
          freeIntervalSec: 5
          mentionIntervalSec: 0
          directIntervalSec: 0
          debounce:
            enabled: true
            silenceSec: 1
            maxMsgs: 10
            mentionDelayed: false

# 覆盖 bnnbotbox 的配置（bundle 已插入该行，这里只改 config）
- id: bnnbotbox
  config:
    enabled: true
    qqbotDataRoot: '${BNN_DATA_ROOT}'
    dataRoot: ''
YAML
    ok "配置已追加到 $PATCH_FILE"

    # YAML 不许 tab
    if grep -qP "^\t" "$PATCH_FILE" 2>/dev/null; then
      err "配置里有 tab 缩进（YAML 不允许）→ 请把这些行改成空格："
      grep -nP "^\t" "$PATCH_FILE" | head -5
    else
      ok "配置无 tab 缩进"
    fi
  fi
fi

# ══════════════════════════════════════════════════════════════════════════
# ⑥ 验收
# ══════════════════════════════════════════════════════════════════════════
hr
info "⑥ 验收…"
PASS=0; FAIL=0
vok() { ok "$*"; PASS=$((PASS+1)); }
vno() { err "$*"; FAIL=$((FAIL+1)); }

# 通道
# 通道：存在 + 版本对得上（钉住版本才是「适配过」的状态）
if [ -d "$PROFILE_DIR/node_modules/@zaofan/dsh-qqbot" ]; then
  VQ="$(node -e "try{console.log(require('$QDIR/package.json').version)}catch(e){console.log('')}" 2>/dev/null)"
  if [ "$LATEST_PLUGIN" = "1" ]; then
    vwarn "通道 $VQ（--latest-plugin，未验证）"
  elif [ "$VQ" = "$PINNED_QQBOT_VERSION" ]; then
    vok "通道 $VQ（= 钉住版本）"
  else
    vno "通道 $VQ ≠ 钉住版本 $PINNED_QQBOT_VERSION（升级上游后可能静默失效）"
  fi
else
  vno "通道缺失"
fi

# 插件能导入
if [ "${IMPORT_OUT%|*}" = "bnnbotbox|52" ] || [ "$IMPORT_OUT" = "bnnbotbox|52|systemPrompt,llm,tools" ]; then
  vok "插件可导入（配置 52 字段）"
else
  case "$IMPORT_OUT" in bnnbotbox\|52\|*) vok "插件可导入（配置 52 字段）";; *) vno "插件导入异常";; esac
fi

# 扩展包
if [ "${BNN_SKIP_EXT:-0}" = "1" ]; then
  warn "扩展包按需跳过，不计入验收"
else
  [ -f "$BNN_DATA_ROOT/extension-packs/bnn-custom/qqbot-pack.json" ] && vok "扩展包已就位" || vno "扩展包缺失"
  CARDS="$(ls "$BNN_DATA_ROOT/.qqbot-extensions/botplay"/*.mjs 2>/dev/null | wc -l)"
  [ "${CARDS:-0}" -ge 13 ] && vok "卡片已同步（$CARDS 个）" || vno "卡片不足（$CARDS 个，应 ≥13）"
fi

# 配置
if command -v dsh >/dev/null 2>&1; then
  if dsh --profile "$BNN_PROFILE" --dump-config 2>/dev/null | grep -q "id: bnnbotbox"; then
    vok "组合配置里含 bnnbotbox 行"
  else
    vno "组合配置里没有 bnnbotbox 行（插件可能没挂载）"
  fi
else
  grep -q "id: *bnnbotbox" "$PATCH_FILE" 2>/dev/null && vok "配置含 bnnbotbox" || vwarn "没 dsh 命令，跳过组合校验"
fi

# 人格（重启后才会自动铺，这里只检查是否已有）
[ -d "$BNN_WORKSPACE/Bot/人格/角色卡" ] && [ -n "$(ls "$BNN_WORKSPACE/Bot/人格/角色卡"/*.md 2>/dev/null)" ] \
  && vok "人格卡已存在" || warn "人格卡还没生成（重启 DSH 后会自动铺「小忆」）"

hr
printf "${BOLD}结果：%d 通过 / %d 失败${N}\n" "$PASS" "$FAIL"
hr

# ── 收尾提示：把「还需要人做的事」变成三行能照抄的话 ──
if [ -n "$OWNER_OPENID" ]; then
  OWNER_HINT="已写入 groupAdmin.owners = $OWNER_OPENID（重启后生效）"
else
  OWNER_HINT="还没设 → 先给机器人发一条消息，然后在 $BNN_DATA_ROOT 下的日志里搜你的 openid（形如 32 位大写十六进制），
接着重跑：./install.sh --owner-openid <你的openid>（或直接编辑配置里的 groupAdmin.owners）
  不设的后果：所有「只有主人能做」的功能对**任何人**开放。"
fi

# 模型检测：DSH 的默认模型在 profile 配置 / 设置界面里
MODEL_HINT="在 DSH 设置 → 模型里确认已选一个可用模型"
if node -e '
  const fs=require("fs");
  const f=process.argv[1];
  const t=fs.readFileSync(f,"utf8");
  process.exit(/agent-default-model/.test(t) && /provider:\s*\S/.test(t) ? 0 : 1);
' "$PATCH_FILE" 2>/dev/null; then
  MODEL_HINT="已检测到默认模型配置（agent-default-model）。若换模型，去 DSH 设置 → 模型 改，别改这个文件"
else
  MODEL_HINT="⚠️ 没检测到默认模型。去 DSH 设置 → 模型 选一个并保存，否则她不会回复"
fi

cat <<EOF

${BOLD}下一步（必须做）${N}

1) ${BOLD}重启 DSH${N}（不是热重载，配置和 hooks 都要重启才生效）

2) 如果上面提示凭证是占位符，先填好：
   ${PATCH_FILE}

3) 重启后确认：
   cat "$BNN_DATA_ROOT/.qqbot-extensions/data/version-guard.json"
   期望看到 "status": "ok"

4) 去 QQ 群里 @ 机器人，看它会不会用自己的语气回你。
   没反应 → 检查 QQ 平台「沙箱配置」里有没有加这个群。

5) 主人身份（决定「只有主人能做的事」对谁开放）
   ${OWNER_HINT}

6) 模型（没配模型 = 她一个字都不会回）
   ${MODEL_HINT}

${Y}注意${N}：日志出现「主动消息失败, 无权限」是 QQ 平台的主动消息限制，
      不是 bug。群聊被动窗口 5 分钟 5 条，主动发言大概率失败。

路径备忘：
  工作区     $BNN_WORKSPACE
  数据根     $BNN_DATA_ROOT
  配置       $PATCH_FILE
  插件源码   $PLUGIN_DIR

EOF

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
