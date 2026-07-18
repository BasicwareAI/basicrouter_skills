# generate-video (Hermes / portable)

> Hermes 专用适配待确认；当前为 portable markdown。

## 触发
用户要求"生成视频/文生视频/图生视频"且走本项目 API。

## 流程
1. `bash ~/skills-media-gen/scripts/self-update.sh`
2. 确认 `~/.media-gen/config.json`。
3. `bash ~/skills-media-gen/scripts/list-models.sh video` 列可用模型。
4. body：`{"text": ..., "model": ..., "videoType"?, "resolution"?, "ratio"?, "duration"?, "imageUrls"?}`（图生视频填 `imageUrls`）。
5. `bash ~/skills-media-gen/scripts/run-media-task.sh video '<body>'`
6. 回报 `saved:` 路径。

接口：`POST /v1/video-generations`，`GET /v1/video-generations/{taskId}`，15 秒轮询，建议 `max_seconds ≥ 600`。详见 `~/skills-media-gen/manifest.json`。
