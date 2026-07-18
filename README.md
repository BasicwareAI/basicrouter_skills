# skills-media-gen

跨工具（Claude Code / Codex / Hermes / 通用 agent）的**图片与视频生成 skill 包**，调用 MidwayFlow OpenAPI，结果轮询后下载到本地。带 git 版本自检、模型清单与下架对比。

- 图片：`POST /v1/image-generations` 提交 → `GET /v1/image-generations/{taskId}` 轮询
- 视频：`POST /v1/video-generations` 提交 → `GET /v1/video-generations/{taskId}` 轮询
- 轮询间隔 **15 秒**，终态 `success` / `failed`

完整调用流程：**版本自检 → 拉模型并对比更新/下架 → 选模型与配置 → 提交 → 15s 轮询 → 下载到本地**。

---

## 目录

- [前置依赖](#前置依赖)
- [安装教程](#安装教程)
- [配置](#配置查看--更新)
- [使用教程](#使用教程)
  - [Claude Code](#claude-code)
  - [Codex CLI](#codex-cli)
  - [Hermes / 通用 agent](#hermes--通用-agent)
  - [纯命令行（不依赖任何 agent）](#纯命令行不依赖任何-agent)
- [版本与更新](#版本与更新)
- [目录结构](#目录结构)
- [常见问题](#常见问题)

---

## 前置依赖

| 依赖 | 用途 | macOS 安装 |
|---|---|---|
| `curl` | 调 API | 系统自带 |
| `jq` | 解析 JSON（必装） | `brew install jq` |
| `git` | 版本自检、拉取更新 | `brew install git` |

确认：
```bash
curl --version && jq --version && git --version
```

还需要：
- 一个运行中的 MidwayFlow 后端（提供 `/v1/image-generations` 等接口）
- 该后端的有效 **API token 或 JWT**（用于 `Authorization: Bearer <token>`）

---

## 安装教程

### 1. 克隆仓库

```bash
git clone git@github.com:BasicwareAI/basicrouter_skills.git ~/skills-media-gen
cd ~/skills-media-gen
```

> 默认克隆到 `~/skills-media-gen`。放别处也行，但 skill 脚本默认按这个路径找——若改了路径，调用时注意软链指向。

### 2. 运行安装脚本

```bash
bash install.sh all
```

这一步会：

1. 把各工具的适配层**软链**到对应目录：
   - `~/.claude/skills/generate-image`、`generate-video`
   - `~/.codex/prompts/generate-image.md`、`generate-video.md`
   - `~/.hermes/skills/generate-image.md`、`generate-video.md`
2. 进入**交互式配置引导**，提示你填 `base_url` 和 `token`（见下节）。

只装某一种工具也行：
```bash
bash install.sh claude    # 仅 Claude Code
bash install.sh codex     # 仅 Codex CLI
bash install.sh hermes    # 仅 Hermes
bash install.sh all       # 全部（默认）
```

### 3. 填写配置

安装脚本会依次问：
```
base_url: http://你的服务地址/api      # 含 /api 前缀，例如 http://localhost:8081/api
token:    你的 API token 或 JWT        # 直接粘裸 token，脚本自动加 Bearer 前缀
```

看到 `✅ 配置完成` 即装好。若回车跳过留空，会提示 `⚠️ 未填写`，skill 无法调用——稍后用 `config.sh` 补上即可。

### 一行完成（克隆 + 安装 + 配置）

```bash
git clone git@github.com:BasicwareAI/basicrouter_skills.git ~/skills-media-gen \
  && bash ~/skills-media-gen/install.sh all
```

---

## 配置（查看 / 更新）

配置文件：`~/.media-gen/config.json`（首次安装自动从 [config.example.json](config.example.json) 生成）。

字段：

| 字段 | 含义 | 示例 |
|---|---|---|
| `base_url` | 后端地址（含 `/api`） | `http://localhost:8081/api` |
| `auth.header` / `auth.value` | 鉴权头 | `Authorization` / `Bearer <token>` |
| `endpoints.*` | 各接口路径 | 默认已填好，一般不用改 |
| `poll.interval_seconds` | 轮询间隔 | `15` |
| `poll.max_seconds` | 轮询超时 | `600` |
| `output_dir` | 生成文件下载目录 | `./outputs` |

### 查看 / 更新

```bash
bash scripts/config.sh                          # 交互式逐项更新（回车保留当前值）
bash scripts/config.sh show                     # 打印当前配置（token 脱敏）
bash scripts/config.sh set base_url <url>       # 设 base_url
bash scripts/config.sh set token <raw-token>    # 设 token（自动加 Bearer；已带则不重复）
bash scripts/config.sh set output_dir <path>    # 设输出目录
bash scripts/config.sh set poll_interval <sec>  # 设轮询间隔
bash scripts/config.sh set poll_max <sec>       # 设轮询超时
```

**改完即生效**——下次 skill 调用就读新值，无需重启。换环境/换 token 时用 `set` 或交互式均可。

---

## 使用教程

### Claude Code

skill 已软链到 `~/.claude/skills/`，两种唤起方式：

**方式 A：斜杠命令（显式）**
```
/generate-image
/generate-video
```
输入 `/` 会弹出技能列表，选这两个即可。

**方式 B：自然语言（隐式）**
直接说意图，Claude 根据 skill 的 `description` 自动匹配：
- "生成一张戴墨镜的猫的图"
- "画个赛博朋克城市"
- "做个文生视频：海浪拍打礁石"
- "把这张图转成视频"（图生视频）

调用后 Claude 会按 SKILL.md 走完整流程：
1. `self-update.sh` 版本自检（有新版会在 stderr 提示 `git pull`，不阻塞）
2. `fetch-models.sh image|video` 拉取可用模型并对比 🆕新增 / ⚠️下架 / ✅仍在
3. 用 **AskUserQuestion** 弹卡片让你选：模型、分辨率、比例（图片还有 count；视频还有 videoType、duration）——上次选过的会标"(上次)"作默认
4. 选完提交 `POST /v1/image-generations` 或 `/v1/video-generations`
5. 每 15 秒轮询任务状态到 `success`/`failed`
6. `success` → 下载到 `output_dir`，返回本地路径；`failed` → 返回 errorMessage

> 当前会话里这两个 skill 已可用，可直接 `/generate-image` 试。

### Codex CLI

prompt 文件在 `~/.codex/prompts/`，用 `@` 引用：
```
@generate-image 生成一只在月球上的猫
@generate-video 海浪拍打礁石，5 秒
```

Codex 会走 `choose-and-run.sh` 终端交互选模型与配置（终端 `read` 提示），或匹配到 prompt 后按其中步骤执行。

### Hermes / 通用 agent

Hermes 适配待确认工具具体形态，当前为 portable markdown。通用 agent 把 `adapters/generic/*.md` 作为系统提示加载，然后自然语言驱动，走 `choose-and-run.sh` 终端交互。

### 纯命令行（不依赖任何 agent）

手动跑完整流程，适合脚本化：

```bash
# 1. 版本自检（非阻塞）
bash scripts/self-update.sh

# 2. 拉模型 + 对比更新/下架（缓存到 ~/.media-gen/cache/）
bash scripts/fetch-models.sh image
bash scripts/fetch-models.sh video

# 3. 交互选模型并生成（终端 read，列模型 + 各模型支持的配置 + 上次选择作默认）
bash scripts/choose-and-run.sh image '一只戴墨镜的猫'
bash scripts/choose-and-run.sh video '海浪拍打礁石'

# 或跳过交互，直接提交已知 body：
bash scripts/run-media-task.sh image '{"text":"一只戴墨镜的猫","model":"kling-omni-image","resolution":"1080P","ratio":"1:1"}'
bash scripts/run-media-task.sh video '{"text":"海浪拍打礁石","model":"kling-text2video","duration":5}'

# 查看本地模型清单（读 manifest；加 --remote 从 API 实时拉）
bash scripts/list-models.sh image
bash scripts/list-models.sh video --remote
```

---

## 版本与更新

- 版本号在 [VERSION](VERSION) 与 [manifest.json](manifest.json)。
- skill 每次调用前跑 `scripts/self-update.sh`：`git fetch` 后比较远端 `VERSION`，不一致在 stderr 提示升级（非阻塞）：
  ```
  [skills-media-gen] 有新版本: 本地=0.2.0 远端=0.3.0 — 运行 cd "~/skills-media-gen" && git pull 升级
  ```
- **升级到新版本**：
  ```bash
  cd ~/skills-media-gen && git pull
  ```
  软链会自动指向新内容，无需重跑 install.sh。
- **维护者新增/更新模型**：改 `manifest.json` 的 `models` + bump `VERSION` + 记 [CHANGELOG.md](CHANGELOG.md)，提交推送，所有用户下次调用自动感知。

---

## 目录结构

```
skills-media-gen/
├── VERSION                  # 单点版本号（0.2.0）
├── manifest.json            # 版本 + 模型清单 + 接口规格
├── CHANGELOG.md
├── README.md
├── config.example.json      # 配置模板
├── install.sh               # 软链各工具适配层 + 配置引导
├── scripts/
│   ├── self-update.sh       # 版本自检（git fetch 比对远端 VERSION，非阻塞）
│   ├── config.sh            # 查看/交互更新/命令行设配置
│   ├── fetch-models.sh      # 拉模型列表 + 缓存 + 对比 🆕/⚠️/✅
│   ├── choose-and-run.sh    # 终端交互选模型与配置 → 提交 → 轮询 → 下载
│   ├── run-media-task.sh    # 提交 + 15s 轮询 + 下载（被上面复用）
│   └── list-models.sh       # 读 manifest 列模型（--remote 从 API 拉）
├── src/                     # 工具无关的 prompt 源
│   ├── generate-image.md
│   └── generate-video.md
└── adapters/                # 各工具适配层
    ├── claude-code/         # SKILL.md 格式 → ~/.claude/skills/
    ├── codex/               # prompts/*.md → ~/.codex/prompts/
    ├── hermes/              # portable markdown（待确认）
    └── generic/             # 纯 markdown，任意 agent
```

| 工具 | 适配目录 | 软链落地位置 |
|---|---|---|
| Claude Code | `adapters/claude-code/` | `~/.claude/skills/` |
| Codex CLI | `adapters/codex/` | `~/.codex/prompts/` |
| Hermes | `adapters/hermes/` | `~/.hermes/skills/`（portable，待确认） |
| 通用 | `adapters/generic/` | 自行 copy |

---

## 常见问题

**Q: 调用报 "缺少 config.json" / "base_url 或 token 未填写"**
A: 跑 `bash ~/skills-media-gen/scripts/config.sh` 填上 base_url 和 token，或 `set` 单独设。

**Q: Claude Code 里 `/` 看不到 generate-image / generate-video**
A: 确认软链存在：`ls -l ~/.claude/skills/generate-image`。没有就重跑 `bash ~/skills-media-gen/install.sh claude`，然后重开会话。

**Q: token 怎么填？**
A: 直接粘裸 token（如 `sk-xxx` 或 JWT），脚本自动加 `Bearer ` 前缀。已带 `Bearer ` 也不重复加。

**Q: 下载的文件在哪？**
A: `~/.media-gen/config.json` 里的 `output_dir`，默认 `./outputs`（相对当前工作目录）。改：`bash scripts/config.sh set output_dir ~/my-outputs`。

**Q: 提示有新版本怎么升级？**
A: `cd ~/skills-media-gen && git pull`。软链自动指向新内容。

**Q: 轮询超时了怎么办？**
A: 视频生成较慢，`poll.max_seconds` 默认 600s。不够就调大：`bash scripts/config.sh set poll_max 1200`。

**Q: 放到别的机器怎么装？**
A: 一行：`git clone git@github.com:BasicwareAI/basicrouter_skills.git ~/skills-media-gen && bash ~/skills-media-gen/install.sh all`，再填配置即可。
