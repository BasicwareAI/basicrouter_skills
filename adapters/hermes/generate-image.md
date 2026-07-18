# generate-image (Hermes / portable)

> Hermes 专用适配待确认；当前为 portable markdown，大多数 agent 工具可直接作为系统提示加载。

## 触发
用户要求"生成图片/画图"且走本项目（MidwayFlow）API。

## 流程
1. `bash ~/skills-media-gen/scripts/self-update.sh`（版本自检，非阻塞）
2. 确认 `~/.media-gen/config.json`，没有就 `cp ~/skills-media-gen/config.example.json ~/.media-gen/config.json` 并填写。
3. `bash ~/skills-media-gen/scripts/list-models.sh image` 列可用模型。
4. body：`{"text": ..., "model": ..., "resolution"?, "ratio"?, "count"?}`
5. `bash ~/skills-media-gen/scripts/run-media-task.sh image '<body>'`
6. 回报脚本输出的 `saved:` 路径。

接口：`POST /v1/image-generations`，`GET /v1/image-generations/{taskId}`，15 秒轮询。详见 `~/skills-media-gen/manifest.json`。
