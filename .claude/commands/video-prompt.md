# video-prompt

Mutter 영상 연출·프롬프팅을 Codex의 `mutter-video-director`에게 맡긴다. 티저·런칭·소셜 숏폼·앱 데모 영상의 컨셉→샷리스트→AI 영상 모델 프롬프트(Veo·Kling·Seedance)와 Hyperframes 브리프가 산출물이다.

## 작업 순서

1. 요청이 비어 있으면 목적·플랫폼·길이 세 가지를 한 번에 묻는다(예: "인스타 릴스 15초 티저").
2. Bash로 실행한다(`run_in_background`). 같은 영상의 후속이면 `-n`을 뺀다.
   ```bash
   scripts/ai/codex.sh -n -w -a mutter-video-director <<'REQ'
   $ARGUMENTS
   REQ
   ```
3. 산출물(`marketing/video/<slug>/…`)을 확인하고 추천 모델·다음 단계(렌더 방법)를 한국어로 요약한다.
4. 실제 렌더(`npx hyperframes render`)나 모델 API 호출은 사용자가 명시적으로 요청할 때만 진행한다.
