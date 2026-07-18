#!/usr/bin/env bash
# 把本地图片转成 Data URI (data:<mime>;base64,<payload>)，供 imageUrls 字段使用。
# 后端 imageUrls 兼容三种: HTTP(S) URL / data: URI / 裸 base64，统一输出 data: URI 最稳。
#
#   bash image-to-datauri.sh <图片路径> [<图片路径> ...]
#   bash image-to-datauri.sh --json <图片路径> [<图片路径> ...]   # 输出 JSON 数组, 可直接塞 imageUrls
#
# 也接受 HTTP(S) URL: 原样透传 (后端会自己识别)。
set -euo pipefail

to_datauri() {
  local p="$1"
  if [[ "$p" =~ ^https?:// ]]; then
    printf '%s' "$p"   # URL 原样透传
    return
  fi
  [ -f "$p" ] || { echo "文件不存在: $p" >&2; exit 1; }
  # 推断 mime
  local mime ext
  ext="${p##*.}"; ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
  case "$ext" in
    jpg|jpeg) mime="image/jpeg" ;;
    png)      mime="image/png" ;;
    gif)      mime="image/gif" ;;
    webp)     mime="image/webp" ;;
    bmp)      mime="image/bmp" ;;
    *)        mime="image/jpeg" ;;  # 兜底
  esac
  # base64 编码 (macOS base64 / Linux base64 -w0 都支持; 用 -i 避免换行问题)
  local b64
  if base64 --help 2>&1 | grep -q -- '-w'; then
    b64=$(base64 -w 0 "$p")        # GNU
  else
    b64=$(base64 -i "$p" | tr -d '\n')  # BSD (macOS)
  fi
  printf 'data:%s;base64,%s' "$mime" "$b64"
}

MODE="plain"
files=()
for a in "$@"; do
  case "$a" in
    --json) MODE="json" ;;
    -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) files+=("$a") ;;
  esac
done
[ ${#files[@]} -gt 0 ] || { echo "用法: image-to-datauri.sh [--json] <图片路径|URL> [...]" >&2; exit 1; }

if [ "$MODE" = "json" ]; then
  # 输出 JSON 字符串数组, 每个元素是 data:URI 或 URL, 可直接塞 imageUrls
  printf '['
  for i in "${!files[@]}"; do
    [ "$i" -gt 0 ] && printf ','
    printf '"%s"' "$(to_datauri "${files[$i]}")"
  done
  printf ']'
  echo
else
  for f in "${files[@]}"; do
    to_datauri "$f"
    echo
  done
fi
