# generate-video

通过 MidwayFlow OpenAPI 提交视频生成任务，轮询结果，下载到本地。

## 接口（来自 manifest.json）
- 提交：`POST /v1/video-generations`，body `{text, model, videoType?, resolution?, ratio?, duration?, imageUrls?}`
- 查询：`GET /v1/video-generations/{taskId}`，返回含 `status` 与结果 URL
- 终态：`status ∈ {success, failed}`

## 步骤
1. 读 `~/.media-gen/config.json`。
2. 调用前先 `bash scripts/self-update.sh` 自检版本。
3. `POST` 提交，取 `data.taskId`。
4. 每 15 秒 `GET` 查询一次，直到终态或超时。
5. `success` → 下载视频到 `output_dir`；`failed` → 打印错误退出。
6. 输出本地文件路径。

## 说明
- 视频生成较慢，`poll.max_seconds` 建议设到 600 以上。
- 图生视频时把参考图 URL 放进 `imageUrls`。
