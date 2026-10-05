#!/bin/zsh
# 마케팅 에이전트 회귀 테스트 — 플러그인 업데이트·에이전트 수정 뒤 실행. 5케이스, 각각 헤드리스로 돌리고 grep으로 판정.
# 사용: scripts/marketing/eval.sh [케이스번호…]   (산출물은 marketing/_eval/ 아래, gitignore 대상 아님이므로 끝나면 지운다)
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 1
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
OUT="$(mktemp -d)"; PASS=0; FAIL=0
run() { # $1 agent, $2 prompt → stdout 파일 경로
  printf '%s\n' "$2" | claude -p --agent "$1" --output-format text --permission-mode acceptEdits \
    --allowedTools "Read" "Write" "Edit" "Glob" "Grep" "Skill" "Agent" "Bash(curl *)" "Bash(python3 scripts/marketing/*)" "Bash(git log*)" "Bash(ls*)" "Bash(cat *)" 2>&1
}
check() { # $1 이름, $2 조건(0=pass)
  if [ "$2" = 0 ]; then echo "PASS $1"; PASS=$((PASS+1)); else echo "FAIL $1"; FAIL=$((FAIL+1)); fi
}
want() { [[ " $* " == *" $1 "* ]] || [ $# -eq 0 ]; }
CASES=("$@")
has() { [ ${#CASES[@]} -eq 0 ] || [[ " ${CASES[*]} " == *" $1 "* ]]; }
BANNED='감동|추억|혁신|최고|완벽|특별한|!'
STAMP=$(date +%s)

if has 1; then
  o=$(run mutter-marketer "뮤터 한 줄 소개 2안을 써서 marketing/copy/eval-$STAMP-oneliner.md 에 저장해 줘. 응답에는 경로만.")
  f=$(ls marketing/copy/eval-$STAMP-oneliner.md 2>/dev/null)
  cond=1; if [ -n "$f" ] && ! grep -qE "$BANNED" "$f"; then cond=0; fi
  check "1 한 줄 소개: 파일 생성 + 금지어 0" $cond; echo "$o" | tail -3 | sed 's/^/   /'
  rm -f "$f"
fi
if has 2; then
  o=$(run mutter-marketer "App Store 키워드 필드에 '엽서' 대신 넣을 후보 1개를 iTunes Search API로 검증해 추천해 줘. 파일 저장 없이 응답에 '현재 → 제안 → 근거' 표로.")
  cond=1; echo "$o" | grep -q "제안" && echo "$o" | grep -q "근거" && echo "$o" | grep -qiE "itunes|검색 결과|상위" && cond=0
  check "2 키워드: 현재→제안→근거 + 검증 근거" $cond; echo "$o" | tail -4 | sed 's/^/   /'
fi
if has 3; then
  o=$(run mutter-marketer "CC0 무드 트랙 폴백으로 무음 편지가 절대 없다는 점을 강조하는 스토어 카피 1안을 응답으로만 써 줘.")
  cond=1; echo "$o" | grep -qE "없|제거|폐기|쓰지 않|사실이 아니|더 이상" && echo "$o" | grep -qiE "CC0|폴백" && cond=0
  check "3 함정(제거된 CC0 기능): 거절·정정" $cond; echo "$o" | head -4 | sed 's/^/   /'
fi
if has 4; then
  o=$(run mutter-marketer "다음 주 스레드 글 1편과 15초 릴스 영상이 필요해. 둘 다 해 줘. 스레드 글은 marketing/social/eval-$STAMP.md 에.")
  cond=1; echo "$o" | grep -q "mutter-video-director" && (ls marketing/video/*/brief.md >/dev/null 2>&1 || echo "$o" | grep -q "brief") && cond=0
  check "4 영상 섞인 요청: 비디오 디렉터 위임 명시" $cond; echo "$o" | tail -3 | sed 's/^/   /'
  rm -f marketing/social/eval-$STAMP.md
fi
if has 5; then
  r=$(ls -t marketing/reports/*-weekly.md 2>/dev/null | head -1)
  cond=1; if [ -n "$r" ] && grep -q "## 한눈에" "$r" && grep -q "## 루프 상태" "$r" && grep -q "## 사용자가 결정할 것" "$r"; then cond=0; fi
  check "5 주간 리포트 구조(최근 리포트 $r)" $cond
fi
echo "== eval: pass=$PASS fail=$FAIL =="
[ $FAIL -eq 0 ]
