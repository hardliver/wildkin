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
#   （W70 加第 5 列，火山洞用）48 岩漿池、49 有岩漿裂縫的地面、50 溫泉（冒熱氣）、51 冒蒸氣的孔
#   （W73 加第 6 列，鐵輪工廠用；只用已經有的顏色）60/61 輸送帶（兩格輪流畫就會動）、62 控制台（運轉中）、
#   63 控制台（停了）、64 打卡機、65 玻璃罩（裡面發光的燈蛾）、66 電梯門、67 貨梯（木架＋鐵欄）
#   （W74 加第 7 列，山脊、聖所用）72 岩壁、73 崖邊（上面是草、下面是岩壁）、74 草地上的大石頭、
#   75 雲（聖所邊緣，雲海和草地的交界）、76 立石（聖所的石圈）、77 雲海
#   （W74）老榕樹 3×3：84、85、86／96、97、98／108、109、110（上排樹冠、中排樹冠＋樹幹、下排氣根和樹根）
import os, sys
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

sheet = Image.new("RGBA", (12 * 16, 10 * 16), (0, 0, 0, 0))

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

# 48：岩漿池
fill(48, RED)
for y in range(16):
    for x in range(16):
        v = h(x // 2, y // 2, 48) % 7
        if v == 0: put(48, x, y, LAMP)
        elif v == 1: put(48, x, y, SALMON)
        elif v == 2 and y % 4 == 0: put(48, x, y, OUT_)

# 49：有岩漿裂縫的地面（焦黑的地，一條條發光的縫）
fill(49, OUT_)
for y in range(16):
    for x in range(16):
        if h(x, y, 49) % 9 == 0: put(49, x, y, G_D)
for (x0, y0, dx, dy, n) in ((1, 3, 1, 1, 6), (7, 8, 1, -1, 5), (9, 12, 1, 0, 5), (3, 10, 0, 1, 4)):
    for i in range(n):
        x, y = x0 + dx * i, y0 + dy * i
        put(49, x, y, LAMP if i % 2 else SALMON)

# 50：溫泉（偏綠的水、幾縷熱氣）
water(50, 13)
for y in range(16):
    for x in range(16):
        if (x + y * 3) % 13 == 0: put(50, x, y, W2)
for (x, y) in ((4, 3), (4, 2), (5, 1), (10, 6), (11, 5), (11, 4)):
    put(50, x, y, FOAM)

# 51：冒蒸氣的孔（焦黑的地上一個洞，白煙往上飄）
fill(51, OUT_)
for y in range(9, 14):
    for x in range(5, 11):
        if (x - 8) ** 2 + (y - 11) ** 2 * 2 < 10: put(51, x, y, G_D)
for (x, y) in ((7, 8), (8, 7), (8, 6), (9, 5), (8, 4), (7, 3), (8, 2)):
    put(51, x, y, G_L)

# 60、61：輸送帶（上下是鐵軌、中間是皮帶上的斜紋；61 的斜紋往右挪 2 格，兩格輪流畫看起來就在動）
def conveyor(n, shift):
    fill(n, G_M)
    for x in range(16):
        put(n, x, 0, OUT_); put(n, x, 1, G_D); put(n, x, 14, G_D); put(n, x, 15, OUT_)
        for y in range(3, 13):
            if (x - y - shift) % 4 == 0: put(n, x, y, G_L)
        put(n, x, 2, G_D if x % 4 else OUT_); put(n, x, 13, G_D if x % 4 else OUT_)   # 滾輪
conveyor(60, 0)
conveyor(61, 2)

# 62、63：控制台（灰色的機台、上面一個小螢幕、紅色的停止鈕）
def console(n, on):
    for y in range(3, 16):
        for x in range(2, 14):
            edge = x in (2, 13) or y in (3, 15)
            put(n, x, y, OUT_ if edge else G_M)
    for y in range(5, 9):
        for x in range(4, 12):
            put(n, x, y, (GRASS if (x + y) % 3 else GRASS_D) if on else G_D)   # 螢幕：運轉中是綠的波形
    for (x, y) in ((5, 11), (6, 11), (5, 12), (6, 12)):
        put(n, x, y, RED if on else SALMON)                                  # 停止鈕：按下去之後變淡
    for x in (9, 11):
        put(n, x, 11, LAMP if on else G_D); put(n, x, 12, G_D)               # 指示燈
console(62, True)
console(63, False)

# 64：打卡機（牆上的灰盒子、圓形的鐘、下面插卡的縫）
for y in range(1, 15):
    for x in range(3, 13):
        put(64, x, y, OUT_ if x in (3, 12) or y in (1, 14) else G_L)
for y in range(3, 9):
    for x in range(5, 11):
        if (x - 7.5) ** 2 + (y - 5.5) ** 2 <= 8: put(64, x, y, FOAM)
put(64, 7, 4, OUT_); put(64, 7, 5, OUT_); put(64, 8, 5, OUT_)                  # 指針
for x in range(5, 11): put(64, x, 11, OUT_)                                   # 插卡的縫
put(64, 10, 12, RED)

# 65：玻璃罩（照明線：關著一隻燈蛾，發著光）
for y in range(1, 16):
    for x in range(2, 14):
        edge = x in (2, 13) or y in (1, 15)
        put(65, x, y, G_D if edge else W2)
for y in range(4, 13):
    for x in range(4, 12):
        d = (x - 7.5) ** 2 + (y - 8) ** 2
        if d <= 4: put(65, x, y, LAMP_L)
        elif d <= 10: put(65, x, y, LAMP)
put(65, 4, 3, FOAM); put(65, 4, 4, FOAM); put(65, 5, 3, FOAM)                 # 玻璃的反光
for x in range(2, 14): put(65, x, 15, OUT_)

# 66：電梯門（兩片灰門、中間一條縫、上面的樓層燈）
for y in range(0, 16):
    for x in range(1, 15):
        edge = x in (1, 14) or y == 0
        put(66, x, y, OUT_ if edge else (G_L if x < 8 else G_M))
for y in range(3, 16): put(66, 7, y, OUT_); put(66, 8, y, G_D)
for x in range(5, 11): put(66, x, 1, G_D)
put(66, 7, 1, LAMP); put(66, 8, 1, LAMP)

# 67：貨梯（木頭的框、鐵欄杆，火山洞往工廠）
for y in range(0, 16):
    for x in range(0, 16):
        if x in (0, 1, 14, 15) or y in (0, 1): put(67, x, y, WOOD_D if x in (0, 15) or y == 0 else WOOD)
        elif x % 3 == 0: put(67, x, y, G_D)
        else: put(67, x, y, OUT_)
for x in range(2, 14): put(67, x, 15, WOOD)

# ---- W74：山脊、聖所 ----
LEAF_D = (71, 159, 74)        # Tiny Town 最暗的樹葉綠（本來就在調色盤裡）

def rock_fill(n, seed):
    """山的岩壁：不規則的大石塊（用格子點附近的距離分區，像 Voronoi），每塊左上亮、右下暗，塊和塊之間是深色的縫"""
    pts = [((h(i, 0, seed) % 16), (h(i, 1, seed) % 16)) for i in range(6)]
    def cell(x, y):
        best, bd, second = 0, 1e9, 1e9
        for i, (px, py) in enumerate(pts):
            for ox in (-16, 0, 16):                 # 左右上下接得起來（格子拼在一起看不出接縫）
                for oy in (-16, 0, 16):
                    d = (x - px - ox) ** 2 + (y - py - oy) ** 2
                    if d < bd: best, second, bd = i, bd, d
                    elif d < second: second = d
        return best, second - bd
    for y in range(16):
        for x in range(16):
            i, gap = cell(x, y)
            if gap < 10: put(n, x, y, OUT_ if gap < 4 else G_D)          # 石塊之間的縫
            else:
                ci, _ = cell(x - 1, y - 1)
                put(n, x, y, G_L if ci != i else (G_M if h(x, y, seed + 9) % 9 else G_D))   # 左上的邊亮一點

# 72：岩壁
rock_fill(72, 72)
# 73：崖邊（上面 5 行是草，草的下緣有一排深色的影子，下面是岩壁）
rock_fill(73, 73)
for y in range(5):
    for x in range(16):
        put(73, x, y, GRASS if h(x, y, 73) % 5 else GRASS_D)
for x in range(16):
    put(73, x, 5, GRASS_D if x % 3 else OUT_)
    put(73, x, 6, OUT_ if h(x, 6, 7) % 3 == 0 else G_D)
# 74：草地上的大石頭
fill(74, GRASS)
for y in range(16):
    for x in range(16):
        if h(x, y, 74) % 7 == 0: put(74, x, y, GRASS_D)
for y in range(3, 15):
    for x in range(2, 14):
        d = ((x - 7.5) / 6) ** 2 + ((y - 9) / 6) ** 2
        if d <= 1:
            c = G_L if (x + y < 14) else (G_M if d < 0.7 else G_D)
            put(74, x, y, c)
        elif d <= 1.25: put(74, x, y, OUT_)
for x in range(4, 12): put(74, x, 15, GRASS_D)                     # 石頭下的影子
# 77：雲海（淡藍底、一團團白雲）
def clouds(n, seed, top=0):
    for y in range(top, 16):
        for x in range(16):
            put(n, x, y, W2 if (x + y * 2 + seed) % 11 else FOAM)
    for (cx, cy, r) in ((4, 6, 4), (11, 9, 5), (2, 13, 3), (13, 3, 3)):
        for y in range(max(top, cy - r), min(16, cy + r + 1)):
            for x in range(cx - r - 1, cx + r + 2):
                if 0 <= x < 16 and (x - cx) ** 2 + ((y - cy) * 1.4) ** 2 <= r * r:
                    put(n, x, y, FOAM if y < cy else (232, 244, 250))
clouds(77, 0)
# 75：雲（上半是草地的邊緣，下半是雲）
clouds(75, 3, top=0)
for y in range(0, 6):
    for x in range(16):
        if y < 4 or h(x, y, 75) % 3: put(75, x, y, GRASS if h(x, y, 76) % 4 else GRASS_D)
for x in range(16): put(75, x, 6 if h(x, 0, 75) % 2 else 5, OUT_)
# 76：立石（草地上一根直立的長石頭）
fill(76, GRASS)
for y in range(1, 15):
    for x in range(5, 11):
        edge = x in (5, 10) or y == 1
        put(76, x, y, OUT_ if edge else (G_L if x < 8 else G_M))
for (x, y) in ((7, 5), (8, 6), (7, 9)): put(76, x, y, G_D)        # 刻痕
for x in range(4, 12): put(76, x, 15, GRASS_D)

# 老榕樹（3×3 格 = 48×48 像素）：先畫在一張大圖上，再切成 9 格貼到 84～86、96～98、108～110
big_t = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
def bput(x, y, c):
    if 0 <= x < 48 and 0 <= y < 48: big_t.putpixel((x, y), (*c, 255))
# 樹冠：好幾團綠葉疊起來（亮的在上、暗的在下）
for (cx, cy, r) in ((24, 13, 14), (12, 17, 10), (36, 17, 10), (18, 8, 8), (31, 8, 8), (24, 22, 12)):
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            d = (x - cx) ** 2 + (y - cy) ** 2
            if d <= r * r:
                c = LEAF_D if y > cy + r // 3 else (GRASS_D if h(x // 2, y // 2, 9) % 3 else GRASS)
                bput(x, y, c)
for y in range(48):                                              # 樹冠的外框
    for x in range(48):
        p = big_t.getpixel((x, y))
        if p[3] == 0 and y < 34:
            if any(0 <= x + dx < 48 and 0 <= y + dy < 48 and big_t.getpixel((x + dx, y + dy))[3] and big_t.getpixel((x + dx, y + dy))[:3] != OUT_
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                bput(x, y, OUT_)
# 樹幹：粗、往下張開
for y in range(26, 44):
    w = 6 + (y - 26) // 3
    for x in range(24 - w, 24 + w):
        edge = x in (24 - w, 24 + w - 1)
        bput(x, y, OUT_ if edge else (WOOD if (x + y) % 5 else WOOD_D))
# 氣根：從樹冠下緣垂下來（淺色，和樹幹分開），根尖有小葉片
for i, x in enumerate((8, 13, 18, 30, 35, 40)):
    top = 26 + (i % 2) * 2
    L = 12 + (i * 5) % 9
    for y in range(top, top + L):
        xx = x + ((y // 4) % 2 if i % 2 else -((y // 4) % 2))
        bput(xx, y, SAND_D)
    bput(x, top + L, GRASS)
    bput(x + 1, top + L, GRASS_D)
# 樹根：在地面上往兩邊伸
for (x0, dx) in ((14, -1), (34, 1), (20, -1), (28, 1)):
    for i in range(8):
        bput(x0 + dx * i, 44 + i // 4, WOOD_D)
        bput(x0 + dx * i, 45 + i // 4, OUT_)
for j, n0 in enumerate((84, 96, 108)):
    for i in range(3):
        cell = big_t.crop((i * 16, j * 16, i * 16 + 16, j * 16 + 16))
        ox, oy = tile(n0 + i)
        sheet.alpha_composite(cell, (ox, oy))

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../assets/art/harbor.png")
if len(sys.argv) > 1: out = sys.argv[1]
sheet.save(out)
print("ok", len({p[:3] for p in sheet.getdata() if p[3]}), "colors")
