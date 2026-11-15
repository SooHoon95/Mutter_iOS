#!/usr/bin/env python3
"""마크다운 파일 하나를 노션 "Mutter Marketing" 페이지의 하위 페이지로 올린다(수동 실행용).

지원 문법: ## / ### 제목, - 목록, 1. 번호 목록, - [ ] 할 일, > 인용, ``` 코드, **굵게**, `코드`.
올릴 곳은 .env.marketing의 NOTION_PARENT_PAGE(notion_weekly.py와 같다).
사용: notion_page.py <파일.md> --title "제목" [--dry-run]
"""
import re
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from notion_weekly import api, env, page_body, parent_page  # noqa: E402


def rich(text):
    out = []
    for part in re.split(r"(\*\*[^*]+\*\*|`[^`]+`)", text):
        if not part:
            continue
        ann = {}
        if part.startswith("**"):
            part, ann = part[2:-2], {"bold": True}
        elif part.startswith("`"):
            part, ann = part[1:-1], {"code": True}
        item = {"type": "text", "text": {"content": part[:1900]}}
        if ann:
            item["annotations"] = ann
        out.append(item)
    return out


def blk(kind, text, **extra):
    return {"object": "block", "type": kind, kind: {"rich_text": rich(text), **extra}}


def to_blocks(md):
    blocks, code = [], None
    for line in md.splitlines():
        if line.startswith("```"):
            if code is None:
                code = []
            else:
                body = "\n".join(code)[:1900]
                blocks.append({"object": "block", "type": "code", "code": {
                    "language": "plain text", "rich_text": [{"type": "text", "text": {"content": body}}]}})
                code = None
            continue
        if code is not None:
            code.append(line)
            continue
        s = line.strip()
        if not s:
            continue
        if s.startswith("### "):
            blocks.append(blk("heading_3", s[4:]))
        elif s.startswith("## "):
            blocks.append(blk("heading_2", s[3:]))
        elif m := re.match(r"- \[( |x)\] (.*)", s):
            blocks.append(blk("to_do", m.group(2), checked=m.group(1) == "x"))
        elif s.startswith("- "):
            blocks.append(blk("bulleted_list_item", s[2:]))
        elif m := re.match(r"\d+\. (.*)", s):
            blocks.append(blk("numbered_list_item", m.group(1)))
        elif s.startswith("> "):
            blocks.append(blk("quote", s[2:]))
        else:
            blocks.append(blk("paragraph", s))
    return blocks


def main():
    args = sys.argv[1:]
    dry = "--dry-run" in args
    title = args[args.index("--title") + 1]
    blocks = to_blocks(pathlib.Path(args[0]).read_text(encoding="utf-8"))
    if dry:
        print(f"dry-run: '{title}' 블록 {len(blocks)}개")
        return 0
    token = env("NOTION_TOKEN")
    parent = parent_page()
    if not token or not parent:
        print("실패: .env.marketing에 NOTION_TOKEN·NOTION_PARENT_PAGE가 있어야 한다")
        return 1
    body = page_body(parent, title)
    body["children"] = blocks[:100]
    code, res = api(token, "POST", "pages", body)
    if code != 200:
        print(f"실패 {code} {res.get('code')} {str(res.get('message'))[:300]}")
        return 1
    # 노션은 한 번에 블록 100개까지만 받는다.
    for i in range(100, len(blocks), 100):
        c, r = api(token, "PATCH", f"blocks/{res['id']}/children", {"children": blocks[i:i + 100]})
        if c != 200:
            print(f"추가 실패 {c} {str(r.get('message'))[:300]}")
            return 1
    print(f"완료: 블록 {len(blocks)}개 → {res.get('url')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
