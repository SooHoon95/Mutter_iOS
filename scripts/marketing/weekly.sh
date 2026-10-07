#!/bin/zsh
# 뮤터 주간 마케팅 루프 — launchd(월 09:00 KST)와 수동 실행이 같은 본문을 쓴다.
# 수집(스크립트) → 판단(리드 에이전트 헤드리스) → 알림 → 커밋. Tier 2(발행·스토어 변경)는 하지 않는다.
# 옵션: --collect-only (수집만) · --no-commit
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
export MUTTER_ANDROID_DIR="${MUTTER_ANDROID_DIR:-$ROOT/../Mutter_android}"
DATE=$(date +%F)
mkdir -p marketing/data/logs
LOG="marketing/data/logs/$DATE.log"
exec >>"$LOG" 2>&1
echo "== weekly loop start $(date '+%F %T') =="

if [ -f marketing/LOOP_DISABLED ]; then
  echo "LOOP_DISABLED 존재 — 종료"
  exit 0
fi

COLLECT_ONLY=0; NO_COMMIT=0
for a in "$@"; do
  case "$a" in
    --collect-only) COLLECT_ONLY=1 ;;
    --no-commit) NO_COMMIT=1 ;;
  esac
done

STALE=0
for s in aso_watch reviews_pull season context_sync; do
  if ! python3 "scripts/marketing/$s.py"; then echo "수집 실패: $s"; STALE=1; fi
done
[ $COLLECT_ONLY = 1 ] && { echo "collect-only 종료"; exit 0; }

STATUS=$([ $STALE = 1 ] && echo "STALE(일부 수집 실패 — 변화를 단정하지 말고 stale data로 보고)" || echo "OK")
PROMPT="주간 루프 모드를 실행한다. 오늘 날짜 $DATE. 수집 상태: $STATUS. 입력은 marketing/data/ 아래 파일, 리포트는 marketing/reports/$DATE-weekly.md, 초안은 marketing/queue/. 끝나면 '한눈에' 3줄과 생성 파일 경로만 출력한다."

# 프롬프트는 stdin으로 — --allowedTools 가 가변 인자라 뒤에 오는 위치 인자를 삼킨다.
printf '%s\n' "$PROMPT" | claude -p --agent mutter-marketer --output-format text --permission-mode acceptEdits \
  --allowedTools "Read" "Write" "Edit" "Glob" "Grep" "Skill" "Agent" "WebSearch" "WebFetch" \
    "Bash(python3 scripts/marketing/*)" "Bash(curl *)" "Bash(git log*)" "Bash(git diff*)" "Bash(git status*)" "Bash(date*)" "Bash(ls*)" "Bash(cat *)"
RC=${pipestatus[2]:-$?}
echo "claude rc=$RC"

REPORT="marketing/reports/$DATE-weekly.md"
python3 - "$RC" "$REPORT" <<'PY'
import json, sys, re, pathlib, datetime
rc, report = int(sys.argv[1]), pathlib.Path(sys.argv[2])
p = pathlib.Path("marketing/data/state.json"); st = json.load(open(p))
ok = rc == 0 and report.exists()
st["consecutive_failures"] = 0 if ok else st.get("consecutive_failures", 0) + 1
if ok:
    st["last_run"] = datetime.datetime.now().astimezone().isoformat(timespec="seconds")
    # 카운터는 에이전트가 아니라 여기서 올린다 — 조건 (g) 월간 점검이 LLM의 state 쓰기에 의존하지 않게.
    st["runs"] = st.get("runs", 0) + 1
# handled 정리: 날짜 달린 키(cl:YYYY-MM-DD:…)는 5주 지나면 버리고, 전체는 최근 300개만 유지.
cutoff = (datetime.date.today() - datetime.timedelta(days=35)).isoformat()
def keep(k):
    m = re.match(r"^[a-z]+:(\d{4}-\d{2}-\d{2}):", k)
    return not (m and m.group(1) < cutoff)
st["handled"] = [k for k in st.get("handled", []) if keep(k)][-300:]
json.dump(st, open(p, "w"), ensure_ascii=False, indent=2); open(p, "a").write("\n")
print(f"state: ok={ok} consecutive_failures={st['consecutive_failures']}")
if st["consecutive_failures"] >= 3:
    pathlib.Path("marketing/LOOP_DISABLED").write_text("연속 3회 실패로 자동 비활성화. 로그 확인 후 이 파일을 지우면 재개.\n")
    print("연속 3회 실패 → LOOP_DISABLED 생성")
PY

if [ -f "$REPORT" ]; then
  HEAD3=$(sed -n '/## 한눈에/,/^## /p' "$REPORT" | sed '1d;$d' | head -3 | tr '\n' ' ')
  osascript -e "display notification \"${HEAD3//\"/\\\"}\" with title \"뮤터 주간 마케팅 리포트 $DATE\"" 2>/dev/null || true
  echo "리포트: $REPORT"; echo "$HEAD3"
else
  osascript -e "display notification \"리포트가 생성되지 않았습니다. 로그: $LOG\" with title \"뮤터 마케팅 루프 실패\"" 2>/dev/null || true
fi

if [ $NO_COMMIT = 0 ]; then
  git add marketing/data marketing/reports marketing/queue marketing/aso .agents/product-marketing.md 2>/dev/null
  if ! git diff --cached --quiet; then
    git commit -q -m "chore(marketing-loop): $DATE 주간 루프" && echo "커밋 완료" || echo "커밋 실패"
  else
    echo "커밋할 변경 없음"
  fi
fi
echo "== weekly loop end $(date '+%F %T') rc=$RC =="
exit $RC
