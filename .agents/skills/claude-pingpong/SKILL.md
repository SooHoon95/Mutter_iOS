---
name: claude-pingpong
description: Claude Code와 핑퐁 — 같은 Claude 세션에 리뷰·의견·구현을 요청하고 답을 받아 이어서 작업한다. 사용자가 "클로드한테 물어봐", "클로드 리뷰", "핑퐁", "교차 검토"라고 하거나, 사소하지 않은 변경을 커밋하기 전 독립 리뷰가 필요할 때 쓴다.
---

# Claude 핑퐁

`scripts/ai/claude.sh`로 Claude Code(헤드리스)에 요청을 넘긴다. 직전 세션을 이어 가므로 왕복할수록 맥락이 쌓인다.

```sh
scripts/ai/claude.sh -n <<'EOF'      # 새 세션
<목적 · 관련 파일 경로 · 확인된 사실 · 원하는 응답 형식>
EOF
scripts/ai/claude.sh "<후속 질문>"    # 같은 세션 이어 가기
scripts/ai/claude.sh -w "<구현 요청>" # 파일 수정 허용(acceptEdits)
```

- 기본은 읽기 전용(Read·Glob·Grep·git log/diff/show). 리뷰·의견에는 이것으로 충분하다.
- 샌드박스: Claude는 네트워크와 `~/.claude` 쓰기가 필요하다. `workspace-write` + `sandbox_workspace_write.network_access=true`로 실행 중이 아니면 승인(escalation)을 요청해 실행한다.
- 요청은 자족적으로 쓴다. Claude는 이 대화를 모른다. 첫 메시지에 "이 저장소 규칙은 CLAUDE.md"를 붙인다.
- 답은 그대로 믿지 않는다. 지적마다 코드를 확인해 맞음/틀림/보류로 판정하고 맞는 것만 반영한다. 반박은 같은 세션에 근거와 함께. 합의되거나 3왕복이면 멈춘다.
- `-w`로 맡겼으면 `git diff`로 바뀐 파일을 직접 검토한다.
- 사용자 보고는 한국어로: Claude의 핵심 의견, 반영/기각과 이유, 세션 id(`.ai-pingpong/claude-session`).
