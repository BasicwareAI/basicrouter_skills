---
name: generate-image
description: "通过 MidwayFlow OpenAPI 生成图片：提交 /v1/image-generations，每 15 秒轮询 /v1/image-generations/{taskId}，下载到本地。当用户要求“生成图片/画图/出图”且要走本项目 API 时调用。"
allowed-tools:
  - Bash
  - Read
triggers:
  - 生成图片
  - 画一张图
  - 生成一张图片
  - 出图
---

## When to invoke
用户要用本项目（MidwayFlow）API 生成图片时调用。走 `POST /v1/image-generations` 提交，`GET /v1/image-generations/{taskId}` 轮询。

## Preamble（每次调用先跑）
```bash
bash ~/skills-media-gen/scripts/self-update.sh   # 版本自检，非阻塞
```

## Instructions
1. 确认 `~/.media-gen/config.json` 存在；不存在提示用户 `cp ~/skills-media-gen/config.example.json ~/.media-gen/config.json` 并填写。
2. 用 `bash ~/skills-media-gen/scripts/list-models.sh image` 确认模型名（用户没指定模型时列出可选）。
3. 组装 body：`{"text": <提示词>, "model": <模型>, "resolution"?, "ratio"?, "count"?}`（参考 [src/generate-image.md](../../../src/generate-image.md) 与 [manifest.json](../../../manifest.json)）。
4. 执行：
   ```bash
   bash ~/skills-media-gen/scripts/run-media-task.sh image '<body-json>'
   ```
5. 脚本会自动每 15 秒轮询到终态，下载图片到 `output_dir`，打印 `saved: <path>`。
6. 把保存的本地路径回报给用户。失败时把 `errorMessage` 原样返回。
