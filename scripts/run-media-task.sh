#!/usr/bin/env bash
# 提交 + 轮询 + 下载 的统一运行器。
#   bash run-media-task.sh image|video '<json-body>'
# 依赖：curl, jq。配置来自 ~/.media-gen/config.json。
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KIND="${1:?usage: run-media-task.sh image|video <body-json>}"
BODY="${2:?missing body json}"
CFG="${MEDIA_GEN_CONFIG:-$HOME/.media-gen/config.json}"
[ -f "$CFG" ] || { echo "缺少 $CFG，请复制 config.example.json 到 $CFG 并填写"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "需要 jq"; exit 1; }

BASE=$(jq -r .base_url "$CFG")
AUTH_H=$(jq -r .auth.header "$CFG"); AUTH_V=$(jq -r .auth.value "$CFG")
OUT=$(jq -r .output_dir "$CFG")
INTERVAL=$(jq -r '.poll.interval_seconds // 15' "$CFG")
MAX=$(jq -r '.poll.max_seconds // 600' "$CFG")
mkdir -p "$OUT"

case "$KIND" in
  image) SUB="/v1/image-generations"; Q="/v1/image-generations"; URL_FIELD="images";;
  video) SUB="/v1/video-generations"; Q="/v1/video-generations"; URL_FIELD="videos";;
  *) echo "kind 必须是 image|video"; exit 1;;
esac

# 1) 提交
RESP=$(curl -sS -X POST "$BASE$SUB" -H "$AUTH_H: $AUTH_V" -H "Content-Type: application/json" -d "$BODY")
TASK_ID=$(echo "$RESP" | jq -r '.data.taskId // .taskId // empty')
[ -n "$TASK_ID" ] || { echo "提交失败: $RESP"; exit 1; }
echo "taskId=$TASK_ID"

# 2) 轮询
DEADLINE=$(( $(date +%s) + MAX ))
while :; do
  sleep "$INTERVAL"
  QRESP=$(curl -sS "$BASE$Q/$TASK_ID" -H "$AUTH_H: $AUTH_V")
  STATUS=$(echo "$QRESP" | jq -r '.data.status // .status // empty')
  echo "status=$STATUS"
  case "$STATUS" in
    success)
      # 兼容 images 数组或单个 url 字段
      URLS=$(echo "$QRESP" | jq -r ".data.$URL_FIELD[]? // .data.url? // empty" 2>/dev/null || true)
      if [ -z "$URLS" ]; then
        URLS=$(echo "$QRESP" | jq -r ".data.resultUrl? // .data.videoUrl? // empty" 2>/dev/null || true)
      fi
      TS=$(date +%Y%m%d-%H%M%S)
      i=1
      for u in $URLS; do
        [ -n "$u" ] || continue
        EXT="${u##*.}"; EXT="${EXT%%\?*}"; [ -n "$EXT" ] || EXT="bin"
        F="$OUT/${KIND}-${TS}-${i}.${EXT}"
        curl -sS -o "$F" "$u" && echo "saved: $F"
        i=$((i+1))
      done
      exit 0
      ;;
    failed)
      echo "任务失败: $(echo "$QRESP" | jq -r '.data.errorMessage // .errorMessage // empty')"
      exit 1
      ;;
  esac
  [ "$(date +%s)" -lt "$DEADLINE" ] || { echo "轮询超时（${MAX}s），最后状态: $STATUS"; exit 2; }
done
