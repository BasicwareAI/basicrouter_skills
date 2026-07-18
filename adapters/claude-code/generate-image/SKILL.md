---
name: generate-image
description: "通过 MidwayFlow OpenAPI 生成图片。先查 /v1/image-models 拉可用模型与配置并对比更新/下架，用 AskUserQuestion 引导用户选模型和 resolution/ratio/count，如需参考图则收集本地图片或 URL（本地图自动转 base64 Data URI），选完提交 /v1/image-generations，每 15 秒轮询到终态，下载到本地。当用户要求“生成图片/画图/出图/图生图/参考图改图”且走本项目 API 时调用。"
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
triggers:
  - 生成图片
  - 画一张图
  - 生成一张图片
  - 出图
  - 图生图
  - 参考图
  - 改图
---

## When to invoke
用户要用本项目（MidwayFlow）API 生成图片时调用。包含文生图和图生图（带参考图）。

## Instructions

### 1. 版本自检 + 拉取模型（对比更新/下架）
```bash
bash ~/skills-media-gen/scripts/self-update.sh
bash ~/skills-media-gen/scripts/fetch-models.sh image
```
`fetch-models.sh` 会把 `/v1/image-models` 缓存到 `~/.media-gen/cache/image-models.json`，并与上次对比打印 🆕 新增 / ⚠️ 下架 / ✅ 仍在。把这一段对比结果告诉用户。

### 2. 判断是否需要参考图（图生图）

**先看用户意图**：
- 用户只描述了要画什么 → **文生图**，不传 `imageUrls`
- 用户提到"参考这张图"、"基于这张图改"、"图生图"、上传/拖入了图片 → **图生图**，需收集参考图

如果是图生图，向用户确认参考图来源（用 AskUserQuestion 或直接问）：
- **本地图片**：问用户要本地路径（如 `~/Desktop/cat.png`、`/path/to/img.jpg`）。可多个。
- **网络图片**：要 HTTP/HTTPS URL。

收集到本地路径后，转成 Data URI（后端 `imageUrls` 兼容 URL / data URI / 裸 base64，统一用 data URI 最稳）：
```bash
# 单张或多张本地图 -> JSON 数组，可直接塞 imageUrls
bash ~/skills-media-gen/scripts/image-to-datauri.sh --json ~/path/to/a.png ~/path/to/b.jpg
# 输出: ["data:image/png;base64,...","data:image/jpeg;base64,..."]
```
URL 则直接放进数组，不转换。

> 注意多图参考：单张走标准图生图；多张（通常 2+）后端走 multi-image2image。具体上限以模型为准，不确定就先问用户要几张。

### 3. 选模型（AskUserQuestion）
从缓存读模型列表与每个模型支持的配置：
```bash
jq -r '.data[] | {id, displayName, description, resolutions, ratios, maxCount}' ~/.media-gen/cache/image-models.json
```
上次选择在 `~/.media-gen/cache/last-choice.json`（`.image.model` 等），把它作为推荐项放在选项第一位并标注"(上次)"。
用 **AskUserQuestion** 让用户选：
- 模型（header `模型`）——注意：不是所有模型都支持图生图，可优先选支持参考图的（如 nano banana、seedream、kling 系列）
- 分辨率（从该模型 `resolutions` 取）
- 比例（从该模型 `ratios` 取）
- 数量（≤ `maxCount`，可省略）

### 4. 记住选择
把用户选的写回 `~/.media-gen/cache/last-choice.json` 的 `.image`：
```bash
# 先确保文件存在且有 .image 结构
[ -f ~/.media-gen/cache/last-choice.json ] || echo '{}' > ~/.media-gen/cache/last-choice.json
jq --argjson c '{"model":"...","resolution":"...","ratio":"...","count":N}' '.image=$c' ~/.media-gen/cache/last-choice.json > ~/.media-gen/cache/last-choice.tmp && mv ~/.media-gen/cache/last-choice.tmp ~/.media-gen/cache/last-choice.json
```

### 5. 组装 body 并提交（异步，不阻塞主任务）

body 字段：
- `text`：提示词（必填）
- `model`：选的模型 id（必填）
- `resolution`、`ratio`、`count`：可选
- `imageUrls`：**参考图数组**（图生图才加）——元素是 URL 或 Data URI（第 2 步生成的）

**重要**：图片生成耗时几十秒到几分钟，同步轮询会卡住主任务。用**拆分模式**：
```bash
# 5a. 提交（秒回 taskId）
bash ~/skills-media-gen/scripts/run-media-task.sh submit image '<body-json>'
# 输出: taskId=2af008d2-...

# 5b. 后台轮询 + 下载（不阻塞，完成后通知）
bash ~/skills-media-gen/scripts/run-media-task.sh poll image <taskId> &
```

文生图 body 示例：
```json
{"text":"赛博朋克城市","model":"seedream-5.0","resolution":"2k","ratio":"16:9","count":1}
```
图生图 body 示例（imageUrls 是第 2 步的 Data URI 数组）：
```json
{"text":"改成水彩风格","model":"nano banana pro","resolution":"2k","ratio":"1:1","imageUrls":["data:image/jpeg;base64,..."]}
```

- `submit` 只提交，立即返回 `taskId=...`
- `poll` 每 15 秒查一次到 `success`/`failed`，下载图片到 `output_dir`，打印 `saved: <path>`
- 也可用 Agent 工具起子 agent 跑 `poll`，主任务继续

### 6. 回报
把 `saved:` 本地路径给用户；失败把 `errorMessage` 原样返回。接口规格见 `~/skills-media-gen/manifest.json`。
