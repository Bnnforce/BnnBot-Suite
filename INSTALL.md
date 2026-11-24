# INSTALL.md · BnnBot 套组一键安装（自包含）

> **这份文件是自包含的。** 你（人或 AI）不需要再打开别的文档就能装完。
> 需要更细的解释时才去看 [`docs/`](docs/) 里的对应章节。

---

## 怎么拿到这份文件（如果你还没拿到）

```
https://github.com/Bnnforce/BnnBot-Suite/releases/download/v1.0.2/INSTALL.md
```

⚠️ **不要用 `raw.githubusercontent.com`** —— 本机实测该域名会连接重置（HTTP 000），
`cdn.jsdelivr.net` 也一样。上面的 releases 直链连测 3 次全部 200。

同目录还有可执行脚本：

```
https://github.com/Bnnforce/BnnBot-Suite/releases/download/v1.0.2/install.sh
https://github.com/Bnnforce/BnnBot-Suite/releases/download/v1.0.2/verify.sh
```

---

## 给 AI 代理：先读这五条

1. **先向人类要 `appId` 和 `appSecret`。拿不到就先只装不配，别自己编。**
2. **判断「装好了」不能看文件存在**，必须真的 `import` 一次 / 真的收到回复。
3. **改完配置必须重启 DSH**，`hooks`/`commands` 不支持热重载。
4. **不要改 `dataRoot`**，它决定所有数据位置。
5. **失败就停下来报告**，不要猜着修、不要跳过步骤。

---

## 第 0 步：确认环境

```bash
node --version     # 必须 >= 24.9.0（DSH 的硬要求，不是插件的要求）
pnpm --version     # 必须 >= 9
git --version
dsh --version      # 没有也行（Android App 内 PATH 里可能没有）
```

**不满足就停**，先解决环境：

| 缺什么 | 怎么办 |
|---|---|
| Node < 24.9.0 | 装 Node 24。Android 用户装 [DeepCode APK](https://github.com/kelai141/dsh-mobile-apk)（自带 Node） |
| 没有 pnpm | `npm i -g pnpm` 或 `corepack enable` |

### 确定这四个路径（后面全要用）

```bash
echo "DSH_HOME=$DSH_HOME"            # 通常 ~/.dsh
echo "DSH_PROFILE=$DSH_PROFILE"      # 通常 web
echo "DSH_PROFILE_DIR=$DSH_PROFILE_DIR"
```

记成：

```
{PROFILE}     = ${DSH_PROFILE:-web}
{PROFILE_DIR} = ${DSH_PROFILE_DIR:-$DSH_HOME/profiles/$DSH_PROFILE}
{WORKSPACE}   = 人类指定的工作目录（默认 $HOME/bnnbot，Android 常见 /sdcard/DSH）
{DATA_ROOT}   = {WORKSPACE}/Bot/dshqqbot
```

> `{PROFILE_DIR}` 不存在说明 DSH 还没初始化过。**先启动一次 DSH** 让它生成 profile。

---

## 第 1 步：向人类索取凭证

```
我需要两样东西才能配好 QQ 通道：
1) QQ 机器人的 AppID
2) QQ 机器人的 AppSecret
从 https://q.qq.com → 机器人 → 开发管理 里拿。Secret 只显示一次。
```

**要不到就继续装（只是配置留占位符），但必须明确告知人类最后要自己填。**

---

## 第 1.5 步：通道补丁（脚本会自动做）

装完通道插件后，install.sh 会**自动打 4 个补丁**，修的是上游 `@zaofan/dsh-qqbot@1.13.20` 的真 bug：

| 补丁 | 修什么 | 不打会怎样 |
|---|---|---|
| botplay 点击者身份 | 卡片回调拿到正确的 `ctx.user.openid` | 🔴 抽奖图鉴记错人、小店归属错、权限判断失效 |
| 图片表情 | `faceType=6` 输出「【图片表情】」而非猜成「微笑」 | 🟠 群友发贴纸她一律理解成在笑 |
| 会话命令兜底 | `getScopePeer` 用 `caps.replyTarget` 兜底 + fork 超时 | 🟠 `/子会话` `/会话列表` 在 web 上下文抛错 |
| 工具错误静默 | 群内不展示联网工具凭据/内部错误 | 🟡 群里可能漏原始报错 |

补丁文件在 `patches/qqbot-1.13.20/`（**只分发 diff，不分发整文件**）。

> ⚠️ 许可：`@zaofan/dsh-qqbot` 是 **AFL-3.0**，这些 diff 属于其派生内容，
> 受 AFL-3.0 约束，**不在本套组的 MIT 范围内**。详见 `patches/qqbot-1.13.20/LICENSE-NOTICE.md`。

校验（6 个 marker 必须全在）：

```bash
cd "{PROFILE_DIR}/node_modules/@zaofan/dsh-qqbot"
grep -rhoE "QQBot(Security|Local)Patch:[a-z-]+" dist/features/botplay.js \
  dist/features/face-tags.js dist/commands/session.js dist/transport/tool-presenter.js | sort -u
```

跳过补丁：`install.sh --no-patch`（**不推荐**，功能会缺一块）。

---

## 第 2 步：一键装（推荐）

如果本文件旁边的 `install.sh` 可用：

```bash
bash install.sh \
  --workspace "{WORKSPACE}" \
  --data-root "{DATA_ROOT}" \
  --app-id "<AppID>" \
  --app-secret "<AppSecret>"
```

它做这些：装通道 → 装插件 → 放扩展包 → 写配置 → 验收。

只装人格不装玩法：加 `--skip-ext`。
只装不写配置：加 `--no-config`。

> **`install.sh` 从哪来**：
> - 仓库 clone 下来的话就在根目录
> - 或者从 [Releases](https://github.com/Bnnforce/BnnBot-Suite/releases/latest) 下载

**脚本跑完跳到第 4 步。**

---

## 第 3 步：手动装（脚本不可用时）

### 3.1 装通道 `@zaofan/dsh-qqbot`（★ 装指定的版本）

```bash
cd "{PROFILE_DIR}"
pnpm add @zaofan/dsh-qqbot@1.13.20
```

> ⚠️ **必须钉版本，不要装最新版。**
>
> 上游只声明最低版本（`minPluginVersion`），**没有上限机制**，而真实风险是「向上不兼容」。
> 实测 `1.13.21`~`1.13.23` 这批版本：
>
> | 上游改动 | 对本套组的影响 |
> |---|---|
> | 改了本套组打过补丁的 4 个 dist 文件 | 补丁冲突，相关功能**静默失效** |
> | `outboundLastCtxFallback` 默认改为 `false`（拒发） | 扩展包 `outbound/60-split-bubbles` 里不传 target 的 `ctx.send()` **全部失败** ⇒ 多段回复只有第一段能发出去 |
>
> **为什么不靠 `^1.13.20`**：`^` 允许自动升到 `1.13.23`，上面两个坑都会踩。
>
> 想用最新版：自己承担风险，装完必须看 `verify.sh` 的 `compat` 结果。

验证（**必须完全等于这个版本**）：

```bash
node -e "console.log(require('{PROFILE_DIR}/node_modules/@zaofan/dsh-qqbot/package.json').version)"
# 期望输出：1.13.20（不是 >= 1.13.16，也不是 1.13.23）
```

装成了别的版本怎么办（pnpm 按老范围解了）：

```bash
cd "{PROFILE_DIR}"
pnpm add @zaofan/dsh-qqbot@1.13.20 --save-exact
```

### 3.2 装插件 `dsh-bnnbotbox`

```bash
mkdir -p ~/bnnbot-src && cd ~/bnnbot-src
git clone --depth 1 https://github.com/Bnnforce/dsh-bnnbotbox.git
cd dsh-bnnbotbox
pnpm install
```

挂进 profile：

```bash
cd "{PROFILE_DIR}"
pnpm add "link:$HOME/bnnbot-src/dsh-bnnbotbox"
```

**验证（关键，不能只看文件）：**

```bash
cd "{PROFILE_DIR}"
node --input-type=module -e "
  const m = await import('dsh-bnnbotbox');
  const n = Object.keys(m.Config.dict).length;
  console.log('name=' + m.name, 'fields=' + n);
  if (m.name !== 'bnnbotbox') throw new Error('name 不对');
  if (n !== 52) throw new Error('配置字段应为 52，实际 ' + n);
  console.log('PASS');
"
```

必须看到 `PASS`。`fields=32` 说明装的是老版本。

### 3.3 放扩展包（可选，想要积分/点歌/抽奖才需要）

```bash
mkdir -p "{DATA_ROOT}/extension-packs"
cd ~/bnnbot-src
git clone --depth 1 https://github.com/Bnnforce/dsh-qqbot-bnn-custom.git
cp -r dsh-qqbot-bnn-custom "{DATA_ROOT}/extension-packs/bnn-custom"
```

> ⚠️ 目标目录名**必须**是 `bnn-custom`。

```bash
cd "{DATA_ROOT}/extension-packs/bnn-custom"
node scripts/check-syntax.mjs     # 期望 ✅ 语法全部通过
node scripts/doctor.mjs --fix     # 期望 ✅ 必需目录齐全
node scripts/sync-botplay.mjs     # 同步 13 张卡片的运行时副本
```

### 3.4 写配置

编辑 `{PROFILE_DIR}/cordis.patch.yml`，**追加**以下内容：

```yaml
# qqbot 通道：新增一行，配自己的凭证
- insert:
    - id: im-qqbot-2
      name: '@zaofan/dsh-qqbot'
      config:
        appId: '<AppID>'
        appSecret: '<AppSecret>'
        settingsNs: 'im-qqbot-2'
        preset: 'qqbot'
        cwd: '{WORKSPACE}/Bot'
        dataRoot: '{DATA_ROOT}'
        sessionIdleTimeout: 14400000
        requireMention: false
        historyLimit: 50
        behavior:
          freeIntervalSec: 5
          mentionIntervalSec: 0
          directIntervalSec: 0
          debounce:
            enabled: true
            silenceSec: 1
            maxMsgs: 10
            mentionDelayed: false

# bnnbotbox：它已被 bundle 自动插入，这里只覆盖 config（不要写 insert！）
- id: bnnbotbox
  config:
    enabled: true
    qqbotDataRoot: '{DATA_ROOT}'
    dataRoot: ''
```

> ⚠️ **两个陷阱**：
> 1. **YAML 只能用空格缩进，绝不能有 tab**
> 2. `bnnbotbox` 那行**不能写成 `- insert:`**，否则会插出重复 id。
>    它由插件自带的 patch 自动插入，我们只是按 id 覆盖它的 `config`。

验证配置语法：

```bash
cd "{PROFILE_DIR}"
grep -nP "^\t" cordis.patch.yml && echo "❌ 有 tab" || echo "✅ 无 tab"
dsh --profile "{PROFILE}" --dump-config >/dev/null 2>&1 && echo "✅ 配置能解析" || echo "❌ 配置有语法错误"
```

---

## 第 4 步：重启 DSH

**必须重启，不是热重载。** 告诉人类去做，或者自己重启引擎。

重启后的第一次启动会自动做这些（**只在缺失时做，不覆盖已有文件**）：

| 动作 | 结果 |
|---|---|
| 铺最小默认人格 | `{WORKSPACE}/Bot/人格/角色卡/小忆.md` + `persona-config.json` |
| 建必需目录 | `Bot/人格/`、`Bot/人格/积分/`、`.qqbot-extensions/data/` |
| 同步卡片 | 13 张卡片 + `lib/` 依赖树复制到 `.qqbot-extensions/` |

---

## 第 5 步：验收（必须做，别跳过）

### 一条命令版

```bash
bash verify.sh --workspace "{WORKSPACE}" --data-root "{DATA_ROOT}"
```

期望 `通过 N / 警告 M / 失败 0`。

### 手动版

```bash
# ① 插件能加载且配置 52 字段
cd "{PROFILE_DIR}"
node --input-type=module -e "
  const m = await import('dsh-bnnbotbox');
  console.log('PASS', m.name, Object.keys(m.Config.dict).length);
"

# ② 卡片真的能加载（13/13）
cd "{DATA_ROOT}/.qqbot-extensions/botplay" && node --input-type=module -e "
import fs from 'node:fs';
let ok = 0; const bad = [];
for (const f of fs.readdirSync('.').filter(x => x.endsWith('.mjs'))) {
  try { await import('file://' + process.cwd() + '/' + f + '?v=' + Date.now()); ok++; }
  catch { bad.push(f); }
}
console.log('cards=' + ok + '/13', bad.length ? 'BAD=' + bad.join(',') : 'PASS');
"

# ③ 运行时状态
cat "{DATA_ROOT}/.qqbot-extensions/data/version-guard.json"
cat "{DATA_ROOT}/.qqbot-extensions/data/workspace-dirs.json"
```

**通过标准**：

| 检查 | 期望 |
|---|---|
| 插件 import | `PASS bnnbotbox 52` |
| 卡片 | `cards=13/13 PASS` |
| `version-guard.json` | `"status": "ok"`（或含 `"changed"` = 文件有变动，重启后消失） |
| `workspace-dirs.json` | 有 created / existed / hintOptional 字段 |

---

## 第 6 步：交给人类做最后一步（AI 做不了）

明确告知人类：

```
装好了。剩下三件需要你自己做：

1) 去 QQ 群 @ 机器人，看它会不会用自己的语气回你
   没反应 → 检查 QQ 平台「沙箱配置」有没有加这个群

2) 如果配置里凭证还是占位符，填这里：
   {PROFILE_DIR}/cordis.patch.yml

3) 知道一件事：日志里的「主动消息失败, 无权限」
   是 QQ 平台的主动消息限制（群被动窗口 5 分钟 5 条），不是 bug
```

---

## 附录 A：这套东西由什么组成

| 组件 | 来源 | 许可 |
|---|---|---|
| **DSH**（宿主） | [dexharness](https://github.com/deepseek-ai/deepseek-harness) / 安卓壳 [DeepCode](https://github.com/kelai141/dsh-mobile-apk) | MIT |
| `@zaofan/dsh-qqbot`（QQ 通道，第三方） | [zaofan-make/dsh-qqbot](https://github.com/zaofan-make/dsh-qqbot) | AFL-3.0 |
| `dsh-bnnbotbox`（人格 + 记忆） | [Bnnforce/dsh-bnnbotbox](https://github.com/Bnnforce/dsh-bnnbotbox) | MIT |
| `dsh-qqbot-bnn-custom`（群聊玩法） | [Bnnforce/dsh-qqbot-bnn-custom](https://github.com/Bnnforce/dsh-qqbot-bnn-custom) | MIT |

---

## 附录 B：验证过的版本

| 组件 | 版本 |
|---|---|
| DSH | `0.2.2-rc.3` |
| Node.js | `24.18.0`（要求 ≥ 24.9.0） |
| pnpm | `10.12.1`（要求 ≥ 9） |
| `@zaofan/dsh-qqbot` | `1.13.20` |
| `dsh-bnnbotbox` | `3.1.1` |
| `dsh-qqbot-bnn-custom` | `1.0.57` |

---

## 附录 C：装不上时

按顺序跑这三条，输出全部贴出来：

```bash
cd "{PROFILE_DIR}" && node --input-type=module -e "await import('dsh-bnnbotbox')"
cd "{DATA_ROOT}/extension-packs/bnn-custom" 2>/dev/null && node scripts/doctor.mjs
bash verify.sh --workspace "{WORKSPACE}" --data-root "{DATA_ROOT}"
```

对照 [docs/06-排障.md](docs/06-排障.md) 的症状表。

**最高频的五个原因**：

| 现象 | 原因 | 解决 |
|---|---|---|
| `ERR_MODULE_NOT_FOUND` | 没跑 `pnpm install` | 进插件目录跑一次 |
| 插件装了但群里没反应 | 没重启 | 重启，不是热重载 |
| `配置里缺 bnnbotbox 行` | `bnnbotbox` 写成了 `insert` | 改成按 id 覆盖 |
| 卡片报「模块加载失败」 | 没同步运行时副本 | `node scripts/sync-botplay.mjs` |
| 扩展包加载不出来 | 目录名不是 `bnn-custom` | 改名 |

---

## 附录 D：停止条件（AI 必须停）

- 拿不到 `appId` / `appSecret`
- Node 版本 < 24.9.0 且无法升级
- `pnpm add` 连续两次网络失败
- 插件 import 一直失败
- 需要删除或覆盖任何已有数据目录
- 配置文件里已有同名 id 且结构看不懂

**停下来报告，比猜着修好。**
