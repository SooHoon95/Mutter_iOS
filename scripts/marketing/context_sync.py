#!/usr/bin/env python3
"""코드에서 제품 사실을 뽑아 .agents/product-marketing.md의 auto 블록을 다시 쓴다.

왜: 컨텍스트 파일이 낡으면 에이전트 전체가 틀린 사실을 믿는다(CC0 폴백 사고). 사람이 기억해서 고치는 대신
버전·색·테마·순위·리뷰는 매 루프마다 코드와 수집 데이터에서 생성한다. 손으로 쓰는 절(포지셔닝·고객 언어)은 건드리지 않는다.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _common import DATA, ROOT, load_json, today  # noqa: E402

CTX = ROOT / ".agents" / "product-marketing.md"
ANDROID = Path(os.environ.get("MUTTER_ANDROID_DIR", ROOT.parent / "Mutter_android"))
BEGIN, END = "<!-- auto:begin -->", "<!-- auto:end -->"
THEMES = ["classic-serif", "modern-minimal", "warm-craft", "night-sky", "spring-day", "vintage-typewriter", "pure-space"]


def git_head() -> str:
    return subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.strip()


def ios_version() -> str:
    m = re.search(r"MARKETING_VERSION = ([\d.]+)", (ROOT / "XCConfigs/MarketingVersion.xcconfig").read_text())
    return m.group(1) if m else "?"


def android_version():
    f = ANDROID / "app/build.gradle.kts"
    if not f.exists():
        return None
    t = f.read_text()
    code = re.search(r"versionCode = (\d+)", t)
    name = re.search(r'versionName = "([^"]+)"', t)
    pkg = re.search(r'applicationId = "([^"]+)"', t)
    return {"versionCode": code and code.group(1), "versionName": name and name.group(1), "package": pkg and pkg.group(1)}


def hex_of(colorset: str):
    f = ROOT / "Projects/UIComponent/Resources/Assets/Colors.xcassets" / f"{colorset}.colorset/Contents.json"
    if not f.exists():
        return None
    c = json.loads(f.read_text())["colors"][0]["color"]["components"]
    def v(k):
        x = c[k]
        return int(x, 16) if x.startswith("0x") else round(float(x) * 255)
    return "#%02X%02X%02X" % (v("red"), v("green"), v("blue"))


def theme_table():
    rows = []
    for t in THEMES:
        camel = "".join(p.capitalize() for p in t.split("-"))
        rows.append(f"| {t} | `{hex_of(camel + 'Bg')}` | `{hex_of(camel + 'Fg')}` | `{hex_of(camel + 'Accent')}` |")
    return "\n".join(rows)


def base_url() -> str:
    m = re.search(r'baseURL = "([^"]+)"', (ROOT / "Projects/AppFoundation/Sources/Define/AppLink.swift").read_text())
    return m.group(1) if m else "?"


def latest_aso():
    files = sorted((DATA / "aso").glob("????-??-??.json"))
    return load_json(files[-1]) if files else None


def review_summary():
    f = DATA / "reviews.jsonl"
    if not f.exists():
        return 0, None
    rows = [json.loads(l) for l in f.read_text().splitlines() if l.strip()]
    avg = round(sum(r["rating"] for r in rows) / len(rows), 2) if rows else None
    return len(rows), avg


def render() -> str:
    aso = latest_aso()
    android = android_version()
    n_reviews, avg = review_summary()
    lines = [BEGIN,
             "## 자동 생성 사실 (코드·수집 데이터 기준 — 손으로 고치지 않는다)",
             "",
             f"- verified_commit: `{git_head()}` · verified_at: {today()} · 생성: `scripts/marketing/context_sync.py`",
             f"- iOS: 저장소 MARKETING_VERSION {ios_version()} · 스토어 라이브 {aso['app']['version'] if aso else '?'}(iTunes lookup) · App Store id 6790086549 · 번들 com.efreedom.mutter",
             (f"- Android: {android['versionName']} (versionCode {android['versionCode']}) · 패키지 {android['package']}" if android else "- Android: (Mutter_android 저장소 미접근 — MUTTER_ANDROID_DIR 확인)"),
             f"- 웹 뷰어 베이스 URL: `{base_url()}` (`AppLink.swift`) · 커스텀 도메인 `[확인 필요]`",
             f"- 브랜드 토큰: Ivory `{hex_of('Ivory')}` · Ink `{hex_of('Ink')}` · Gold(액센트, 실값 모브 핑크) `{hex_of('Gold')}` · GoldDeep `{hex_of('GoldDeep')}` · GoldSoft `{hex_of('GoldSoft')}`",
             "",
             "| 편지지 테마 | Bg | Fg | Accent |", "|---|---|---|---|", theme_table(), ""]
    if aso:
        pri = [(k, v) for k, v in aso["keywords"].items() if v.get("priority")]
        rank = lambda v: f"{v['rank']}/{v['total']}" if v["rank"] else f"미노출/{v['total']}"
        lines += [f"- 키워드 순위(iTunes Search API KR, {aso['date']} — 실제 스토어 순위와 토크나이징이 달라 추세 지표로만): " + " · ".join(f"{k} {rank(v)}" for k, v in pri),
                  f"- 앱 평점: {aso['app']['rating'] or 0} ({aso['app']['rating_count'] or 0}건) · 수집 리뷰 {n_reviews}건" + (f", 평균 {avg}" if avg else ""),
                  "- 경쟁앱: " + " · ".join(f"{c['name']} v{c['version']} {round(c['rating'], 2) if c['rating'] else '—'}★({c['rating_count'] or 0}건, {c['updated']})" for c in aso["competitors"].values())]
    else:
        lines += ["- 키워드 순위: 아직 수집 전(`scripts/marketing/aso_watch.py`)"]
    lines.append(END)
    return "\n".join(lines)


def main():
    text = CTX.read_text(encoding="utf-8")
    if BEGIN not in text or END not in text:
        raise SystemExit("auto 블록 마커가 없다")
    pre, rest = text.split(BEGIN, 1)
    _, post = rest.split(END, 1)
    new = pre + render() + post
    changed = new != text
    CTX.write_text(new, encoding="utf-8")
    print(f"CONTEXT {today()}: auto 블록 {'갱신' if changed else '변화 없음'} · commit {git_head()}")


if __name__ == "__main__":
    main()
