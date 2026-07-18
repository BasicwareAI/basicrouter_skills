# generate-image (generic portable)

工具无关的纯 markdown 提示词。任何能加载 markdown 系统提示的 agent 工具均可使用。

## 何时用
用户要"生成图片"且走本项目（MidwayFlow）API。

## 前置
- 仓库：`~/skills-media-gen`，版本：见 `VERSION` / `manifest.json`。
- 配置：`~/.media-gen/config.json`（从 `config.example.json` 复制）。
- 自检：先跑 `bash ~/skills-media-gen/scripts/self-update.sh`。

## 执行
```bash
bash ~/skills-media-gen/scripts/run-media-task.sh image '{"text":"...","model":"kling-omni-image"}'
```
脚本会提交 `POST /v1/image-generations`、每 15 秒轮询 `GET /v1/image-generations/{taskId}`、下载到 `output_dir`，打印 `saved: <path>`。把这个路径回报给用户。
