---
name: generate-video
description: "通过 MidwayFlow OpenAPI 生成视频。先查 /v1/video-models 拉可用模型与每种 videoType 的能力限制，用 AskUserQuestion 引导用户选 videoType 和模型及配置；按所选类型收集参考素材（图/视频/音频，本地的自动转 base64 Data URI），全能参考模式用 @图片N/@视频N/@音频N 引用语法；选完提交 /v1/video-generations，异步轮询到终态，下载到本地。当用户要求“生成视频/做视频/文生视频/图生视频/全能参考”且走本项目 API 时调用。"
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
triggers:
  - 生成视频
  - 做一个视频
  - 文生视频
  - 图生视频
  - 视频生成
  - 全能参考
---

## When to invoke
用户要用本项目 API 生成视频时调用。涵盖 6 种 videoType，尤其是全能参考（图+视频+音频混合引用）。

## Instructions

### 1. 版本自检 + 拉取模型
```bash
bash ~/skills-media-gen/scripts/self-update.sh
bash ~/skills-media-gen/scripts/fetch-models.sh video
```
缓存到 `~/.media-gen/cache/video-models.json`，把 🆕/⚠️/✅ 对比结果告诉用户。

### 2. 选 videoType（关键：决定要收集什么素材）

videoType 决定素材类型和提示词写法。从 manifest.json 读能力表：
```bash
jq '.video_types | to_entries[] | {code:.key, name:.value.name, desc:.value.desc, fields:.value.fields, prompt:.value.prompt_syntax}' ~/skills-media-gen/manifest.json
```

6 种类型：
| code | 名称 | 需要素材 | 提示词写法 |
|---|---|---|---|
| 1 | 文生视频 | 无 | 普通描述 |
| 2 | 图生视频-首帧 | `imageUrls`[0]=首帧 | 普通描述 |
| 3 | 图生视频-首尾帧 | `imageUrls`[0]=首帧,[1]=尾帧 | 普通描述 |
| 4 | 多图参考 | `imageUrls`/`urls` 多张参考 | 普通描述 |
| 5 | **全能参考** | `imageUrls`+`videoUrls`+`audioUrls`+`elementIds` | **`@图片N`/`@视频N`/`@音频N` 引用** |
| 6 | 数字人 | `imageUrls`[0]=形象,`audioUrls`[0]=驱动音频 | 普通描述 |

用 **AskUserQuestion** 让用户选 videoType。注意：**不是所有模型都支持所有类型**，先看模型 `allowedVideoTypes` 有哪些 code，只在其中选。

> 模型 spec 的 `allowedVideoTypes` 只返回 code+name，每种类型的素材限制以上表为准（源自 manifest.json，已据后端代码梳理）。

### 3. 收集参考素材（按所选 videoType）

若 videoType 需要素材（2/3/4/5/6），向用户确认素材来源：本地文件路径 or URL。本地的转 Data URI（后端各字段都兼容 URL/Data URI/裸base64，统一用 Data URI 最稳）：

```bash
# 图片 -> 字符串数组, 塞 imageUrls
bash ~/skills-media-gen/scripts/image-to-datauri.sh --json ~/a.png ~/b.jpg
# 输出: ["data:image/png;base64,...","data:image/jpeg;base64,..."]

# 视频 -> 对象数组, 塞 videoUrls (可带 referType/keepOriginalSound, 默认 feature/yes)
bash ~/skills-media-gen/scripts/image-to-datauri.sh --json-obj ~/ref.mp4
# 输出: [{"videoUrl":"data:video/mp4;base64,..."}]

# 音频 -> 字符串数组, 塞 audioUrls
bash ~/skills-media-gen/scripts/image-to-datauri.sh --json ~/voice.mp3
```

URL 直接放进对应数组，不转换。

**全能参考(code 5)特别注意**：
- 素材分三类独立上传：`imageUrls`（图）、`videoUrls`（视频，对象数组）、`audioUrls`（音频）
- 提示词里用 `@图片N` 引用 imageUrls 第 N 个、`@视频N` 引用 videoUrls 第 N 个、`@音频N` 引用 audioUrls 第 N 个（N 从 1 起，顺序与数组一致）
- 也可用官方占位 `<<<image_N>>>` / `<<<video_N>>>` / `<<<element_N>>>`
- 例：`参考@图片1的男生和@图片2的女生，两人在校园里散步，镜头跟随` → imageUrls 放两张图
- 后端会校验引用序号不超数组长度，超了报错

### 4. 选模型与配置（AskUserQuestion）
从缓存读每个模型 spec，按所选 videoType 过滤出支持该类型的模型：
```bash
jq -r --argjson vt <所选code> '.data[] | select((.allowedVideoTypes//[]|map(.code)|index($vt))!=null) | {id, displayName, resolutions, ratios, videoDurationMin, videoDurationMax, videoDurationSuggest}' ~/.media-gen/cache/video-models.json
```
上次选择在 `~/.media-gen/cache/last-choice.json` 的 `.video`，作推荐项放第一位标"(上次)"。
用 **AskUserQuestion** 让用户选：
- 模型（已按 videoType 过滤）
- 分辨率、比例（从该模型 `resolutions`/`ratios` 取）
- duration（落在 `videoDurationMin`-`videoDurationMax`，参考 `videoDurationSuggest`）

### 5. 记住选择
写回 `~/.media-gen/cache/last-choice.json` 的 `.video`（先确保文件存在）：
```bash
[ -f ~/.media-gen/cache/last-choice.json ] || echo '{}' > ~/.media-gen/cache/last-choice.json
jq --argjson c '{"videoType":<code>,"model":"...","resolution":"...","ratio":"...","duration":M}' '.video=$c' ~/.media-gen/cache/last-choice.json > ~/.media-gen/cache/last-choice.tmp && mv ~/.media-gen/cache/last-choice.tmp ~/.media-gen/cache/last-choice.json
```

### 6. 组装 body 并提交（异步，不阻塞主任务）

body 字段（按 videoType 组合）：
- `text`：提示词（必填，全能参考含 @图片N 等引用）
- `model`：模型 id（必填）
- `videoType`：类型 code（必填，1-6）
- `resolution`、`ratio`、`duration`：可选
- `imageUrls`/`videoUrls`/`audioUrls`/`elementIds`/`multiPrompt`：按 videoType 选填

**重要**：视频生成很慢，**务必用拆分模式**：
```bash
# 6a. 提交（秒回 taskId）
bash ~/skills-media-gen/scripts/run-media-task.sh submit video '<body-json>'
# 6b. 后台轮询 + 下载（不阻塞）
bash ~/skills-media-gen/scripts/run-media-task.sh poll video <taskId> &
```

body 示例：
```json
// 文生视频
{"text":"海浪拍打礁石","model":"kling-text2video","videoType":1,"duration":5}
// 图生视频(首帧)
{"text":"镜头缓慢推进","model":"kling-image2video","videoType":2,"duration":5,"imageUrls":["data:image/png;base64,..."]}
// 全能参考: 两张图引用
{"text":"参考@图片1的男生和@图片2的女生，并肩散步","model":"kling-omni-video","videoType":5,"duration":5,"imageUrls":["data:...","data:..."]}
// 全能参考: 图+视频+音频
{"text":"@图片1的人物跟随@视频1的动作，配@音频1的背景音","model":"kling-omni-video","videoType":5,"imageUrls":["data:..."],"videoUrls":[{"videoUrl":"data:..."}],"audioUrls":["data:..."]}
```

- `submit` 立即返回 `taskId=...`
- `poll` 每 15 秒查一次到 `success`/`failed`，下载到 `output_dir`，打印 `saved: <path>`
- `poll.max_seconds` 建议 ≥ 600；推荐用 Agent 工具起子 agent 跑 `poll`

### 7. 回报
把 `saved:` 路径给用户；失败返回 `errorMessage`。接口规格见 `~/skills-media-gen/manifest.json`。
