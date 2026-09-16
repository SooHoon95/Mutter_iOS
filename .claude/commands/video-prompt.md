# video-prompt

Mutter 영상 콘텐츠 연출·프롬프팅을 `mutter-video-director` 에이전트에 위임한다. 티저·런칭·소셜 숏폼·앱 데모 영상의 컨셉→샷리스트→AI 영상 모델 프롬프트(Veo·Kling·Seedance)와 Hyperframes 브리프가 산출물이다.

## 작업 순서

1. `Agent` 툴로 `subagent_type: mutter-video-director`를 호출하고, 아래 요청을 그대로 전달한다.
   - 요청: `$ARGUMENTS`
   - 요청이 비어 있으면 목적·플랫폼·길이 세 가지를 한 번에 묻는다(예: "인스타 릴스 15초 티저").
2. 산출물 경로(`marketing/video/<slug>/…`)와 추천 모델·다음 단계(렌더 방법)를 요약해 전달한다.
3. 실제 렌더(`npx hyperframes render`)나 모델 API 호출은 사용자가 명시적으로 요청할 때만 진행한다.
