---
name: generate-video
description: 通过 MidwayFlow OpenAPI 生成视频，15 秒轮询，下载到本地。
---

# generate-video (Codex)

当用户要求生成视频（文生/图生）且走本项目 API 时执行。

## 步骤
1. `bash ~/skills-media-gen/scripts/self-update.sh`
2. 确认 `~/.media-gen/config.json` 存在。
3. 列模型：`bash ~/skills-media-gen/scripts/list-models.sh video`
4. 组装 body `{text, model, videoType?, resolution?, ratio?, duration?, imageUrls?}` 并执行：
   ```bash
   bash ~/skills-media-gen/scripts/run-media-task.sh video '<body>'
   ```
5. 把脚本输出的 `saved:` 路径回报给用户。

接口：`POST /v1/video-generations` → `GET /v1/video-generations/{taskId}`，轮询间隔 15 秒，建议 `max_seconds ≥ 600`。详见 `@~/skills-media-gen/manifest.json`。
