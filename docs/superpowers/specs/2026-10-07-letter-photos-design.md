# 편지 사진 (본문 사이사이 여러 장) — 설계

- 날짜: 2026-10-07
- 범위: Supabase(letter-app 저장소) · 웹 수신 뷰어 · iOS(Mutter) · Android(Mutter_android)
- 결정(사용자): 여러 장 · 본문 사이사이 · 웹/Android 함께 · **비공개 버킷 + 서명 URL**

## 1. 목표

발신자가 편지 본문 단락 사이에 사진을 넣고, 수신자는 웹·iOS·Android 어디서 열어도 같은 위치에서 사진을 본다.
링크를 회수하거나 링크가 만료되면 사진도 볼 수 없어야 한다.

비목표: 사진 캡션, 사진 편집(자르기·필터), 동영상. (웹 작성 화면 업로드는 2026-10-07 사용자 요청으로 범위에 포함 — §6.4)

## 2. 데이터 계약 (세 플랫폼 공통 — 바꾸지 말 것)

`letters.paragraphs` jsonb 배열 요소에 선택 필드 `photo`를 추가한다. 스키마 변경은 없다.

```jsonc
{ "id": "uuid", "order": 2, "text": "", "photo": { "path": "<ownerId>/<letterId>/<uuid>.jpg", "width": 1536, "height": 2048 } }
```

- `photo`가 있는 단락이 사진 블록이다. 이때 `text`는 `""`이고 `cue`는 없다.
- 위치는 `order` 순서 그대로다.
- 구버전 클라이언트는 빈 단락으로 렌더한다. 이 정도는 허용한다.
- 큐(`cue`)는 지금처럼 "첫 텍스트 단락"에 붙는다. 사진 단락에는 붙이지 않는다.
- 제한은 편지당 최대 **5장**이다. 업로드 전에 기기에서 긴 변 **2048px**, JPEG 품질 **0.8**로 줄인다.

## 3. 저장소 (Supabase Storage)

- 버킷 `letter-photos`: `public = false`, `file_size_limit = 10MB`, `allowed_mime_types = {image/jpeg}`.
- 경로는 `<auth.uid()>/<letterId>/<uuid>.jpg`이다. 첫 폴더가 소유자, 둘째 폴더가 편지 id다.
- `storage.objects` RLS(authenticated): `bucket_id = 'letter-photos' and (storage.foldername(name))[1] = auth.uid()::text`이면 insert·select·delete를 허용한다. update는 허용하지 않는다.
- 마이그레이션: `letter-app/supabase/migrations/0034_letter_photos.sql`.

## 4. 서명 URL 발급 — Edge Function `letter-photo-urls`

`POST`이고 `verify_jwt = false`로 배포한다. 함수 안에서 직접 인증한다.

요청은 둘 중 하나다.
- 수신자 모드: `{ "token": string, "password": string | null }`
- 소유자 모드: `{ "letterId": string }`와 `Authorization: Bearer <user JWT>`

처리 순서는 다음과 같다.
1. **수신자 모드**: 사용자 JWT 없이 **anon 클라이언트**로 `get_letter_by_token(token, password)`를 호출한다.
   - 토큰·회수·만료·예약 공개·암호 검사를 그대로 재사용한다. 검증 로직을 복제하지 않는다.
   - `auth.uid()`가 null이라 받은함 저장 부수효과는 생기지 않는다.
   - RPC 에러는 메시지를 그대로 `403 { error }`로 돌려준다.
2. **소유자 모드**: 사용자 JWT로 만든 클라이언트로 `letters`를 `id = letterId`로 select한다(RLS가 소유자만 보장). 결과가 없으면 403을 돌려준다.
3. service role로 `letters.owner_id`를 조회한다. 단락의 `photo.path` 중 `<owner_id>/<letterId>/`로 시작하는 것만 남긴다.
   - 발신자가 jsonb에 남의 경로를 넣어 서명을 받아 가는 것을 막는다.
4. service role로 `createSignedUrls(paths, 3600)`를 호출한다.
5. 응답은 `200 { "urls": { "<path>": "<signedUrl>" }, "expiresIn": 3600 }`이다.

CORS는 웹 수신 뷰어 도메인을 포함해 기존 함수 관례를 따른다.

## 5. 클라이언트 공통 규칙

- 서명 URL은 1시간 동안 유효하다. 이미지 캐시 키는 **path**로 쓴다(URL은 매번 달라진다).
- 뷰어는 본문을 받은 직후 같은 모드로 `letter-photo-urls`를 한 번 호출한다. 실패하면 사진 자리에 차분한 플레이스홀더를 두고 본문은 그대로 보여준다.
- 저장 흐름은 다음 순서로 한다.
  1. 새 편지면 먼저 생성해서 letterId를 확보한다.
  2. 대기 중인 사진을 업로드해 path를 받는다.
  3. paragraphs에 path를 넣어 update한다.
  4. 이전 버전에는 있었지만 지금은 없는 path는 삭제한다(best effort).
  - 업로드가 하나라도 실패하면 저장 실패로 처리하고 사용자에게 알린다. 이미 올라간 객체는 남겨도 된다(다음 저장 때 정리).
- 편지를 삭제하면 `<ownerId>/<letterId>/` 아래 객체도 삭제한다(best effort).

## 6. 플랫폼별

### 6.1 Supabase + 웹 (letter-app)
- `0034_letter_photos.sql`과 `supabase/functions/letter-photo-urls/index.ts`를 만든다.
- `Paragraph` 타입에 `photo?: { path: string; width: number; height: number }`를 추가한다.
- 웹 수신 뷰어(LetterView/Paginated)는 사진 단락을 비율을 유지한 이미지로 렌더한다.
- 웹 작성(useLetterDraft)은 사진 단락을 **보존**해야 한다. 기존 편지를 웹에서 고쳐도 사진이 사라지면 안 된다.
- 배포(마이그레이션 적용, 함수 배포, 웹 배포)는 하지 않는다. 사용자 확인 후 별도로 진행한다.

### 6.2 iOS
- Domain: `LetterBlock` enum(`.text(String)`, `.photo(LetterPhoto)`)과 `LetterPhoto`(`id`, `path: String?`, `width`, `height`, `pendingJPEG: Data?`)를 추가한다.
  - `Letter`·`LetterDraft`·`LetterPayload`는 `blocks`를 갖는다.
  - 기존 호출부를 깨지 않도록 `body`는 텍스트 블록을 `"\n\n"`로 이은 계산 속성으로 유지한다. `init(body:)` 편의 생성자도 유지한다.
- Infrastructure: `LetterContentCodec`이 paragraphs와 blocks를 변환한다.
  - 연속된 텍스트 단락은 하나의 텍스트 블록으로 합친다.
  - 저장할 때는 텍스트 블록을 `"\n\n"` 기준으로 나눠 단락으로 만든다.
  - Storage 업로드·삭제와 Edge Function 호출은 새 Repository(`LetterPhotoRepository`)가 맡는다.
- Compose: 블록 편집기로 바꾼다(텍스트 블록마다 TextEditor, 사진 블록마다 카드와 삭제 버튼). "사진 넣기"는 PhotosPicker를 쓰고, 마지막으로 포커스된 텍스트 블록 뒤에 사진 블록과 빈 텍스트 블록을 넣는다.
- Viewer: 단락 렌더 사이에 사진을 넣는다.

### 6.4 웹 작성 (2026-10-07 추가)
iOS·Android와 같은 블록 편집기를 쓴다(텍스트 블록과 사진 카드, 최대 5장). 브라우저에서 EXIF 방향을 반영해 긴 변 2048px, JPEG 0.8로 줄인 뒤 §5 저장 흐름을 따른다. 저장된 사진의 썸네일은 소유자 모드 서명 URL로 불러온다.

### 6.3 Android
iOS와 같은 모델·흐름으로 구현한다(Photo Picker는 `PickVisualMedia`).

## 7. 검증
- 코덱 단위 테스트(세 플랫폼): 연속 텍스트 병합, 사진 위치 보존, 큐 위치, 구 형식 호환.
- Edge Function: 남의 경로가 걸러지는지, 잘못된 암호면 403인지를 단위 수준으로 확인한다(가능하면 deno test).
- 빌드: iOS `xcodebuild`, Android `assembleDebug`, 웹 `npm run build` + `vitest`.
- 실제 업로드·서명 왕복은 마이그레이션과 함수를 배포한 뒤 실기기에서 확인한다(배포 전 미검증으로 명시).
