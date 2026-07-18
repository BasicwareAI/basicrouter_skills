#!/usr/bin/env bash
# 自检更新：比较本地 VERSION 与 git 远端 VERSION，不一致则提示。
# 非阻塞、非退出，只往 stderr 打一行。被 skill preamble 调用。
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 0

if ! command -v git >/dev/null 2>&1; then exit 0; fi
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then exit 0; fi

LOCAL="$(cat VERSION 2>/dev/null | tr -d '[:space:]')"
# 静默 fetch，3 秒超时，离线/无远端时直接放弃
git fetch --quiet --tags origin 2>/dev/null &
FETCH_PID=$!
( sleep 3 && kill "$FETCH_PID" 2>/dev/null ) &
wait "$FETCH_PID" 2>/dev/null

REMOTE="$(git show origin/HEAD:VERSION 2>/dev/null | tr -d '[:space:]')"
[ -z "$REMOTE" ] && exit 0
if [ "$LOCAL" != "$REMOTE" ]; then
  echo "[skills-media-gen] 有新版本: 本地=$LOCAL 远端=$REMOTE — 运行 cd \"$REPO_ROOT\" && git pull 升级" >&2
fi
