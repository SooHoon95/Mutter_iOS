---
description: Codex와 핑퐁 — 같은 Codex 스레드에 요청·리뷰·구현을 넘기고 답을 받아 이어서 작업
argument-hint: "[new] [write] <요청>"
---

`scripts/ai/codex.sh`로 Codex에 요청을 넘기고, 답을 읽고 이어서 작업한다. 사용자 요청: $ARGUMENTS

1. 인자 해석
   - 첫 단어가 `new` → `-n`(새 스레드). 없으면 직전 스레드를 이어 간다.
   - `write`가 있으면 `-w`(Codex가 파일 수정). 없으면 read-only — 리뷰·의견·설계 대안만 받는다.
   - 요청이 비어 있으면 지금 대화의 작업(최근 diff, 막힌 지점)을 요약해 "독립 리뷰"를 요청한다.
2. Codex에 보낼 메시지는 자족적으로 쓴다. Codex는 이 대화를 모른다 — 목적, 관련 파일 경로, 확인된 사실, 원하는 응답 형식(예: "문제점을 심각도순 목록으로")을 넣는다. 첫 메시지에는 "이 저장소의 규칙은 AGENTS.md"를 붙인다.
3. 실행: `scripts/ai/codex.sh [-n] [-w] <<'EOF'` … `EOF` (긴 요청은 heredoc). 수 분 걸릴 수 있으니 `run_in_background`로 돌리고 그동안 독립 작업을 한다.
4. 답을 받으면 그대로 믿지 않는다. 지적마다 코드를 확인해 맞음/틀림/보류로 판정하고, 맞는 것만 반영한다. 반박할 게 있으면 같은 스레드로 근거와 함께 되묻는다(핑퐁). 합의되거나 3왕복이면 멈춘다.
5. `write` 모드였으면 `git diff`로 Codex가 바꾼 파일을 직접 검토한 뒤 보고한다.
6. 사용자에게는 한국어로: Codex가 낸 핵심 의견, 내가 반영한 것·기각한 것과 이유, 스레드 id.

반대 방향(Codex → Claude)은 Codex가 `scripts/ai/claude.sh`를 쓴다(`.agents/skills/claude-pingpong`).
