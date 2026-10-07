# marketing

Mutter 마케팅 작업을 Codex의 `mutter-marketer`(리드)에게 맡긴다. 포지셔닝·출시 계획·ASO·카피·광고 소재·소셜 콘텐츠·가격/페이월·경쟁 분석이 대상이다.

## 작업 순서

1. 요청이 비어 있으면 무엇을 할지 한 줄로 묻는다(예: "App Store 부제 3안", "출시 4주 플랜", "인스타 릴스 캡션 5개").
2. Bash로 실행한다(`run_in_background`, 그동안 독립 작업). 같은 주제의 후속이면 `-n`을 빼서 스레드를 이어 간다.
   ```bash
   scripts/ai/codex.sh -n -w -a mutter-marketer <<'REQ'
   $ARGUMENTS
   REQ
   ```
3. 결과가 오면 `git status`로 생성·수정 파일을 확인하고 훑어본다. 컨텍스트 파일(`.agents/product-marketing.md`)과 충돌하는 사실·금지어가 있으면 같은 스레드로 근거와 함께 되돌려 고치게 한다(최대 2왕복).
4. 산출물 경로와 핵심 결론을 한국어로 요약한다. 파일 전체를 다시 붙이지 않는다.
5. 영상 제작 요청이 섞여 있으면 이어서 `/video-prompt`.
