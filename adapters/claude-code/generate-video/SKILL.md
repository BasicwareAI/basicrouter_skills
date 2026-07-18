---
name: generate-video
description: "通过 MidwayFlow OpenAPI 生成视频。先查 /v1/video-models 拉可用模型与配置并对比更新/下架，用 AskUserQuestion 引导用户选模型和 videoType/resolution/ratio/duration，选完提交 /v1/video-generations，每 15 秒轮询 /v1/video-generations/{taskId}，下载到本地。当用户要求“生成视频/做视频/文生视频/图生视频”且走本项目 API 时调用。"
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
triggers:
  - 生成视频
  - 做一个视频
  - 文生视频
  - 图生视频
---

## When to invoke
用户要用本项目 API 生成视频（文生/图生）时调用。

## Instructions

### 1. 版本自检 + 拉取模型（对比更新/下架）
```bash
bash ~/skills-media-gen/scripts/self-update.sh
bash ~/skills-media-gen/scripts/fetch-models.sh video
```
打印的 🆕/⚠️/✅ 对比结果告诉用户。缓存落在 `~/.media-gen/cache/video-models.json`。

### 2. 选模型与配置（AskUserQuestion）
从缓存读每个模型 spec：
```bash
jq -r '.data[] | {id, displayName, description, allowedVideoTypes, resolutions, ratios, videoDurationMin, videoDurationMax, videoDurationSuggest}' ~/.media-gen/cache/video-models.json
```
上次选择在 `~/.media-gen/cache/last-choice.json` 的 `.video`，作为推荐项放第一位标"(上次)"。
用 **AskUserQuestion** 让用户选：
- 模型（header `模型`）
- videoType（从 `allowedVideoTypes` 的 `code`/`name` 取）
- 分辨率、比例（从该模型 `resolutions`/`ratios` 取）
- duration（落在 `videoDurationMin`-`videoDurationMax`，参考 `videoDurationSuggest`）

### 3. 记住选择
写回 `~/.media-gen/cache/last-choice.json` 的 `.video`。

### 4. 提交 + 轮询 + 下载
```bash
bash ~/skills-media-gen/scripts/run-media-task.sh video '<body-json>'
```
body = `{"text":<提示词>,"model":<模型>,"videoType"?,"resolution"?,"ratio"?,"duration"?,"imageUrls"?}`（图生视频把参考图 URL 放 `imageUrls`）。脚本每 15 秒轮询，建议 `poll.max_seconds ≥ 600`。

### 5. 回报
把 `saved:` 路径给用户；失败返回 `errorMessage`。
