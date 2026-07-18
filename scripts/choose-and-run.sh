#!/usr/bin/env bash
# 终端交互式引导：列模型 → 选模型 → 看支持配置 → 选配置 → 提交 → 轮询。
# 给 codex/hermes/generic 等没有 AskUserQuestion 的工具用。Claude Code 走 SKILL.md 里的 AskUserQuestion 流程。
#   bash choose-and-run.sh image|video '<text>'
set -euo pipefail
KIND="${1:?usage: choose-and-run.sh image|video <text>}"
PROMPT="${2:?missing text prompt}"
CACHE_DIR="$HOME/.media-gen/cache"
MODELS="$CACHE_DIR/${KIND}-models.json"
LAST="$CACHE_DIR/last-choice.json"
[ -f "$MODELS" ] || { echo "先跑 fetch-models.sh $KIND" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "需要 jq" >&2; exit 1; }

# 上次选择（默认值）
LAST_MODEL=$(jq -r ".${KIND}.model // empty" "$LAST" 2>/dev/null || true)
LAST_RES=$(jq -r ".${KIND}.resolution // empty" "$LAST" 2>/dev/null || true)
LAST_RATIO=$(jq -r ".${KIND}.ratio // empty" "$LAST" 2>/dev/null || true)
LAST_COUNT=$(jq -r ".${KIND}.count // empty" "$LAST" 2>/dev/null || true)
LAST_VTYPE=$(jq -r ".${KIND}.videoType // empty" "$LAST" 2>/dev/null || true)
LAST_DUR=$(jq -r ".${KIND}.duration // empty" "$LAST" 2>/dev/null || true)

echo "== 选择 $KIND 模型 =="
jq -r '.data[] | "\(.id)\t\(.displayName // .id)\t\(.description // "")"' "$MODELS" | cat -A 2>/dev/null || \
  jq -r '.data[] | "\(.id)  |  \(.displayName // .id)  |  \(.description // "")"' "$MODELS"
if [ -n "$LAST_MODEL" ]; then echo "（上次选过: $LAST_MODEL，直接回车沿用）"; fi
read -p "模型 id: " M </dev/tty
[ -n "$M" ] || M="$LAST_MODEL"
[ -n "$M" ] || { echo "未选模型"; exit 1; }

SPEC=$(jq -c --arg m "$M" '.data[]|select(.id==$m)' "$MODELS")
[ "$SPEC" != "null" ] && [ -n "$SPEC" ] || { echo "模型不存在: $M"; exit 1; }

# 分辨率
RES_LIST=$(echo "$SPEC" | jq -r '(.resolutions // [])[]' 2>/dev/null || true)
if [ -n "$RES_LIST" ]; then
  echo "可选分辨率: $(echo "$RES_LIST" | tr '\n' ' ')"
  read -p "resolution[${LAST_RES}]: " R </dev/tty
  [ -n "$R" ] || R="$LAST_RES"
fi
# 比例
RATIO_LIST=$(echo "$SPEC" | jq -r '(.ratios // [])[]' 2>/dev/null || true)
if [ -n "$RATIO_LIST" ]; then
  echo "可选比例: $(echo "$RATIO_LIST" | tr '\n' ' ')"
  read -p "ratio[${LAST_RATIO}]: " RT </dev/tty
  [ -n "$RT" ] || RT="$LAST_RATIO"
fi

BODY=$(jq -cn --arg t "$PROMPT" --arg m "$M" '{text:$t, model:$m}')
[ -n "${R:-}" ] && BODY=$(echo "$BODY" | jq -c --arg r "$R" '.resolution=$r')
[ -n "${RT:-}" ] && BODY=$(echo "$BODY" | jq -c --arg r "$RT" '.ratio=$r')

if [ "$KIND" = "image" ]; then
  MAXC=$(echo "$SPEC" | jq -r '.maxCount // empty')
  [ -n "$MAXC" ] && echo "单次最多 ${MAXC} 张"
  read -p "count[${LAST_COUNT}]: " C </dev/tty
  [ -n "$C" ] || C="$LAST_COUNT"
  [ -n "$C" ] && BODY=$(echo "$BODY" | jq -c --argjson c "$C" '.count=$c')
fi

if [ "$KIND" = "video" ]; then
  VTYPES=$(echo "$SPEC" | jq -r '(.allowedVideoTypes // [])[] | "\(.code)=\(.name)"' 2>/dev/null || true)
  if [ -n "$VTYPES" ]; then
    echo "可选 videoType: $(echo "$VTYPES" | tr '\n' ' ')"
    read -p "videoType[${LAST_VTYPE}]: " VT </dev/tty
    [ -n "$VT" ] || VT="$LAST_VTYPE"
    [ -n "$VT" ] && BODY=$(echo "$BODY" | jq -c --argjson v "$VT" '.videoType=$v')
  fi
  DMIN=$(echo "$SPEC" | jq -r '.videoDurationMin // empty'); DMAX=$(echo "$SPEC" | jq -r '.videoDurationMax // empty')
  [ -n "$DMIN" ] && echo "时长范围 ${DMIN}-${DMAX}s，建议: $(echo "$SPEC" | jq -r '(.videoDurationSuggest // [])|join(",")')"
  read -p "duration[${LAST_DUR}]: " D </dev/tty
  [ -n "$D" ] || D="$LAST_DUR"
  [ -n "$D" ] && BODY=$(echo "$BODY" | jq -c --argjson d "$D" '.duration=$d')
fi

echo "最终 body: $BODY"

# 记住这次选择
mkdir -p "$(dirname "$LAST")"
touch "$LAST"
CHOICE=$(jq -cn --arg m "$M" --arg r "${R:-}" --arg rt "${RT:-}" \
  --arg c "${C:-}" --arg vt "${VT:-}" --arg d "${D:-}" \
  '{model:$m, resolution:$r, ratio:$rt, count:$c, videoType:$vt, duration:$d}')
jq --arg k "$KIND" --argjson c "$CHOICE" '.[$k]=$c' "$LAST" 2>/dev/null > "$LAST.tmp" && mv "$LAST.tmp" "$LAST" || echo "$CHOICE" > "$LAST"

exec bash "$(dirname "${BASH_SOURCE[0]}")/run-media-task.sh" "$KIND" "$BODY"
