# 野伴戰鬥圖產生器（W24b）。在 wildkin/tools/art 執行：python3 build.py
# 輸出 assets/art/kin_front.png（64×64 × 10）與 kin_back.png（32×32 × 10），預覽在 build/kin_preview.png
#
# 引擎的調色盤所有圖片加起來最多 240 色（Kenney 的地圖已經用掉一些），
# 所以全部野伴的正面＋背面一起「減色」成 MAX_COLORS 色，共用同一組顏色。
# W66 起：前 FROZEN 隻凍結不動，新加的另外減色（見下面）。要整批重畫時把 FROZEN 改成 0
import os
from PIL import Image
import pals, pals2, pals3

MAX_COLORS = 128
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "assets", "art")
BUILD = os.path.join(HERE, "..", "..", "build")

ALL = pals.ALL + pals2.ALL2 + pals3.ALL3   # 順序 = species.json 的 sprite（0～4 第一批、5～9 第二批、10～ 第三批 W66）
# W66：已經畫好的野伴「凍結」——直接沿用 assets 裡的圖，不重新減色（不然舊的野伴顏色會跟著偏移）。
# 只有新加的（第 FROZEN 隻以後）才算圖、減色：先減成 NEW_COLORS 色，跟舊顏色很接近的就直接用舊顏色。
from build_frozen import FROZEN
NEW_COLORS = 16
NEAR = 10 * 10 * 3           # 顏色距離平方小於這個就算「很接近」（W67 從 14 收緊到 6：礫殼犰狳的石頭灰被換成灰綠；W70 放寬到 10：顏色快用完）
N = len(ALL)
oldF = Image.open(os.path.join(OUT, "kin_front.png")).convert("RGBA")
oldB = Image.open(os.path.join(OUT, "kin_back.png")).convert("RGBA")
F = Image.new("RGBA", (64 * N, 64), (0, 0, 0, 0))
B = Image.new("RGBA", (32 * N, 32), (0, 0, 0, 0))
F.paste(oldF.crop((0, 0, 64 * FROZEN, 64)), (0, 0))
B.paste(oldB.crop((0, 0, 32 * FROZEN, 32)), (0, 0))
old_cols = sorted({p[:3] for im in (oldF, oldB) for p in im.getdata() if p[3]})

new = ALL[FROZEN:]
if new:
    nf = Image.new("RGBA", (64 * len(new), 64), (0, 0, 0, 0))
    nb = Image.new("RGBA", (32 * len(new), 32), (0, 0, 0, 0))
    for i, p in enumerate(new):
        nf.paste(p.front(), (i * 64, 0)); nb.paste(p.back(), (i * 32, 0))
    both = Image.new("RGB", (nf.width, nf.height + nb.height), (0, 0, 0))
    both.paste(nf.convert("RGB"), (0, 0)); both.paste(nb.convert("RGB"), (0, nf.height))
    mask = Image.new("L", both.size, 0)
    mask.paste(nf.getchannel("A"), (0, 0)); mask.paste(nb.getchannel("A"), (0, nf.height))
    px = both.load(); mk = mask.load()
    fill = next(px[x, y] for y in range(both.height) for x in range(both.width) if mk[x, y])
    for y in range(both.height):
        for x in range(both.width):
            if not mk[x, y]: px[x, y] = fill
    q = both.quantize(colors=NEW_COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    # 每個新顏色：舊顏色裡有很接近的就用舊的
    remap = {}
    for c in {q.getpixel((x, y)) for y in range(q.height) for x in range(q.width) if mk[x, y]}:
        best = min(old_cols, key=lambda o: sum((a - b) ** 2 for a, b in zip(o, c)))
        remap[c] = best if sum((a - b) ** 2 for a, b in zip(best, c)) < NEAR else c
    def apply(src, top):
        out = src.copy(); o = out.load(); qp = q.load()
        for y in range(src.height):
            for x in range(src.width):
                if o[x, y][3]: o[x, y] = (*remap[qp[x, y + top]], 255)
                else: o[x, y] = (0, 0, 0, 0)
        return out
    nf, nb = apply(nf, 0), apply(nb, nf.height)
    F.paste(nf, (64 * FROZEN, 0)); B.paste(nb, (32 * FROZEN, 0))
    added = {c for c in remap.values() if c not in set(old_cols)}
    print("new kin:", len(new), "new colors:", len(added))

os.makedirs(OUT, exist_ok=True); os.makedirs(BUILD, exist_ok=True)
F.save(os.path.join(OUT, "kin_front.png")); B.save(os.path.join(OUT, "kin_back.png"))
cols = {p[:3] for im in (F, B) for p in im.getdata() if p[3]}
print("colors:", len(cols))

# 預覽：上排正面，下排背面（放大 2 倍，和遊戲裡一樣）
P = Image.new("RGBA", (N * 72 + 8, 64 * 2 + 24), (150, 190, 140, 255))
for i in range(N):
    f = F.crop((i * 64, 0, i * 64 + 64, 64)); b = B.crop((i * 32, 0, i * 32 + 32, 32)).resize((64, 64), Image.NEAREST)
    P.paste(f, (8 + i * 72, 8), f); P.paste(b, (8 + i * 72, 80), b)
P.resize((P.width * 3, P.height * 3), Image.NEAREST).save(os.path.join(BUILD, "kin_preview.png"))
