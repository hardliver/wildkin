# 標題畫面的標誌（W49）：python3 tools/art/logo.py → assets/art/logo.png
# 字型：Noto Sans CJK Black（SIL OFL 授權，可以商用）。算好之後存成 PNG，遊戲裡不需要字型檔。
# 做法：大字畫成黑白 → 上半淺綠、下半深綠 → 外面兩圈深色框；英文小字放在下面。
# 顏色都用 Kenney Tiny Town 調色盤裡有的，不多佔調色盤。
import os, sys
from PIL import Image, ImageDraw, ImageFont

FONT = "/usr/share/fonts/opentype/noto/NotoSansCJK-Black.ttc"   # Mac：brew install --cask font-noto-sans-cjk
OUT = (0x3f, 0x26, 0x31)
G1, G2, G3 = (0x47, 0x9f, 0x4a), (0x84, 0xc6, 0x69), (0x8b, 0xd8, 0x7d)
CREAM, GOLD = (0xfc, 0xbc, 0x8f), (0xfd, 0xbe, 0x53)

def mask(text, size, index=1, spacing=0):
    font = ImageFont.truetype(FONT, size, index=index)
    w = sum(font.getbbox(c)[2] for c in text) + spacing * (len(text) - 1) + 8
    im = Image.new("L", (w, size + 16), 0)
    d = ImageDraw.Draw(im)
    x = 4
    for c in text:
        d.text((x, 0), c, font=font, fill=255)
        x += font.getbbox(c)[2] + spacing
    im = im.point(lambda v: 255 if v > 110 else 0)
    return im.crop(im.getbbox())

def outlined(m, fill, ring, pad):
    """m：黑白字形；fill(x, y, h) 回傳顏色；外面加 ring 圈深色框"""
    w, h = m.size
    out = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    px = m.load()
    for y in range(h):
        for x in range(w):
            if px[x, y]:
                for dy in range(-ring, ring + 1):
                    for dx in range(-ring, ring + 1):
                        if abs(dx) + abs(dy) <= ring + 1:
                            out.putpixel((x + pad + dx, y + pad + dy), (*OUT, 255))
    for y in range(h):
        for x in range(w):
            if px[x, y]: out.putpixel((x + pad, y + pad), (*fill(x, y, h), 255))
    return out

def build():
    big = mask("野伴", 58, spacing=3)
    def green(x, y, h):
        if y < h * 0.18: return G3
        return G2 if y < h * 0.55 else G1
    a = outlined(big, green, 2, 3)
    small = mask("WILDKIN", 16, spacing=3)
    b = outlined(small, lambda x, y, h: GOLD if y < h // 2 else CREAM, 1, 2)
    W = max(a.width, b.width)
    logo = Image.new("RGBA", (W, a.height + b.height - 2), (0, 0, 0, 0))
    logo.alpha_composite(a, ((W - a.width) // 2, 0))
    logo.alpha_composite(b, ((W - b.width) // 2, a.height - 2))
    return logo

if __name__ == "__main__":
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../assets/art/logo.png")
    if len(sys.argv) > 1: out = sys.argv[1]
    build().save(out)
