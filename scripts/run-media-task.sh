#!/usr/bin/env bash
# 提交 + 轮询 + 下载 的统一运行器。
#
#   一体模式（同步阻塞，旧用法）:
#     bash run-media-task.sh image|video '<json-body>'
#
#   拆分模式（异步友好，不阻塞主流程）:
#     bash run-media-task.sh submit  image|video '<json-body>'   # 只提交, 打印 taskId=...
#     bash run-media-task.sh poll   image|video <taskId>         # 轮询到终态并下载, 打印 saved:...
#
# 依赖：curl, jq。配置来自 ~/.media-gen/config.json。
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CFG="${MEDIA_GEN_CONFIG:-$HOME/.media-gen/config.json}"
[ -f "$CFG" ] || { echo "缺少 $CFG，请复制 config.example.json 到 $CFG 并填写"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "需要 jq"; exit 1; }

BASE=$(jq -r .base_url "$CFG")
AUTH_H=$(jq -r .auth.header "$CFG"); AUTH_V=$(jq -r .auth.value "$CFG")
OUT=$(jq -r .output_dir "$CFG")
INTERVAL=$(jq -r '.poll.interval_seconds // 15' "$CFG")
MAX=$(jq -r '.poll.max_seconds // 600' "$CFG")
mkdir -p "$OUT"

# 解析 kind -> 端点路径
resolve_kind() {
  case "$1" in
    image) SUB="/v1/image-generations"; Q="/v1/image-generations"; URL_FIELD="images";;
    video) SUB="/v1/video-generations"; Q="/v1/video-generations"; URL_FIELD="videos";;
    *) echo "kind 必须是 image|video" >&2; exit 1;;
  esac
}

# 提交任务, 打印 taskId=...
do_submit() {
  local kind="$1" body="$2"
  resolve_kind "$kind"
  local resp tid
  resp=$(curl -sS -X POST "$BASE$SUB" -H "$AUTH_H: $AUTH_V" -H "Content-Type: application/json" -d "$body")
  tid=$(echo "$resp" | jq -r '.data.taskId // .taskId // empty')
  [ -n "$tid" ] || { echo "提交失败: $resp" >&2; exit 1; }
  echo "taskId=$tid"
}

# 轮询单个任务到终态并下载, 打印 saved:...
do_poll() {
  local kind="$1" tid="$2"
  resolve_kind "$kind"
  local deadline qresp status
  deadline=$(( $(date +%s) + MAX ))
  while :; do
    sleep "$INTERVAL"
    qresp=$(curl -sS "$BASE$Q/$tid" -H "$AUTH_H: $AUTH_V")
    status=$(echo "$qresp" | jq -r '.data.status // .status // empty')
    echo "status=$status"
    case "$status" in
      success)
        # URL 字段可能是原生数组, 也可能是字符串化的 JSON 数组 "[\"url\",...]"
        local urls
        urls=$(echo "$qresp" | jq -r "
          .data.$URL_FIELD as \$v |
          if (\$v | type) == \"string\" then (\$v | fromjson) else \$v end |
          if type == \"array\" then .[] else . end
        " 2>/dev/null || true)
        if [ -z "$urls" ]; then
          urls=$(echo "$qresp" | jq -r ".data.url? // .data.resultUrl? // .data.videoUrl? // empty" 2>/dev/null || true)
        fi
        local ts i u ext f
        ts=$(date +%Y%m%d-%H%M%S); i=1
        for u in $urls; do
          [ -n "$u" ] || continue
          ext="${u##*.}"; ext="${ext%%\?*}"; [ -n "$ext" ] || ext="bin"
          f="$OUT/${kind}-${ts}-${i}.${ext}"
          curl -sS -o "$f" "$u" && echo "saved: $f"
          i=$((i+1))
        done
        exit 0 ;;
      failed)
        echo "任务失败: $(echo "$qresp" | jq -r '.data.errorMessage // .errorMessage // empty')" >&2
        exit 1 ;;
    esac
    [ "$(date +%s)" -lt "$deadline" ] || { echo "轮询超时（${MAX}s），最后状态: $status" >&2; exit 2; }
  done
}

# ── 分发 ──
MODE="${1:-}"
case "$MODE" in
  submit) shift; do_submit "$@" ;;
  poll)   shift; do_poll "$@" ;;
  image|video)
    # 旧用法: run-media-task.sh image|video '<body>' —— 提交后同步轮询
    BODY="${2:?missing body json}"
    tid=$(do_submit "$MODE" "$BODY" | sed 's/^taskId=//')
    do_poll "$MODE" "$tid" ;;
  *)
    echo "用法:" >&2
    echo "  bash run-media-task.sh image|video '<json-body>'           # 提交+轮询(同步)" >&2
    echo "  bash run-media-task.sh submit image|video '<json-body>'    # 仅提交" >&2
    echo "  bash run-media-task.sh poll image|video <taskId>           # 仅轮询+下载" >&2
    exit 1 ;;
esac
