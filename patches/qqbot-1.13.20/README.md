# qqbot 补丁 · 1.13.20

> ⚠️ **这些补丁修改的是第三方作品** [`@zaofan/dsh-qqbot`](https://github.com/zaofan-make/dsh-qqbot)
> （AFL-3.0 许可）。本目录**只分发 diff**，不重新分发整文件。
>
> 许可与归属说明见本目录的 [`LICENSE-NOTICE.md`](LICENSE-NOTICE.md)。
> 本套组其余部分（文档、脚本）是 MIT —— 两者不混同。

---

## 为什么需要补丁

本套组钉死 `@zaofan/dsh-qqbot@1.13.20`。这个版本有 4 个上游 bug 会直接影响 BnnBot 的功能，
**原版装上就会踩**，所以随套组分发修复。

`install.sh` 会在装完通道后**自动应用**这 4 个补丁，并校验 6 个 marker 是否在位；
`verify.sh` 也会检查。

---

## 4 个补丁分别修什么

| 文件 | 补丁 | 修什么 | 不加会怎样 |
|---|---|---|---|
| `01-botplay-clicker-id.patch` | `dist/features/botplay.js` | 卡片点击者身份：`clickerId ?? triggererId`；错误回复定向给点击者（`safeReply` 带 `presser`） | 🔴 **严重**：`ctx.user.openid` 拿不到 → 抽奖图鉴记错人、小店归属错、权限判断失效 |
| `02-face-tags-image.patch` | `dist/features/face-tags.js` | 图片表情（`faceType=6`）输出中性的「【图片表情】」，不再按经典表情表查 | 🟠 群友发贴纸，她一律理解成「微笑 / 在笑」 |
| `03-session-context.patch` | `dist/commands/session.js` | `getScopePeer` 兜底（用 `caps.replyTarget`）+ `/bot-new` fork 20s 超时 | 🟠 `/子会话`、`/会话列表` 在 web/dock 上下文抛 `TypeError`；fork 卡死时 QQ 侧永远等不到回复 |
| `04-tool-presenter-errors.patch` | `dist/transport/tool-presenter.js` | QQ 群不展示 `web_search` / `web_fetch` 的凭据与网络内部错误 | 🟡 群里可能漏出原始报错 |

合计约 137 行差异。

---

## 怎么应用

```bash
PKG="{PROFILE_DIR}/node_modules/@zaofan/dsh-qqbot"
cd "$PKG"
for p in {路径}/patches/qqbot-1.13.20/*.patch; do
  patch -p1 --forward < "$p"
done
```

`install.sh` 会自动做这件事，**一般不需要手动**。

### 校验是否成功

6 个 marker 必须全部在位：

```bash
cd "{PROFILE_DIR}/node_modules/@zaofan/dsh-qqbot"
grep -rhoE "QQBot(Security|Local)Patch:[a-z-]+" \
  dist/features/botplay.js dist/features/face-tags.js \
  dist/commands/session.js dist/transport/tool-presenter.js | sort -u
```

期望输出：

```
QQBotLocalPatch:face-type-image
QQBotLocalPatch:session-cmd-context
QQBotSecurityPatch:botplay-clicker-id
QQBotSecurityPatch:safe-reply-fallback
QQBotSecurityPatch:safe-reply-mention
QQBotSecurityPatch:web-tool-error-silent
```

`verify.sh` 也会检查这一项。

---

## 幂等性

补丁带 marker，重复应用会因「已存在」而失败（`patch` 报 `Reversed (or previously applied) patch detected`）。
`install.sh` 的做法是**先查 marker**：

- 6 个都在 → 跳过打补丁
- 一个都没有 → 全量应用
- 部分在位 → 报错并停下（状态不明，别硬打）

---

## 什么时候需要重新生成

只有一种情况：**上游版本变了**（比如以后从 1.13.20 升到 1.13.23）。
那时这 4 个补丁大概率打不上（上游也改过这 4 个文件），必须人工重并。

重并步骤：

```bash
# 1. 拿到原版
npm pack @zaofan/dsh-qqbot@<新版本>     # 得到 tgz
tar xzf dsh-qqbot-*.tgz                 # 解到 package/

# 2. 逐个文件对比「本机已打补丁版」与「新原版」
diff -u package/dist/features/botplay.js \
        {PROFILE_DIR}/node_modules/@zaofan/dsh-qqbot/dist/features/botplay.js

# 3. 手工把差异移植到新版本，生成新补丁
diff -u --label a/dist/<file> --label b/dist/<file> \
        package/dist/<file> <新打的文件> > patches/qqbot-<新版本>/01-....patch

# 4. 在纯净副本上验证
cp -r package /tmp/applytest && cd /tmp/applytest
for p in patches/qqbot-<新版本>/*.patch; do patch -p1 --dry-run < "$p" || echo "打不上: $p"; done
```

> 注意：Android 上 `/tmp` 不可写，用工作区下的临时目录代替。

---

## 与上游的关系

这 4 个修复都是上游的真 bug，我们已经整理成 PR 提到
[`zaofan-make/dsh-qqbot`](https://github.com/zaofan-make/dsh-qqbot)。

**上游合并后**，将来升级到修好的版本就可以删掉整个 `patches/` 目录 —— 这也是为什么补丁按
`qqbot-<版本>` 分目录：换版本时天然隔离，不会拿旧补丁打新版本。
