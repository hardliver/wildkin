# 野伴戰鬥圖產生器（W24b）。在 wildkin/tools/art 執行：python3 build.py
# 輸出 assets/art/kin_front.png（64×64 × 5）與 kin_back.png（32×32 × 5），預覽在 build/kin_preview.png
#
# 引擎的調色盤所有圖片加起來最多 240 色（Kenney 的地圖已經用掉一些），
# 所以 5 隻野伴的正面＋背面一起「減色」成 MAX_COLORS 色，共用同一組顏色。
import os
from PIL import Image
import pals

MAX_COLORS = 96
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "assets", "art")
BUILD = os.path.join(HERE, "..", "..", "build")

fronts = [p.front() for p in pals.ALL]
backs = [p.back() for p in pals.ALL]
F = Image.new("RGBA", (64 * 5, 64), (0, 0, 0, 0))
B = Image.new("RGBA", (32 * 5, 32), (0, 0, 0, 0))
for i, im in enumerate(fronts): F.paste(im, (i * 64, 0))
for i, im in enumerate(backs): B.paste(im, (i * 32, 0))

# 減色：兩張圖拼在一起算一組共用的顏色，再各自換成最接近的顏色
both = Image.new("RGB", (F.width, F.height + B.height), (0, 0, 0))
both.paste(F.convert("RGB"), (0, 0)); both.paste(B.convert("RGB"), (0, F.height))
mask = Image.new("L", both.size, 0)
mask.paste(F.getchannel("A"), (0, 0)); mask.paste(B.getchannel("A"), (0, F.height))
# 只用不透明的像素算顏色：把透明的地方先填成某個不透明像素的顏色
px = both.load(); mk = mask.load()
fill = next(px[x, y] for y in range(both.height) for x in range(both.width) if mk[x, y])
for y in range(both.height):
    for x in range(both.width):
        if not mk[x, y]: px[x, y] = fill
q = both.quantize(colors=MAX_COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")

def apply(src, top):
    out = src.copy(); o = out.load(); qp = q.load()
    for y in range(src.height):
        for x in range(src.width):
            if o[x, y][3]: o[x, y] = (*qp[x, y + top], 255)
            else: o[x, y] = (0, 0, 0, 0)
    return out

F, B = apply(F, 0), apply(B, F.height)
os.makedirs(OUT, exist_ok=True); os.makedirs(BUILD, exist_ok=True)
F.save(os.path.join(OUT, "kin_front.png")); B.save(os.path.join(OUT, "kin_back.png"))
cols = {p[:3] for im in (F, B) for p in im.getdata() if p[3]}
print("colors:", len(cols))

# 預覽：上排正面，下排背面（放大 2 倍，和遊戲裡一樣）
P = Image.new("RGBA", (5 * 72 + 8, 64 * 2 + 24), (150, 190, 140, 255))
for i in range(5):
    f = F.crop((i * 64, 0, i * 64 + 64, 64)); b = B.crop((i * 32, 0, i * 32 + 32, 32)).resize((64, 64), Image.NEAREST)
    P.paste(f, (8 + i * 72, 8), f); P.paste(b, (8 + i * 72, 80), b)
P.resize((P.width * 3, P.height * 3), Image.NEAREST).save(os.path.join(BUILD, "kin_preview.png"))
