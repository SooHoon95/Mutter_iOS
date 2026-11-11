# 승인 기반 Threads / Instagram 카드 발행

대상은 `@mu_sic_letter` 전용 계정. Meta 앱은 개발 모드 유지. 실제 게시/예약 실행 활성화는 별도 사용자 확인 후에만 한다. Instagram 릴스 경로도 구현됐으며 완성·검증된 MP4가 필수다. 모션 타이포는 원본 앱 녹화 없이 만들 수 있지만 앱 데모에는 실제 녹화가 필요하다.

## 구조와 안전 계약

- 주간 생성: `.claude/agents/mutter-marketer.md` → 카피라이터 → `marketing/queue/*.md`(`draft`). Threads 2편 + Instagram 카드 1편 기본. 스케줄러는 초안 큐를 읽어 게시하지 않는다.
- `/marketing-approve <id>`: 본문/이미지/계정/미래 예약 시각 검수 → preview 해시 확인 → 명시 승인 → 고정 스냅샷 등록. 대안 B/C와 메모는 게시 본문에서 제외.
- 로컬 `marketing/publishing/jobs/`: 승인 당시 JSON + SHA256(본문/대상/시간/이미지 해시). `assets/`: 1080×1350 RGB JPEG 또는 1080×1920/30fps/15초 H.264·AAC MP4, 공개 업로드 전 로컬 고정. Instagram 카드와 릴스는 같은 채널의 하루 한도/미확정 보류를 공유한다. 이 폴더 전체는 gitignore.
- `state/`: `pending → uploading → creating → container_ready → publishing → published`. 호출 의도를 디스크에 먼저 fsync. 종료/타임아웃/5xx로 생성·게시 결과가 불확실하면 `uncertain`에서 멈추며 수동 대조 전 같은 채널의 다른 작업도 보류한다(날짜가 바뀌어도 유지). 자동 재게시하지 않는다. 퍼머링크 실패도 게시 성공을 취소하지 않는다.
- 프로세스 flock, 동일 큐 ID 중복 등록 금지, 전용 계정 ID/username API 대조. 승인 후 이미지/JSON 변경은 실패. SHA256은 변경 감지이며 같은 Mac 사용자의 악의적인 파일 재서명을 방어하는 보안 서명은 아니다.
- 기본 `run`은 dry-run, 네트워크 호출/게시/상태 변경 없음. `--live`만 쓰기 허용. 매 호출 채널별 1건, KST 하루 채널별 1건. 24시간 이상 지난 예약은 `expired_hold`(시즌·시간 재검수). 밀린 초안을 한꺼번에 올리지 않는다.
- 새 실행 시 `PUBLISH_DISABLED`가 있으면 네트워크 없이 중지. 진행 중에는 조회 루프·POST 바로 앞에서 재확인하는 cooperative pause이며 이미 전송된 요청은 취소할 수 없다. sleep은 다음 확인까지 최대 60초 남을 수 있다. API POST 자동 재시도 없음. 단순 GET만 일시 오류 1회 재시도. 이미지 업로드는 불변 콘텐츠 해시 경로, 충돌 시 원격 바이트 비교.

## 최초 설정

`.env.marketing`은 chmod 600, gitignore. 토큰/서비스키를 명령 인자·문서·작업 JSON·로그에 넣지 않는다. env에는 `THREADS_USER_ID/ACCESS_TOKEN`, `IG_USER_ID/ACCESS_TOKEN`, `SUPABASE_URL/SERVICE_ROLE_KEY`, 선택 `MARKETING_EXPECTED_USERNAME=mu_sic_letter`가 필요하다. CLI는 다른 username 설정을 거부하고 개인 계정으로 전환하지 않는다. 앱 비밀키는 기존 로컬 파일에서만 유지한다.

카드 폰트: `marketing/assets/fonts/README.md`. 전역 폰트 설치 없이 Noto Serif CJK KR를 프로젝트에 둔다.

장기 대시보드 토큰 발급 시각/만료 시각은 값 없이 메타데이터만 등록:

```sh
python3 scripts/marketing/social_publish.py register-token threads --issued-at <시간대포함ISO> --expires-at <시간대포함ISO>
python3 scripts/marketing/social_publish.py register-token instagram --issued-at <시간대포함ISO> --expires-at <시간대포함ISO>
python3 scripts/marketing/social_publish.py check
```

`token_state.json`에는 발급/만료/토큰 SHA256 지문만 있다. 공식 응답 만료값이 없으면 확인된 발급일의 59일 뒤처럼 보수적으로 등록한다. 알 수 없는 발급 시각을 추정해 자동 등록하지 않는다. 토큰 교체 후 지문 불일치는 발행 중단·재등록 필요. 장기 토큰은 발급 24시간 이후, 잔여 14일 이하일 때 갱신. 응답 `expires_in`으로 만료 갱신하고 env를 원자 저장한다. 저장 도중 종료해 env/state가 달라지면 수동 복구 전 중단. Instagram debug API는 검증된 계약이 없어 구현하지 않는다.

Meta 대시보드에서 교체한 토큰은 `register-token`도 다시 실행해야 한다. 예약 갱신으로 로컬 env의 토큰이 바뀌면 기존 Vault 사본은 자동 갱신하지 않으므로 env가 최신 정본이다.

## 초안 프리뷰와 승인

Threads: `## 최종`이 있으면 우선, 없으면 `## 추천안`. 카드: `## 카드 제목`, `## 카드 본문`, `## 캡션`. 큐 frontmatter id와 파일명, type/channel이 일치해야 한다. 지원 유형은 `threads/threads`, `instagram_card/instagram`, `instagram_reel/instagram`. 릴스는 `video_file: marketing/video/<slug>/preview.mp4`와 `## 캡션` 필수. 촬영 계획 reel_caption은 자동 게시 유형이 아니다. 수정 본문은 먼저 큐에 확정한다.

```sh
PY=.venv-marketing/bin/python3
$PY scripts/marketing/social_publish.py preview marketing/queue/<id>.md --at 2026-10-13T20:30:00+09:00
# 출력의 전체 본문/이미지/대상/시각을 보고 사용자 승인 후:
$PY scripts/marketing/social_publish.py approve marketing/queue/<id>.md --at 2026-10-13T20:30:00+09:00 --confirmed --preview-sha <사용자가검수한해시>
$PY scripts/marketing/social_publish.py list
$PY scripts/marketing/social_publish.py run                 # dry-run
```

`--text-file`을 썼으면 preview/approve에 같은 파일을 제공한다. 추천: 큐 `## 최종`에 저장하여 흔적 유지. 승인 후 큐는 scheduled, 원장은 pending. 큐 상태 표시 쓰기 실패 시에도 원장의 예약은 유효하며 경고 후 list로 확인한다(중복 재승인 금지). 초안 생성은 발행 승인이 아니다. 초안 승인도 전체 예약 실행 활성화 승인이 아니다. 기존 과거 큐와 릴스 캡션은 자동 전환하지 않는다.

## Mac 예약 실행

실제 Terminal에서 사용자 승인 후 설치:

```sh
cd /Users/choesuhun/Desktop/Code/Mutter
./scripts/marketing/install-social-launchd.sh
```

전용 `.venv-marketing`+Pillow, `com.efreedom.mutter.social-publish` LaunchAgent를 설치한다. 기존 주간 생성 LaunchAgent와 별개다. Desktop TCC 접근은 Terminal `.command` 경로로 처리하며 해당 폴더 접근 권한을 사용자가 허용해야 한다. 설치/재설치 시작 시 의존성 설치보다 먼저 중지하고, 성공·실패 모두 **일시중지 상태** 유지. 자동 실행 즉시 게시 안 함.

검증 후 사용자 동의를 받아 `social_publish.py resume`. 20:30 로컬 시간 타이머 + 5분 간격 재확인. launchd는 `~/Library/Application Support/Mutter/publish-armed`가 있을 때만 Terminal 래퍼를 띄운다(`resume`이 만들고 `pause`가 지움). 중지 상태에서는 창이 뜨지 않는다. 실제 예약 ISO 시각이 기준이고 로그는 `marketing/data/logs/publish-YYYY-MM-DD.log`. 본문/토큰은 로그에 출력하지 않는다. 자신의 단일 탭 창만 tty 확인 후 성공/실패와 관계없이 닫아 오류 창 누적을 줄이며, 오류는 로그에 남긴다. 다른 사용자 창/여러 탭 창은 닫지 않는다(여러 탭으로 여는 Terminal 설정은 실제 설치 시 확인 필요).

Mac 전원 연결 상태에서 잠자기 비활성. 꺼짐/로그아웃 시 실행 불가. 배터리 잠자기는 기존 1분이므로 상시 실행은 충전 상태 권장. macOS가 깨어난 뒤 due 작업을 재확인하지만 24시간 넘은 작업은 보류.

- 전체 일시중지: `social_publish.py pause`.
- 작업 취소: `social_publish.py cancel <job_id>`(게시됨/미확정 작업은 자동 취소 금지).
- 해제: `launchctl bootout gui/$(id -u)/com.efreedom.mutter.social-publish`.
- 상태: `launchctl print gui/$(id -u)/com.efreedom.mutter.social-publish`.

`uncertain` 수동 복구: 먼저 `pause`, 실제 계정에서 본문·시간·이미지로 게시 여부 대조. 게시됐으면 사용자 확인 후 해당 ID/링크·published_at·대조 증거/시각을 원장에 기록하고 `published`로 확정한다. **미게시가 확인됐으면 사용자 승인 아래 기존 state만 `cancelled`로 수동 확정**하고 reason·reconciled_at·대조 증거를 기록한다(approval/job 파일은 변경하지 않는다). old uncertain이 남아 있으면 새 작업도 계속 차단되므로, 원장 대조를 끝낸 뒤에만 새 큐/작업을 새로 검수·승인하고 resume한다. 게시 여부를 확신하지 못하면 계속 보류한다. 같은 작업을 pending으로 되돌리는 자동 명령은 제공하지 않는다.

## 검증

```sh
python3 -m unittest discover -s scripts/marketing/tests
python3 -m py_compile scripts/marketing/{social_api,social_jobs,social_publish,render_card}.py
zsh -n scripts/marketing/{publish,install-social-launchd}.sh
```

이 테스트는 모의 API만 사용한다. `/me` 읽기 확인/카드 로컬 렌더/dry-run으로 실제 계정·로컬 경로를 확인하더라도 실제 업로드·컨테이너·게시 성공은 증명하지 않는다. 실게시 테스트는 별도 승인 전까지 보류한다.

## 릴스 로컬 제작과 검수

`render_reel.py`는 첫 줄 예시의 **고정 15초 모션 시안**이다. 실제 앱 UI를 만들어 내지 않는다. 첫 줄 훅 → 버스/빵집 문장 → 다음에 같이 가고 싶은 말 → 노래 한 곡 문장 → 뮤터/프로필 CTA. 아이보리/모브핑크/명조/종이 질감, 안전 여백, 부드러운 전환. 현재 무음 stereo AAC 트랙이며 SoundCloud 음원·인스타 유행 음원은 사용하지 않는다.

```sh
# 사용자 허용 후 실제 Terminal에서 로컬 렌더·네이티브 smoke·450frame 검수만 수행
/Users/choesuhun/Desktop/Code/Mutter/scripts/marketing/render-motion-reel.command
# 일반 렌더 (새 출력 파일만, 기존 파일 덮어쓰기 안 함)
python3 scripts/marketing/render_reel.py --output marketing/video/<slug>/preview.mp4
python3 scripts/marketing/render_reel.py --probe marketing/video/<slug>/preview.mp4
```

실행 파일은 `marketing/assets/bin/ffmpeg`(같은 Mac 로컬 도구, gitignore), 없으면 `requirements-render-reel.txt`의 플랫폼 wheel에서 binary를 찾는다. executable discovery/version subprocess는 하지 않는다. 인코더가 실제 실행되지 않으면 MP4 완료로 보고하지 않는다. 현재 Aside 환경의 native FFmpeg/Terminal 시작 실패는 독립 브라우저 WebCodecs+Mediabunny 경로로 실제 MP4를 만들고 검증하여 해결했다. 사용자 Terminal 실행은 필요 없다.

검수: 1080×1920·30fps·15초±0.2·H.264/yuv420p progressive·stereo AAC48k·faststart·450개 프레임 전체 디코드. JSON에는 실제 probe 결과를 저장한다. file·pipe 프로토콜/MP4 demuxer만 허용하고 header20초/decode120초/render480초 제한. 잘못된/큰 파일은 해시 전에 거부, SHA는45MiB streaming cap. 승인 시 캡션/MP4 bytes SHA/경로/spec/REELS/피드 표시를 함께 고정한다. GIF/샷리스트/인코딩 설정·mock 테스트만으로 MP4 생성·게시 성공을 주장하지 않는다.

업로드: 실제 승인 후에만 MP4 <=45MiB를 불변 hash 경로로 공개 업로드. create_reel은 video_url·media_type=REELS·caption·share_to_feed=true(릴스와 피드 표시), 기존 Instagram status_code → media_publish 흐름. POST 재시도/미확정 재게시 없음. 공개 버킷 제한에 맞춰45MiB를 보수 적용했다. 네이티브 smoke는 `RUN_REEL_ENCODER_TEST=1`일 때만 실행; 일반 offline suite는 이를 skip하며 실제 렌더 proof를 대신하지 않는다.

### 실제 브라우저 인코딩 시안 (2026-10-11 검증)

완성 파일: `marketing/video/2026-10-11-motion-first-line/preview-browser.mp4`. SHA d22352031129d39b9ef8d46ad92ce83737db6d607c41f408f5762bd1561a0458,4,457,200bytes. PIL 고해상도 450프레임을 Chrome WebCodecs/Mediabunny1.61.3로 H264+무음 stereoAAC48k에 인코딩·MP4 faststart mux. 완성 buffer를 새 Input/VideoSampleSink/AudioSampleSink로 열어 **450프레임·707 AAC 샘플 전체 디코드**, 모든 영상 timestamp=i/30·1080×1920 확인. 영상 트랙15초, AAC padding 포함 파일15.083초. Native HTMLvideo에서도 실제 MP4의5초/14초 seek·장면을 확인했다.

`preview-browser.validation.json`은 동일 macOS 사용자로 실행된 신뢰된 producer의 실제 전체 디코드 기록이며 SHA로 해당 파일에 묶는다. 서명/새 Python 디코더/외부 공급자가 작성한 임의 JSON 검증으로 주장하지 않는다. `reel_validation.py`가 bytes45MiB·cache64KiB 제한으로 실제 MP4/SPS/AAC/샘플 테이블/오프셋을 재검사하여 픽셀420/8bit/progressive·450/30fps·스테레오48k·faststart를 확인한다. sidecar가 있으면 `render_reel.validate_reel/metadata_probe`는 이 경로, 없으면 nativeFFmpeg 경로. 잘못된 sidecar는 fail-closed. 승인 asset은 기존처럼 실제 MP4 SHA/영상 spec을 고정하고 이후 bytes가 달라지면 게시를 거부한다.

사용자 전달본은 `/Users/choesuhun/Downloads/aside/mutter-motion-reel-2026-10-12.mp4` 및 session artifacts. 이 시안의 영상·캡션·@mu_sic_letter·미래 날짜/시각·피드 표시를 사용자에게 보여준 뒤 명시 승인 필요. 실제 업로드/컨테이너/게시/발행 활성화는 아직 하지 않았다.
