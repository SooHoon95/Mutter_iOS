# Veo 3 / 3.1 prompts — 「여는 순간」 인스타 릴스 15초

샷 5개. 오브젝트 묘사와 STYLE 블록은 `sheets.md`의 것을 verbatim으로 넣었다(시트 변경 시 여기도 함께 갱신).
프롬프트 본문에는 모델명·길이·비율·해상도를 넣지 않는다(`video-prompting` 전역 규칙). 그 값은 아래 "권장 파라미터"로 콘솔/API에 따로 준다.

## 공통 권장 파라미터 (프롬프트 밖)

| 파라미터 | 값 | 메모 |
|---|---|---|
| aspectRatio | `9:16` | 콘솔이 16:9만 제공하면 피사체를 중앙 세로 밴드에 두고 후반 크롭 |
| durationSeconds | Veo 3: `8` 고정 → 편집에서 트림 · Veo 3.1: 샷 1·2·5 = `4`, 샷 3 = `4`, 샷 4 = `6` | 샷 길이(3·3·2·4·3s)보다 길게 뽑아 편집 여유 확보 |
| resolution | `1080p` | 릴스 업로드 기준 |
| generateAudio | `true` | 가이드 트랙 용도. 실제 곡은 후반 교체 |
| personGeneration | `allow_adult` | 손만 등장 |
| seed | 샷별 고정 후 재시도 | 같은 프롬프트 재실행은 결과 변화가 작으므로 변화가 필요하면 프롬프트를 바꾼다 |
| negativePrompt | 아래 공통 NEGATIVE | Veo는 "no ~" 대신 제외 대상 명사 나열을 권장 |

공통 NEGATIVE (negativePrompt 필드에 그대로):
```
legible text, letters, words, subtitles, captions, watermark, logo, app interface, icons, screen reflections, faces, people in background, neon light, HDR glow, lens flare, fast cutting, camera shake, extra fingers, deformed hands, oversaturated color, stock footage gloss
```

공통 STYLE (모든 PROMPT 끝에 포함됨):
```
STYLE (Mutter): warm ivory paper world, background #FFFDF2, ink #221D14 text tones,
accent #C77BAE (soft mauve, can read as muted rose-gold in warm light), serif/Myeongjo typography
for letter text, paper grain, soft window light, drifting dust motes, gentle depth of field,
slow deliberate camera (dolly-in, slow tilt, static with micro-drift), no fast cuts inside a shot,
quiet and intimate — "a letter staged like a small performance". Realistic, filmic, 24fps look,
soft natural color grading, no neon, no HDR punch, no stock-footage gloss.
```

일관성 워크플로(권장): 샷 1을 먼저 뽑고 마지막 프레임을 추출해 샷 2의 첫 프레임(image-to-video)으로 쓴다. 샷 2 → 샷 3도 같은 방식. 샷 4·5는 `sheets.md`의 `ref-sidetable.png`를 참조 이미지로 공유한다. i2v일 때는 프롬프트에서 장면 묘사를 줄이고 움직임·카메라·오디오에 집중한다.

---

## Shot 1 — 떠오르는 사람 (3s, 9:16)
의도(한국어): 노래가 새어 나오는 오후 책상. 손이 접힌 편지에 잠시 머무는 것으로 "떠오르는 사람"을 보여준다. 캡션 1 자리(상단 1/3)를 비운다.

PROMPT:
[CINEMATOGRAPHY] Slow dolly-in at eye level, medium close-up settling into a close-up, shallow depth of field, the upper third of the frame is soft-focus ivory wall left empty.
[SUBJECT] a pale birch writing desk beside a tall window, surface lightly worn, a single ivory linen runner, warm ivory wall behind it; on it a matte black smartphone with slim bezels lying face down, a single sheet of thick ivory paper, tri-folded, faint illegible serif handwriting in soft focus, a thin soft-mauve ribbon lying loose beside it, and a pair of small white wireless earbuds resting beside their open white case.
[ACTION] Nothing moves at first except a slow breath of air lifting the end of the ribbon and dust motes drifting through the light. Then a young adult's hand with natural short nails and a thin silver ring on the little finger, sleeve of an oversized cream knit sweater, enters from the lower right and rests two fingertips lightly on the folded letter, holding still.
[CONTEXT] A quiet apartment in the late afternoon. Soft diffused afternoon window light from the left, gentle warm haze, dust motes drifting slowly through the light.
[STYLE & AMBIANCE] STYLE (Mutter): warm ivory paper world, background #FFFDF2, ink #221D14 text tones, accent #C77BAE (soft mauve, can read as muted rose-gold in warm light), serif/Myeongjo typography for letter text, paper grain, soft window light, drifting dust motes, gentle depth of field, slow deliberate camera (dolly-in, slow tilt, static with micro-drift), no fast cuts inside a shot, quiet and intimate — "a letter staged like a small performance". Realistic, filmic, 24fps look, soft natural color grading, no neon, no HDR punch, no stock-footage gloss.
AUDIO: music — a soft solo piano melody, slow and gentle, heard only as a tiny tinny leak from the earbuds, far away (guide track, replaced in post); Ambient noise: a very quiet room tone with distant muffled city outside; SFX: a faint whisper of paper as the ribbon lifts; dialogue — none. No dialogue, no subtitles.
ON-SCREEN TEXT: none (후반 합성: "좋아하는 노래를 들으면 떠오르는 사람이 있잖아요." · 명조 · 상단 1/3)
NEGATIVE: 공통 NEGATIVE 사용
MODEL NOTES: Veo 3 → 8s 생성 후 앞 3초 사용(손이 들어오는 타이밍이 늦으면 뒤 구간에서 3초 선택). 텍스트-투-비디오로 시작하는 유일한 샷. 마지막 프레임을 추출해 샷 2 첫 프레임으로 쓴다. 이어폰 누출음이 너무 크게 나오면 "barely audible"을 music 줄에 추가.

---

## Shot 2 — 쓴다 (3s, 9:16)
의도(한국어): 폰을 들어 편지를 쓴다. 화면은 빈 아이보리 면으로 두고 실제 작성 화면(R1)을 후반에 합성한다.

PROMPT:
[CINEMATOGRAPHY] Over-the-shoulder high angle looking down at the desk, static camera with a barely perceptible micro-drift, close-up on the phone, shallow depth of field, the upper third of the frame is soft-focus desk surface left empty.
[SUBJECT] a young adult's hand with natural short nails and a thin silver ring on the little finger, sleeve of an oversized cream knit sweater, holding a matte black smartphone with slim bezels; when face up, its screen is a plain evenly lit pale ivory surface with a soft sheen and nothing displayed on it.
[ACTION] The hand lifts the phone from the desk, turns it face up in one unhurried motion, then the thumb hovers and begins to tap slowly and deliberately on the lower half of the blank screen, pausing between taps as if choosing words. The screen stays a plain evenly lit pale ivory surface throughout.
[CONTEXT] a pale birch writing desk beside a tall window, surface lightly worn, a single ivory linen runner, warm ivory wall behind it; the folded ivory letter and the soft-mauve ribbon sit soft-focus at the edge of frame. Soft diffused afternoon window light from the left, gentle warm haze, dust motes drifting slowly through the light.
[STYLE & AMBIANCE] STYLE (Mutter): warm ivory paper world, background #FFFDF2, ink #221D14 text tones, accent #C77BAE (soft mauve, can read as muted rose-gold in warm light), serif/Myeongjo typography for letter text, paper grain, soft window light, drifting dust motes, gentle depth of field, slow deliberate camera (dolly-in, slow tilt, static with micro-drift), no fast cuts inside a shot, quiet and intimate — "a letter staged like a small performance". Realistic, filmic, 24fps look, soft natural color grading, no neon, no HDR punch, no stock-footage gloss.
AUDIO: music — the same soft solo piano melody continuing as a tiny tinny leak from earbuds off-frame (guide track, replaced in post); Ambient noise: quiet room tone; SFX: soft fingertip taps on glass, unevenly spaced, the light rustle of a knit sleeve; dialogue — none. No dialogue, no subtitles.
ON-SCREEN TEXT: none
NEGATIVE: 공통 NEGATIVE + `phone UI, keyboard, text on screen, glowing screen`
MODEL NOTES: 샷 1 마지막 프레임을 첫 프레임으로 넣는 i2v 권장. i2v면 [SUBJECT]·[CONTEXT]를 절반으로 줄이고 [ACTION]·AUDIO만 남긴다. 폰 화면이 흰색으로 날아가면 "matte, slightly darker than the paper" 추가. 화면 합성은 폰 네 모서리 트래킹(DaVinci Fusion/AE) — 화면 각도가 가파를수록 합성이 쉬우므로 하이앵글 유지. 실기기 실촬로 대체 가능(`shotlist.md` 참조).

---

## Shot 3 — 보낸다 (2s, 9:16)
의도(한국어): 보내기 탭 한 번. 손을 떼는 순간 뒤의 종이가 창가로 밀려 "편지가 떠난다"를 물리적으로 보여준다. 피아노가 한 음에서 멈춰 다음 샷의 정적을 만든다.

PROMPT:
[CINEMATOGRAPHY] Extreme close-up with a macro lens, static camera, very shallow depth of field, focus on the thumb and the lower edge of the phone, the upper third of the frame is soft-focus desk and letter.
[SUBJECT] the thumb of a young adult's hand with natural short nails and a thin silver ring on the little finger, sleeve of an oversized cream knit sweater, over a matte black smartphone with slim bezels; when face up, its screen is a plain evenly lit pale ivory surface with a soft sheen and nothing displayed on it.
[ACTION] The thumb presses once at the bottom center of the blank screen and lifts away. In the same instant a breath of air moves through the frame: behind the phone, out of focus, a single sheet of thick ivory paper, tri-folded, faint illegible serif handwriting in soft focus, a thin soft-mauve ribbon lying loose beside it, slides a few centimeters toward the window as if nudged, the ribbon trailing after it, then settles.
[CONTEXT] a pale birch writing desk beside a tall window, surface lightly worn, a single ivory linen runner, warm ivory wall behind it. Soft diffused afternoon window light from the left, gentle warm haze, dust motes drifting slowly through the light.
[STYLE & AMBIANCE] STYLE (Mutter): warm ivory paper world, background #FFFDF2, ink #221D14 text tones, accent #C77BAE (soft mauve, can read as muted rose-gold in warm light), serif/Myeongjo typography for letter text, paper grain, soft window light, drifting dust motes, gentle depth of field, slow deliberate camera (dolly-in, slow tilt, static with micro-drift), no fast cuts inside a shot, quiet and intimate — "a letter staged like a small performance". Realistic, filmic, 24fps look, soft natural color grading, no neon, no HDR punch, no stock-footage gloss.
AUDIO: music — the faint earbud piano plays two more notes and stops on a single held note that fades (guide track, replaced in post); Ambient noise: quiet room tone; SFX: one soft fingertip tap on glass, then a dry whisper of paper sliding across linen; dialogue — none. No dialogue, no subtitles.
ON-SCREEN TEXT: none
NEGATIVE: 공통 NEGATIVE + `phone UI, buttons, text on screen, glowing screen`
MODEL NOTES: 샷 2 마지막 프레임 i2v 권장. 2초만 쓰므로 Veo 3.1은 4s, Veo 3은 8s 생성 후 탭 순간 기준으로 2초 선택. 종이 이동이 과하면 "slides barely two centimeters"로 줄인다. 탭 SFX가 안 나오면 "SFX: a single soft tap" 줄을 프롬프트 앞쪽으로 옮긴다.

---

## Shot 4 — 여는 순간 (4s, 9:16) · 히어로 샷
의도(한국어): 다른 방, 저녁. 수신자가 폰을 내려놓자 접힌 편지가 스스로 펼쳐지고 음악이 차오른다. 이 샷 하나가 핵심 메시지다. 캡션 2 자리(상단 1/3)를 비운다.

PROMPT:
[CINEMATOGRAPHY] Low angle, slow dolly-in from a medium close-up to a close-up, shallow depth of field, the folded letter at the center of the lower two thirds, the upper third of the frame is soft-focus dim ivory wall left empty.
[SUBJECT] a single sheet of thick ivory paper, tri-folded, faint illegible serif handwriting in soft focus, a thin soft-mauve ribbon lying loose beside it, resting on a small dark walnut side table with a warm ceramic table lamp, a dim evening room behind it.
[ACTION] A young adult's hand with natural short nails and bare fingers, sleeve of a charcoal gray cotton shirt with the cuff unbuttoned, enters from the right and sets down a matte black smartphone with slim bezels face up beside the letter; its screen is a plain evenly lit pale ivory surface with a soft sheen and nothing displayed on it, glowing softly out of focus. The hand withdraws. The folded letter begins to open by itself, slowly: the top fold lifts and lays back, then the second fold, the paper flexing and settling flat with a gentle spring, the illegible handwriting catching the lamp light, the soft-mauve ribbon slipping off to one side. Dust motes swirl upward through the lamp beam as the paper opens.
[CONTEXT] A quiet evening room. A single warm table lamp from the right, soft falloff into dim ivory shadows, dust motes drifting slowly in the lamp beam.
[STYLE & AMBIANCE] STYLE (Mutter): warm ivory paper world, background #FFFDF2, ink #221D14 text tones, accent #C77BAE (soft mauve, can read as muted rose-gold in warm light), serif/Myeongjo typography for letter text, paper grain, soft window light, drifting dust motes, gentle depth of field, slow deliberate camera (dolly-in, slow tilt, static with micro-drift), no fast cuts inside a shot, quiet and intimate — "a letter staged like a small performance". Realistic, filmic, 24fps look, soft natural color grading, no neon, no HDR punch, no stock-footage gloss.
AUDIO: music — silence at first, then as the paper begins to open a soft solo piano melody enters faintly and blooms to full warm presence in the room, unhurried, in step with the paper unfolding (guide track, replaced in post); Ambient noise: a quiet evening room, a faint clock ticking far away; SFX: crisp paper crackle as each fold opens, a soft settle as the sheet lies flat, the light tap of the phone touching wood; dialogue — none. No dialogue, no subtitles.
ON-SCREEN TEXT: none (후반 합성: "받는 사람이 편지를 여는 순간, 그 음악이 함께 흐릅니다." · 명조 · 샷 후반 2초 · 상단 1/3)
NEGATIVE: 공통 NEGATIVE + `hands touching the letter while it opens, paper tearing, wind blowing objects`
MODEL NOTES: 텍스트-투-비디오 또는 `ref-sidetable.png` 참조 이미지. Veo 3.1은 6s, Veo 3은 8s 생성 후 종이가 열리는 4초 구간 선택. 종이가 안 열리면 [ACTION]에서 폰 내려놓기를 빼고 "the letter is already beginning to open as the shot starts"로 단순화. 피아노 상승이 종이와 어긋나면 후반에서 실제 곡으로 맞추므로 시각 우선으로 고른다. 손이 종이를 만지는 결과가 나오면 NEGATIVE 추가분을 프롬프트 [ACTION] 끝에 "the hand stays clear of the letter"로 옮긴다.

---

## Shot 5 — 남는다 (3s, 9:16)
의도(한국어): 펼쳐진 편지 위의 빛과 종이결. 손끝이 가장자리에 머문다. 음악이 마지막 코드로 정리되고 상단에 엔드카드가 올라간다.

PROMPT:
[CINEMATOGRAPHY] Extreme close-up with a macro lens, a very slow tilt down that comes to rest, very shallow depth of field, the upper third of the frame is soft-focus dim ivory wall left empty for the whole shot.
[SUBJECT] a single sheet of thick ivory paper lying fully open and flat, faint illegible serif handwriting in soft focus, visible paper grain, a thin soft-mauve ribbon curled at one corner, on a small dark walnut side table with a warm ceramic table lamp, a dim evening room behind it.
[ACTION] The fingertips of a young adult's hand with natural short nails and bare fingers, sleeve of a charcoal gray cotton shirt with the cuff unbuttoned, rest on the bottom edge of the page and stay still. Dust motes drift slowly through the lamp beam. Nothing else moves.
[CONTEXT] A quiet evening room. A single warm table lamp from the right, soft falloff into dim ivory shadows, dust motes drifting slowly in the lamp beam.
[STYLE & AMBIANCE] STYLE (Mutter): warm ivory paper world, background #FFFDF2, ink #221D14 text tones, accent #C77BAE (soft mauve, can read as muted rose-gold in warm light), serif/Myeongjo typography for letter text, paper grain, soft window light, drifting dust motes, gentle depth of field, slow deliberate camera (dolly-in, slow tilt, static with micro-drift), no fast cuts inside a shot, quiet and intimate — "a letter staged like a small performance". Realistic, filmic, 24fps look, soft natural color grading, no neon, no HDR punch, no stock-footage gloss.
AUDIO: music — the soft solo piano resolves on one gentle final chord and holds, slowly fading (guide track, replaced in post); Ambient noise: a quiet evening room; SFX: none; dialogue — none. No dialogue, no subtitles.
ON-SCREEN TEXT: none (후반 합성 엔드카드: 뮤터 로고 + "링크로 편지 보내기" · 서브카피 `[mutter-marketer 카피 필요]` · 상단 1/3)
NEGATIVE: 공통 NEGATIVE
MODEL NOTES: 샷 4 마지막 프레임 i2v 권장(종이·리본 위치 연속). 정지에 가까운 샷이므로 Veo 3.1은 4s로 충분. 손이 움직이면 "the hand is completely still"을 [ACTION] 앞에 둔다. 엔드카드가 올라갈 상단 1/3이 밝은 벽으로 나오면 후반에서 약간 어둡게 그레이딩해 흰 로고 대비를 확보한다.

---

## 편집 노트

- 순서·길이: 1(3s) → 2(3s) → 3(2s) → 4(4s) → 5(3s) = 15s. 하드컷 4회.
- 실제 곡: 샷 1–3은 이어폰 누출음처럼 로우패스 + 볼륨 낮게, 샷 4 종이 첫 폴드에서 풀 사운드로 열고, 샷 5에서 종결. Veo 가이드 트랙은 타이밍 참고 후 전부 제거.
- 무음 버전: 곡을 빼고 SFX(종이·탭)만 남긴 버전을 함께 내보낸다(인스타 음원 라이브러리 사용 대비).
- 캡션 2줄·엔드카드: Hyperframes(`general-video`) 또는 DaVinci Resolve. 판단은 `brief.md` "Hyperframes 분기 판단".

## Kling · Seedance 변형 (요청 범위 밖 — 필요 시)

요청이 Veo 기준이라 작성하지 않았다. 필요하면 같은 샷리스트·시트로 `prompts/kling.md`(모션 강도 낮음 · 카메라 프리셋 dolly-in) · `prompts/seedance.md`(샷 3→4를 타임코드 멀티샷 하나로 묶기)를 추가한다.
