# marketing-loop

뮤터 주간 마케팅 루프를 지금 실행한다(월요일 자동 실행과 같은 본문). 수집 → 판정 → 실무 위임 → 리포트.

## 작업 순서

1. `marketing/LOOP_DISABLED`가 있으면 "루프 비활성"만 알리고 끝낸다.
2. 수집 스크립트를 순서대로 실행한다. 하나라도 실패하면 `STALE`로 표시한다.
   ```bash
   python3 scripts/marketing/aso_watch.py && python3 scripts/marketing/reviews_pull.py && python3 scripts/marketing/season.py && python3 scripts/marketing/context_sync.py
   ```
3. `Agent` 툴로 `subagent_type: mutter-marketer`를 호출한다. 프롬프트: "주간 루프 모드를 실행한다. 오늘 날짜 <yyyy-mm-dd>. 수집 상태: OK|STALE. 입력 파일은 marketing/data/ 아래, 리포트는 marketing/reports/<date>-weekly.md, 초안은 marketing/queue/."
4. 리드가 돌려준 "한눈에" 3줄과 생성 파일 경로를 사용자에게 전달한다. 큐 초안이 있으면 `/marketing-approve <id>` 안내를 붙인다.
5. 커밋은 하지 않는다(자동 실행은 `scripts/marketing/weekly.sh`가 커밋한다). 사용자가 원하면 `/commit`.
