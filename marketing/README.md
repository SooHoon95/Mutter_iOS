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

## 진입점

- `/marketing <요청>` → mutter-marketer
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
