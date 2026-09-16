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

## 새 머신에서 스킬 재설치 (전역)

```bash
npx skills add coreyhaines31/marketingskills -g -y -s product-marketing marketing-plan marketing-council launch aso copywriting copy-editing ad-creative social video content-strategy marketing-psychology customer-research competitor-profiling paywalls pricing referrals analytics image
npx skills add eronred/aso-skills -g -y -s aso-audit keyword-research metadata-optimization screenshot-optimization app-preview-video app-launch seasonal-aso competitor-analysis app-store-featured creator-ugc-marketing rating-prompt-strategy review-management android-aso localization
npx skills add parthjadhav/app-store-screenshots -g -y
npx skills add replicate/skills -g -y -s prompt-videos
npx skills add square-zero-labs/video-prompting-skill -g -y -s video-prompting
claude plugin install hyperframes@claude-plugins-official
brew install ffmpeg   # Hyperframes 렌더
```
