# icons.py：16×16 的野伴小圖示（W42）。基地裡派駐的野伴走來走去用
# 在 wildkin/tools/art 執行：python3 icons.py → assets/art/kin_icons.png（每隻 3 格，第 sprite × 3 格開始）
# 用戰鬥圖同一個 3D 模型縮小，從斜上方看（和地圖上的角色一樣的角度），再補眼睛。
#
# 走路動畫是「真的動腳」：把模型裡的腳（tag 是 leg、foot、toe…）找出來移動，再算一次圖：
#   四隻腳的：對角線兩隻一起往前（左前＋右後、右前＋左後），像真的動物在走
#   兩隻腳的：左右腳一前一後，手和同一邊的腳反方向擺
#   有翅膀的（哨哨雀、燈蛾）：翅膀上下拍，腳不動
# 每隻 3 格：0 站著、1 左腳在前、2 右腳在前。
# 遊戲裡播 1 → 0（身體往上 1 像素）→ 2 → 0（往上 1 像素），4 拍一個循環（npc 的走路也是這樣）
# 都面向左，往右走時左右翻轉。
import numpy as np
from PIL import Image
import pals, pals2, pals3
from r3d import *
from paint import put

ALL = pals.ALL + pals2.ALL2 + pals3.ALL3
VIEW = rot_x(deg(-25)) @ rot_y(deg(20))
OPT = pals.OPT
V = lambda *a: np.array(a, float)
EYES = {
    "Sheep": V(-2.8, -1.2, 4.8), "Tanuki": V(-6.6, -2, 6.6), "Catfish": V(-6, -3.5, 6),
    "Hamster": V(-5, -2.5, 5.2), "Bird": V(-2, -1.2, 4.6), "ForestRam": V(-3, -1.5, 5),
    "StoveTanuki": V(-5.5, -2, 5.6), "RiverLord": V(-5, -3.5, 6.5), "MushroomCrab": None, "LampMoth": None,
    "FanBat": V(-3, -1, 4), "StoneArmadillo": V(-2.4, -0.6, 3.8), "MistJelly": None,
}

def kind(tag):
    t = str(tag)
    if t.startswith("wing"): return "wing"
    if t in ("lf", "lf2", "lb", "lb2") or t.startswith(("leg", "foot", "toe")): return "leg"
    if t.startswith(("arm", "hand")): return "arm"
    return None

def posed(p, phase):
    """phase：+1 左腳在前、-1 右腳在前、0 站著。回傳動過腳的模型"""
    m = p.model()
    if phase == 0: return m
    tags = [kind(t) for (_, _, _, _, t) in m.parts]
    flying = "wing" in tags
    legs = [m.parts[i][0] for i, k in enumerate(tags) if k == "leg"]
    quad = len(legs) > 0 and len({(round(c[0] / 8), np.sign(c[2])) for c in legs}) >= 4
    new = []
    for (c, r, R, mat, tag), k in zip(m.parts, tags):
        c = c.copy()
        side = 1 if c[2] >= 0 else -1          # 靠近鏡頭這邊（左）＝ +1
        if flying:
            if k == "wing": c[1] += -1.8 * phase * (1 if side > 0 else 1)   # 翅膀上下拍
        elif k == "leg":
            front = 1 if (not quad or c[0] < 2) else -1
            swing = phase * side * front        # +1 這隻腳往前（往 -x，頭的方向）
            c[0] -= 2.6 * swing
            if swing > 0: c[1] -= 1.0            # 往前跨的腳抬起來一點
        elif k == "arm":
            c[0] += 1.6 * phase * side           # 手和同一邊的腳反方向擺
        new.append((c, r, R, mat, tag))
    m.parts = new
    return m

def frames(p):
    # 用「站著」的樣子決定大小和位置，3 格都用同一個，走路時才不會忽大忽小
    base = p.model()
    im, _ = render(base, 16, VIEW, 0.4, (8, 9), **OPT)
    x0, y0, x1, y1 = im.getbbox()
    k = min(15 / (x1 - x0), 14 / (y1 - y0))
    scale = 0.4 * k
    off = (8 - ((x0 + x1) / 2 - 8) * k, 15 - (y1 - 9) * k)
    out = []
    for phase in (0, 1, -1):
        im, info = render(posed(p, phase), 16, VIEW, scale, off, **OPT)
        e = EYES[type(p).__name__]
        if e is not None:
            x, y = project(info, p.HEAD + e)
            if 0 <= x < 16 and 0 <= y < 16 and im.getpixel((x, y))[3]:
                put(im, x, y, (24, 18, 26))
        out.append(im)
    return out

def sheet_image():
    out = Image.new("RGBA", (48 * len(ALL), 16), (0, 0, 0, 0))
    for i, p in enumerate(ALL):
        for j, f in enumerate(frames(p)):
            out.paste(f, (i * 48 + j * 16, 0))
    return out

def snap_to(img, palette_files):
    """每個像素換成戰鬥圖用過的最接近的顏色：小圖示不另外佔調色盤（引擎所有圖片最多 240 色）"""
    pal = set()
    for f in palette_files:
        for c in Image.open(f).convert("RGBA").getdata():
            if c[3]: pal.add(c[:3])
    pal = np.array(sorted(pal), int)
    out = img.copy(); px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a:
                i = int(np.argmin(((pal - (r, g, b)) ** 2).sum(1)))
                px[x, y] = (*map(int, pal[i]), 255)
    return out

if __name__ == "__main__":
    import os
    here = os.path.dirname(os.path.abspath(__file__))
    art = os.path.join(here, "..", "..", "assets", "art")
    s = snap_to(sheet_image(), [os.path.join(art, "kin_front.png"), os.path.join(art, "kin_back.png")])
    # W67：前面 FROZEN 隻的圖示凍結不動（和 build.py 一樣）。調色盤多了顏色時，舊圖示重新對色可能會變
    import build_frozen
    old = Image.open(os.path.join(art, "kin_icons.png")).convert("RGBA")
    n = min(build_frozen.FROZEN * 48, old.width)
    s.paste(old.crop((0, 0, n, 16)), (0, 0))
    s.save(os.path.join(here, "..", "..", "assets", "art", "kin_icons.png"))
    # 預覽：每隻的走路循環 1 → 0（上 1）→ 2 → 0（上 1）
    bg = Image.new("RGBA", (4 * 20 + 4, len(ALL) * 20), (132, 198, 105, 255))
    for i in range(len(ALL)):
        f = [s.crop((i * 48 + j * 16, 0, i * 48 + j * 16 + 16, 16)) for j in range(3)]
        for t, (idx, dy) in enumerate(((1, 0), (0, -1), (2, 0), (0, -1))):
            bg.paste(f[idx], (4 + t * 20, i * 20 + 3 + dy), f[idx])
    bg.resize((bg.width * 5, bg.height * 5), Image.NEAREST).save(os.path.join(here, "..", "..", "build", "kin_icons_preview.png"))
