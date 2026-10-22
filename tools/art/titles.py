# 章節標題（W54）：python3 tools/art/titles.py → assets/art/chapters.png
# 黑畫面中間的大字：上面一行小字「第 1 章」，下面一行大字章名。每章一格 256×64，由上往下排（第 0 格是第 1 章）。
# 字型：Noto Sans CJK Black（和 logo.py 一樣，SIL OFL 授權）。顏色用 Tiny Town 調色盤裡有的
# 凍結（W73）：前 FROZEN 格直接從現有的 chapters.png 拿，只畫後面新加的章。
#   原因：第 1～3 章是用 NotoSansCJK-Black.ttc（index 1）畫的；換一台電腦字型檔不同，重畫會有一兩個字長得不一樣。
#   字型找不到 .ttc 時，用繁中版的 NotoSansCJKtc-Black.otf（可以放在 FONT_DIRS 任一處，或 NOTO_FONT 環境變數指定）
import os, sys
from PIL import Image, ImageDraw, ImageFont

FONTS = [
    (os.environ.get("NOTO_FONT", ""), 0),
    ("/usr/share/fonts/opentype/noto/NotoSansCJK-Black.ttc", 1),
    (os.path.expanduser("~/Library/Fonts/NotoSansCJKtc-Black.otf"), 0),
    ("/usr/share/fonts/opentype/noto/NotoSansCJKtc-Black.otf", 0),
]
FONT, FONT_INDEX = next(((f, i) for f, i in FONTS if f and os.path.exists(f)), FONTS[1])
CHAPTERS = [
    ("第 1 章", "霧林的守護者"),
    ("第 2 章", "舊礦坑的燈"),
    ("第 3 章", "火山的煙"),
    ("終章", "夥伴，還是工具"),     # W73
]
FROZEN = 3
W, H = 256, 64
GOLD, WHITE, OUT = (0xfd, 0xbe, 0x53), (0xff, 0xff, 0xff), (0x3f, 0x26, 0x31)

def mask(text, size):
    font = ImageFont.truetype(FONT, size, index=FONT_INDEX)
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

def build(old=None):
    sheet = Image.new("RGBA", (W, H * len(CHAPTERS)), (0, 0, 0, 0))
    for i, (label, title) in enumerate(CHAPTERS):
        if old is not None and i < FROZEN:
            sheet.alpha_composite(old.crop((0, i * H, W, (i + 1) * H)).convert("RGBA"), (0, i * H))
            continue
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
    old = Image.open(out) if os.path.exists(out) else None
    if len(sys.argv) > 1: out = sys.argv[1]
    build(old).save(out)
