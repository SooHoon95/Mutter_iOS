"""마케팅 루프 스크립트 공통 — 표준 라이브러리만 쓴다(에이전트 없이 cron에서 도는 결정적 수집 단계)."""
import json
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MARKETING = ROOT / "marketing"
DATA = MARKETING / "data"
STATE_PATH = DATA / "state.json"
KST = timezone(timedelta(hours=9))


def today() -> str:
    return datetime.now(KST).strftime("%Y-%m-%d")


def now_iso() -> str:
    return datetime.now(KST).isoformat(timespec="seconds")


def load_json(path: Path, default=None):
    if not path.exists():
        return default
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def load_state() -> dict:
    return load_json(STATE_PATH, {})


def save_state(state: dict) -> None:
    save_json(STATE_PATH, state)


def http_json(url: str, timeout: int = 20, retries: int = 1):
    """GET → JSON. 일시 오류는 5초 뒤 1회 재시도 — 타임아웃 한 번에 주간 루프 전체가 stale이 되지 않게."""
    req = urllib.request.Request(url, headers={"User-Agent": "mutter-marketing-loop/1.0"})
    for attempt in range(retries + 1):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as res:
                return json.loads(res.read().decode("utf-8"))
        except Exception:
            if attempt >= retries:
                raise
            time.sleep(5)


def itunes_search(term: str, country: str, limit: int):
    q = urllib.parse.urlencode({"country": country, "entity": "software", "limit": limit, "term": term})
    return http_json(f"https://itunes.apple.com/search?{q}")


def itunes_lookup(ids, country: str):
    q = urllib.parse.urlencode({"id": ",".join(str(i) for i in ids), "country": country})
    return http_json(f"https://itunes.apple.com/lookup?{q}")


def fail(msg: str, code: int = 2) -> None:
    print(f"ERROR {msg}", file=sys.stderr)
    sys.exit(code)
