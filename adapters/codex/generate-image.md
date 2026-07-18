---
name: generate-image
description: 通过 MidwayFlow OpenAPI 生成图片，先拉模型对比更新/下架，交互选模型与配置，提交后 15 秒轮询，下载到本地。
---

# generate-image (Codex)

## 流程
1. `bash ~/skills-media-gen/scripts/self-update.sh`
2. `bash ~/skills-media-gen/scripts/fetch-models.sh image` —— 拉 `/v1/image-models`，缓存并对比 🆕 新增 / ⚠️ 下架 / ✅ 仍在，把结果给用户看。
3. 交互选模型 + resolution + ratio + count：
   ```bash
   bash ~/skills-media-gen/scripts/choose-and-run.sh image '<提示词>'
   ```
   脚本会列模型、显示每个模型支持的配置、记住上次选择（`~/.media-gen/cache/last-choice.json`）作默认、组装 body、提交 `POST /v1/image-generations`、每 15 秒轮询 `GET /v1/image-generations/{taskId}`、下载到 `output_dir`。
4. 把脚本输出的 `saved:` 路径回报给用户。

接口规格见 `@~/skills-media-gen/manifest.json`。
