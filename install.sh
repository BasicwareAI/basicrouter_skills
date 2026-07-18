#!/usr/bin/env bash
# 把各工具适配层软链到对应工具的 skills/prompts 目录, 并引导填写 base_url / API token.
#   bash install.sh [claude|codex|hermes|generic|all]   默认 all
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-all}"
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

# ── 配置引导 ──
# 没有配置就先拷贝默认值作为起点
if [ ! -f "$CFG" ]; then
  cp "$REPO_ROOT/config.example.json" "$CFG"
fi

# 判断 base_url / token 是否仍是占位或空
needs_baseurl() {
  local v; v=$(jq -r '.base_url // empty' "$CFG" 2>/dev/null)
  [ -z "$v" ] || [[ "$v" == *"<"* ]] || [[ "$v" == *"example"* ]]
}
needs_token() {
  local v; v=$(jq -r '.auth.value // empty' "$CFG" 2>/dev/null)
  [ -z "$v" ] || [[ "$v" == *"<"* ]]
}

echo ""
echo "── 配置 base_url 与 API token ──"
echo " MidwayFlow OpenAPI 的 base_url (含 /api 前缀), 例如 http://localhost:8081/api"
if needs_baseurl; then
  printf "  base_url: "
  read -r IN_BASE || IN_BASE=""
  if [ -n "$IN_BASE" ]; then
    jq --arg b "$IN_BASE" '.base_url=$b' "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
  fi
else
  echo "  当前 base_url=$(jq -r '.base_url' "$CFG") (回车保留, 输入新值覆盖)"
  printf "  base_url: "
  read -r IN_BASE || IN_BASE=""
  if [ -n "$IN_BASE" ]; then
    jq --arg b "$IN_BASE" '.base_url=$b' "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
  fi
fi

echo " API token / API Key (将作为 Authorization: Bearer <token> 发送)"
if needs_token; then
  printf "  token: "
  read -r IN_TOKEN || IN_TOKEN=""
  if [ -n "$IN_TOKEN" ]; then
    jq --arg t "Bearer $IN_TOKEN" '.auth.value=$t' "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
  fi
else
  echo "  当前已配置 token (回车保留, 输入新值覆盖; 不带 Bearer 前缀, 脚本会自动加)"
  printf "  token: "
  read -r IN_TOKEN || IN_TOKEN=""
  if [ -n "$IN_TOKEN" ]; then
    jq --arg t "Bearer $IN_TOKEN" '.auth.value=$t' "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
  fi
fi

echo ""
if needs_baseurl || needs_token; then
  echo "⚠️  base_url 或 token 未填写, skill 将无法调用 API."
  echo "   请编辑 $CFG 补全后再使用."
else
  echo "✅ 配置完成: $CFG"
  echo "   base_url=$(jq -r '.base_url' "$CFG")"
fi
