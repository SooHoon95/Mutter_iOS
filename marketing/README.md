# marketing/

뮤터 마케팅·영상 산출물. `mutter-marketer`·`mutter-video-director` 에이전트(`.claude/agents/`)가 여기에 쓴다. 공유 제품 컨텍스트는 `.agents/product-marketing.md`.

## 폴더

| 경로 | 내용 |
|---|---|
| `plans/` | 마케팅 플랜·GTM·council 결론 |
| `aso/` | 스토어 리스팅 제안(현재 값 → 제안 → 근거) |
| `copy/` | 스토어·랜딩·캡션 카피 |
| `social/` | 소셜 캘린더·스크립트 |
| `research/` | 경쟁사 프로파일·고객 언어 |
| `video/<slug>/` | 영상 1건: `brief.md` · `concept.md` · `shotlist.md` · `prompts/{veo,kling,seedance}.md` · `hyperframes/`(Hyperframes 프로젝트) |

파일명은 `<yyyy-mm-dd>-<slug>.md`. 렌더 결과(`renders/`, `*.mp4`)와 `node_modules/`는 gitignore.

## 주간 루프 (자동화)

매주 월요일 09:00(KST) launchd가 `scripts/marketing/weekly.sh`를 실행한다. 수집은 스크립트, 판단은 에이전트, 발행·스토어 변경은 사람이 승인한다.

| 단계 | 무엇 | 산출 |
|---|---|---|
| 수집 | `aso_watch.py`(키워드 16개 순위·경쟁앱 2개) · `reviews_pull.py`(리뷰 RSS) · `season.py`(21일 내 시즌) · `context_sync.py`(코드 → 컨텍스트 파일 auto 블록) | `marketing/data/aso/<date>.json`, `latest-diff.json`, `reviews.jsonl`, `season-active.json` |
| 판단 | `claude -p --agent mutter-marketer`(주간 루프 모드) → 행동 조건 판정 → `mutter-aso-analyst`·`mutter-copywriter` 위임 | `marketing/reports/<date>-weekly.md`, `marketing/aso/<date>-analysis.md`, `marketing/queue/*.md`(status: draft) |
| 기록 | macOS 알림 + `chore(marketing-loop): <date>` 커밋(push 없음) | `marketing/data/logs/<date>.log` |

- **승인**: `/marketing-approve <queue-id>` — 프로모션 텍스트는 `fastlane promo_text`(dry-run 먼저), 소셜 글은 붙여넣기용으로 표시.
- **수동 실행**: `/marketing-loop`(대화형) 또는 `scripts/marketing/weekly.sh [--collect-only|--no-commit]`.
- **멈추기**: `touch marketing/LOOP_DISABLED`. 연속 3회 실패하면 스크립트가 스스로 이 파일을 만든다. 재개는 파일 삭제.
- **회귀 테스트**: `scripts/marketing/eval.sh` — 플러그인 업데이트나 에이전트 수정 뒤 5케이스.
- **스케줄 관리**: `launchctl list | grep mutter` · 등록 `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.efreedom.mutter.marketing-loop.plist` · 해제 `launchctl bootout gui/$(id -u)/com.efreedom.mutter.marketing-loop`.
- **왜 Terminal을 거치나**: launchd가 직접 띄운 프로세스는 macOS TCC 때문에 `~/Desktop` 아래 저장소를 읽지 못한다. 그래서 plist는 `open -g -a Terminal "~/Library/Application Support/Mutter/weekly.command"`를 실행하고, 그 래퍼가 `weekly.sh`를 돌린 뒤 자기 창만 닫는다(`-g`: 포커스 탈취 방지). 래퍼 로그 `~/Library/Application Support/Mutter/wrapper.log`. 셸 시작 시 입력을 읽는 프롬프트(oh-my-zsh 업데이트 등)가 있으면 명령 첫 글자를 삼키므로 `.zshrc`에 `zstyle ':omz:update' mode reminder`를 omz 로드 전에 둔다.
- **설정**: 키워드·경쟁앱 `marketing/watch.json`, 시즌 달력 `marketing/calendar.json`, 상태 `marketing/data/state.json`.

## 진입점

- `/marketing <요청>` → mutter-marketer(리드, 임의 요청 모드)
- `/marketing-loop` → 주간 루프 즉시 실행
- `/marketing-approve <id>` → 큐 초안 승인·실행(Tier 2)
- `/video-prompt <요청>` → mutter-video-director

## 스킬·플러그인 설치

마케팅 스킬은 **프로젝트 범위 플러그인**이다. `.claude/settings.json`에 마켓플레이스와 활성화가 선언돼 있어, 저장소를 받아 Claude Code를 열면 설치를 묻는다.

| 플러그인 | 출처 | 스킬 수 |
|---|---|---|
| `marketing-skills` | coreyhaines31/marketingskills (GitHub 52.8K★) | 50 |
| `aso-skills` | eronred/aso-skills | 40 |
| `hyperframes` | claude-plugins-official (user 범위) | 20 |

수동 설치가 필요하면:

```bash
claude plugin marketplace add coreyhaines31/marketingskills
claude plugin marketplace add eronred/aso-skills
claude plugin install marketing-skills@marketingskills --scope project
claude plugin install aso-skills@aso-skills --scope project
# 영상 쪽 전역 스킬(플러그인 없음)
npx skills add replicate/skills -g -y -s prompt-videos
npx skills add square-zero-labs/video-prompting-skill -g -y -s video-prompting
npx skills add parthjadhav/app-store-screenshots -g -y
claude plugin install hyperframes@claude-plugins-official
brew install ffmpeg
```
