#!/usr/bin/env bash
# 拉取 /v1/image-models 或 /v1/video-models，缓存到 ~/.media-gen/cache/，
# 与上次缓存 diff，输出：新增 / 下架 / 仍在。供 skill 第一步调用。
#   bash fetch-models.sh image|video
# 输出（stdout）：人类可读的对比 + JSON 摘要最后一行以 "JSON:" 开头。
set -euo pipefail
KIND="${1:?usage: fetch-models.sh image|video}"
CFG="${MEDIA_GEN_CONFIG:-$HOME/.media-gen/config.json}"
CACHE_DIR="$HOME/.media-gen/cache"
mkdir -p "$CACHE_DIR"
[ -f "$CFG" ] || { echo "缺少 $CFG" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "需要 jq" >&2; exit 1; }

BASE=$(jq -r .base_url "$CFG")
AUTH_H=$(jq -r .auth.header "$CFG"); AUTH_V=$(jq -r .auth.value "$CFG")
case "$KIND" in
  image) PATH_="/v1/image-models";;
  video) PATH_="/v1/video-models";;
  *) echo "kind 必须是 image|video" >&2; exit 1;;
esac

NEW="$CACHE_DIR/${KIND}-models.json"
OLD="$CACHE_DIR/${KIND}-models.prev.json"

# 拉取
RAW=$(curl -sS "$BASE$PATH_" -H "$AUTH_H: $AUTH_V")
echo "$RAW" | jq -e '.data' >/dev/null || { echo "拉取失败: $RAW" >&2; exit 1; }

# 滚动缓存：当前 → prev
[ -f "$NEW" ] && cp "$NEW" "$OLD"
echo "$RAW" | jq '.' > "$NEW"

# diff
NEW_IDS=$(jq -r '.data[].id' "$NEW" | sort -u)
if [ -f "$OLD" ]; then
  OLD_IDS=$(jq -r '.data[].id' "$OLD" | sort -u)
  ADDED=$(comm -23 <(echo "$NEW_IDS") <(echo "$OLD_IDS"))
  REMOVED=$(comm -13 <(echo "$NEW_IDS") <(echo "$OLD_IDS"))
  KEPT=$(comm -12 <(echo "$NEW_IDS") <(echo "$OLD_IDS"))
else
  ADDED="$NEW_IDS"; REMOVED=""; KEPT=""
fi

echo "== ${KIND} 模型（$(echo "$NEW_IDS" | grep -c .) 个）=="
if [ -n "${ADDED// /}" ]; then echo "🆕 新增: $(echo "$ADDED" | tr '\n' ' ')"; fi
if [ -n "${REMOVED// /}" ]; then echo "⚠️ 下架: $(echo "$REMOVED" | tr '\n' ' ')"; fi
if [ -n "${KEPT// /}" ]; then echo "✅ 仍在: $(echo "$KEPT" | tr '\n' ' ')"; fi
[ -z "${ADDED// /}" ] && [ -z "${REMOVED// /}" ] && [ -f "$OLD" ] && echo "（无变化）"

# JSON 摘要供上层解析
echo "JSON: $(jq -c '{kind:$k, models:[.data[]|{id, displayName, description}]}' --arg k "$KIND" "$NEW")"
