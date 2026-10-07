# marketing-loop

뮤터 주간 마케팅 루프를 지금 실행한다(월요일 자동 실행과 같은 본문). 수집 → 판정 → 실무 위임 → 리포트.

## 작업 순서

1. `marketing/LOOP_DISABLED`가 있으면 "루프 비활성"만 알리고 끝낸다.
2. 월요일 자동 실행과 같은 스크립트를 커밋 없이 돌린다(수집 → Codex 리드 판단·위임 → 리포트). 수 분 걸리므로 `run_in_background`.
   ```bash
   scripts/marketing/weekly.sh --no-commit
   ```
3. 끝나면 `marketing/data/logs/<date>.log` 끝의 `rc=`와 `marketing/data/logs/<date>-codex-last.txt`(리드 최종 응답)를 읽는다. rc≠0이면 로그에서 원인을 찾아 보고한다.
4. 리드가 돌려준 "한눈에" 3줄과 생성 파일 경로를 사용자에게 전달한다. 큐 초안이 있으면 `/marketing-approve <id>` 안내를 붙인다.
5. 커밋은 하지 않는다(자동 실행은 `scripts/marketing/weekly.sh`가 커밋한다). 사용자가 원하면 `/commit`.
