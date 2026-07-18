# generate-image (generic portable)

工具无关纯 markdown 提示词。

## 流程
1. `bash ~/skills-media-gen/scripts/self-update.sh`（版本自检）
2. `bash ~/skills-media-gen/scripts/fetch-models.sh image` —— 拉 `/v1/image-models`，缓存到 `~/.media-gen/cache/image-models.json`，对比上次打印 🆕 新增 / ⚠️ 下架 / ✅ 仍在。
3. 交互引导（终端 read）：
   ```bash
   bash ~/skills-media-gen/scripts/choose-and-run.sh image '<提示词>'
   ```
   脚本列模型、显示每个模型支持的 resolution/ratio/count、以 `~/.media-gen/cache/last-choice.json` 上次选择作默认、组装 body、提交 `POST /v1/image-generations`、每 15 秒轮询 `GET /v1/image-generations/{taskId}`、下载到 `output_dir`。
4. 把脚本输出的 `saved:` 路径回报给用户。

接口规格见 `~/skills-media-gen/manifest.json`。
