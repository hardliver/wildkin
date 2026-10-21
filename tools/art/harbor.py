# 港灣圖塊（W68）：python3 tools/art/harbor.py → assets/art/harbor.png
# Kenney 的 Tiny Town、Tiny Dungeon 都沒有海，港灣鎮用這張自己畫的圖塊（12 × 3 格，每格 16 × 16）。
# 地圖的 tilesets = ["town", "dungeon", "harbor"] → 這張的第 n 格 = 地圖格子編號 265 + n。
# 顏色盡量用 Tiny Town 已經有的（引擎全部圖片最多 240 色）；新的只有海水的藍、沙灘的淺黃。
#
#   第 0～15 格：海水。格子編號的 4 個 bit = 哪幾邊靠岸（1 北、2 東、4 南、8 西），靠岸那邊畫白色浪花
#   16 沙灘、17 沙灘（有貝殼）、18 木棧道（橫的木板）、19 木棧道（直的）、20 海裡的木樁、
#   21 防波堤石塊、22 防波堤石塊（有青苔）、23 繫船柱（在木棧道上）
#   24/25 燈塔頂（燈）、26/27 燈塔中段（紅白條紋）、28/29 燈塔底（門）、
#   30/31 小船（左、右）、32 一箱魚、33 浮標（海上）、34 漁網、35 海裡的礁石
#   （W69 加第 4 列）36 木筏（海上，拖筏渡水）、37 潮池（沙灘上的小水窪）、38 沙灘上的礁岩、39 崖邊的草（海岸北邊）、
#   40 漂流木、41 籠子（運輸船甲板上，裡面有野伴的影子）
import os
from PIL import Image

OUT_ = (63, 38, 49)          # Tiny Town 的外框色
DIRT, WOOD, WOOD_D = (234, 165, 108), (189, 108, 74), (118, 59, 54)
G_L, G_M, G_D = (192, 203, 220), (139, 155, 180), (82, 96, 124)
RED, SALMON, GRASS, GRASS_D = (195, 75, 53), (242, 132, 98), (132, 198, 105), (101, 165, 86)
W0, W1, W2, FOAM = (52, 120, 186), (72, 152, 210), (122, 190, 230), (232, 244, 250)   # 新的：海水
SAND, SAND_D = (240, 206, 146), (214, 172, 116)                                       # 新的：沙灘
LAMP, LAMP_L = (255, 204, 80), (255, 240, 170)

def h(x, y, s=0):
    v = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
    v ^= v >> 13
    return (v * 1274126177 >> 16) & 0xffff

sheet = Image.new("RGBA", (12 * 16, 4 * 16), (0, 0, 0, 0))

def tile(n):
    return (n % 12) * 16, (n // 12) * 16

def put(n, x, y, c):
    ox, oy = tile(n)
    if 0 <= x < 16 and 0 <= y < 16:
        sheet.putpixel((ox + x, oy + y), (*c, 255))

def fill(n, c):
    for y in range(16):
        for x in range(16): put(n, x, y, c)

def water(n, seed=0):
    fill(n, W1)
    for y in range(16):                       # 一條條淺淺的波紋
        for x in range(16):
            v = h(x // 3, y, seed + n) % 23
            if v == 0: put(n, x, y, W2)
            elif v == 1: put(n, x, y, W0)

# 0～15：海水＋靠岸那邊的浪花
for m in range(16):
    water(m)
    for i in range(16):
        if m & 1:                             # 北
            put(m, i, 0, FOAM); put(m, i, 1, W2 if i % 3 else FOAM)
        if m & 4:                             # 南
            put(m, i, 15, FOAM); put(m, i, 14, W2 if i % 3 else FOAM)
        if m & 8:                             # 西
            put(m, 0, i, FOAM); put(m, 1, i, W2 if i % 3 else FOAM)
        if m & 2:                             # 東
            put(m, 15, i, FOAM); put(m, 14, i, W2 if i % 3 else FOAM)

# 16、17：沙灘
for n in (16, 17):
    fill(n, SAND)
    for y in range(16):
        for x in range(16):
            if h(x, y, n) % 17 == 0: put(n, x, y, SAND_D)
if True:   # 17：貝殼
    for (x, y) in ((5, 6), (6, 6), (5, 7), (6, 7), (7, 7)): put(17, x, y, SALMON)
    put(17, 6, 5, G_L); put(17, 11, 11, G_L); put(17, 12, 11, G_L)

# 18：木棧道（橫的木板），19：直的
fill(18, WOOD)
for y in (0, 4, 8, 12):
    for x in range(16): put(18, x, y, WOOD_D)
for y in range(16):
    for x in (3, 11):
        if y % 4 == 2: put(18, x, y, OUT_)   # 釘子
fill(19, WOOD)
for x in (0, 4, 8, 12):
    for y in range(16): put(19, x, y, WOOD_D)
for x in range(16):
    for y in (3, 11):
        if x % 4 == 2: put(19, x, y, OUT_)

# 20：海裡的木樁
water(20, 5)
for y in range(3, 15):
    for x in range(6, 10):
        put(20, x, y, WOOD if x < 9 else WOOD_D)
for x in range(6, 10): put(20, x, 3, DIRT)
for x in range(5, 11): put(20, x, 14, FOAM)

# 21、22：防波堤的大石塊
for n in (21, 22):
    fill(n, G_M)
    for (x0, y0, w, hh) in ((0, 0, 8, 7), (8, 0, 8, 5), (0, 7, 5, 9), (5, 7, 11, 4), (8, 5, 8, 2), (5, 11, 11, 5)):
        for x in range(x0, x0 + w):
            put(n, x, y0, G_L)
            put(n, x, y0 + hh - 1, G_D)
        for y in range(y0, y0 + hh):
            put(n, x0, y, G_L)
            put(n, x0 + w - 1, y, G_D)
for (x, y) in ((2, 12), (3, 12), (3, 13), (11, 2), (12, 2), (12, 3), (13, 3)):
    put(22, x, y, GRASS_D)

# 23：繫船柱（木棧道上）
for y in range(16):
    for x in range(16): sheet.putpixel((tile(23)[0] + x, tile(23)[1] + y), sheet.getpixel((tile(18)[0] + x, tile(18)[1] + y)))
for y in range(5, 13):
    for x in range(5, 11): put(23, x, y, G_D if x > 8 else G_M)
for x in range(4, 12): put(23, x, 5, OUT_); put(23, x, 12, OUT_)
for x in range(5, 11): put(23, x, 7, G_L)

# 24～29：燈塔（2 格寬、3 格高）
def tower(n0, row):
    for half in (0, 1):
        n = n0 + half
        for y in range(16):
            for x in range(16):
                gx = half * 16 + x                    # 燈塔的 x（0～31）
                if row == 0:                          # 頂：燈
                    if 9 <= gx <= 22 and y >= 5:
                        c = LAMP_L if (gx + y) % 5 else LAMP
                        if gx in (9, 22) or y == 5: c = OUT_
                        put(n, x, y, c)
                    if 7 <= gx <= 24 and y >= 14: put(n, x, y, RED if y == 14 else OUT_)
                    if 13 <= gx <= 18 and 1 <= y < 5: put(n, x, y, RED if y > 1 else OUT_)
                else:
                    l, r = 8, 23
                    if l <= gx <= r:
                        stripe = (y // 6 + row) % 2 == 0
                        c = (G_L if stripe else RED)
                        if gx == l or gx == r: c = OUT_
                        elif gx > r - 4: c = (G_M if stripe else (150, 56, 40))
                        put(n, x, y, c)
                    if row == 2 and 13 <= gx <= 18 and y >= 7:   # 門
                        put(n, x, y, WOOD_D if 14 <= gx <= 17 else OUT_)
tower(24, 0); tower(26, 1); tower(28, 2)

# 30、31：小船（停在水上）
for half, n in ((0, 30), (1, 31)):
    water(n, 9)
    for y in range(4, 14):
        for x in range(16):
            gx = half * 16 + x
            top = 6 if 3 < gx < 28 else 9
            inside = (y >= top) and (gx - (y - 6) // 2 >= 1) and (gx + (y - 6) // 2 <= 30)
            if inside:
                c = WOOD if y < 11 else WOOD_D
                if y == top: c = OUT_
                if y == 9: c = RED
                put(n, x, y, c)
    for x in range(16): put(n, x, 14, FOAM if (x + half) % 3 else W2)

# 32：一箱魚
fill(32, (0, 0, 0)); sheet.paste(Image.new("RGBA", (16, 16), (0, 0, 0, 0)), tile(32))
for y in range(6, 15):
    for x in range(2, 14):
        put(32, x, y, WOOD if y > 7 else WOOD_D)
for x in range(2, 14): put(32, x, 6, OUT_); put(32, x, 14, OUT_)
for (x, y) in ((4, 4), (5, 4), (6, 5), (7, 4), (8, 4), (9, 5), (10, 4), (11, 4)):
    put(32, x, y, G_L); put(32, x, y + 1, G_M)

# 33：浮標
water(33, 3)
for y in range(4, 12):
    for x in range(5, 11):
        put(33, x, y, RED if y < 8 else G_L)
for x in range(4, 12): put(33, x, 12, FOAM)

# 34：漁網（掛在沙灘上）
fill(34, SAND)
for y in range(2, 14):
    for x in range(2, 14):
        if (x + y) % 3 == 0 or (x - y) % 3 == 0: put(34, x, y, G_D)

# 35：海裡的礁石
water(35, 7)
for y in range(5, 14):
    for x in range(3, 13):
        if (x - 8) ** 2 + (y - 10) ** 2 * 2 < 36:
            put(35, x, y, G_M if x < 9 else G_D)
for x in range(3, 13): put(35, x, 13, FOAM)

# 36：木筏（海上）
water(36, 11)
for y in range(4, 13):
    for x in range(1, 15):
        c = WOOD if (x // 3) % 2 == 0 else (200, 120, 82) if False else WOOD
        if x % 3 == 0: c = WOOD_D
        if y in (4, 12) or x in (1, 14): c = OUT_
        put(36, x, y, c)
for x in (3, 12):
    for y in range(5, 12): put(36, x, y, DIRT)          # 綁木頭的繩子
for x in range(1, 15): put(36, x, 13, FOAM if x % 3 else W2)

# 37：潮池（沙灘上的小水窪）
fill(37, SAND)
for y in range(3, 13):
    for x in range(2, 14):
        if (x - 8) ** 2 + (y - 8) ** 2 * 2 < 34:
            put(37, x, y, W2 if y < 6 else W1)
put(37, 6, 9, SALMON); put(37, 9, 7, G_L)              # 小螃蟹、小石頭

# 38：沙灘上的礁岩（擋路）
fill(38, SAND)
for y in range(3, 15):
    for x in range(1, 15):
        if (x - 8) ** 2 + (y - 10) ** 2 * 2 < 52:
            put(38, x, y, G_M if x < 9 else G_D)
            if y < 6 or (x - 8) ** 2 + (y - 10) ** 2 * 2 > 44: put(38, x, y, OUT_ if y > 4 else G_L)

# 39：崖邊（上面是草，下面是土崖）
fill(39, GRASS)
for y in range(9, 16):
    for x in range(16):
        put(39, x, y, WOOD if y > 10 else OUT_)
        if y > 11 and (x + y) % 4 == 0: put(39, x, y, WOOD_D)

# 40：漂流木（沙灘上）
fill(40, SAND)
for x in range(2, 14):
    for y in range(7, 11):
        put(40, x, y, WOOD_D if y == 10 or x in (2, 13) else WOOD)

# 41：籠子（運輸船的甲板上，裡面有野伴的影子）
fill(41, WOOD)
for y in range(2, 15):
    for x in range(2, 14):
        if x in (2, 13) or y in (2, 14) or x % 3 == 2: put(41, x, y, G_D)
        elif (x - 8) ** 2 + (y - 9) ** 2 < 10: put(41, x, y, OUT_)

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../assets/art/harbor.png")
sheet.save(out)
big = sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST)
big.save(os.path.expanduser("~/mnt/nova/.hb.png"))
print("ok", len({p[:3] for p in sheet.getdata() if p[3]}), "colors")
