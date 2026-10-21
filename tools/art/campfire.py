# 營火（W71）：python3 tools/art/campfire.py → assets/art/campfire.png（16×16 × 3 格）
# 第 0 格：還沒點燃（一圈石頭、交叉的柴）；第 1、2 格：點燃（火焰兩種形狀輪流，看起來在閃）
# 顏色全部用已經有的（Tiny Town、設施圖、港灣圖塊），不多佔調色盤
import os
from PIL import Image
OUT = (0x3f, 0x26, 0x31)
W1, W2, W3 = (0x76, 0x3b, 0x36), (0xbd, 0x6c, 0x4a), (0xea, 0xa5, 0x6c)
S1, S2, S3 = (0x5a, 0x69, 0x88), (0x8b, 0x9b, 0xb4), (0xc0, 0xcb, 0xdc)
RED, YEL = (0xc3, 0x4b, 0x35), (0xfd, 0xbe, 0x53)
LAMP_L = (255, 240, 170)

sheet = Image.new("RGBA", (48, 16), (0, 0, 0, 0))
def px(f, x, y, c):
    if 0 <= x < 16 and 0 <= y < 16: sheet.putpixel((f * 16 + x, y), (*c, 255))

def base(f):
    # 一圈石頭（橢圓）
    for (x, y) in ((2, 12), (3, 13), (5, 14), (7, 14), (9, 14), (11, 13), (13, 12), (12, 11), (3, 11), (6, 11), (10, 11)):
        px(f, x, y, S2); px(f, x + 1, y, S1); px(f, x, y - 1, S3)
    # 交叉的柴
    for i in range(8):
        px(f, 4 + i, 12 - i // 3, W2); px(f, 4 + i, 13 - i // 3, W1)
        px(f, 11 - i, 12 - i // 3, W3); px(f, 11 - i, 13 - i // 3, W1)

def flame(f, shape):
    rows = shape
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            c = {"r": RED, "y": YEL, "w": LAMP_L, "o": OUT}.get(ch)
            if c: px(f, x + 4, y + 1, c)

base(0)
base(1); flame(1, ["...r....", "...rr...", "..rry...", "..ryyr..", ".rryyr..", ".ryywyr.", ".ryywyr.", "rrywwyrr", ".ryyyyr.", "..rrrr.."])
base(2); flame(2, ["....r...", "...rr...", "...ryr..", "..ryyr..", "..ryyrr.", ".ryywyr.", ".rywwyr.", "rryywyrr", ".ryyyyr.", "..rrrr.."])
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../assets/art/campfire.png")
sheet.save(out)
sheet.resize((48 * 6, 16 * 6), Image.NEAREST).save(os.path.expanduser("~/mnt/nova/.cf.png"))
