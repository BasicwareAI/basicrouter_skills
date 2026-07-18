# generate-video (Hermes / portable)

> Hermes 专用适配待确认；当前 portable markdown。

## 流程
1. `bash ~/skills-media-gen/scripts/self-update.sh`
2. `bash ~/skills-media-gen/scripts/fetch-models.sh video` —— 拉 `/v1/video-models`，缓存并对比 🆕/⚠️/✅。
3. 交互选模型 + videoType + resolution + ratio + duration：
   ```bash
   bash ~/skills-media-gen/scripts/choose-and-run.sh video '<提示词>'
   ```
   脚本显示各模型支持配置，记住上次选择作默认，组装 body，提交 `POST /v1/video-generations`，每 15 秒轮询 `GET /v1/video-generations/{taskId}`，下载到 `output_dir`。图生视频补 `imageUrls`。
4. 回报 `saved:` 路径。

`poll.max_seconds` 建议 ≥ 600。接口规格见 `~/skills-media-gen/manifest.json`。
