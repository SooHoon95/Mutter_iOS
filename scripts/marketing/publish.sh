#!/bin/zsh
# launchd/Terminal이 같은 진입점 사용. 수동 호출 기본 dry-run, --live만 네트워크 쓰기 허용.
set -eu
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
export PATH="/Users/choesuhun/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
PY="$ROOT/.venv-marketing/bin/python3"
if [[ ! -x "$PY" ]]; then
  echo '전용 Python 환경 없음: scripts/marketing/install-social-launchd.sh를 Terminal에서 실행하세요.' >&2
  exit 2
fi
mkdir -p marketing/data/logs
exec >>"marketing/data/logs/publish-$(date +%F).log" 2>&1
printf '== publisher %s ==\n' "$(date '+%F %T %z')"
"$PY" scripts/marketing/social_publish.py run "$@"
