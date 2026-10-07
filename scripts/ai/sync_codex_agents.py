#!/usr/bin/env python3
"""`.claude/agents/*.md`(정본) → `.codex/agents/*.toml` 생성.

Codex 앱의 1회성 가져오기는 이후 수정이 반영되지 않아 사본이 낡는다. 원본은 Claude 쪽 하나로 두고
Codex용은 매번 이 스크립트로 만든다(weekly.sh가 실행 전에 호출). 표준 라이브러리만 쓴다.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / ".claude" / "agents"
DST = ROOT / ".codex" / "agents"

# 본문은 Claude Code 도구 이름으로 쓰여 있다. Codex에서 같은 뜻으로 읽히도록 앞에 대응표를 붙인다.
PREAMBLE = """\
> Codex 실행 메모(자동 생성): 아래 지침은 Claude Code 기준 용어로 쓰였다. 다음처럼 읽는다.
> - "Agent 툴로 호출/위임" → 이름이 같은 Codex 커스텀 에이전트(`.codex/agents/<name>.toml`)를 서브에이전트로 띄운다.
> - "Skill" `a:b` → 플러그인 `a`의 스킬 `b`. 없으면 지침의 부재 규칙대로 자기 지식으로 진행한다.
> - WebSearch/WebFetch → 웹 검색 도구, 또는 `curl`.
> - `/marketing-approve` 등 슬래시 커맨드는 사람이 Claude Code에서 실행하는 것이다. Codex는 실행하지 않는다.

"""


def toml_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def toml_ml(s: str) -> str:
    # 리터럴 다중행('''…''')은 이스케이프가 없어 본문 그대로 들어간다. 본문에 '''가 있으면 기본 다중행으로.
    if "'''" not in s:
        return "'''\n" + s + "'''"
    return '"""\n' + s.replace("\\", "\\\\").replace('"""', '\\"\\"\\"') + '"""'


def convert(md: pathlib.Path) -> str:
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", md.read_text(), re.S)
    if not m:
        sys.exit(f"frontmatter 없음: {md}")
    fm, body = m.groups()
    name = re.search(r"^name:\s*(.+)$", fm, re.M).group(1).strip()
    # description은 여러 줄 블록(>, |)일 수 있다 — 다음 키 전까지를 한 줄로 합친다.
    dm = re.search(r"^description:\s*[>|]?-?\s*\n?(.*?)(?=^\w+:|\Z)", fm, re.M | re.S)
    desc = " ".join(dm.group(1).split()) if dm else ""
    return (
        f"# 자동 생성 — scripts/ai/sync_codex_agents.py. 원본 {md.relative_to(ROOT)}를 고친다.\n"
        f"name = {toml_str(name)}\n"
        f"description = {toml_str(desc)}\n"
        f"developer_instructions = {toml_ml(PREAMBLE + body.lstrip())}\n"
    )


def main() -> int:
    DST.mkdir(parents=True, exist_ok=True)
    changed = 0
    for md in sorted(SRC.glob("*.md")):
        out = DST / (md.stem + ".toml")
        new = convert(md)
        if not out.exists() or out.read_text() != new:
            out.write_text(new)
            changed += 1
    print(f"codex agents: {len(list(SRC.glob('*.md')))}개 확인, {changed}개 갱신")
    return 0


if __name__ == "__main__":
    sys.exit(main())
