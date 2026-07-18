#!/usr/bin/env bash
# 把本地文件转成 Data URI (data:<mime>;base64,<payload>)，供 imageUrls/videoUrls/audioUrls 字段使用。
# 后端这些字段都兼容: HTTP(S) URL / data: URI / 裸 base64，统一输出 data: URI 最稳。
#
#   bash image-to-datauri.sh <文件路径|URL> [...]                    # 每行一个 data:URI
#   bash image-to-datauri.sh --json <文件路径|URL> [...]             # 输出 JSON 字符串数组
#   bash image-to-datauri.sh --json-obj <文件路径|URL> [...]         # 输出对象数组 [{videoUrl:...}] 供 videoUrls
#
# 也接受 HTTP(S) URL: 原样透传 (后端会自己识别)。
set -euo pipefail

# 推断 mime
mime_of() {
  local p="$1" ext
  ext="${p##*.}"; ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
  case "$ext" in
    jpg|jpeg) printf 'image/jpeg' ;;
    png)      printf 'image/png' ;;
    gif)      printf 'image/gif' ;;
    webp)     printf 'image/webp' ;;
    bmp)      printf 'image/bmp' ;;
    mp4|m4v)  printf 'video/mp4' ;;
    mov)      printf 'video/quicktime' ;;
    webm)     printf 'video/webm' ;;
    avi)      printf 'video/x-msvideo' ;;
    mp3)      printf 'audio/mpeg' ;;
    wav)      printf 'audio/wav' ;;
    m4a)      printf 'audio/mp4' ;;
    aac)      printf 'audio/aac' ;;
    ogg)      printf 'audio/ogg' ;;
    *)        printf 'application/octet-stream' ;;
  esac
}

to_datauri() {
  local p="$1"
  if [[ "$p" =~ ^https?:// ]]; then
    printf '%s' "$p"   # URL 原样透传
    return
  fi
  [ -f "$p" ] || { echo "文件不存在: $p" >&2; exit 1; }
  local mime b64
  mime=$(mime_of "$p")
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
    --json-obj) MODE="json_obj" ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) files+=("$a") ;;
  esac
done
[ ${#files[@]} -gt 0 ] || { echo "用法: image-to-datauri.sh [--json|--json-obj] <文件路径|URL> [...]" >&2; exit 1; }

if [ "$MODE" = "json" ]; then
  # 字符串数组: ["data:...","data:..."], 塞 imageUrls / audioUrls
  printf '['
  for i in "${!files[@]}"; do
    [ "$i" -gt 0 ] && printf ','
    printf '"%s"' "$(to_datauri "${files[$i]}")"
  done
  printf ']\n'
elif [ "$MODE" = "json_obj" ]; then
  # 对象数组: [{"videoUrl":"data:..."},...], 塞 videoUrls
  printf '['
  for i in "${!files[@]}"; do
    [ "$i" -gt 0 ] && printf ','
    printf '{"videoUrl":"%s"}' "$(to_datauri "${files[$i]}")"
  done
  printf ']\n'
else
  for f in "${files[@]}"; do
    to_datauri "$f"
    echo
  done
fi
