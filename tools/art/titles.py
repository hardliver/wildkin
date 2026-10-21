# 章節標題（W54）：python3 tools/art/titles.py → assets/art/chapters.png
# 黑畫面中間的大字：上面一行小字「第 1 章」，下面一行大字章名。每章一格 256×64，由上往下排（第 0 格是第 1 章）。
# 字型：Noto Sans CJK Black（和 logo.py 一樣，SIL OFL 授權）。顏色用 Tiny Town 調色盤裡有的
import os, sys
from PIL import Image, ImageDraw, ImageFont

FONT = "/usr/share/fonts/opentype/noto/NotoSansCJK-Black.ttc"
CHAPTERS = [
    ("第 1 章", "霧林的守護者"),
    ("第 2 章", "舊礦坑的燈"),
    ("第 3 章", "火山的煙"),
]
W, H = 256, 64
GOLD, WHITE, OUT = (0xfd, 0xbe, 0x53), (0xff, 0xff, 0xff), (0x3f, 0x26, 0x31)

def mask(text, size):
    font = ImageFont.truetype(FONT, size, index=1)
    im = Image.new("L", (W * 2, size * 2), 0)
    ImageDraw.Draw(im).text((4, 0), text, font=font, fill=255)
    im = im.point(lambda v: 255 if v > 120 else 0)
    return im.crop(im.getbbox())

def paste(card, m, y, color):
    x0 = (W - m.width) // 2
    px = m.load()
    for yy in range(m.height):
        for xx in range(m.width):
            if px[xx, yy]: card.putpixel((x0 + xx, y + yy), (*color, 255))

def build():
    sheet = Image.new("RGBA", (W, H * len(CHAPTERS)), (0, 0, 0, 0))
    for i, (label, title) in enumerate(CHAPTERS):
        card = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        a, b = mask(label, 14), mask(title, 30)
        paste(card, a, 4, GOLD)
        paste(card, b, 4 + a.height + 10, WHITE)
        # 章名下面一條細線
        for x in range((W - b.width) // 2, (W + b.width) // 2):
            card.putpixel((x, min(H - 2, 4 + a.height + 10 + b.height + 6)), (*GOLD, 255))
        sheet.alpha_composite(card, (0, i * H))
    return sheet

if __name__ == "__main__":
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../assets/art/chapters.png")
    if len(sys.argv) > 1: out = sys.argv[1]
    build().save(out)
