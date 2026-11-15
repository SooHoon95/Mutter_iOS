# supabase-swift (사본)

- 원본: https://github.com/supabase/supabase-swift 태그 `v2.48.0` (커밋 `e5020ae`), MIT 라이선스(`LICENSE`).
- 가져온 것: `Package.swift`, `Sources/`, `Tests/`, `LICENSE`. 예제·문서·CI 설정은 뺐다. `Package.swift`는 손대지 않았다.

## 왜 사본을 쓰나

Xcode 27.2 SDK의 Foundation은 `Date.>=`와 `Date.<=`를 `@backDeployed(before: iOS 27.2)`로 선언한다.
이 SDK로 빌드한 코드는 OS가 27.2 이상이면 시스템의 구현을 부르는데, **iOS 27.2 초기 베타에는 그 구현이 없어**
없는 주소를 호출하고 죽는다(`EXC_BAD_ACCESS code=1, address=0x0`). 27.1 이하와 27.2 정식은 문제없다.

앱 전체(빌드된 바이너리 98개)에서 이 두 연산자를 쓰는 곳은 supabase-swift의 Auth 모듈 두 군데뿐이었다.

| 파일 | 언제 실행되나 | 증상 |
|---|---|---|
| `Sources/Auth/Internal/APIClient.swift` `handleError` | 로그인 오류 응답(틀린 비밀번호·틀린 코드 등) | 오류 문구 대신 크래시 |
| `Sources/Auth/AuthClient.swift` `setSession` | 카카오·구글 로그인(서버가 준 토큰으로 세션 설정) | 로그인 직후 크래시 |

## 고친 것 (두 줄, `Mutter 패치` 주석으로 표시)

`Date`끼리 `>=`·`<=`로 비교하던 것을 `timeIntervalSince1970`(Double)끼리 비교하도록 바꿨다. 동작은 같다.

## 확인 방법

빌드한 앱에서 아래 두 심볼을 참조하는 바이너리가 없어야 한다(`scripts/check_date_backdeploy.sh`).

- `_$s10Foundation4DateV2geoiySbAC_ACtFZ` (`Date.>=`)
- `_$s10Foundation4DateV2leoiySbAC_ACtFZ` (`Date.<=`)

## 원본으로 되돌리거나 버전을 올릴 때

1. 새 태그를 받아 `Package.swift`·`Sources/`·`Tests/`·`LICENSE`를 덮어쓴다.
2. `grep -rn " >= \| <= " Sources/Auth`로 `Date`끼리 비교하는 줄을 찾아 같은 방식으로 고친다.
3. 빌드 후 `scripts/check_date_backdeploy.sh`가 통과하는지 본다.
4. Apple이 초기 27.2 베타를 더는 배포하지 않고 쓰는 기기도 없다고 판단되면 `Tuist/Package.swift`를 원격 패키지로 되돌리고 이 폴더를 지운다.
