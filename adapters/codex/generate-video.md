---
name: generate-video
description: 通过 MidwayFlow OpenAPI 生成视频，先拉模型对比更新/下架，交互选模型与配置，提交后 15 秒轮询，下载到本地。
---

# generate-video (Codex)

## 流程
1. `bash ~/skills-media-gen/scripts/self-update.sh`
2. `bash ~/skills-media-gen/scripts/fetch-models.sh video` —— 拉 `/v1/video-models`，缓存并对比 🆕/⚠️/✅，给用户看。
3. 交互选模型 + videoType + resolution + ratio + duration：
   ```bash
   bash ~/skills-media-gen/scripts/choose-and-run.sh video '<提示词>'
   ```
   脚本显示每个模型支持的配置，记住上次选择作默认，组装 body，提交 `POST /v1/video-generations`，每 15 秒轮询 `GET /v1/video-generations/{taskId}`，下载到 `output_dir`。图生视频在交互后补 `imageUrls`。
4. 把 `saved:` 路径回报给用户。

视频较慢，`poll.max_seconds` 建议 ≥ 600。接口规格见 `@~/skills-media-gen/manifest.json`。
