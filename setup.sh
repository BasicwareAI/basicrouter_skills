#!/usr/bin/env bash
# 一键安装 skills-media-gen: 检查依赖 -> clone 仓库 -> 软链适配层 -> 配置引导
#
# 直接跑:
#   bash setup.sh                      # 装到 ~/skills-media-gen, 全部工具
#   bash setup.sh claude               # 仅 Claude Code
#   bash setup.sh all --dir ~/my/path  # 装到指定目录
#
# 远程一键 (curl | bash):
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/BasicwareAI/basicrouter_skills/main/setup.sh)"
#
# 远程一键 + 指定工具:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/BasicwareAI/basicrouter_skills/main/setup.sh)" -- claude
set -u

REPO_URL="https://github.com/BasicwareAI/basicrouter_skills.git"
DEFAULT_DIR="$HOME/skills-media-gen"

# ── 解析参数 ──
TARGET="all"
INSTALL_DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    all|claude|codex|hermes|generic) TARGET="$1" ;;
    --dir) shift; INSTALL_DIR="${1:-}" ;;
    -h|--help)
      sed -n '2,13p' "$0" 2>/dev/null || echo "usage: bash setup.sh [all|claude|codex|hermes] [--dir <path>]"
      exit 0 ;;
    *) echo "未知参数: $1"; echo "usage: bash setup.sh [all|claude|codex|hermes] [--dir <path>]"; exit 1 ;;
  esac
  shift
done
[ -n "$INSTALL_DIR" ] || INSTALL_DIR="$DEFAULT_DIR"

# ── 检查依赖 ──
echo "── 检查依赖 ──"
MISSING=""
command -v git  >/dev/null 2>&1 || MISSING="$MISSING git"
command -v curl >/dev/null 2>&1 || MISSING="$MISSING curl"
command -v jq   >/dev/null 2>&1 || MISSING="$MISSING jq"
if [ -n "$MISSING" ]; then
  echo "✗ 缺少依赖:$MISSING"
  echo "  macOS:  brew install$MISSING"
  echo "  Ubuntu: sudo apt-get install -y$MISSING"
  exit 1
fi
echo "✓ git curl jq 就绪"

# ── clone 仓库 ──
echo ""
echo "── 克隆仓库到 $INSTALL_DIR ──"
if [ -d "$INSTALL_DIR/.git" ]; then
  echo "目录已存在, 执行 git pull 更新"
  git -C "$INSTALL_DIR" pull --ff-only || { echo "git pull 失败, 请检查 $INSTALL_DIR"; exit 1; }
else
  mkdir -p "$(dirname "$INSTALL_DIR")"
  git clone "$REPO_URL" "$INSTALL_DIR" || { echo "克隆失败 (确认有 GitHub SSH 权限)"; exit 1; }
fi

# ── 安装 + 配置 ──
echo ""
echo "── 安装适配层 ($TARGET) ──"
cd "$INSTALL_DIR" || exit 1
if [ -t 0 ]; then
  # 交互终端: 走完整配置引导
  bash "$INSTALL_DIR/install.sh" "$TARGET"
else
  # 非交互 (curl|bash 管道): 只软链, 跳过配置, 提示后续补
  bash "$INSTALL_DIR/install.sh" "$TARGET" --no-config
  echo ""
  echo "ℹ️  当前通过管道安装, 无法交互填配置。装好后请运行:"
  echo "    bash \"$INSTALL_DIR/scripts/config.sh\""
  echo "  填入 base_url 和 token 即可使用。"
fi
