# 첫 줄은 오늘 있었던 일로: 15초 모션 릴스

- 목적: 편지 첫 줄의 부담을 줄이고, 일상의 구체적인 장면에서 음악 편지로 이어진다.
- 플랫폼: 인스타그램 릴스, 9:16, 1080×1920, 30fps, 정확히 450프레임 / 15초.
- 핵심 메시지: 짧은 편지에 노래 한 곡을 담아요.
- CTA: `뮤터 · 음악 편지 / 프로필 링크에서`.
- Customer Language 참조: “기념일에도, 그냥 네 생각이 난 날에도.” (`.agents/product-marketing.md`).
- 예시 편지는 창작 문장이다. 실제 이용 후기, 사용자의 사적인 편지, 앱 화면을 재현하지 않는다.

## 연출

웜 아이보리 `#FFFDF2`, 잉크 `#221D14`, 모브 `#C77BAE`. 로컬 `marketing/assets/fonts/NotoSerifCJKkr-Regular.otf` 명조를 검증 후 합성한다. 종이 섬유 질감, 부드러운 창빛, 느린 돌리와 미세한 드리프트, 여백과 짧은 문장의 호흡. 상단 270px / 하단 350px을 비우고 모든 글자를 그 안의 안전영역에 둔다. 작은 고정 `@mu_sic_letter`만 보조 표기한다.

원본 클립 없이 Pillow로 장면을 합성한다. 실제 앱 UI, 가짜 플레이어, 버튼, 스마트폰 목업을 만들지 않는다. 추상적인 악보 선/물결은 음악 편지의 이미지일 뿐 기능 시연이 아니다. 컷 사이 약 0.72초 smoothstep 크로스페이드, 빠른 컷/네온/과한 색보정 없음. 승인된 문장은 코드에 고정한다.

## 오디오와 상태

**음소거 검토용 프리뷰.** 모든 장면: 대사 없음, 앰비언스 없음, SFX 없음, 음악 없음. 기술 규격을 위한 48kHz 스테레오 AAC 무음 트랙만 포함한다. SoundCloud나 저작권 음악을 다운로드/생성/삽입하지 않는다. 앱의 음악 재생을 체험하는 영상으로 오인하지 않도록 캡션 및 승인 단계에서도 무음 프리뷰임을 유지한다. 게시/업로드는 이 작업에 포함되지 않는다.

## 실행과 검증

- 런타임: Pillow + `imageio-ffmpeg==0.6.0`의 로컬 FFmpeg(libx264/AAC). 부모가 로컬 휠 바이너리를 `marketing/assets/bin/ffmpeg`에 준비한 경우 이를 우선 사용하므로 Pillow만 설치된 운영 venv에서도 동작한다. 패키지 바이너리 탐색은 별도 20초 제한 프로세스로 실행한다.
- `python3 scripts/marketing/render_reel.py --output <새 경로>/preview.mp4`
- `python3 scripts/marketing/render_reel.py --probe <기존 경로>/preview.mp4`
- `render_reel(output: Path, font_path=DEFAULT_FONT, duration=15, fps=30) -> Path`: 고정 프리뷰만, 기존 파일 덮어쓰기 거부, 원자적 완료 후 반환.
- `metadata_probe(path) -> dict`: 실제 로컬 파일의 헤더/MP4 atom 검사. `validate_reel(path) -> dict`: 규격 검사와 실제 450프레임 디코드 확인.
- H.264, yuv420p, progressive, +faststart(moov가 mdat보다 앞), AAC 48kHz stereo, 최대 45MiB. 렌더 FFmpeg 프로세스 타임아웃 480초, 헤더 20초, 디코드 120초.
- 승인 전 최종 MP4의 SHA-256 및 캡션을 부모 작업에서 고정한다. 이 문서는 렌더 완료나 게시 승인을 주장하지 않는다.
