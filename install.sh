#!/usr/bin/env bash
# 把各工具适配层软链到对应工具的 skills/prompts 目录, 并引导填写 base_url / API token.
#   bash install.sh [claude|codex|hermes|generic|all]   默认 all
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NO_CONFIG="0"
TARGET="all"
for a in "$@"; do
  case "$a" in
    --no-config) NO_CONFIG="1" ;;
    claude|codex|hermes|generic|all) TARGET="$a" ;;
    -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
    *) echo "未知参数: $a (用法: install.sh [all|claude|codex|hermes] [--no-config])"; exit 1 ;;
  esac
done
CFG_DIR="$HOME/.media-gen"
CFG="$CFG_DIR/config.json"
mkdir -p "$CFG_DIR"

link_claude() {
  local D="$HOME/.claude/skills"
  mkdir -p "$D"
  ln -sfn "$REPO_ROOT/adapters/claude-code/generate-image" "$D/generate-image"
  ln -sfn "$REPO_ROOT/adapters/claude-code/generate-video" "$D/generate-video"
  echo "linked: $D/generate-image, $D/generate-video"
}
link_codex() {
  local D="$HOME/.codex/prompts"
  mkdir -p "$D"
  ln -sfn "$REPO_ROOT/adapters/codex/generate-image.md" "$D/generate-image.md"
  ln -sfn "$REPO_ROOT/adapters/codex/generate-video.md" "$D/generate-video.md"
  echo "linked: $D/generate-image.md, $D/generate-video.md"
}
link_hermes() {
  local D="$HOME/.hermes/skills"
  mkdir -p "$D"
  ln -sfn "$REPO_ROOT/adapters/hermes/generate-image.md" "$D/generate-image.md"
  ln -sfn "$REPO_ROOT/adapters/hermes/generate-video.md" "$D/generate-video.md"
  echo "linked(hermes): $D/*"
}
link_generic() {
  echo "generic adapter 在 $REPO_ROOT/adapters/generic/, 按你的工具自行 copy"
}

case "$TARGET" in
  claude) link_claude;;
  codex)  link_codex;;
  hermes) link_hermes;;
  generic) link_generic;;
  all) link_claude; link_codex; link_hermes; link_generic;;
  *) echo "未知目标: $TARGET"; exit 1;;
esac

# ── 配置引导 (复用 scripts/config.sh 的交互逻辑) ──
# 没有配置就先拷贝默认值作为起点
[ -f "$CFG" ] || cp "$REPO_ROOT/config.example.json" "$CFG"

if [ "$NO_CONFIG" = "1" ]; then
  # 非交互场景 (如 curl|bash): 跳过交互配置, 只确保配置文件存在
  exit 0
fi

echo ""
exec bash "$REPO_ROOT/scripts/config.sh"
