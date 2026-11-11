# 뮤터 브랜드 필름 — 「들려줘」

9:16 · 20초 · 인스타 릴스(원본) → 쇼츠·틱톡 재배포
원칙: 기능·앱 화면·설명 자막 0. 사람과 순간만. 슬로건은 마지막 한 줄.

## 한 줄 컨셉

서로 모르는 네 사람이 각자의 자리에서 **같은 노래**를 듣기 시작하는 순간. 누군가 보낸 노래가 그 사람의 표정을 바꾼다.
보는 사람이 상상하는 건 "저 표정을 만든 사람이 나라면".

## 소리 설계 (영상의 뼈대)

- 0~2초: 버스 소음만. 노래 없음.
- 2초: 첫 인물이 이어폰을 꽂는 순간 노래 인트로가 들어온다.
- 이후 장면이 바뀌어도 노래는 끊기지 않고 이어진다 — 네 사람이 같은 곡으로 연결된다.
- 17초: 노래가 숨을 멈추듯 끊기고 무음 + 검은 화면 → 슬로건.
- 음원: 인스타 업로드 시 앱 내 음악으로 얹는다(저작권). 편집은 BPM 80 안팎의 잔잔한 곡 기준 컷.

## 샷리스트

| # | 시간 | 장면 | 감정 |
|---|---|---|---|
| 1 | 0.0–3.5s | 새벽 첫차 버스 창가, 20대 여성. 김 서린 창. 폰이 진동하고 이어폰을 꽂는다. | 지침 → 멈춤 |
| 2 | 3.5–7.0s | 같은 여성 클로즈업. 노래가 들어오자 입꼬리가 천천히 올라가고 눈가가 젖는다. 창밖 가로등이 얼굴을 훑고 지나간다. | 무너짐 |
| 3 | 7.0–10.0s | 좁은 자취방, 20대 남성이 침대 끝에 앉아 고개를 숙인 채 듣다가 손으로 얼굴을 쓸어내린다. 책상 위 컵라면. | 참았던 것 |
| 4 | 10.0–13.0s | 오후 햇살 드는 부엌, 50대 어머니가 폰을 귀 가까이 들고 볼륨을 올린다. 눈을 감고 살짝 몸을 흔든다. | 수줍은 기쁨 |
| 5 | 13.0–16.5s | 해 질 녘 옥상, 보낸 사람(20대). 폰을 내려다보다 고개를 들고 길게 숨을 내쉰다. 바람에 머리카락. 화면은 보이지 않는다. | 안도 |
| 6 | 16.5–20.0s | 검은 화면. 흰 명조 "들려줘." → 0.8초 뒤 작게 "뮤터". | — |

## 룩

- 35mm 필름 질감, 약한 그레인, 낮은 채도, 따뜻한 하이라이트. 자연광만.
- 핸드헬드지만 흔들림 최소. 얕은 심도. 인물 얼굴이 화면 중앙 위쪽(인스타 안전 영역).
- 편집: 컷은 노래 박자에. 화면 전환 효과 없음, 하드컷만.

## 생성 프롬프트 (Veo 3 / Kling / Seedance 공통, 영문)

공통 스타일 꼬리말:
`vertical 9:16, shot on 35mm film, subtle grain, muted colors, warm highlights, natural light only, shallow depth of field, handheld but steady, cinematic, Korean, no text, no phone screen visible, no logos`

1. `Pre-dawn first city bus in Seoul, a tired Korean woman in her 20s sits by a fogged window, streetlights sliding past. Her phone buzzes in her lap; she slowly puts in one wireless earbud and looks at the phone, face unreadable. Medium shot from the seat across the aisle.` + 꼬리말
2. `Extreme close-up of the same Korean woman on the bus as music begins in her ear; the corner of her mouth slowly lifts while her eyes well up, orange streetlight sweeps across her face and away. She does not look at the camera.` + 꼬리말
3. `Small dim studio apartment at night, a Korean man in his 20s sits on the edge of his bed wearing earphones, head bowed, listening; after a moment he slowly drags his hand down over his face and exhales. A cup of instant noodles on the desk, warm desk lamp.` + 꼬리말
4. `Bright afternoon kitchen, sunlight through lace curtains, a Korean mother in her 50s holds her phone close to her ear, turns the volume up with her thumb, closes her eyes and sways slightly, a shy smile. Steam from a pot behind her.` + 꼬리말
5. `Rooftop at golden hour in a Korean residential neighborhood, a young Korean person in their 20s looks down at a phone (screen not visible), then lifts their head toward the sky and lets out a long breath of relief, hair moving in the wind, city soft in the background.` + 꼬리말

각 5초 생성 → 편집에서 필요한 3~3.5초만 쓴다. 인물 일관성이 필요한 1·2번은 같은 시드/레퍼런스 이미지로 생성.

## 편집 (HyperFrames)

생성 클립을 받아 하드컷 타이밍·그레인 통일·마지막 슬로건 타이포·안전 영역을 맞춰 1080×1920 MP4로 렌더한다. 자막 없음.
