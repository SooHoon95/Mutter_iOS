# Object sheets — 「여는 순간」

반복 등장 오브젝트의 고정 묘사. `prompts/veo.md`의 모든 샷에 **verbatim** 삽입한다(`video-prompting`의 character-sheet 원칙 준용 — 오브젝트만 있고 얼굴 없음). 시트를 바꾸면 모든 샷을 함께 바꾼다.

## 오브젝트

```
[DESK] a pale birch writing desk beside a tall window, surface lightly worn, a single ivory linen runner, warm ivory wall behind it
[PHONE] a matte black smartphone with slim bezels; when face up, its screen is a plain evenly lit pale ivory surface with a soft sheen and nothing displayed on it
[LETTER] a single sheet of thick ivory paper, tri-folded, faint illegible serif handwriting in soft focus, a thin soft-mauve ribbon lying loose beside it
[EARBUDS] a pair of small white wireless earbuds resting beside their open white case
[SENDER HAND] a young adult's hand with natural short nails and a thin silver ring on the little finger, sleeve of an oversized cream knit sweater
[RECIPIENT HAND] a young adult's hand with natural short nails and bare fingers, sleeve of a charcoal gray cotton shirt with the cuff unbuttoned
[SIDE TABLE] a small dark walnut side table with a warm ceramic table lamp, a dim evening room behind it
```

## 조명

```
[LIGHT DAY] soft diffused afternoon window light from the left, gentle warm haze, dust motes drifting slowly through the light
[LIGHT EVENING] a single warm table lamp from the right, soft falloff into dim ivory shadows, dust motes drifting slowly in the lamp beam
```

## 고정 스타일 블록 (에이전트 정의 그대로)

```
STYLE (Mutter): warm ivory paper world, background #FFFDF2, ink #221D14 text tones,
accent #C77BAE (soft mauve, can read as muted rose-gold in warm light), serif/Myeongjo typography
for letter text, paper grain, soft window light, drifting dust motes, gentle depth of field,
slow deliberate camera (dolly-in, slow tilt, static with micro-drift), no fast cuts inside a shot,
quiet and intimate — "a letter staged like a small performance". Realistic, filmic, 24fps look,
soft natural color grading, no neon, no HDR punch, no stock-footage gloss.
```

## 레퍼런스 스틸 (선택, Veo 3.1 reference-images용)

Veo 3.1 콘솔이 참조 이미지(최대 3장)를 받으면 아래 스틸을 이미지 모델로 먼저 만들어 모든 샷에 같은 파일을 넣는다. 첫 샷 생성 결과의 마지막 프레임을 다음 샷 첫 프레임으로 쓰는 방식도 같은 효과.

- `ref-desk.png`: `[DESK]` + `[LETTER]` + `[EARBUDS]` + `[PHONE]`(face down) + `[LIGHT DAY]`, 9:16, 사람 없음.
- `ref-sidetable.png`: `[SIDE TABLE]` + `[LETTER]` + `[LIGHT EVENING]`, 9:16, 사람 없음.
- `ref-letter.png`: `[LETTER]` 단독, 펼쳐진 상태, 매크로, 종이결·리본.
