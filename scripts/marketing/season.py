#!/usr/bin/env python3
"""marketing/calendar.json에서 lead_days 안에 들어온 시즌 → marketing/data/season-active.json.

cooldown(state.cooldowns["season:<key>"])이 미래면 "이미 초안 작성됨"으로 표시해 에이전트가 중복 생성하지 않게 한다.
"""
import sys
from datetime import date, datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _common import DATA, MARKETING, load_json, load_state, save_json, today  # noqa: E402


def next_occurrence(d: str, base: date) -> date:
    if len(d) == 10:
        return date.fromisoformat(d)
    m, dd = (int(x) for x in d.split("-"))

    def safe(year):  # 2/29 같은 날짜는 평년에 없다 — 그 해엔 2/28로 당긴다.
        try:
            return date(year, m, dd)
        except ValueError:
            return date(year, m, dd - 1)

    cand = safe(base.year)
    return cand if cand >= base else safe(base.year + 1)


def main():
    cfg = load_json(MARKETING / "calendar.json")
    state = load_state()
    base = date.fromisoformat(today())
    active = []
    for ev in cfg["events"]:
        when = next_occurrence(ev["date"], base)
        days = (when - base).days
        lead = ev.get("lead_days", cfg.get("default_lead_days", 21))
        if 0 <= days <= lead:
            cd = state.get("cooldowns", {}).get(f"season:{ev['key']}")
            drafted = bool(cd and datetime.fromisoformat(cd).date() > base)
            active.append({"key": ev["key"], "name": ev["name"], "date": when.isoformat(), "days_left": days, "hint": ev.get("hint", ""), "already_drafted": drafted})
    active.sort(key=lambda e: e["days_left"])
    save_json(DATA / "season-active.json", {"date": today(), "active": active})
    print(f"SEASON {today()}: 활성 {len(active)}건 " + ", ".join(f"{e['name']}(D-{e['days_left']}{', 초안 있음' if e['already_drafted'] else ''})" for e in active))


if __name__ == "__main__":
    main()
