---
name: generate-video
description: "通过 MidwayFlow OpenAPI 生成视频：提交 /v1/video-generations，每 15 秒轮询 /v1/video-generations/{taskId}，下载到本地。当用户要求“生成视频/做视频/文生视频/图生视频”且要走本项目 API 时调用。"
allowed-tools:
  - Bash
  - Read
triggers:
  - 生成视频
  - 做一个视频
  - 文生视频
  - 图生视频
---

## When to invoke
用户要用本项目 API 生成视频时调用。`POST /v1/video-generations` 提交，`GET /v1/video-generations/{taskId}` 轮询。

## Preamble（每次调用先跑）
```bash
bash ~/skills-media-gen/scripts/self-update.sh
```

## Instructions
1. 确认 `~/.media-gen/config.json` 存在。
2. 用 `bash ~/skills-media-gen/scripts/list-models.sh video` 确认模型名。
3. 组装 body：`{"text": <提示词>, "model": <模型>, "videoType"?, "resolution"?, "ratio"?, "duration"?, "imageUrls"?}`（图生视频把参考图 URL 放 `imageUrls`）。参考 [src/generate-video.md](../../../src/generate-video.md)。
4. 执行：
   ```bash
   bash ~/skills-media-gen/scripts/run-media-task.sh video '<body-json>'
   ```
5. 视频生成较慢，`poll.max_seconds` 建议 ≥ 600。脚本每 15 秒轮询一次，完成后下载到 `output_dir`。
6. 把保存的本地路径回报给用户。失败返回 `errorMessage`。
