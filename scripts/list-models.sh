#!/usr/bin/env bash
# 列出 manifest.json 中的可用模型，或从 API 实时拉取。
#   bash list-models.sh image|video|all [--remote]
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPO_ROOT/manifest.json"
CFG="${MEDIA_GEN_CONFIG:-$HOME/.media-gen/config.json}"
KIND="${1:-all}"
REMOTE="${2:-}"

print_local() {
  command -v jq >/dev/null 2>&1 || { echo "需要 jq"; exit 1; }
  if [ "$KIND" = "image" ] || [ "$KIND" = "all" ]; then
    echo "== image =="; jq -r '.models.image[]|"\(.id)\t\(.provider)"' "$MANIFEST"
  fi
  if [ "$KIND" = "video" ] || [ "$KIND" = "all" ]; then
    echo "== video =="; jq -r '.models.video[]|"\(.id)\t\(.provider)"' "$MANIFEST"
  fi
}

print_remote() {
  command -v jq >/dev/null 2>&1 || { echo "需要 jq"; exit 1; }
  [ -f "$CFG" ] || { echo "缺少 $CFG"; exit 1; }
  BASE=$(jq -r .base_url "$CFG")
  H=$(jq -r .auth.header "$CFG"); V=$(jq -r .auth.value "$CFG")
  if [ "$KIND" = "image" ] || [ "$KIND" = "all" ]; then
    echo "== image (remote) =="
    curl -s "$BASE/v1/image-models" -H "$H: $V" | jq -r '.data[]?.id // empty'
  fi
  if [ "$KIND" = "video" ] || [ "$KIND" = "all" ]; then
    echo "== video (remote) =="
    curl -s "$BASE/v1/video-models" -H "$H: $V" | jq -r '.data[]?.id // empty'
  fi
}

if [ "$REMOTE" = "--remote" ]; then print_remote; else print_local; fi
