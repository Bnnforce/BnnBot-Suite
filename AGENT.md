# AGENT.md · 给 AI 代理的安装手册

> **这份文件是给 AI 代理（DSH / 其他 agent）读的。**
> 人类请读 [README](README.md)。
>
> 你的任务：**把 BnnBot 套组装到这台机器上并验证可用。**
> 按步骤执行，每步都有通过判据。**判据不过不要往下走。**

---

## 0. 铁律（违反会静默装坏）

| # | 规则 |
|---|---|
| 1 | **不要凭空填 `appId` / `appSecret`**。必须向人类要。拿不到就停在这一步 |
| 2 | **判断「装好了没有」不能看文件存在**。必须真的 `import` 一遍 / 真的收到回复 |
| 3 | **改配置后必须重启 DSH**。`hooks/`、`commands/` 不支持热重载 |
| 4 | **不要改 `dataRoot`**。它决定所有数据的位置，改了等于数据消失 |
| 5 | 每步失败 → **停下来报告**，不要猜着修、不要跳过 |
| 6 | 扩展包目录名**必须**是 `bnn-custom` |
| 7 | 这个机可能是 Android：**没有 `tar czf`、没有软链、`/tmp` 不可写**（见 §7） |

---

## 1. 先探明环境（不要假设）

```bash
node --version
pnpm --version
dsh --version 2>/dev/null || echo "NO_DSH"
echo "DSH_HOME=$DSH_HOME"
echo "DSH_PROFILE=$DSH_PROFILE"
echo "DSH_PROFILE_DIR=$DSH_PROFILE_DIR"
uname -a
```

**要确定的值**：

| 变量 | 怎么确定 |
|---|---|
| `{PROFILE}` | `$DSH_PROFILE`，没有就问人类 |
| `{PROFILE_DIR}` | `$DSH_PROFILE_DIR`；没有就用 `$DSH_HOME/profiles/$DSH_PROFILE` |
| `{DATA_ROOT}` | 默认建议 `{WORKSPACE}/Bot/dshqqbot`，**问人类确认** |
| `{WORKSPACE}` | 人类指定的工作目录。Android 常见 `/sdcard/DSH` |

**停止条件**：

- `node --version` < v24.9.0 → 停，报告「Node 版本不够，DSH 要求 ≥ 24.9.0」
- 没有 `pnpm` → 停，报告需要先装 pnpm
- 没有 `dsh` → 停，报告需要先装 DSH（安卓装 DeepCode APK）

---

## 2. 向人类索取（不要跳过）

必须问清楚这四件，**不要自己编**：

1. QQ 机器人的 **AppID**
2. QQ 机器人的 **AppSecret**
3. 想在哪个工作区部署（`{WORKSPACE}`）
4. 机器人要不要用**人格 + 记忆**（要 = 装 `dsh-bnnbotbox`），要不要**玩法扩展**（要 = 装扩展包）

> 如果人类说「你看着办」：
> - `{WORKSPACE}` 用 `~/bnnbot` 或 `/sdcard/DSH`
> - 两个都装（功能完整）

---

## 3. 装通道 `@zaofan/dsh-qqbot`

```bash
cd "{PROFILE_DIR}"
pnpm add @zaofan/dsh-qqbot
```

**通过判据**：

```bash
node -e "console.log(require('{PROFILE_DIR}/node_modules/@zaofan/dsh-qqbot/package.json').version)"
```

输出 ≥ `1.13.16` 才算过。

---

## 4. 装插件 `dsh-bnnbotbox`

```bash
cd ~
[ -d dsh-bnnbotbox ] || git clone https://github.com/Bnnforce/dsh-bnnbotbox.git
cd dsh-bnnbotbox
pnpm install
```

挂进 profile：

```bash
cd "{PROFILE_DIR}"
pnpm add "link:$HOME/dsh-bnnbotbox"
```

**通过判据（必须 import 真的成功）**：

```bash
cd "{PROFILE_DIR}"
node --input-type=module -e "
  const m = await import('dsh-bnnbotbox');
  const n = Object.keys(m.Config.dict).length;
  console.log(JSON.stringify({ name: m.name, fields: n, inject: m.inject }, null, 0));
  if (m.name !== 'bnnbotbox') throw new Error('name 不对');
  if (n !== 52) throw new Error('配置字段应为 52，实际 ' + n + '（可能装到老版本）');
  console.log('PASS');
"
```

必须看到 `PASS`。看不到就停。

---

## 5. 装扩展包（如果人类要玩法）

```bash
cd ~
[ -d dsh-qqbot-bnn-custom ] || git clone https://github.com/Bnnforce/dsh-qqbot-bnn-custom.git

mkdir -p "{DATA_ROOT}/extension-packs"
rm -rf "{DATA_ROOT}/extension-packs/bnn-custom"
cp -r ~/dsh-qqbot-bnn-custom "{DATA_ROOT}/extension-packs/bnn-custom"
```

> ⚠️ 目标目录名必须是 `bnn-custom`，不是 `dsh-qqbot-bnn-custom`。

**通过判据**：

```bash
cd "{DATA_ROOT}/extension-packs/bnn-custom"
node scripts/check-syntax.mjs | tail -2   # 期望 ✅ 语法全部通过
node scripts/doctor.mjs --fix | tail -4   # 期望 ✅ 必需目录齐全
node scripts/sync-botplay.mjs             # 同步卡片运行时副本
```

---

## 6. 写配置

编辑 `{PROFILE_DIR}/cordis.patch.yml`，**追加**（不要覆盖已有内容）：

```yaml
- insert:
    - id: im-qqbot-2
      name: '@zaofan/dsh-qqbot'
      config:
        appId: '<人类的 AppID>'
        appSecret: '<人类的 AppSecret>'
        settingsNs: 'im-qqbot-2'
        preset: 'qqbot'
        cwd: '<WORKSPACE>/Bot'
        dataRoot: '<DATA_ROOT>'
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

    - id: bnnbotbox
      name: 'dsh-bnnbotbox'
      config:
        enabled: true
        qqbotDataRoot: '<DATA_ROOT>'
        dataRoot: ''
```

**注意事项**：

- 用**空格**缩进，**绝不能有 tab**
- `qqbotDataRoot` 必须等于通道的 `dataRoot`
- 如果 `cordis.patch.yml` 里已经有同名 `id`，改成已有那条的 `config`，不要重复 insert

**通过判据**：

```bash
cd "{PROFILE_DIR}"
grep -nP "^\t" cordis.patch.yml && echo "FAIL: 有 tab" || echo "PASS: 无 tab"
dsh --profile "{PROFILE}" --dump-config 2>&1 | head -20
```

`--dump-config` 不报错 = 语法 OK。

---

## 7. 重启并验证运行时

**告诉人类重启 DSH**（你无法替他重启引擎）。重启后继续：

```bash
# ① 插件状态
cat "{DATA_ROOT}/.qqbot-extensions/data/version-guard.json"

# ② 目录自愈结果
cat "{DATA_ROOT}/.qqbot-extensions/data/workspace-dirs.json"

# ③ 卡片真的能加载吗
cd "{DATA_ROOT}/.qqbot-extensions/botplay" 2>/dev/null && node --input-type=module -e "
import fs from 'node:fs';
let ok = 0; const bad = [];
for (const f of fs.readdirSync('.').filter(x => x.endsWith('.mjs'))) {
  try { await import('file://' + process.cwd() + '/' + f + '?v=' + Date.now()); ok++; }
  catch (e) { bad.push(f); }
}
console.log('cards=' + ok, bad.length ? 'BAD=' + bad.join(',') : 'PASS');
"
```

**通过判据**：

| 检查 | 期望 |
|---|---|
| `version-guard.json` | `"status": "ok"` |
| 卡片加载 | `cards=13 PASS` |
| 人格目录 | `{WORKSPACE}/Bot/人格/角色卡/` 里有 `.md` |

---

## 8. 交给人类做的最后一步

**你无法代替人类做这些**，明确告诉他：

1. 去 QQ 群里 **@ 机器人**，看它会不会用自己的语气回
2. 如果没反应 → 检查 QQ 平台「沙箱配置」里有没有加这个群
3. 如果日志出现 `主动消息失败, 无权限` → **这是平台的主动消息限制，不是 bug**

---

## 9. Android 环境注意事项

如果 `uname -a` 显示是 Android：

| 限制 | 替代做法 |
|---|---|
| 没有 `tar czf` | 用 `cp -r` |
| `cp -r` 大目录可能静默失败 | 用 node `copyFileSync` 逐文件复制 |
| `ln -s` 失败（FUSE） | 复制代替 |
| `/tmp` 不可写 | 用 `os.tmpdir()` 或工作区内临时目录 |
| `grep 'a\|b'` 静默假阴性 | 用 `grep -E` 或 `rg` |

---

## 10. 你要报告的格式

装完（或卡住）时，按这个格式回报：

```
【结论】成功 / 卡在第 N 步
【环境】node=..., pnpm=..., dsh=..., 平台=...
【路径】PROFILE_DIR=..., DATA_ROOT=..., WORKSPACE=...
【已验证】
  - qqbot 版本: ...
  - 插件 import: PASS（配置 52 字段）
  - 扩展包语法: PASS
  - doctor: PASS
  - 卡片加载: cards=13 PASS
【未验证】（需要人类做）
  - 群内 @ 回复
  - 平台沙箱配置
【遗留问题】
  - ...
```

---

## 11. 停止条件（必须停，不要自己决定）

- 拿不到 `appId` / `appSecret`
- Node 版本 < 24.9.0 且无权升级
- `pnpm add` 报网络错误（先重试一次，仍失败就停）
- 插件 `import` 一直失败
- 配置文件里已有同名 `id`，且结构看不懂
- 需要删除或覆盖任何已有数据目录

**停下来报告，比猜着修好。**
