# 贡献指南

感谢你有兴趣为 BnnBot 套组做贡献。这是一个「部署总入口」仓库，改动大多是文档、安装脚本和清单，不需要复杂的开发环境。

## 这个仓库是干什么的

- `install.sh` —— 一键安装（把三个组件装到正确位置）
- `verify.sh` —— 只读验收（装完跑一遍确认没漏）
- `manifest.json` —— 组件清单（机器可读，版本号唯一真相）
- `docs/` —— 六篇自包含文档（环境 / 安装 / 配置 / 平台 / 验收 / 排障）
- `PROMPT.txt` —— 一行指令（给 AI 助手看）

**它不含业务代码**：插件逻辑在 `dsh-bnnbotbox`，群聊玩法在 `dsh-qqbot-bnn-custom`。

## 改完必做三件事

1. **改版本号走 `scripts/sync-version.mjs`**，不要手改每个文件。
2. **跑发版检查**，确认没有遗漏的下载链接和版本引用。
3. **发 Release 时带上附件**（install.sh / INSTALL.md / verify.sh / PROMPT.txt / manifest.json），并在此文件 CHANGELOG.md 记录。

## 提交规范

- 提交信息用中文，格式 `type(scope): 描述`，type 见下：
  - `feat` 新功能 / `fix` 修复 / `docs` 文档 / `chore` 杂务（版本号、清单同步）

## 行为准则

- 不提交任何凭据、openid、真实群号、个人昵称。
- 素材（角色卡、曲库、图片）不随仓库分发。
- 别把「某个部署的专属配置」写进通用脚本。
