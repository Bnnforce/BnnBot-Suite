# 第三方组件声明

**BnnBot-Suite（本仓库）本身不含任何可执行代码依赖。**

它是一个**部署总入口**：`install.sh` / `verify.sh` / `manifest.json` / 文档 + 预设，
负责把下面这些由**别的仓库**维护的组件拼到一台机器上跑起来。
本仓库不 `vendor` 任何第三方源码，没有 `node_modules/`，也没有 `vendor/` 目录。

所以这份声明分三段：
① 本套组自己是谁、什么许可；② 它编排的所有组件及各自许可；③ 各组件的依赖去哪看。

---

## 一、本仓库

| 项 | 内容 |
|---|---|
| 仓库 | <https://github.com/Bnnforce/BnnBot-Suite> |
| 性质 | 文档 + 安装/验收脚本 + `manifest.json` 清单 + 预设，无可执行运行时依赖 |
| 许可证 | **MIT**（见 [`LICENSE`](LICENSE)，`Copyright (c) 2026 BnnBot 套组 contributors`） |

`install.sh` 只调用使用者机器上已有的 `node` / `pnpm` / `git` / 常规 shell 工具，
不下载、不打包任何第三方二进制进本仓库。

## 二、被编排的组件

版本号取自 [`manifest.json`](manifest.json) 的 `components[]`（本套组验证过的版本），
许可证以其各自仓库的 `LICENSE` 为准。

### BnnBot 自有三件套（同作者，MIT）

| 组件 | 角色 | 验证版本 | 许可证 | 仓库 |
|---|---|---|---|---|
| **BnnBot-Suite**（本仓库） | 部署总入口 | 1.0.21 | **MIT** | <https://github.com/Bnnforce/BnnBot-Suite> |
| **dsh-bnnbotbox** | 人格 + 记忆插件 | 3.4.7 | **MIT** | <https://github.com/Bnnforce/dsh-bnnbotbox> |
| **dsh-qqbot-bnn-custom** | 群聊玩法扩展包 | 1.0.76 | **MIT** | <https://github.com/Bnnforce/dsh-qqbot-bnn-custom> |

各自的第三方依赖见对应仓库的 `THIRD-PARTY.md`：

- 插件（`dsh-bnnbotbox`）依赖 `@deepseek-ai/schemastery`、`@deepseek-ai/dsh-tools`、`@deepseek-ai/cordis`（均 MIT）。
- 扩展包（`dsh-qqbot-bnn-custom`）依赖 `silk-wasm`（MIT），并 vendor 了 `mpg123-decoder` / `simple-yenc`（均 MIT）。

### 第三方组件（不由本套组维护）

| 组件 | 角色 | 验证版本 | 许可证 | 仓库 |
|---|---|---|---|---|
| **DeepSeek Harness**（DSH） | 宿主运行时 | 0.2.2-rc.3 | **MIT** | <https://github.com/deepseek-ai/deepseek-harness> |
| **DeepCode**（DSH 安卓壳） | Android 容器（可选，仅手机安装用） | — | **MIT** | <https://github.com/kelai141/dsh-mobile-apk> |
| **`@zaofan/dsh-qqbot`** | QQ 通道插件 | **1.13.29（钉死）** | **AFL-3.0** | <https://github.com/zaofan-make/dsh-qqbot> |
| **`dsh-memewiki`**（梗指南） | 网络梗查询词库（可选） | 0.1.20+ | **MIT** | 由 `install.sh` 经 pnpm 安装 |

> ⚠️ **AFL-3.0 是本节里唯一的 copyleft 许可。** `@zaofan/dsh-qqbot` 是独立进程/独立包，
> 本套组既不分发它也不修改它（`install.sh` 只做 `pnpm add` 安装 + 读取其公开行为做兼容校验），
> 因此本套组的 MIT 不受其影响。若你要**再分发**该插件，需自行遵守 AFL-3.0 的义务。

### 可选运行时依赖

| 组件 | 版本 | 许可证 | 用途 | 归属 |
|---|---|---|---|---|
| `silk-wasm` | ^3.7.1 | **MIT** | 音频转 SILK（QQ 语音条） | 扩展包声明，`manifest.json` 的 `optionalDeps` |
| `pnpm` | >= 9 | MIT | 包管理器（使用者环境自带） | 外部工具 |
| Node.js | >= 20（实测 v24） | MIT | 运行时（使用者环境自带） | 外部工具 |

## 三、素材与内容版权

本仓库**不含**任何角色素材。`manifest.json` 明确记录：

> 曲库(.mp3) / 美图库(图片) / 事件库(.md) 不在仓库内（版权原因）。

使用者自备素材时，版权与合规责任由使用者承担。
插件自带的默认人格卡「小忆」为原创占位文本，不基于第三方作品角色。

## 四、AI 生成内容声明

套组本身不含模型权重，也不内置模型服务。机器人输出由使用者配置的模型生成，
不构成事实性主张或专业建议；数据流向见各组件仓库的 `PRIVACY.md`。

---

## 更新记录

- 2026-11-26：首次建立。汇总 `manifest.json` 中全部组件的许可证，
  标注 `@zaofan/dsh-qqbot` 为 AFL-3.0（本套组唯一非 MIT 组件），并说明本仓库自身无代码依赖。

*`manifest.json` 增删组件或调整版本时，请同步更新本文件第二节。*
