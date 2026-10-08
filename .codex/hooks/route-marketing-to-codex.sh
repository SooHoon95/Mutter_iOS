#!/bin/zsh
# PreToolUse(Agent) 훅 — 마케팅·영상 에이전트 호출을 Claude 서브에이전트 대신 Codex로 돌린다.
# 막을 때 exit 2 + stderr 안내 → Claude가 그 안내대로 scripts/ai/codex.sh -a <에이전트>를 실행한다.
# MUTTER_MARKETING_ENGINE=claude 이면 통과(주간 루프의 Claude 폴백·eval.sh용).
[ "${MUTTER_MARKETING_ENGINE:-codex}" = claude ] && exit 0
AGENT=$(python3 -c 'import json,sys;print(json.load(sys.stdin).get("tool_input",{}).get("subagent_type",""))' 2>/dev/null)
case "$AGENT" in
  mutter-marketer|mutter-aso-analyst|mutter-copywriter|mutter-video-director) ;;
  *) exit 0 ;;
esac
cat >&2 <<EOF
마케팅 작업은 Codex가 맡는다($AGENT 서브에이전트 호출 차단). 대신 Bash로 실행한다:
  scripts/ai/codex.sh -w -a $AGENT <<'REQ'
  <원래 Agent 프롬프트 그대로>
  REQ
- 같은 주제의 후속 요청은 -n 없이 같은 스레드를 이어 간다. 주제가 바뀌면 -n.
- 수 분 걸리므로 run_in_background로 돌리고 그동안 독립 작업을 한다.
- 결과가 오면 git status/diff로 Codex가 만든 파일을 확인하고, 사실 오류(컨텍스트 파일과 충돌·금지어)가 있으면 같은 스레드로 되돌려 고치게 한 뒤 한국어로 요약 보고한다.
EOF
exit 2
