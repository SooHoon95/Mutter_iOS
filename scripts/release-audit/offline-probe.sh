#!/usr/bin/env bash
# iOS 런타임 캡처 프로브 — release-audit 에이전트의 런타임 패스가 호출.
# iOS는 adb airplane-mode 같은 앱별 오프라인 CLI가 없다. 오프라인은 호스트 Network Link
# Conditioner(시뮬은 호스트 네트워크 스택 공유) 또는 실기기 NLC로 토글하고, 이 스크립트는
# "현재 상태"의 스크린샷 + 크래시 로그만 phase 단위로 캡처한다. 판단은 에이전트(LLM)가 아티팩트로.
#
# 사용법:
#   offline-probe.sh <label> <phase>   # phase: online|offline|recovered  (한 상태 캡처)
#   offline-probe.sh --self-check
#
# ponytail: 시뮬레이터(booted) 기준. 스크린샷은 simctl로 확실히 되고, 오프라인은 호스트 NLC로.
# 실기기 CLI 스크린샷은 환경 의존(libimobiledevice)이라 미지원 — 필요하면 idevicescreenshot 경로 추가.
set -euo pipefail

OUT="${AUDIT_OUT:-$HOME/release-audit-ios}"
mkdir -p "$OUT"
CRASH_DIR="$HOME/Library/Logs/DiagnosticReports"

die() { echo "ERROR: $*" >&2; exit 1; }
command -v xcrun >/dev/null || die "xcrun 없음 — Xcode 설치 확인"

booted_udid() { xcrun simctl list devices booted 2>/dev/null | grep -oE '[0-9A-F-]{36}' | head -1; }

if [ "${1:-}" = "--self-check" ]; then
  U=$(booted_udid || true)
  echo "OK xcode=$(xcodebuild -version 2>/dev/null | head -1) booted_sim=${U:-none}"
  [ -n "${U:-}" ] || echo "  (부팅된 시뮬레이터 없음 — 'xcrun simctl boot <udid>' 후 앱 실행 필요)"
  exit 0
fi

LABEL="${1:?label 필요}"
PHASE="${2:?phase 필요 (online|offline|recovered)}"
UDID=$(booted_udid || true)
[ -n "$UDID" ] || die "부팅된 시뮬레이터가 없습니다. 시뮬 부팅 + 대상 화면 표시 후 재실행."

echo "[$LABEL/$PHASE] 스크린샷 캡처 (sim=$UDID)"
xcrun simctl io "$UDID" screenshot "$OUT/${LABEL}_${PHASE}.png" 2>/dev/null \
  || echo "  (screenshot 실패)"

echo "[$LABEL/$PHASE] 최근 크래시 로그 수집 (최근 2분)"
# 최근 생성된 .ips 크래시 리포트만 (오탐 방지 위해 2분 이내)
find "$CRASH_DIR" -name "*.ips" -mmin -2 2>/dev/null > "$OUT/${LABEL}_${PHASE}_crash_list.txt" || true
CN=$(wc -l < "$OUT/${LABEL}_${PHASE}_crash_list.txt" 2>/dev/null | tr -d ' ')
echo "---"
echo "아티팩트: $OUT/${LABEL}_${PHASE}.png"
echo "요약: 최근 크래시 리포트 ${CN:-0}건"
if [ "$PHASE" = "offline" ]; then
  echo "→ ${LABEL}_offline.png에서 에러페이지 노출 / 알럿 중복(2개↑) / 빈 화면 여부를 에이전트가 판정할 것."
fi
