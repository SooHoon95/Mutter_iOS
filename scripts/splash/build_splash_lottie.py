#!/usr/bin/env python3
"""스플래시 Lottie(SplashAnimation.json)를 만든다.

장면: 런치 화면과 같은 닫힌 봉투에서 시작 → 덮개가 뒤로 젖혀지고 → 편지지가 올라오며 글줄이 그려지고
→ 편지 뒤에서 음표가 흘러나온다. 움직임은 서로 겹치고, 빠르게 시작해 길게 가라앉는다(튕김 없음).
- 0프레임은 런치 이미지와 같은 그림이다(봉투 위치·색·글자). 런치 화면에서 넘어올 때 튀지 않는다.
- 글자는 글꼴 대신 윤곽선으로 넣는다. iOS·Android 어디서도 글꼴 대체가 일어나지 않는다.
- 길이 2초(60프레임, 30fps). MainView의 최소 스플래시 시간(2초)과 같다.

사용: python3 scripts/splash/build_splash_lottie.py [출력 경로]
필요: fontTools (pip install fonttools)
"""
import json
import pathlib
import sys

from fontTools.pens.basePen import BasePen
from fontTools.ttLib import TTCollection, TTFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "Projects/UIComponent/Resources/Lotties/SplashAnimation.json"
SERIF_TTC = ("/System/Library/AssetsV2/PreinstalledAssetsV2/InstallWithOs/com_apple_MobileAsset_Font7/"
             "3584a8e371c39d71203db0d1d650a284432d0606.asset/AssetData/NanumMyeongjo.ttc")
SANS = ROOT / "Projects/UIComponent/Resources/Fonts/Pretendard-Medium.ttf"

W, H, FR, OP = 1080, 1920, 30, 60

# 봉투 자리(런치 이미지에서 잰 값)
L, R, T, B = 350, 730, 747, 1024
CX, APEX = 540, 896

# 전체 크기(%)와 줄일 때의 중심 높이. 100이면 처음 런치 이미지와 같은 크기다.
STAGE_SCALE, STAGE_CENTER_Y = 80, 980


def rgb(hexstr):
    h = hexstr.lstrip("#")
    return [round(int(h[i:i + 2], 16) / 255, 4) for i in (0, 2, 4)]


def st(v):
    return {"a": 0, "k": v}


def kf(t, s, ease=None, to=None, ti=None, hold=False):
    """키프레임. ease=(ox, oy, ix, iy)는 이 키프레임에서 다음 키프레임까지의 가감속."""
    k = {"t": t, "s": s if isinstance(s, list) else [s]}
    if hold:
        k["h"] = 1
    elif ease:
        k["o"] = {"x": [ease[0]], "y": [ease[1]]}
        k["i"] = {"x": [ease[2]], "y": [ease[3]]}
    if to is not None:
        k["to"], k["ti"] = to, ti
    return k


def anim(*keys):
    return {"a": 1, "k": list(keys)}


EASE_OUT = (0.22, 0.6, 0.36, 1)      # 빠르게 시작해 부드럽게 멈춤
EASE_IO = (0.42, 0, 0.58, 1)         # 천천히 시작해 천천히 멈춤
FLOAT = (0.25, 0.45, 0.45, 1)        # 떠오르는 움직임
FOLD_IN = (0.88, 0, 1, 1)            # 덮개가 세워질 때: 천천히 떼어져 속도가 붙은 채 옆모습을 지난다
FOLD_OUT = (0.08, 0, 0.1, 1)         # 덮개가 넘어갈 때: 그 속도로 넘어가 길게 가라앉는다
SETTLE = (0.333, 0, 0, 1)            # 편지지: 빠르게 올라와 길게 가라앉는다
DRAW = (0.44, 0, 0.12, 1)            # 글줄이 그려질 때
DRIFT = (0.649, 0, 0.206, 1)         # 봉투 전체가 천천히 떠오를 때


def path(verts, closed=True, ins=None, outs=None):
    n = len(verts)
    return {"ty": "sh", "ks": st({"c": closed, "v": [list(v) for v in verts],
                                  "i": [list(v) for v in (ins or [(0, 0)] * n)],
                                  "o": [list(v) for v in (outs or [(0, 0)] * n)]})}


def fill(color, opacity=100):
    return {"ty": "fl", "c": st(rgb(color) + [1]), "o": st(opacity), "r": 1}


def stroke(color, width, opacity=100):
    return {"ty": "st", "c": st(rgb(color) + [1]), "o": st(opacity), "w": st(width), "lc": 2, "lj": 2}


def gradient(stops, start, end, radial=False, alphas=None):
    k = []
    for pos, color in stops:
        k += [pos] + rgb(color)
    for pos, a in (alphas or []):
        k += [pos, a]
    return {"ty": "gf", "o": st(100), "r": 1, "t": 2 if radial else 1,
            "g": {"p": len(stops), "k": st(k)}, "s": st(list(start)), "e": st(list(end)),
            "h": st(0), "a": st(0)}


def trim(start, end):
    """선을 일부만 그린다(0~100). 글줄이 가운데에서 양쪽으로 그려지는 데 쓴다."""
    return {"ty": "tm", "s": start, "e": end, "o": st(0), "m": 1}


def tr(p=(0, 0), a=(0, 0), s=(100, 100), r=0, o=100):
    wrap = lambda v: v if isinstance(v, dict) else st(list(v) if isinstance(v, tuple) else v)
    return {"ty": "tr", "p": wrap(p), "a": wrap(a), "s": wrap(s), "r": wrap(r), "o": wrap(o),
            "sk": st(0), "sa": st(0)}


def group(items, name="", **transform):
    return {"ty": "gr", "nm": name, "it": items + [tr(**transform)]}


def layer(ind, name, shapes=None, parent=None, ip=0, op=OP, **ks):
    wrap = lambda v: v if isinstance(v, dict) else st(v)
    out = {"ddd": 0, "ind": ind, "ty": 4 if shapes is not None else 3, "nm": name, "sr": 1, "ao": 0,
           "ks": {"o": wrap(ks.get("o", 100)), "r": wrap(ks.get("r", 0)),
                  "p": wrap(ks.get("p", [0, 0, 0])), "a": wrap(ks.get("a", [0, 0, 0])),
                  "s": wrap(ks.get("s", [100, 100, 100]))},
           "ip": ip, "op": op, "st": 0, "bm": 0}
    if shapes is not None:
        out["shapes"] = shapes
    if parent is not None:
        out["parent"] = parent
    return out


# ── 글자 윤곽선 ─────────────────────────────────────────────────────────────
class ContourPen(BasePen):
    """글리프를 3차 베지어 윤곽선 목록으로 모은다(2차 곡선은 BasePen이 3차로 바꿔 준다)."""

    def __init__(self, glyph_set):
        super().__init__(glyph_set)
        self.contours = []

    def _moveTo(self, pt):
        self.contours.append([("M", pt)])

    def _lineTo(self, pt):
        self.contours[-1].append(("L", pt))

    def _curveToOne(self, c1, c2, pt):
        self.contours[-1].append(("C", c1, c2, pt))


def text_shapes(font, text, tracking, box):
    """text를 box=(x0, y0, x1, y1) 너비에 맞춘 윤곽선 path 목록으로 만든다. 아래쪽을 y1에 맞춘다."""
    glyph_set, cmap, upm = font.getGlyphSet(), font.getBestCmap(), font["head"].unitsPerEm
    contours, x = [], 0
    for ch in text:
        name = cmap[ord(ch)]
        pen = ContourPen(glyph_set)
        glyph_set[name].draw(pen)
        for c in pen.contours:
            contours.append([(seg[0],) + tuple((px + x, py) for px, py in seg[1:]) for seg in c])
        x += glyph_set[name].width + tracking * upm / 1000
    pts = [p for c in contours for seg in c for p in seg[1:]]
    xmin, xmax = min(p[0] for p in pts), max(p[0] for p in pts)
    ymin = min(p[1] for p in pts)
    k = (box[2] - box[0]) / (xmax - xmin)
    fx = lambda p: (round(box[0] + (p[0] - xmin) * k, 2), round(box[3] - (p[1] - ymin) * k, 2))
    shapes = []
    for c in contours:
        verts, ins, outs = [fx(c[0][1])], [(0, 0)], [(0, 0)]
        for seg in c[1:]:
            if seg[0] == "L":
                verts.append(fx(seg[1])); ins.append((0, 0)); outs.append((0, 0))
            else:
                c1, c2, p = fx(seg[1]), fx(seg[2]), fx(seg[3])
                outs[-1] = (round(c1[0] - verts[-1][0], 2), round(c1[1] - verts[-1][1], 2))
                verts.append(p); ins.append((round(c2[0] - p[0], 2), round(c2[1] - p[1], 2))); outs.append((0, 0))
        if len(verts) > 1 and verts[-1] == verts[0]:  # 닫는 점이 시작점과 같으면 합친다
            ins[0] = ins[-1]
            verts.pop(); ins.pop(); outs.pop()
        shapes.append(path(verts, True, ins, outs))
    return shapes


# ── 음표·반짝임 모양 ────────────────────────────────────────────────────────
def eighth_note(color):
    return [
        group([{"ty": "el", "p": st([0, 0]), "s": st([31, 23])}, fill(color)], "head", p=(-9, 23), r=-22),
        group([path([(5, 19), (5, -36)], False),
               path([(5, -36), (25, -6)], False, ins=[(0, 0), (4, -15)], outs=[(11, 5), (0, 0)]),
               stroke(color, 5.5)], "stem"),
    ]


def beamed_notes(color):
    return [
        group([{"ty": "el", "p": st([0, 0]), "s": st([29, 22])}, fill(color)], "head1", p=(-23, 26), r=-22),
        group([{"ty": "el", "p": st([0, 0]), "s": st([29, 22])}, fill(color)], "head2", p=(21, 16), r=-22),
        group([path([(-10, 22), (-10, -30)], False), path([(34, 12), (34, -40)], False), stroke(color, 5)], "stems"),
        group([path([(-10, -29), (34, -39)], False), stroke(color, 10)], "beam"),
    ]


def sparkle(color, r):
    q = r * 0.2
    verts = [(0, -r), (q, -q), (r, 0), (q, q), (0, r), (-q, q), (-r, 0), (-q, -q)]
    return [group([path(verts), fill(color)], "star")]


def note_layer(ind, shapes, t0, t1, p0, p1, sway, scale, rot):
    """음표 하나. p0→p1을 S자 곡선으로 떠오르며 커지고, 끝에서 사라진다."""
    dur = t1 - t0
    to = [sway, -(p0[1] - p1[1]) * 0.42, 0]
    ti = [sway * 0.9, (p0[1] - p1[1]) * 0.36, 0]
    return layer(
        ind, f"note{ind}", shapes, ip=t0, op=t1 + 1,
        p=anim(kf(t0, [p0[0], p0[1], 0], FLOAT, to, ti), kf(t1, [p1[0], p1[1], 0])),
        s=anim(kf(t0, [scale * 0.5, scale * 0.5, 100], EASE_OUT), kf(t0 + dur * 0.5, [scale, scale, 100])),
        r=anim(kf(t0, rot[0], EASE_IO), kf(t0 + dur * 0.5, rot[1], EASE_IO), kf(t1, rot[2])),
        o=anim(kf(t0, 0, EASE_IO), kf(t0 + 4, 100, EASE_IO), kf(t1 - dur * 0.4, 100, EASE_IO), kf(t1, 0)),
    )


def sparkle_layer(ind, color, r, t0, pos):
    return layer(
        ind, f"sparkle{ind}", sparkle(color, r), ip=t0, op=t0 + 17, p=[pos[0], pos[1], 0],
        s=anim(kf(t0, [0, 0, 100], EASE_OUT), kf(t0 + 6, [100, 100, 100], EASE_IO), kf(t0 + 16, [0, 0, 100])),
        r=anim(kf(t0, -20, EASE_IO), kf(t0 + 16, 35)),
    )


def build():
    serif = next(f for f in TTCollection(SERIF_TTC).fonts if "ExtraBold" in f["name"].getDebugName(4))
    sans = TTFont(str(SANS))
    ENV = 1  # 봉투 부품들의 부모(널). 봉투 전체가 천천히 떠오르는 움직임을 맡는다.
    c = 28 * 0.5523  # 아래 모서리 둥글림
    RISE = 12        # 봉투가 떠오르는 높이

    env_null = layer(ENV, "envelope-rig", None, a=[CX, B, 0],
                     p=anim(kf(0, [CX, B, 0], DRIFT), kf(46, [CX, B - RISE, 0])))

    # 덮개 윤곽: 끝이 뭉툭하고 둥글다. 주머니의 파인 부분도 같은 선을 쓴다(닫혔을 때 딱 맞물린다).
    tip_dx, tip_dy = 30, 30 * (APEX - T) / (CX - L)
    tip_r, tip_l = (CX + tip_dx, APEX - tip_dy), (CX - tip_dx, APEX - tip_dy)
    tan = (tip_dx * 0.6, tip_dy * 0.6)

    def flap_outline(closed=True):
        return path([(L, T), (R, T), tip_r, tip_l], closed,
                    ins=[(0, 0), (0, 0), (0, 0), (tan[0], tan[1])],
                    outs=[(0, 0), (0, 0), (-tan[0], tan[1]), (0, 0)])

    pocket = layer(60, "pocket", [group([
        path([(L, T), tip_l, tip_r, (R, T), (R, B - 28), (R - 28, B), (L + 28, B), (L, B - 28)],
             ins=[(0, 0), (0, 0), (-tan[0], tan[1]), (0, 0), (0, 0), (c, 0), (0, 0), (0, c)],
             outs=[(0, 0), (tan[0], tan[1]), (0, 0), (0, 0), (0, c), (0, 0), (-c, 0), (0, 0)]),
        gradient([(0, "#E4AED3"), (0.5, "#C177AA"), (1, "#874A78")], (L, T), (R, B)),
    ], "pocket")], parent=ENV)

    # 아래 접힌 면: 조금 밝은 삼각형. 꼭짓점이 파인 부분 위로 올라와 편지지 아랫부분을 덮는다.
    fold_y = T + (B - T) * 0.42
    fx, fy = 26, 26 * (B - 28 - fold_y) / (CX - L)
    bottom_flap = layer(65, "bottom-flap", [
        group([path([(L, B - 28), (CX - fx, fold_y + fy), (CX + fx, fold_y + fy), (R, B - 28)], False,
                    ins=[(0, 0), (0, 0), (-fx * 0.6, -fy * 0.6), (0, 0)],
                    outs=[(0, 0), (fx * 0.6, -fy * 0.6), (0, 0), (0, 0)]),
               stroke("#8E4E7E", 2, 22)], "fold-line"),
        group([path([(L, B - 28), (CX - fx, fold_y + fy), (CX + fx, fold_y + fy), (R, B - 28), (R - 28, B), (L + 28, B)],
                    ins=[(0, c), (0, 0), (-fx * 0.6, -fy * 0.6), (0, 0), (c, 0), (0, 0)],
                    outs=[(0, 0), (fx * 0.6, -fy * 0.6), (0, 0), (0, c), (0, 0), (-c, 0)]),
               gradient([(0, "#EDC2DF"), (0.55, "#D195C0"), (1, "#A9628F")], (L, fold_y), (R, B))], "face"),
    ], parent=ENV)

    # 덮개 앞면: 접히는 선(y=T)을 축으로 세워져 옆모습이 된다 → 그 순간 뒷면으로 바뀌어 뒤로 넘어간다.
    FLIP = 15
    flap_front = layer(70, "flap-front", [group([
        group([path([(L, T), tip_l, tip_r, (R, T)], False,
                    ins=[(0, 0), (0, 0), (-tan[0], tan[1]), (0, 0)], outs=[(0, 0), (tan[0], tan[1]), (0, 0), (0, 0)]),
               stroke("#9C5C8C", 2.5, 40)], "edge"),
        group([flap_outline(), gradient([(0, "#F1CDE5"), (1, "#D59AC5")], (CX, T), (CX, APEX))], "face"),
    ], "flap", a=(CX, T), p=(CX, T), s=anim(kf(2, [100, 100], FOLD_IN), kf(FLIP, [100, 0])))],
        parent=ENV, op=FLIP)

    flap_back = layer(20, "flap-back", [group([
        group([flap_outline(), gradient([(0, "#A9628F"), (1, "#C485B3")], (CX, T), (CX, APEX))], "face"),
    ], "flap", a=(CX, T), p=(CX, T), s=anim(kf(FLIP, [100, 0], FOLD_OUT), kf(FLIP + 15, [100, -100])))],
        parent=ENV, ip=FLIP)

    interior = layer(30, "interior", [group([
        {"ty": "rc", "p": st([CX, (T + B - 40) / 2]), "s": st([R - L - 2, B - 40 - T]), "r": st(0)},
        gradient([(0, "#74406A"), (1, "#5A2F52")], (CX, T), (CX, APEX)),
    ], "inside")], parent=ENV)

    # 편지지: 덮개가 반쯤 세워졌을 때부터 올라온다. 글줄은 가운데에서 양쪽으로, 위에서부터 차례로 그려진다.
    paper_top, paper_w, paper_h, paper_rise = T + 24, 314, 250, 112
    line_ys = [paper_top + 40, paper_top + 72, paper_top + 104, paper_top + 136]
    line_ws = [228, 228, 228, 150]
    lines = []
    for i, (y, w) in enumerate(zip(line_ys, line_ws)):
        t0 = 17 + i * 3
        lines.append(group([
            path([(CX - 114, y), (CX - 114 + w, y)], False),
            trim(anim(kf(t0, 50, DRAW), kf(t0 + 20, 0)), anim(kf(t0, 50, DRAW), kf(t0 + 20, 100))),
            stroke("#E7D5C6", 7)], f"line{i}"))
    paper = layer(40, "paper", lines + [
        group([{"ty": "rc", "p": st([CX, paper_top + paper_h / 2]), "s": st([paper_w, paper_h]), "r": st(12)},
               stroke("#CBB79E", 2, 30), fill("#FFF9F0")], "sheet"),
    ], parent=ENV, p=anim(kf(11, [0, 0, 0], SETTLE), kf(40, [0, -paper_rise, 0])))

    shadow = layer(10, "shadow", [group([
        {"ty": "el", "p": st([0, 0]), "s": st([520, 520])},
        gradient([(0, "#8E4E7E"), (1, "#8E4E7E")], (0, 0), (260, 0), radial=True, alphas=[(0, 0.34), (0.55, 0.12), (1, 0)]),
    ], "soft", s=(100, 20))], p=[CX, B + 14, 0],
        s=anim(kf(0, [100, 100, 100], DRIFT), kf(46, [93, 100, 100])),
        o=anim(kf(0, 100, DRIFT), kf(46, 82)))

    # 음표: 편지지 뒤에서 올라온다(편지지보다 아래 층). 서로 겹쳐서, 천천히.
    start_y = T - 20
    notes = [
        note_layer(51, eighth_note("#8E4E7E"), 28, 57, (500, start_y), (408, 452), -64, 132, (-12, 9, -5)),
        note_layer(52, beamed_notes("#C77BAE"), 32, 60, (566, start_y), (606, 404), 58, 136, (9, -7, 5)),
        note_layer(53, eighth_note("#DDA3CA"), 36, 60, (540, start_y), (690, 520), 70, 96, (10, -8, 6)),
    ]
    sparkles = [
        sparkle_layer(55, "#E2BC6E", 15, 36, (472, 560)),
        sparkle_layer(56, "#E2BC6E", 11, 42, (640, 486)),
    ]

    wordmark = layer(80, "wordmark", [group(
        text_shapes(serif, "Mutter", 20, (333, 1160, 745, 1260)) + [fill("#8E4E7E")], "Mutter")])
    tagline = layer(81, "tagline", [group(
        text_shapes(sans, "음악에 마음을 얹어", 150, (348, 1302, 722, 1340)) + [fill("#6E6555")], "tagline")])

    bg = layer(90, "bg", [group([{"ty": "rc", "p": st([W / 2, H / 2]), "s": st([W, H]), "r": st(0)},
                                 fill("#FFFDF2")], "bg")])

    # 전체 크기: 배경을 뺀 모든 층을 무대(널)에 매달아 한 번에 줄인다. 값만 바꾸면 전체가 같이 커지고 작아진다.
    STAGE = 100
    stage = layer(STAGE, "stage", None, a=[CX, STAGE_CENTER_Y, 0], p=[CX, STAGE_CENTER_Y, 0],
                  s=[STAGE_SCALE, STAGE_SCALE, 100])
    for top in (env_null, wordmark, tagline, shadow, *notes, *sparkles):
        top["parent"] = STAGE

    # 위에 있는 층이 먼저 온다.
    layers = [stage, env_null, wordmark, tagline, flap_front, bottom_flap, pocket, paper, *sparkles, *notes,
              interior, flap_back, shadow, bg]
    return {"v": "5.9.0", "fr": FR, "ip": 0, "op": OP, "w": W, "h": H, "nm": "Mutter Splash", "ddd": 0,
            "assets": [], "layers": layers}


if __name__ == "__main__":
    out = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    out.write_text(json.dumps(build(), ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"{out} ({out.stat().st_size:,} bytes)")
