#!/usr/bin/env bash
# 终端交互式引导：列模型 → 选模型 → 看支持配置 → 选配置 → 提交 → 轮询。
# 给 codex/hermes/generic 等没有 AskUserQuestion 的工具用。Claude Code 走 SKILL.md 里的 AskUserQuestion 流程。
#   bash choose-and-run.sh image|video '<text>'
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
if [ -n "$LAST_MODEL" ]; then echo "（上次选过: ${LAST_MODEL}, 直接回车沿用）"; fi
M=""
read -p "模型 id: " M </dev/tty 2>/dev/null || true
[ -n "$M" ] || M="$LAST_MODEL"
[ -n "$M" ] || { echo "未选模型"; exit 1; }

SPEC=$(jq -c --arg m "$M" '.data[]|select(.id==$m)' "$MODELS")
[ "$SPEC" != "null" ] && [ -n "$SPEC" ] || { echo "模型不存在: $M"; exit 1; }

# 分辨率
RES_LIST=$(echo "$SPEC" | jq -r '(.resolutions // [])[]' 2>/dev/null || true)
if [ -n "$RES_LIST" ]; then
  echo "可选分辨率: $(echo "$RES_LIST" | tr '\n' ' ')"
  R=""
  read -p "resolution[${LAST_RES}]: " R </dev/tty 2>/dev/null || true
  [ -n "$R" ] || R="$LAST_RES"
fi
# 比例
RATIO_LIST=$(echo "$SPEC" | jq -r '(.ratios // [])[]' 2>/dev/null || true)
if [ -n "$RATIO_LIST" ]; then
  echo "可选比例: $(echo "$RATIO_LIST" | tr '\n' ' ')"
  RT=""
  read -p "ratio[${LAST_RATIO}]: " RT </dev/tty 2>/dev/null || true
  [ -n "$RT" ] || RT="$LAST_RATIO"
fi

BODY=$(jq -cn --arg t "$PROMPT" --arg m "$M" '{text:$t, model:$m}')
[ -n "${R:-}" ] && BODY=$(echo "$BODY" | jq -c --arg r "$R" '.resolution=$r')
[ -n "${RT:-}" ] && BODY=$(echo "$BODY" | jq -c --arg r "$RT" '.ratio=$r')

if [ "$KIND" = "image" ]; then
  MAXC=$(echo "$SPEC" | jq -r '.maxCount // empty')
  [ -n "$MAXC" ] && echo "单次最多 ${MAXC} 张"
  C=""
  read -p "count[${LAST_COUNT}]: " C </dev/tty 2>/dev/null || true
  [ -n "$C" ] || C="$LAST_COUNT"
  [ -n "$C" ] && BODY=$(echo "$BODY" | jq -c --argjson c "$C" '.count=$c')
fi

if [ "$KIND" = "video" ]; then
  VTYPES=$(echo "$SPEC" | jq -r '(.allowedVideoTypes // [])[] | "\(.code)=\(.name)"' 2>/dev/null || true)
  if [ -n "$VTYPES" ]; then
    echo "可选 videoType: $(echo "$VTYPES" | tr '\n' ' ')"
    echo "  1=文生 2=图生首帧 3=图生首尾帧 4=多图参考 5=全能参考 6=数字人"
    VT=""
    read -p "videoType[${LAST_VTYPE}]: " VT </dev/tty 2>/dev/null || true
    [ -n "$VT" ] || VT="$LAST_VTYPE"
    [ -n "$VT" ] && BODY=$(echo "$BODY" | jq -c --argjson v "$VT" '.videoType=$v')
  fi
  DMIN=$(echo "$SPEC" | jq -r '.videoDurationMin // empty'); DMAX=$(echo "$SPEC" | jq -r '.videoDurationMax // empty')
  [ -n "$DMIN" ] && echo "时长范围 ${DMIN}-${DMAX}s，建议: $(echo "$SPEC" | jq -r '(.videoDurationSuggest // [])|join(",")')"
  D=""
  read -p "duration[${LAST_DUR}]: " D </dev/tty 2>/dev/null || true
  [ -n "$D" ] || D="$LAST_DUR"
  [ -n "$D" ] && BODY=$(echo "$BODY" | jq -c --argjson d "$D" '.duration=$d')

  # ── 按 videoType 收集参考素材 ──
  # 收素材: 读一行"本地路径或URL(可多个空格分隔)", 本地的转DataURI, 输出JSON数组
  collect_urls() {
    local label="$1" out
    raw=""
    read -p "$label (本地路径或URL, 多个空格分隔, 留空跳过): " raw </dev/tty 2>/dev/null || true
    [ -z "$raw" ] && { echo ""; return; }
    # 拆分参数(处理路径含空格用引号的话较复杂, 这里按空格分)
    local arr=()
    for w in $raw; do arr+=("$w"); done
    [ ${#arr[@]} -eq 0 ] && { echo ""; return; }
    out=$(bash "$REPO_ROOT/scripts/image-to-datauri.sh" --json "${arr[@]}" 2>/dev/null)
    echo "$out"
  }
  collect_video_urls() {  # videoUrls 用对象数组
    local label="$1" out
    raw=""
    read -p "$label (本地视频路径或URL, 多个空格分隔, 留空跳过): " raw </dev/tty 2>/dev/null || true
    [ -z "$raw" ] && { echo ""; return; }
    local arr=()
    for w in $raw; do arr+=("$w"); done
    [ ${#arr[@]} -eq 0 ] && { echo ""; return; }
    out=$(bash "$REPO_ROOT/scripts/image-to-datauri.sh" --json-obj "${arr[@]}" 2>/dev/null)
    echo "$out"
  }

  case "${VT:-1}" in
    1) echo "文生视频, 无需素材" ;;
    2)
      echo "图生视频-首帧: 需 1 张图作首帧"
      U=$(collect_urls "首帧图") || true
      [ -n "$U" ] && BODY=$(echo "$BODY" | jq -c --argjson u "$U" '.imageUrls=$u') ;;
    3)
      echo "图生视频-首尾帧: imageUrls[0]=首帧 [1]=尾帧"
      U=$(collect_urls "首帧+尾帧图(2张)") || true
      [ -n "$U" ] && BODY=$(echo "$BODY" | jq -c --argjson u "$U" '.imageUrls=$u') ;;
    4)
      echo "多图参考: 需多张参考图"
      U=$(collect_urls "参考图(多张)") || true
      [ -n "$U" ] && BODY=$(echo "$BODY" | jq -c --argjson u "$U" '.imageUrls=$u') ;;
    5)
      echo "全能参考: 图/视频/音频分开上传, 提示词用 @图片N/@视频N/@音频N 引用"
      U=$(collect_urls "参考图 imageUrls") || true
      [ -n "$U" ] && BODY=$(echo "$BODY" | jq -c --argjson u "$U" '.imageUrls=$u')
      VU=$(collect_video_urls "参考视频 videoUrls") || true
      [ -n "$VU" ] && BODY=$(echo "$BODY" | jq -c --argjson vu "$VU" '.videoUrls=$vu')
      AU=$(collect_urls "参考音频 audioUrls") || true
      [ -n "$AU" ] && BODY=$(echo "$BODY" | jq -c --argjson au "$AU" '.audioUrls=$au')
      echo "提示词中可用 @图片1 @视频1 @音频1 等引用(序号=数组下标+1)"
      echo "当前 body.text = $(echo "$BODY" | jq -r '.text')" ;;
    6)
      echo "数字人: imageUrls[0]=形象, audioUrls[0]=驱动音频"
      U=$(collect_urls "数字人形象图") || true
      [ -n "$U" ] && BODY=$(echo "$BODY" | jq -c --argjson u "$U" '.imageUrls=$u')
      AU=$(collect_urls "驱动音频") || true
      [ -n "$AU" ] && BODY=$(echo "$BODY" | jq -c --argjson au "$AU" '.audioUrls=$au') ;;
  esac
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
