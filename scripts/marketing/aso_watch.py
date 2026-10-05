#!/usr/bin/env python3
"""키워드 순위 + 경쟁앱 스냅샷 수집 → marketing/data/aso/<date>.json, latest-diff.json, state.rank_history.

iTunes Search API(KR)는 실제 App Store 검색과 토크나이징이 달라 절대 순위가 아니라 "주간 변화"를 보는 용도다.
행동 조건 판정(3계단 하락 등)은 여기서 숫자로만 표시하고 해석은 에이전트가 한다.
"""
import hashlib
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _common import DATA, MARKETING, itunes_lookup, itunes_search, load_json, load_state, save_json, save_state, today, now_iso  # noqa: E402

ASO_DIR = DATA / "aso"


def rank_of(results, app_id):
    ids = [r.get("trackId") for r in results]
    return ids.index(app_id) + 1 if app_id in ids else None


def snapshot(cfg):
    app_id = cfg["app_id"]
    country = cfg["country"]
    limit = cfg.get("search_limit", 50)

    keywords = {}
    for kw in cfg["keywords"]:
        term = kw["term"]
        time.sleep(1)  # iTunes Search API 예의상 간격 — 수동 재실행이 몰려도 제한에 걸리지 않게.
        res = itunes_search(term, country, limit).get("results", [])
        keywords[term] = {
            "priority": kw.get("priority", False),
            "rank": rank_of(res, app_id),
            "total": len(res),
            "top3": [r.get("trackName", "")[:30] for r in res[:3]],
        }

    ids = [app_id] + [c["id"] for c in cfg["competitors"]]
    rows = {r["trackId"]: r for r in itunes_lookup(ids, country).get("results", [])}
    me = rows.get(app_id, {})
    app = {
        "version": me.get("version"),
        "rating": me.get("averageUserRating"),
        "rating_count": me.get("userRatingCount"),
        "released": (me.get("currentVersionReleaseDate") or "")[:10],
    }
    competitors = {}
    for c in cfg["competitors"]:
        r = rows.get(c["id"], {})
        desc = r.get("description", "") or ""
        competitors[str(c["id"])] = {
            "name": c["name"],
            "track_name": r.get("trackName"),
            "version": r.get("version"),
            "rating": r.get("averageUserRating"),
            "rating_count": r.get("userRatingCount"),
            "updated": (r.get("currentVersionReleaseDate") or "")[:10],
            "description_sha": hashlib.sha1(desc.encode("utf-8")).hexdigest()[:12],
            "release_notes": (r.get("releaseNotes") or "")[:300],
        }
    return {"date": today(), "collected_at": now_iso(), "app": app, "keywords": keywords, "competitors": competitors}


def diff(prev, cur, drop_alert):
    """이전 스냅샷 대비 변화. 숫자만 — 해석은 에이전트."""
    out = {"keyword_changes": [], "competitor_changes": [], "app_changes": []}
    if not prev:
        out["note"] = "첫 스냅샷 — 비교 대상 없음"
        return out
    for term, cur_k in cur["keywords"].items():
        prev_k = prev["keywords"].get(term)
        if not prev_k:
            continue
        a, b = prev_k.get("rank"), cur_k.get("rank")
        if a == b:
            continue
        kind = "lost" if (a is not None and b is None) else "gained" if (a is None and b is not None) else ("drop" if b > a else "rise")
        material = kind in ("lost",) or (kind == "drop" and (b - a) >= drop_alert)
        out["keyword_changes"].append({"term": term, "priority": cur_k.get("priority"), "from": a, "to": b, "kind": kind, "material": material})
    for cid, cur_c in cur["competitors"].items():
        prev_c = prev["competitors"].get(cid)
        if not prev_c:
            continue
        changed = [f for f in ("version", "description_sha", "rating_count") if prev_c.get(f) != cur_c.get(f)]
        if changed:
            out["competitor_changes"].append({"id": cid, "name": cur_c["name"], "fields": changed, "from": {f: prev_c.get(f) for f in changed}, "to": {f: cur_c.get(f) for f in changed}, "release_notes": cur_c.get("release_notes")})
    for f in ("version", "rating", "rating_count"):
        if prev["app"].get(f) != cur["app"].get(f):
            out["app_changes"].append({"field": f, "from": prev["app"].get(f), "to": cur["app"].get(f)})
    return out


def main():
    cfg = load_json(MARKETING / "watch.json")
    if not cfg:
        raise SystemExit("marketing/watch.json 없음")
    cur = snapshot(cfg)
    prev_files = sorted(p for p in ASO_DIR.glob("????-??-??.json") if p.stem != cur["date"])
    prev = load_json(prev_files[-1]) if prev_files else None
    save_json(ASO_DIR / f"{cur['date']}.json", cur)
    # 스냅샷 회전: 최근 26주만 보관(추세는 state.rank_history가 8주, 그 이상은 git 히스토리에 남는다).
    for old_file in sorted(ASO_DIR.glob("????-??-??.json"))[:-26]:
        old_file.unlink()
    d = diff(prev, cur, cfg.get("rank_drop_alert", 3))
    d["date"] = cur["date"]
    d["prev_date"] = prev["date"] if prev else None
    save_json(ASO_DIR / "latest-diff.json", d)

    # 순위 히스토리(최근 8주) — 2주 연속 하락 같은 자가 점검에 쓴다.
    state = load_state()
    hist = state.setdefault("rank_history", {})
    for term, k in cur["keywords"].items():
        series = hist.setdefault(term, [])
        series = [e for e in series if e["date"] != cur["date"]] + [{"date": cur["date"], "rank": k["rank"]}]
        hist[term] = series[-8:]
    save_state(state)

    material = [c for c in d["keyword_changes"] if c["material"]]
    print(f"ASO {cur['date']}: 키워드 {len(cur['keywords'])}개 수집, 변화 {len(d['keyword_changes'])}건(경보 {len(material)}), 경쟁 변화 {len(d['competitor_changes'])}건, 앱 {cur['app']['version']} 평점수 {cur['app']['rating_count']}")
    for k, v in cur["keywords"].items():
        print(f"  {k:8s} rank={v['rank']}/{v['total']}")


if __name__ == "__main__":
    main()
