---
name: generate-image
description: "通过 MidwayFlow OpenAPI 生成图片。先查 /v1/image-models 拉可用模型与配置并对比更新/下架，用 AskUserQuestion 引导用户选模型和 resolution/ratio/count，选完提交 /v1/image-generations，每 15 秒轮询 /v1/image-generations/{taskId}，下载到本地。当用户要求“生成图片/画图/出图”且走本项目 API 时调用。"
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
triggers:
  - 生成图片
  - 画一张图
  - 生成一张图片
  - 出图
---

## When to invoke
用户要用本项目（MidwayFlow）API 生成图片时调用。

## Instructions

### 1. 版本自检 + 拉取模型（对比更新/下架）
```bash
bash ~/skills-media-gen/scripts/self-update.sh
bash ~/skills-media-gen/scripts/fetch-models.sh image
```
`fetch-models.sh` 会把 `/v1/image-models` 缓存到 `~/.media-gen/cache/image-models.json`，并与上次对比打印 🆕 新增 / ⚠️ 下架 / ✅ 仍在。把这一段对比结果告诉用户。最后一行以 `JSON:` 开头是模型摘要。

### 2. 选模型（AskUserQuestion）
从缓存读模型列表与每个模型支持的配置：
```bash
jq -r '.data[] | {id, displayName, description, resolutions, ratios, maxCount}' ~/.media-gen/cache/image-models.json
```
上次选择在 `~/.media-gen/cache/last-choice.json`（`.image.model` 等），把它作为推荐项放在选项第一位并标注"(上次)"。
用 **AskUserQuestion** 让用户选：
- 模型（header `模型`）
- 分辨率（从该模型 `resolutions` 取）
- 比例（从该模型 `ratios` 取）
- 数量（≤ `maxCount`，可省略）

### 3. 记住选择
把用户选的写回 `~/.media-gen/cache/last-choice.json` 的 `.image`：
```bash
jq --argjson c '{"model":"...","resolution":"...","ratio":"...","count":N}' '.image=$c' ~/.media-gen/cache/last-choice.json
```

### 4. 提交 + 轮询 + 下载
```bash
bash ~/skills-media-gen/scripts/run-media-task.sh image '<body-json>'
```
body = `{"text":<提示词>,"model":<选的模型>,"resolution"?,"ratio"?,"count"?}`。脚本每 15 秒轮询到 `success`/`failed`，下载图片到 `output_dir`，打印 `saved: <path>`。

### 5. 回报
把 `saved:` 本地路径给用户；失败把 `errorMessage` 原样返回。接口规格见 `~/skills-media-gen/manifest.json`。
