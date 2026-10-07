#!/bin/zsh
# Codex → Claude 핑퐁. 같은 Claude 세션을 이어 가며 질문·리뷰·구현을 주고받는다.
#   scripts/ai/claude.sh [-n] [-w] "요청"   (요청을 생략하면 stdin)
#   -n  새 세션으로 시작(기본: 직전 세션 이어 가기)
#   -w  파일 수정 허용(acceptEdits). 기본은 읽기 도구만 — 리뷰·의견만.
# 세션 id는 .ai-pingpong/claude-session에 둔다. 답은 stdout으로 나온다.
set -u
ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
STATE="$ROOT/.ai-pingpong"; mkdir -p "$STATE"
NEW=0; WRITE=0
while getopts "nw" o; do
  case $o in n) NEW=1 ;; w) WRITE=1 ;; *) exit 2 ;; esac
done
shift $((OPTIND - 1))
PROMPT="${*:-$(cat)}"
[ -z "$PROMPT" ] && { echo "요청이 비어 있음" >&2; exit 2; }

ARGS=(-p --output-format json)
SID=""; [ $NEW = 0 ] && [ -f "$STATE/claude-session" ] && SID=$(<"$STATE/claude-session")
[ -n "$SID" ] && ARGS+=(--resume "$SID")
if [ $WRITE = 1 ]; then
  ARGS+=(--permission-mode acceptEdits)
else
  ARGS+=(--allowedTools "Read" "Glob" "Grep" "Bash(git log*)" "Bash(git diff*)" "Bash(git show*)" "Bash(ls*)")
fi
# 프롬프트는 stdin으로 — --allowedTools가 가변 인자라 뒤의 위치 인자를 삼킨다.
cd "$ROOT"
OUT=$(mktemp "$STATE/claude-out.XXXXXX"); ERR=$(mktemp "$STATE/claude-err.XXXXXX")
trap 'rm -f "$OUT"' EXIT
printf '%s\n' "$PROMPT" | claude "${ARGS[@]}" >"$OUT" 2>"$ERR"
RC=${pipestatus[2]}
python3 - "$STATE" "$RC" "$OUT" "$ERR" <<'PY'
import json, sys, pathlib
st, rc, out, err = pathlib.Path(sys.argv[1]), int(sys.argv[2]), pathlib.Path(sys.argv[3]), sys.argv[4]
try:
    d = json.loads(out.read_text())
except Exception:
    print(f"claude 실패 rc={rc} — {err}", file=sys.stderr); sys.exit(rc or 1)
if d.get("session_id"):
    (st / "claude-session").write_text(d["session_id"])
print(f"[claude session {d.get('session_id')}]")
print(d.get("result", ""))
pathlib.Path(err).unlink(missing_ok=True) if rc == 0 else None
sys.exit(rc or (1 if d.get("is_error") else 0))
PY
