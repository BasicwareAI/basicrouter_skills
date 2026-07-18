---
name: generate-video
description: "通过 MidwayFlow OpenAPI 生成视频。先查 /v1/video-models 拉可用模型与配置并对比更新/下架，用 AskUserQuestion 引导用户选模型和 videoType/resolution/ratio/duration，如需参考图（图生视频）则收集本地图片或 URL（本地图自动转 base64 Data URI），选完提交 /v1/video-generations，异步轮询到终态，下载到本地。当用户要求“生成视频/做视频/文生视频/图生视频”且走本项目 API 时调用。"
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
triggers:
  - 生成视频
  - 做一个视频
  - 文生视频
  - 图生视频
  - 视频生成
---

## When to invoke
用户要用本项目 API 生成视频时调用。包含文生视频和图生视频（带参考图）。

## Instructions

### 1. 版本自检 + 拉取模型（对比更新/下架）
```bash
bash ~/skills-media-gen/scripts/self-update.sh
bash ~/skills-media-gen/scripts/fetch-models.sh video
```
`fetch-models.sh` 会把 `/v1/video-models` 缓存到 `~/.media-gen/cache/video-models.json`，并与上次对比打印 🆕/⚠️/✅，把结果告诉用户。

### 2. 判断是否需要参考图（图生视频）

**先看用户意图**：
- 用户描述了要生成的画面 → **文生视频**，不传 `imageUrls`
- 用户提到"把这张图变成视频"、"基于这张图"、"图生视频"、上传/拖入了图片 → **图生视频**，需收集参考图（通常 1 张首帧）

如果是图生视频，向用户确认参考图来源：
- **本地图片**：要本地路径，转 Data URI：
  ```bash
  bash ~/skills-media-gen/scripts/image-to-datauri.sh --json ~/path/to/first-frame.png
  # 输出: ["data:image/png;base64,..."]
  ```
- **网络图片**：直接用 URL，放进 `imageUrls` 数组。

### 3. 选模型与配置（AskUserQuestion）
从缓存读每个模型 spec：
```bash
jq -r '.data[] | {id, displayName, description, allowedVideoTypes, resolutions, ratios, videoDurationMin, videoDurationMax, videoDurationSuggest}' ~/.media-gen/cache/video-models.json
```
上次选择在 `~/.media-gen/cache/last-choice.json` 的 `.video`，作为推荐项放第一位标"(上次)"。
用 **AskUserQuestion** 让用户选：
- 模型（header `模型`）——文生视频选 text2video 类；图生视频选 image2video 类
- videoType（从 `allowedVideoTypes` 的 `code`/`name` 取）
- 分辨率、比例（从该模型 `resolutions`/`ratios` 取）
- duration（落在 `videoDurationMin`-`videoDurationMax`，参考 `videoDurationSuggest`）

### 4. 记住选择
写回 `~/.media-gen/cache/last-choice.json` 的 `.video`（先确保文件存在）：
```bash
[ -f ~/.media-gen/cache/last-choice.json ] || echo '{}' > ~/.media-gen/cache/last-choice.json
jq --argjson c '{"model":"...","videoType":N,"resolution":"...","ratio":"...","duration":M}' '.video=$c' ~/.media-gen/cache/last-choice.json > ~/.media-gen/cache/last-choice.tmp && mv ~/.media-gen/cache/last-choice.tmp ~/.media-gen/cache/last-choice.json
```

### 5. 组装 body 并提交（异步，不阻塞主任务）

body 字段：
- `text`：提示词（必填）
- `model`：选的模型 id（必填）
- `videoType`、`resolution`、`ratio`、`duration`：可选
- `imageUrls`：**参考图数组**（图生视频才加）——URL 或 Data URI（第 2 步生成）

**重要**：视频生成很慢（几分钟到十几分钟），**务必用拆分模式**，别让主任务卡死：
```bash
# 5a. 提交（秒回 taskId）
bash ~/skills-media-gen/scripts/run-media-task.sh submit video '<body-json>'
# 输出: taskId=...

# 5b. 后台轮询 + 下载（不阻塞）
bash ~/skills-media-gen/scripts/run-media-task.sh poll video <taskId> &
```

文生视频 body 示例：
```json
{"text":"海浪拍打礁石","model":"kling-text2video","duration":5}
```
图生视频 body 示例：
```json
{"text":"镜头缓慢推进","model":"kling-image2video","duration":5,"imageUrls":["data:image/png;base64,..."]}
```

- `submit` 立即返回 `taskId=...`
- `poll` 每 15 秒查一次到 `success`/`failed`，下载到 `output_dir`，打印 `saved: <path>`
- `poll.max_seconds` 建议 ≥ 600；推荐用 Agent 工具起子 agent 跑 `poll`

### 6. 回报
把 `saved:` 路径给用户；失败返回 `errorMessage`。
