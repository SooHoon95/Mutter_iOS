# marketing-approve

`marketing/queue/`의 초안 하나를 승인·실행한다. Tier 2(스토어 변경·발행)는 이 커맨드를 통해서만 일어난다.

## 작업 순서

1. 인자 `$ARGUMENTS`가 큐 id다. 비어 있으면 `marketing/queue/*.md` 중 `status: draft`를 표(id · type · season · 추천안 첫 줄)로 보여주고 하나를 고르게 한다.
2. 해당 파일을 읽고 **추천안 본문 전체**(카드는 카드 제목·카드 본문·캡션)를 사용자에게 보여준다. 길이(자)와 금지어 검사 결과를 함께 적는다.
3. 사용자가 "승인" 또는 수정 본문을 주면:
   - `type: promo_text` → 먼저 `fastlane promo_text text:"<본문>" dry:true`로 확인하고, 사용자가 다시 확인하면 `fastlane promo_text text:"<본문>"`을 실행한다(라이브 버전 프로모션 텍스트, 심사 없음). 성공 로그를 보여준다.
   - `type: threads` · `instagram_card` · `instagram_reel` → 아래 승인 예약 절차를 따른다. 사용자가 실제 프리뷰·계정·미래 예약 시각을 승인해야 한다.
   - `type: reel_caption` → 영상 게시 구현은 아직 없다. 본문을 코드블록으로 보여주고 "촬영/붙여넣기용"이라고 안내한다.
4. 파일 frontmatter를 갱신한다: `status: published`(프로모션 텍스트), `status: scheduled`(Threads/카드 승인 예약 성공) 또는 `status: approved`(붙여넣기), `approved_at: <yyyy-mm-dd>`. 수정 본문은 프리뷰 전에 "## 최종"(Threads) / "## 캡션"(카드)에 확정한다. 게시 결과는 `marketing/publishing/state/` 원장이 정본.
5. 거절이면 `status: rejected`와 이유 한 줄을 적는다.
6. 커밋은 사용자가 원할 때 `/commit`.

## Threads / Instagram 카드·릴스 승인 예약

- `marketing/SOCIAL_PUBLISHING.md`를 읽는다. Python은 `.venv-marketing/bin/python3`(미설치 시 Pillow가 설치된 Python). 릴스 렌더/probe는 프로젝트 로컬 ffmpeg 또는 requirements-render-reel.txt 필요. 렌더 도구의 실행이 막히면 게시하지 말고 [blocked]로 보고한다.
- 사용자가 선택한 B/C 또는 수정 본문을 큐에 먼저 확정한다. 기본은 Threads 추천안/카드 캡션. 카드에는 `## 카드 제목`·`## 카드 본문`·`## 캡션` 필수.
- 게시 대상 **@mu_sic_letter · 채널/형식 · 전체 본문/캡션 · 실제 카드 이미지 또는 끝까지 재생할 수 있는 완성 MP4 · 오디오/피드 표시 설정 · 미래의 정확한 날짜/시각(+09:00)**을 검수한다. 시각을 지정하지 않았으면 물어본다(권장 20:30 KST). 지난 날짜/시즌 초안을 자동 예약하지 않는다.
- `social_publish.py preview marketing/queue/<id>.md --at <ISO시각>` 실행 후 `preview_sha256`·본문·실제 카드 이미지/릴스 MP4를 사용자에게 표시한다. 릴스는 `type: instagram_reel`과 marketing/video/ 아래 `video_file`, 별도 `## 캡션` 필수. GIF/샷리스트/촬영용 reel_caption은 게시 영상이 아니다.
- 이 프리뷰에 대해 명시적으로 승인받은 경우에만 같은 큐/시각으로 `social_publish.py approve ... --confirmed --preview-sha <확인한 해시>` 실행. 큐/이미지/계정/시각이 바뀌면 새 프리뷰로 재승인.
- 예약 파일·고정 해시·예정 시각과 `list`의 pending 상태를 확인한다. 즉시 테스트 게시하지 않는다.
- `PUBLISH_DISABLED`이면 발행 일시중지라고 알려준다. 초안 승인과 전체 발행 활성화(resume)는 별도이며, 확인 없이 설치/resume/실제 테스트 게시하지 않는다.
- `uncertain`은 재게시 없이 실제 계정에서 수동 대조한다. `published`면 미디어 ID/퍼머링크를 확인한다.
