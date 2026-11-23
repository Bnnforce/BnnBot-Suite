# BnnBot 套组 · 验收清单

> 打印出来或复制到笔记里，装一步划一步。
> 每一项后面都写了**怎么验证** —— 没有验证方法的勾不算数。

---

## 阶段 1 · 环境

| # | 项目 | 怎么验证 | ✔ |
|---|---|---|---|
| 1.1 | Node.js ≥ 24.9.0 | `node --version` | ☐ |
| 1.2 | pnpm ≥ 9 | `pnpm --version` | ☐ |
| 1.3 | git 可用 | `git --version` | ☐ |
| 1.4 | DSH 能启动 | `dsh --version` | ☐ |
| 1.5 | 知道 `DSH_HOME` | `echo $DSH_HOME` | ☐ |
| 1.6 | 知道 `PROFILE_DIR` | `echo $DSH_PROFILE_DIR` | ☐ |
| 1.7 | 定好 `WORKSPACE` 和 `DATA_ROOT` | 写下来 | ☐ |
| 1.8 | （安卓）加了电池优化白名单 | App 内设置 | ☐ |

**WORKSPACE** = `____________________`
**DATA_ROOT** = `____________________`

---

## 阶段 2 · 装组件

| # | 项目 | 怎么验证 | ✔ |
|---|---|---|---|
| 2.1 | 通道 `@zaofan/dsh-qqbot` 已装 | `node -e "console.log(require('{PROFILE_DIR}/node_modules/@zaofan/dsh-qqbot/package.json').version)"` ≥ 1.13.16 | ☐ |
| 2.2 | `dsh-bnnbotbox` 已 clone | `ls ~/dsh-bnnbotbox/package.json` | ☐ |
| 2.3 | 插件依赖已装 | `cd ~/dsh-bnnbotbox && ls node_modules` 非空 | ☐ |
| 2.4 | 插件挂进 profile | `require('{PROFILE_DIR}/package.json').dependencies['dsh-bnnbotbox']` 存在 | ☐ |
| 2.5 | **插件真的能加载** | `import('dsh-bnnbotbox')` 返回 `name=bnnbotbox` | ☐ |
| 2.6 | **配置字段 = 52** | 同上，`Object.keys(Config.dict).length === 52` | ☐ |
| 2.7 | 扩展包已复制 | `ls {DATA_ROOT}/extension-packs/bnn-custom/qqbot-pack.json` | ☐ |
| 2.8 | 目录名是 `bnn-custom`（不是别的） | 同上路径 | ☐ |

> ⚠️ 2.5 / 2.6 必须看输出，**不能只看文件存在**。

---

## 阶段 3 · 扩展包自检

| # | 项目 | 怎么验证 | ✔ |
|---|---|---|---|
| 3.1 | 语法全过 | `node scripts/check-syntax.mjs` → `✅ 语法全部通过` | ☐ |
| 3.2 | 目录齐全 | `node scripts/doctor.mjs` → `✅ 必需目录齐全` | ☐ |
| 3.3 | 卡片已同步 | `node scripts/sync-botplay.mjs --check` → `✓ 全部已同步` | ☐ |
| 3.4 | **卡片真的能加载** | 逐张 `import` → `cards=13` | ☐ |

---

## 阶段 4 · QQ 平台

| # | 项目 | ✔ |
|---|---|---|
| 4.1 | 已注册 QQ 开放平台并完成主体认证 | ☐ |
| 4.2 | 已创建机器人 | ☐ |
| 4.3 | 拿到 **AppID** | ☐ |
| 4.4 | 拿到 **AppSecret**（只显示一次，已保存好） | ☐ |
| 4.5 | 已配置 **IP 白名单**（出口 IP） | ☐ |
| 4.6 | 沙箱里**加了测试群** | ☐ |
| 4.7 | 机器人**已被拉进那个群** | ☐ |
| 4.8 | 知道「主动消息受限」这回事 | ☐ |

---

## 阶段 5 · 配置

| # | 项目 | 怎么验证 | ✔ |
|---|---|---|---|
| 5.1 | `appId` / `appSecret` 已填入 `cordis.patch.yml` | 肉眼看 | ☐ |
| 5.2 | `dataRoot` 指向 `{DATA_ROOT}` | 肉眼看 | ☐ |
| 5.3 | `qqbotDataRoot` = 通道的 `dataRoot` | 肉眼看，两个要一样 | ☐ |
| 5.4 | `sessionIdleTimeout` = `14400000` | 肉眼看 | ☐ |
| 5.5 | `freeIntervalSec` = `5` | 肉眼看（默认 60 太慢） | ☐ |
| 5.6 | YAML **没有 tab 缩进** | `grep -nP "^\t" cordis.patch.yml` 无输出 | ☐ |
| 5.7 | 配置能被解析 | `dsh --profile {PROFILE} --dump-config` 不报错 | ☐ |
| 5.8 | 人格卡存在 | `ls {WORKSPACE}/Bot/人格/角色卡/` 有 `.md` | ☐ |
| 5.9 | `persona-config.json` 指向存在的卡 | 对比 `defaultPersona` 和文件名 | ☐ |
| 5.10 | **重启过 DSH** | 不是热重载 | ☐ |

---

## 阶段 6 · 真机验收

| # | 项目 | 怎么验证 | ✔ |
|---|---|---|---|
| 6.1 | 群里 @ 她有回复 | 群里发 `@她 你好` | ☐ |
| 6.2 | 回复带 @ 你的标记 | 看消息 | ☐ |
| 6.3 | 她能调工具 | 发 `@她 现在几点` | ☐ |
| 6.4 | 斜杠命令有响应 | 群里发 `/签到` | ☐ |
| 6.5 | 卡片能打开 | 发 `/玩法` | ☐ |
| 6.6 | 卡片按钮能点 | 点卡片按钮 | ☐ |
| 6.7 | 她记得住人（异步，可稍后测） | 说名字 → 过一会问 | ☐ |
| 6.8 | 版本状态正常 | `cat {DATA_ROOT}/.qqbot-extensions/data/version-guard.json` → `status: ok` | ☐ |

---

## 阶段 7 · 排障准备（出问题时能自救）

| # | 项目 | ✔ |
|---|---|---|
| 7.1 | 知道插件日志在 `{DSH_HOME}/data/dsh-bnnbotbox/*.log` | ☐ |
| 7.2 | 知道平台拒收看 `{DATA_ROOT}/.qqbot/ext-deliver.log` | ☐ |
| 7.3 | 知道 `主动消息失败, 无权限` 是平台限制，不是 bug | ☐ |
| 7.4 | 会跑 `node scripts/doctor.mjs` | ☐ |

---

## 出问题时的三连（贴在终端里跑）

```bash
cd {DATA_ROOT}/extension-packs/bnn-custom
node scripts/doctor.mjs
node scripts/check-syntax.mjs
node scripts/sync-botplay.mjs --check
```

```bash
cd {PROFILE_DIR}
node --input-type=module -e "await import('dsh-bnnbotbox'); console.log('✅ 插件能加载')"
```

三个都过 + 插件能加载 → 问题在**平台侧**或**配置项**，看 [06 · 排障](docs/06-排障.md)。

---

## 签字

- 安装人：____________
- 日期：____________
- 全部通过：☐ 是　☐ 有 N 项未通过（列出来：____________）
