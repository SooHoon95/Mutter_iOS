#!/bin/sh
# 빌드한 앱(또는 빌드 산출물 폴더)에 `Date.>=`·`Date.<=`의 시스템 구현을 부르는 바이너리가 있는지 검사한다.
#
# 왜: Xcode 27.2 SDK는 이 두 연산자를 @backDeployed(before: iOS 27.2)로 선언한다. 이 SDK로 빌드한 코드는
#     OS가 27.2 이상이면 시스템 구현을 부르는데, iOS 27.2 초기 베타에는 그 구현이 없어 없는 주소를 호출하고 죽는다
#     (EXC_BAD_ACCESS address=0x0). 그래서 Date끼리는 >=·<=로 비교하지 않는다 — timeIntervalSince1970끼리 비교한다.
#     자세한 경위: Vendor/supabase-swift/VENDORED.md
#
# 사용: scripts/check_date_backdeploy.sh <Mutter.app | .xcarchive | 빌드 산출물 폴더>
# 종료 코드: 0 = 참조 없음, 1 = 참조하는 바이너리가 있다(목록을 출력), 2 = 검사할 바이너리를 못 찾았다.
set -u
ROOT="${1:?검사할 경로(.app, .xcarchive, 빌드 산출물 폴더)를 주세요}"
SYMBOLS='s10Foundation4DateV2(ge|le)oiySbAC_ACtFZ$'

count=0
bad=0
# Mach-O 실행 파일·동적 라이브러리만 본다(프레임워크 안의 같은 이름 파일, .dylib, 앱 본체).
find "$ROOT" -type f \( -path "*.framework/*" -o -name "*.dylib" -o -path "*.app/*" \) ! -name "*.plist" ! -name "*.car" 2>/dev/null |
while IFS= read -r f; do
  case "$(file -b "$f" 2>/dev/null)" in
    *Mach-O*) ;;
    *) continue ;;
  esac
  echo "x" >> "${TMPDIR:-/tmp}/check_date_backdeploy.$$.count"
  hits=$(nm -u "$f" 2>/dev/null | grep -E "$SYMBOLS" | sed -E 's/.*DateV2geoi.*/Date.>=/; s/.*DateV2leoi.*/Date.<=/' | sort -u | tr '\n' ' ')
  if [ -n "$hits" ]; then
    echo "참조함: ${f#"$ROOT"/}  ($hits)"
    echo "x" >> "${TMPDIR:-/tmp}/check_date_backdeploy.$$.bad"
  fi
done

C="${TMPDIR:-/tmp}/check_date_backdeploy.$$.count"
B="${TMPDIR:-/tmp}/check_date_backdeploy.$$.bad"
[ -f "$C" ] && count=$(wc -l < "$C" | tr -d ' ')
[ -f "$B" ] && bad=$(wc -l < "$B" | tr -d ' ')
rm -f "$C" "$B"

if [ "$count" -eq 0 ]; then
  echo "검사할 바이너리를 찾지 못했어요: $ROOT"
  exit 2
fi
if [ "$bad" -gt 0 ]; then
  echo "바이너리 ${count}개 중 ${bad}개가 Date.>=·Date.<=의 시스템 구현을 부릅니다. iOS 27.2 초기 베타에서 죽습니다."
  echo "해당 모듈에서 Date끼리의 >=·<= 비교를 timeIntervalSince1970 비교로 바꾸세요."
  exit 1
fi
echo "바이너리 ${count}개 검사 — Date.>=·Date.<= 시스템 구현을 부르는 곳 없음."
