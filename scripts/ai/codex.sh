#!/bin/zsh
# Claude → Codex 핑퐁. 같은 Codex 스레드를 이어 가며 질문·리뷰·구현을 주고받는다.
#   scripts/ai/codex.sh [-n] [-w] [-a 에이전트] [-m 모델] "요청"   (요청을 생략하면 stdin)
#   -n  새 스레드로 시작(기본: 직전 스레드 이어 가기)
#   -w  파일 수정 허용(workspace-write + 네트워크). 기본은 read-only — 리뷰·의견만.
#   -a  커스텀 에이전트(.codex/agents/<이름>.toml)의 지침으로 실행. 스레드도 에이전트별로 따로 이어 간다.
#       마케팅 작업은 이 경로로만 돈다(.claude/hooks/route-marketing-to-codex.sh).
# 스레드 id는 .ai-pingpong/codex-thread[-<에이전트>]에 둔다(커밋되지 않음). 답은 stdout으로 나온다.
set -u
ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
STATE="$ROOT/.ai-pingpong"; mkdir -p "$STATE"
# Codex 홈 고정 — 마케팅 플러그인이 설치된 곳. 터미널 앱이 CODEX_HOME을 바꿔도 스레드를 이어 갈 수 있게.
export CODEX_HOME="$HOME/.codex"
NEW=0; SANDBOX=read-only; MODEL=(); AGENT=""
while getopts "nwa:m:" o; do
  case $o in n) NEW=1 ;; w) SANDBOX=workspace-write ;; a) AGENT="$OPTARG" ;; m) MODEL=(-m "$OPTARG") ;; *) exit 2 ;; esac
done
shift $((OPTIND - 1))
PROMPT="${*:-$(cat)}"
[ -z "$PROMPT" ] && { echo "요청이 비어 있음" >&2; exit 2; }

cd "$ROOT"  # resume에는 -C가 없다 — 어디서 불러도 저장소 루트 기준으로.
TFILE="$STATE/codex-thread${AGENT:+-$AGENT}"
THREAD=""; [ $NEW = 0 ] && [ -f "$TFILE" ] && THREAD=$(<"$TFILE")

if [ -n "$AGENT" ] && [ -z "$THREAD" ]; then
  # codex exec에는 --agent가 없다 → 새 스레드의 첫 메시지 앞에 에이전트 지침을 붙인다(이어 가기에선 이미 맥락에 있다).
  python3 scripts/ai/sync_codex_agents.py >/dev/null || exit 1
  LEAD=$(python3 -c 'import sys,tomllib;print(tomllib.load(open(sys.argv[1],"rb"))["developer_instructions"])' \
    ".codex/agents/$AGENT.toml") || { echo "에이전트 없음: $AGENT" >&2; exit 2; }
  PROMPT="$LEAD"$'\n\n---\n\n'"$PROMPT"
fi

CFG=(-c "sandbox_mode=\"$SANDBOX\"")
# 쓰기 모드는 iTunes 재조회(curl)·웹 검색이 필요한 작업이 대부분이라 네트워크를 같이 연다. 쓰기 범위는 저장소 안.
[ $SANDBOX = workspace-write ] && CFG+=(-c sandbox_workspace_write.network_access=true -c 'web_search="live"')

# 호출마다 별도 파일 — 동시에 두 번 불러도 서로의 답을 덮어쓰지 않는다. 스레드 파일만 마지막 호출이 이긴다.
OUT=$(mktemp "$STATE/codex-out.XXXXXX"); EVENTS=$(mktemp "$STATE/codex-events.XXXXXX"); ERR=$(mktemp "$STATE/codex-err.XXXXXX")
trap 'rm -f "$OUT" "$EVENTS"' EXIT

# 프롬프트는 stdin(-)으로 넘긴다 — 따옴표·줄바꿈이 섞인 긴 요청도 그대로 간다.
if [ -n "$THREAD" ]; then
  printf '%s\n' "$PROMPT" | codex exec resume "$THREAD" --json -o "$OUT" "${MODEL[@]}" "${CFG[@]}" - >"$EVENTS" 2>"$ERR"
  RC=${pipestatus[2]}
else
  printf '%s\n' "$PROMPT" | codex exec --json -o "$OUT" -C "$ROOT" "${MODEL[@]}" "${CFG[@]}" - >"$EVENTS" 2>"$ERR"
  RC=${pipestatus[2]}
fi
TID=$(sed -n 's/.*"type":"thread.started","thread_id":"\([^"]*\)".*/\1/p' "$EVENTS" | head -1)
[ -n "$TID" ] && print -r -- "$TID" >"$TFILE"
if [ $RC -ne 0 ]; then
  echo "codex 실패 rc=$RC — $ERR" >&2; tail -5 "$ERR" >&2; exit $RC
fi
echo "[codex thread ${TID:-$THREAD} · ${AGENT:-general} · $SANDBOX]"
cat "$OUT"; echo; rm -f "$ERR"
