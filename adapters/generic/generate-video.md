# generate-video (generic portable)

工具无关的纯 markdown 提示词。

## 何时用
用户要"生成视频"（文生/图生）且走本项目 API。

## 前置
- 仓库 `~/skills-media-gen`，先 `bash ~/skills-media-gen/scripts/self-update.sh` 自检版本。
- 配置 `~/.media-gen/config.json`。

## 执行
```bash
# 文生视频
bash ~/skills-media-gen/scripts/run-media-task.sh video '{"text":"...","model":"kling-text2video","duration":5}'
# 图生视频
bash ~/skills-media-gen/scripts/run-media-task.sh video '{"text":"...","model":"kling-image2video","imageUrls":["https://..."]}'
```
脚本提交 `POST /v1/video-generations`、每 15 秒轮询 `GET /v1/video-generations/{taskId}`、下载到 `output_dir`，打印 `saved: <path>`。视频较慢，`poll.max_seconds` 建议 ≥ 600。
