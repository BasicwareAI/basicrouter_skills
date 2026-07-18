---
name: generate-image
description: 通过 MidwayFlow OpenAPI 生成图片，15 秒轮询，下载到本地。
---

# generate-image (Codex)

当用户要求生成图片且走本项目 API 时执行。

## 步骤
1. `bash ~/skills-media-gen/scripts/self-update.sh`
2. 确认 `~/.media-gen/config.json` 存在。
3. 列模型：`bash ~/skills-media-gen/scripts/list-models.sh image`
4. 组装 body `{text, model, resolution?, ratio?, count?}` 并执行：
   ```bash
   bash ~/skills-media-gen/scripts/run-media-task.sh image '<body>'
   ```
5. 把脚本输出的 `saved:` 路径回报给用户。

接口：`POST /v1/image-generations` → `GET /v1/image-generations/{taskId}`，详见 `@~/skills-media-gen/manifest.json`。
