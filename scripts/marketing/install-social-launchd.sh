#!/bin/zsh
# 실제 사용자 Terminal에서 한 번 실행. Aside 샌드박스에서 권한을 우회하지 않는다.
set -eu
REAL_HOME="/Users/choesuhun"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ "$HOME" != "$REAL_HOME" ]]; then
  echo "실제 macOS Terminal에서 실행하세요: $ROOT/scripts/marketing/install-social-launchd.sh" >&2
  exit 2
fi
# 재설치도 의존성 설치/읽기 검증보다 먼저 중지. 이후 실패해도 중지 상태 유지.
mkdir -p "$ROOT/marketing/publishing"
touch "$ROOT/marketing/publishing/PUBLISH_DISABLED"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
python3 -m venv "$ROOT/.venv-marketing"
"$ROOT/.venv-marketing/bin/pip" install -r "$ROOT/scripts/marketing/requirements-publish.txt"
"$ROOT/.venv-marketing/bin/python3" "$ROOT/scripts/marketing/social_publish.py" check
APP_SUPPORT="$HOME/Library/Application Support/Mutter"
AGENTS="$HOME/Library/LaunchAgents"
mkdir -p "$APP_SUPPORT" "$AGENTS"
# Desktop TCC 접근은 기존 주간 루프와 같이 사용자가 권한을 준 Terminal이 맡는다.
ROOT="$ROOT" APP_SUPPORT="$APP_SUPPORT" AGENTS="$AGENTS" python3 - <<'PY'
import os, pathlib, plistlib, shlex
root = pathlib.Path(os.environ['ROOT'])
support = pathlib.Path(os.environ['APP_SUPPORT'])
wrapper = support / 'social-publish.command'
wrapper.write_text('#!/bin/zsh\nset -u\nMY_TTY=$(tty)\n' + shlex.quote(str(root / 'scripts/marketing/publish.sh')) + ' --live\nRC=$?\nif [[ -n ${TERM_SESSION_ID:-} ]]; then\n  osascript -e "tell application \\"Terminal\\"" -e "repeat with w in windows" -e "if (count tabs of w) = 1 then" -e "if tty of selected tab of w is \\"$MY_TTY\\" then close w saving no" -e "end if" -e "end repeat" -e "end tell" >/dev/null 2>&1 || true\nfi\nexit $RC\n')
wrapper.chmod(0o700)
plist = {'Label':'com.efreedom.mutter.social-publish',
 # 발행이 켜졌을 때(social_publish.py resume → publish-armed)만 Terminal을 띄운다. 꺼져 있으면 5분마다 창이 뜨지 않는다.
 'ProgramArguments':['/bin/sh','-c','[ -f "$1" ] || exit 0; exec /usr/bin/open -g -a Terminal "$2"','sh',
                     str(support / 'publish-armed'),str(wrapper)],
 'StartInterval':300, 'StartCalendarInterval':{'Hour':20,'Minute':30},
 'RunAtLoad':False, 'ProcessType':'Background',
 'StandardOutPath':str(support / 'social-launchd.log'),
 'StandardErrorPath':str(support / 'social-launchd.log')}
path = pathlib.Path(os.environ['AGENTS']) / 'com.efreedom.mutter.social-publish.plist'
with path.open('wb') as f: plistlib.dump(plist, f)
path.chmod(0o600)
print(path)
PY
LABEL=com.efreedom.mutter.social-publish
/bin/launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
/bin/launchctl bootstrap "gui/$(id -u)" "$AGENTS/$LABEL.plist"
/bin/launchctl print "gui/$(id -u)/$LABEL"
echo '등록 완료, 발행은 일시중지 상태. 검증·사용자 승인 후 social_publish.py resume. 승인된 시각이 기준이며 20:30 타이머+5분 재확인.'
