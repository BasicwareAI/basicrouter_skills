# skills-media-gen

跨工具（Claude Code / Codex / Hermes / 通用 agent）的图片与视频生成 skill 包，调用 MidwayFlow OpenAPI，结果轮询后下载到本地。带 git 版本自检与模型清单。

## 接口
- 图片：`POST /v1/image-generations` 提交 → `GET /v1/image-generations/{taskId}` 轮询
- 视频：`POST /v1/video-generations` 提交 → `GET /v1/video-generations/{taskId}` 轮询
- 轮询间隔 **15 秒**，终态 `success` / `failed`

## 安装
```bash
bash install.sh all      # 软链到 ~/.claude/skills、~/.codex/prompts、~/.hermes/skills
# 或单装一种：bash install.sh claude | codex | hermes
```
首次安装会在 `~/.media-gen/config.json` 生成占位配置，请填写 `base_url` 和 `auth.value`。

## 配置（~/.media-gen/config.json）
见 [config.example.json](config.example.json)：base_url、auth header、端点路径、轮询参数、输出目录。

## 用法
完整流程：**自检更新 → 拉模型并对比更新/下架 → 选模型与配置 → 提交 → 15s 轮询 → 下载**。

- 拉模型 + 对比更新/下架：`bash scripts/fetch-models.sh image|video`（缓存到 `~/.media-gen/cache/`，与上次 diff）
- 交互选模型并生成（终端 read，Codex/Hermes/generic 用）：
  ```bash
  bash scripts/choose-and-run.sh image '一只戴墨镜的猫'
  bash scripts/choose-and-run.sh video '海浪拍打礁石'
  ```
  会列模型、显示每个模型支持的配置、以 `~/.media-gen/cache/last-choice.json` 上次选择作默认、组装 body、提交 + 轮询 + 下载。
- Claude Code 直接说"生成图片/视频"，skill 会用 AskUserQuestion 引导选模型与配置。
- 手动直接提交：`bash scripts/run-media-task.sh image|video '<body-json>'`
- 旧的本地清单：`bash scripts/list-models.sh image|video`（读 manifest，加 `--remote` 从 API 拉）

## 版本与更新
- 版本号在 [VERSION](VERSION) 与 [manifest.json](manifest.json)。
- skill 每次调用前跑 `scripts/self-update.sh`：`git fetch` 后比较远端 `VERSION`，不一致在 stderr 提示 `git pull` 升级（非阻塞）。
- 新增/更新模型：改 `manifest.json` 的 `models` + bump `VERSION` + 记 [CHANGELOG.md](CHANGELOG.md)，提交推送，所有用户下次调用自动感知。
- 推送到 GitHub：`git remote add origin <url> && git push -u origin main`。

## 适配层
| 工具 | 目录 | 落地位置 |
|---|---|---|
| Claude Code | adapters/claude-code/ | ~/.claude/skills/ |
| Codex CLI | adapters/codex/ | ~/.codex/prompts/ |
| Hermes | adapters/hermes/ | ~/.hermes/skills/ （portable，待确认） |
| 通用 | adapters/generic/ | 自行 copy |

## 依赖
`curl`、`jq`、`git`。
