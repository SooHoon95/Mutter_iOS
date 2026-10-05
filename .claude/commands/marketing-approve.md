# marketing-approve

`marketing/queue/`의 초안 하나를 승인·실행한다. Tier 2(스토어 변경·발행)는 이 커맨드를 통해서만 일어난다.

## 작업 순서

1. 인자 `$ARGUMENTS`가 큐 id다. 비어 있으면 `marketing/queue/*.md` 중 `status: draft`를 표(id · type · season · 추천안 첫 줄)로 보여주고 하나를 고르게 한다.
2. 해당 파일을 읽고 **추천안 본문 전체**를 사용자에게 보여준다. 길이(자)와 금지어 검사 결과를 함께 적는다.
3. 사용자가 "승인" 또는 수정 본문을 주면:
   - `type: promo_text` → 먼저 `fastlane promo_text text:"<본문>" dry:true`로 확인하고, 사용자가 다시 확인하면 `fastlane promo_text text:"<본문>"`을 실행한다(라이브 버전 프로모션 텍스트, 심사 없음). 성공 로그를 보여준다.
   - `type: threads` · `reel_caption` → 발행 API가 없다. 본문을 코드블록으로 보여주고 "붙여넣기용"이라고 안내한다.
4. 파일 frontmatter를 갱신한다: `status: published`(프로모션 텍스트) 또는 `status: approved`(붙여넣기), `approved_at: <yyyy-mm-dd>`, 수정 본문이 있으면 "## 최종" 절로 추가.
5. 거절이면 `status: rejected`와 이유 한 줄을 적는다.
6. 커밋은 사용자가 원할 때 `/commit`.
