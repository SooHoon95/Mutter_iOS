#!/usr/bin/env python3
"""App Store 리뷰 RSS(KR) → marketing/data/reviews.jsonl (신규만 append, id로 dedupe). 리뷰 0건도 정상 종료."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _common import DATA, MARKETING, http_json, load_json, load_state, save_state, today  # noqa: E402

OUT = DATA / "reviews.jsonl"


def fetch(app_id, country, pages=3):
    entries = []
    for page in range(1, pages + 1):
        url = f"https://itunes.apple.com/{country}/rss/customerreviews/page={page}/id={app_id}/sortby=mostrecent/json"
        try:
            feed = http_json(url).get("feed", {})
        except Exception as e:  # 페이지 없음 등 — 수집 실패가 루프를 멈추면 안 된다.
            print(f"  page {page}: {e}", file=sys.stderr)
            break
        e = feed.get("entry", [])
        if isinstance(e, dict):
            e = [e]
        rows = [x for x in e if "im:rating" in x]
        if not rows:
            break
        entries += rows
    return entries


def main():
    cfg = load_json(MARKETING / "watch.json")
    entries = fetch(cfg["app_id"], cfg["country"])
    state = load_state()
    seen = set(state.get("review_ids", []))
    new = []
    for x in entries:
        rid = x["id"]["label"]
        if rid in seen:
            continue
        new.append({
            "id": rid,
            "date": (x.get("updated", {}).get("label") or "")[:10],
            "rating": int(x["im:rating"]["label"]),
            "title": x["title"]["label"],
            "body": x["content"]["label"],
            "version": x.get("im:version", {}).get("label"),
            "author": x.get("author", {}).get("name", {}).get("label"),
            "pulled": today(),
        })
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.touch(exist_ok=True)  # 리뷰가 0건이어도 파일은 존재해야 에이전트 입력 계약이 맞는다.
    if new:
        with open(OUT, "a", encoding="utf-8") as f:
            for r in new:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
    state["review_ids"] = sorted(seen | {r["id"] for r in new})[-500:]
    # 4주 연속 리뷰 0건 → 평점 요청 전략 제안의 근거 카운터. 같은 날 재실행은 세지 않는다(멱등).
    if entries:
        state["zero_review_weeks"] = 0
    elif state.get("last_review_pull") != today():
        state["zero_review_weeks"] = state.get("zero_review_weeks", 0) + 1
    state["last_review_pull"] = today()
    save_state(state)
    avg = round(sum(r["rating"] for r in new) / len(new), 2) if new else None
    print(f"REVIEWS {today()}: 피드 {len(entries)}건, 신규 {len(new)}건, 신규 평균 {avg}, 0건 연속 {state['zero_review_weeks']}주")


if __name__ == "__main__":
    main()
