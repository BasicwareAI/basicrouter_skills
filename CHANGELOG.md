# Changelog

## 0.3.0 — 2026-07-18
- 视频新增 6 种 videoType 能力表(manifest.json video_types), 每种类型的素材字段/限制写清
- 全能参考(code 5): imageUrls/videoUrls/audioUrls 分开上传, 提示词用 @图片N/@视频N/@音频N 引用
- image-to-datauri.sh 扩展: 支持视频/音频文件, 新增 --json-obj 输出对象数组(供 videoUrls)
- generate-video SKILL.md 重写: videoType 选择流程 + 全能参考引用语法 + 素材收集
- manifest 更新模型清单(下架 kling-omni-image 等), submit_body 补全 video 全字段

## 0.2.0 — 2026-07-18
- 新增 `scripts/fetch-models.sh`：调 `/v1/image-models`、`/v1/video-models` 拉取并缓存到 `~/.media-gen/cache/`，与上次对比打印 🆕 新增 / ⚠️ 下架 / ✅ 仍在。
- 新增 `scripts/choose-and-run.sh`：终端交互引导选模型 + 该模型支持的 resolution/ratio/count(videoType/duration)，记住上次选择作默认，组装 body 后提交 + 轮询 + 下载。
- Claude Code 适配层改走 AskUserQuestion 引导；Codex/Hermes/generic 走 `choose-and-run.sh` 终端交互。
- 流程改为：自检 → 拉模型对比 → 选模型与配置 → 提交 → 15s 轮询 → 下载。

## 0.1.0 — 2026-07-18
- Initial scaffolding: generate-image, generate-video skills.
- Adapters: claude-code, codex, hermes (portable), generic.
- Self-update via `scripts/self-update.sh` (compares remote VERSION).
- Config-driven endpoints (`~/.media-gen/config.json`), 15s poll.
