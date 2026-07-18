# generate-image

通过 MidwayFlow OpenAPI 提交图片生成任务，轮询结果，下载到本地。

## 接口（来自 manifest.json）
- 提交：`POST /v1/image-generations`，body `{text, model, resolution?, ratio?, count?}`
- 查询：`GET /v1/image-generations/{taskId}`，返回 `{taskId, status, images[], errorMessage}`
- 终态：`status ∈ {success, failed}`

## 步骤
1. 读 `~/.media-gen/config.json`（不存在则报错并指向 `config.example.json`）。
2. 调用前先 `bash scripts/self-update.sh` 自检版本（非阻塞）。
3. `POST` 提交，取 `data.taskId`。
4. 每 15 秒 `GET` 查询一次，直到 `status` 为终态或超过 `poll.max_seconds`。
5. `status=success` → 下载 `images[]` 到 `output_dir`（按时间戳命名）；`status=failed` → 打印 `errorMessage` 退出。
6. 输出本地文件路径列表。

## 调用示例
```bash
curl -s -X POST "$BASE/v1/image-generations" \
  -H "$AUTH_HEADER: $AUTH_VALUE" -H "Content-Type: application/json" \
  -d '{"text":"一只戴墨镜的猫","model":"kling-omni-image","resolution":"1080P","ratio":"1:1"}'
```
