#!/bin/zsh
# 사용자 허용 후 실제 Terminal에서 로컬 렌더/검증만 수행. 게시 API는 호출하지 않는다.
set -eu
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
export PATH="/Users/choesuhun/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
FOLDER="$ROOT/marketing/video/2026-10-11-motion-first-line"
mkdir -p "$FOLDER"
exec >>"$FOLDER/render.log" 2>&1
trap 'RC=$?; printf "{\"exit_code\":%s,\"finished_at\":\"%s\"}\n" "$RC" "$(date +%FT%T%z)" > "$FOLDER/render-status.json.tmp"; mv "$FOLDER/render-status.json.tmp" "$FOLDER/render-status.json"' EXIT
printf '== local reel rendering %s ==\n' "$(date '+%F %T %z')"
if [[ "$HOME" != /Users/choesuhun ]]; then
  echo '실제 macOS Terminal 경로가 필요합니다.'
  exit 2
fi
if [[ ! -e "$ROOT/marketing/publishing/PUBLISH_DISABLED" ]]; then
  echo '발행 중지 마커가 없어 로컬 검증을 중단합니다.'
  exit 2
fi
PY="$ROOT/.venv-marketing/bin/python3"
if [[ ! -x "$PY" ]]; then
  echo '전용 Python 환경이 없습니다.'
  exit 2
fi
RUN_REEL_ENCODER_TEST=1 "$PY" -m unittest discover -s scripts/marketing/tests -p test_render_reel.py
"$PY" scripts/marketing/render_reel.py --output "$FOLDER/preview.mp4"
"$PY" scripts/marketing/render_reel.py --probe "$FOLDER/preview.mp4" > "$FOLDER/metadata.json"
"$PY" scripts/marketing/social_publish.py preview marketing/queue/2026-10-12-instagram_reel-motion-first-line.md --at 2026-10-12T20:30:00+09:00 > "$FOLDER/preview-payload.json"
printf '완료: %s (로컬 영상/프리뷰만, 실제 게시 없음)\n' "$FOLDER/preview.mp4"
