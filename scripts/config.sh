#!/usr/bin/env bash
# 查看 / 更新 ~/.media-gen/config.json (复用于 install.sh 的配置引导)
#
#   bash config.sh                         交互式逐项更新(回车保留当前值)
#   bash config.sh show                    打印当前配置(token 脱敏)
#   bash config.sh set base_url <url>      设 base_url
#   bash config.sh set token <raw>         设 token (自动加 Bearer 前缀)
#   bash config.sh set output_dir <path>   设输出目录
#   bash config.sh set poll_interval <sec> 设轮询间隔
#   bash config.sh set poll_max <sec>      设轮询超时
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CFG_DIR="$HOME/.media-gen"
CFG="$CFG_DIR/config.json"
mkdir -p "$CFG_DIR"
[ -f "$CFG" ] || cp "$REPO_ROOT/config.example.json" "$CFG"
command -v jq >/dev/null 2>&1 || { echo "需要 jq"; exit 1; }

# 判断 base_url / token 是否仍是占位或空
needs_baseurl() {
  local v; v=$(jq -r '.base_url // empty' "$CFG" 2>/dev/null)
  [ -z "$v" ] || [[ "$v" == *"<"* ]]
}
needs_token() {
  local v; v=$(jq -r '.auth.value // empty' "$CFG" 2>/dev/null)
  [ -z "$v" ] || [[ "$v" == *"<"* ]]
}

# ── show: 打印当前配置(token 脱敏) ──
cmd_show() {
  jq -r '
    "base_url   = \(.base_url // "(空)")",
    "auth.header= \(.auth.header // "Authorization")",
    "token      = \(if (.auth.value|type=="string") and (.auth.value!="") and (.auth.value|test("<")|not) then "(已设置, 已脱敏)" else "(未设置)" end)",
    "output_dir = \(.output_dir // "./outputs")",
    "poll       = 间隔 \(.poll.interval_seconds//15)s / 最长 \(.poll.max_seconds//600)s"
  ' "$CFG"
}

# ── set: 直接设某项 ──
cmd_set() {
  local key="$1" val="${2:-}"
  [ -n "$val" ] || { echo "缺少 $key 的值"; exit 1; }
  case "$key" in
    base_url)
      jq --arg v "$val" '.base_url=$v' "$CFG" >"$CFG.tmp" && mv "$CFG.tmp" "$CFG" ;;
    token)
      # 输入裸 token, 自动加 Bearer; 若已带 Bearer 则不重复加
      case "$val" in Bearer\ *) ;; *) val="Bearer $val" ;; esac
      jq --arg v "$val" '.auth.value=$v' "$CFG" >"$CFG.tmp" && mv "$CFG.tmp" "$CFG" ;;
    output_dir)
      jq --arg v "$val" '.output_dir=$v' "$CFG" >"$CFG.tmp" && mv "$CFG.tmp" "$CFG" ;;
    poll_interval)
      jq --argjson v "$val" '.poll.interval_seconds=($v|tonumber)' "$CFG" >"$CFG.tmp" && mv "$CFG.tmp" "$CFG" ;;
    poll_max)
      jq --argjson v "$val" '.poll.max_seconds=($v|tonumber)' "$CFG" >"$CFG.tmp" && mv "$CFG.tmp" "$CFG" ;;
    *)
      echo "未知 key: $key (可用: base_url token output_dir poll_interval poll_max)"; exit 1 ;;
  esac
  echo "✅ 已更新 $key"
}

# ── 交互式逐项更新(回车保留当前值) ──
cmd_interactive() {
  echo "── 配置 base_url 与 API token (回车保留当前值) ──"
  local cur cur_disp
  cur=$(jq -r '.base_url // empty' "$CFG")
  [ -n "$cur" ] && cur_disp="当前: $cur" || cur_disp="(未设置)"
  echo " MidwayFlow OpenAPI 的 base_url (含 /api 前缀), 例如 http://localhost:8081/api  [$cur_disp]"
  printf "  base_url: "
  { read -r IN_BASE || IN_BASE=""; } </dev/tty 2>/dev/null || read -r IN_BASE || IN_BASE=""
  if [ -n "$IN_BASE" ]; then
    jq --arg b "$IN_BASE" '.base_url=$b' "$CFG" >"$CFG.tmp" && mv "$CFG.tmp" "$CFG"
  fi

  if needs_token; then cur_disp="(未设置)"; else cur_disp="(已设置, 已脱敏)"; fi
  echo " API token / API Key (将作为 Authorization: Bearer <token>; 不带 Bearer 前缀, 脚本自动加)  [$cur_disp]"
  printf "  token: "
  { read -r IN_TOKEN || IN_TOKEN=""; } </dev/tty 2>/dev/null || read -r IN_TOKEN || IN_TOKEN=""
  if [ -n "$IN_TOKEN" ]; then
    case "$IN_TOKEN" in Bearer\ *) ;; *) IN_TOKEN="Bearer $IN_TOKEN" ;; esac
    jq --arg t "$IN_TOKEN" '.auth.value=$t' "$CFG" >"$CFG.tmp" && mv "$CFG.tmp" "$CFG"
  fi

  echo ""
  if needs_baseurl || needs_token; then
    echo "⚠️  base_url 或 token 未填写, skill 将无法调用 API."
    echo "   补全: bash \"$REPO_ROOT/scripts/config.sh\"  或直接编辑 $CFG"
  else
    echo "✅ 配置完成. 当前:"
    cmd_show
  fi
}

case "${1:-}" in
  "") cmd_interactive ;;
  show) cmd_show ;;
  set) shift; cmd_set "$@" ;;
  needs-config)
    # 退出码 0 = 需要配置(有缺项); 1 = 已配置完整。供 install.sh --no-config 用
    if needs_baseurl || needs_token; then exit 0; else exit 1; fi ;;
  -h|--help|help)
    sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) echo "用法: config.sh [show | set <key> <value>]"; echo "  key 可用: base_url token output_dir poll_interval poll_max"; exit 1 ;;
esac
