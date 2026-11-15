#!/usr/bin/env python3
"""주간 리포트의 계획 부분을 노션 "Mutter Marketing" 페이지의 하위 페이지로 올린다.

weekly.sh가 리포트 생성 뒤에 호출한다. 실패해도 루프를 깨지 않도록 항상 0으로 끝난다.
- 토큰: .env.marketing의 NOTION_TOKEN (값은 출력하지 않는다)
- 올릴 곳: .env.marketing의 NOTION_PARENT_PAGE — 페이지 주소를 그대로 넣어도 되고 끝의 32자리 ID만 넣어도 된다.
  저장소가 공개라 워크스페이스 ID를 코드에 적지 않는다. 통합(토큰)이 그 페이지에 연결돼 있어야 한다.
- 같은 날짜는 한 번만 올린다(marketing/data/notion_state.json — 이 컴퓨터에만 두는 기록, git 제외).
사용: notion_weekly.py [YYYY-MM-DD] [--dry-run] [--force]
"""
import datetime
import json
import pathlib
import re
import sys
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
STATE = ROOT / "marketing/data/notion_state.json"
SECTIONS = ["한눈에", "이번 주 초안", "사용자가 결정할 것"]


def env(key):
    for line in (ROOT / ".env.marketing").read_text(encoding="utf-8").splitlines():
        if line.startswith(key + "="):
            return line.split("=", 1)[1].strip().strip("\"'")
    return ""


def parent_page():
    """올릴 페이지의 ID. 주소를 통째로 넣었어도 끝의 32자리만 쓴다(없으면 빈 문자열)."""
    found = re.findall(r"[0-9a-f]{32}", env("NOTION_PARENT_PAGE").split("?")[0].replace("-", ""))
    return found[-1] if found else ""


def page_body(parent, title):
    return {"parent": {"page_id": parent},
            "properties": {"title": {"title": [{"text": {"content": title}}]}}}


def api(token, method, path, body=None):
    req = urllib.request.Request(
        "https://api.notion.com/v1/" + path,
        data=json.dumps(body).encode() if body is not None else None,
        method=method,
        headers={"Authorization": "Bearer " + token, "Notion-Version": "2022-06-28",
                 "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as res:
            return res.status, json.load(res)
    except urllib.error.HTTPError as e:
        return e.code, json.load(e)


def plain(text):
    # 저장소 상대 링크는 노션에서 열리지 않으므로 글자만 남긴다.
    text = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text)
    return text.replace("`", "").strip()


def block(kind, text):
    return {"object": "block", "type": kind,
            kind: {"rich_text": [{"type": "text", "text": {"content": plain(text)[:1900]}}]}}


def blocks_from(report, date):
    out = [block("paragraph", f"주간 루프 자동 생성 · {date} · 원본 marketing/reports/{date}-weekly.md (Mutter 저장소)")]
    for name in SECTIONS:
        m = re.search(rf"^## {re.escape(name)}\n(.*?)(?=^## |\Z)", report, re.S | re.M)
        if not m:
            continue
        out.append(block("heading_2", name))
        for line in m.group(1).strip().splitlines():
            line = line.strip()
            if not line:
                continue
            if line.startswith("- "):
                # 초안 항목은 승인 여부를 체크할 수 있게 할 일로 올린다.
                out.append(block("to_do" if name == "이번 주 초안" else "bulleted_list_item", line[2:]))
            else:
                out.append(block("paragraph", line))
    return out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry, force = "--dry-run" in sys.argv, "--force" in sys.argv
    date = args[0] if args else datetime.date.today().isoformat()
    report_path = ROOT / f"marketing/reports/{date}-weekly.md"
    if not report_path.exists():
        print(f"notion: 리포트 없음 {report_path.name} — 건너뜀")
        return
    state = json.loads(STATE.read_text()) if STATE.exists() else {}
    if date in state and not force:
        print(f"notion: {date} 이미 올림 — 건너뜀")
        return
    title = f"뮤터 주간 계획 {date}"
    children = blocks_from(report_path.read_text(encoding="utf-8"), date)
    if dry:
        print(f"notion dry-run: '{title}' 블록 {len(children)}개")
        for b in children:
            print("  ", b["type"], "|", b[b["type"]]["rich_text"][0]["text"]["content"][:70])
        return
    token = env("NOTION_TOKEN")
    if not token:
        print("notion: NOTION_TOKEN 없음 — 건너뜀")
        return
    parent = parent_page()
    if not parent:
        print("notion: NOTION_PARENT_PAGE 없음 — 건너뜀")
        return
    body = page_body(parent, title)
    body["children"] = children[:100]
    code, res = api(token, "POST", "pages", body)
    if code != 200:
        print(f"notion: 업로드 실패 {code} {res.get('code')} {str(res.get('message'))[:200]}")
        return
    state[date] = {"page_id": res["id"], "url": res.get("url")}
    STATE.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n")
    print(f"notion: 업로드 완료 → {res.get('url')}")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # 루프를 깨지 않는다
        print(f"notion: 예외 {type(e).__name__}: {e}")
