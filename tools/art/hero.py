# 大志（主角）：python3 tools/art/hero.py → assets/art/hero.png（16×16 × 5 格）
# 以 Tiny Dungeon 第 112 格（原本的綠頭巾樵夫）為底重畫成中年大叔：
#   兩鬢微白、髮線後退、八字鬍、藍色 POLO 衫＋卡其褲＋皮帶、咖啡色皮鞋，肚子略寬
# 第 0 格：走路／站著；第 1、2 格：騎菜籃車（踩踏板兩格輪流）；第 3、4 格：電動輔助菜籃車
# 顏色全部取自 Kenney Tiny Dungeon／Tiny Town，不多佔調色盤
import os, sys
from PIL import Image
C = {
    "o": (63, 38, 49),    # 外框
    "h": (118, 59, 54),   # 頭髮、鞋子、皮帶
    "g": (139, 155, 180), # 白頭髮（兩鬢）
    "s": (247, 194, 130), # 皮膚
    "k": (225, 154, 101), # 皮膚陰影
    "e": (38, 43, 68),    # 眼睛
    "G": (90, 105, 136),  # 眼鏡框
    "m": (189, 108, 74),  # 嘴
    "W": (228, 237, 249), # 領子、扣子
    "p": (0, 153, 219),   # POLO 衫
    "P": (82, 96, 124),   # POLO 衫陰影
    "n": (207, 130, 84),  # 卡其褲
    "N": (189, 108, 74),  # 卡其褲陰影
    "Y": (254, 231, 97),  # 皮帶扣
    "r": (139, 155, 180), # 車輪框（灰）
    "R": (82, 96, 124),   # 輪胎
    "f": (232, 69, 55),   # 車架（紅）
    "b": (139, 155, 180), # 菜籃（鐵絲）
    "B": (82, 96, 124),   # 菜籃陰影
    "v": (67, 225, 179),  # 電池燈（綠）
    "V": (37, 149, 106),  # 電池盒
    "L": (254, 231, 97),  # 車燈
}
HERO = [
    "......ooooo.....",
    "....oooooooo....",
    "...oohhhhhhoo...",
    "..oohhhhhhhhoo..",
    "..oogshhhhsgoo..",
    "..oogssssssgoo..",
    "..oossssssssoo..",
    "..ooshesssesoo..",
    "..ooksesssekoo..",
    "..oookhhhhkooo..",
    ".ooopWWkkWWpooo.",
    "ooPppppWpppppPoo",
    "okkPhhhYhhhhPkko",
    "ookonnnNNnnnokoo",
    "oooonnNoonNnoooo",
    ".ooohhhoohhhooo.",
]
# 騎車時的大志（只有上半身：頭、上衣、握把的手、皮帶）：畫在車子左上，往上 3 格（坐在座墊上）
RIDER = HERO[:11] + [
    "..oPppWpppPkkoo.",
    "..oPppppppPoo...",
    "...ohhYhhhho....",
]
RIDER_DX, RIDER_DY = 2, -3
# 菜籃車（24×16，側面，車頭朝右；往左走時整張翻轉）：彎彎的下管（淑女車）、後貨架、前菜籃
def bike(pedal, electric):
    g = [list("." * 24) for _ in range(16)]
    def put(x, y, ch):
        if 0 <= x < 24 and 0 <= y < 16: g[y][x] = ch
    for cx in (4, 19):
        for (dx, dy) in ((-1, -3), (0, -3), (1, -3), (-2, -2), (2, -2), (-3, -1), (3, -1), (-3, 0), (3, 0), (-3, 1), (3, 1), (-2, 2), (2, 2), (-1, 3), (0, 3), (1, 3)):
            put(cx + dx, 12 + dy, "o")
        for (dx, dy) in ((-1, -2), (0, -2), (1, -2), (-2, -1), (2, -1), (-2, 0), (2, 0), (-2, 1), (2, 1), (-1, 2), (0, 2), (1, 2)):
            put(cx + dx, 12 + dy, "r")
        put(cx, 12, "W")
        sp = ((0, -1), (0, 1), (-1, 0), (1, 0)) if pedal else ((-1, -1), (1, 1), (1, -1), (-1, 1))
        for dx, dy in sp: put(cx + dx, 12 + dy, "R")
    # 後貨架
    for x in range(2, 9): put(x, 8, "r")
    put(3, 9, "R"); put(6, 9, "R")
    # 車架（紅）：後下叉、座管、彎彎的下管、龍頭和前叉
    for x in range(5, 12): put(x, 12 + (x - 5) // 4, "f")
    for y in range(9, 13): put(10, y, "f")
    for (x, y) in ((11, 13), (12, 13), (13, 12), (14, 11), (15, 10), (16, 9), (17, 8)): put(x, y, "f")
    for (x, y) in ((17, 7), (18, 9), (18, 10), (19, 11)): put(x, y, "f")
    put(18, 8, "f")
    for x in (15, 16, 17): put(x, 6, "o")   # 握把
    put(9, 8, "o"); put(10, 8, "o"); put(11, 8, "o")   # 座墊
    # 菜籃（龍頭前面）
    for y in range(4, 9):
        for x in range(18, 24):
            put(x, y, "o" if y in (4, 8) or x in (18, 23) else ("b" if (x + y) % 2 else "B"))
    # 腿：從皮帶（車子第 10 列）往下：大腿往前、膝蓋彎、小腿踩踏板，外面一圈外框才看得清楚
    #   pedal 0：右腳在前上方；pedal 1：右腳踩到最下面
    LEG = ([
        "oooooo..",
        "onnnnNo.",
        ".ooooNNo",
        "....ohho",
        ".....oo.",
    ], [
        "ooooo...",
        "onnnNo..",
        ".onnNo..",
        "..oNNo..",
        "..ohhho.",
        "...ooo..",
    ])[pedal]
    for dy, row in enumerate(LEG):
        for dx, ch in enumerate(row):
            if ch != ".": put(8 + dx, 10 + dy, ch)
    if electric:
        for (x, y) in ((5, 10), (6, 10), (7, 10), (6, 11), (7, 11), (8, 11)): put(x, y, "V")
        put(6, 10, "v")
        put(22, 9, "L"); put(23, 9, "L")
    return ["".join(r) for r in g]

# 上下騎（參考 GB 寶可夢：往下騎看到正面＋握把＋菜籃＋前輪，往上騎看到背面＋後貨架＋後輪）
# 16×20：比走路的圖高 4 像素（輪子露在下面），畫的時候往上 4 像素對齊腳底
def legs(g, pedal):
    # 兩隻腳在左右兩邊踩踏板；pedal 1 時左腳低一格、右腳高一格
    L = ["onno", "onno", "oNNo", "ohho", "oooo"]
    for side, x0 in ((0, 1), (1, 11)):
        dy = (1 if side == 0 else -1) if pedal else 0
        for i, row in enumerate(L):
            for j, ch in enumerate(row):
                y = 12 + i + dy
                if 0 <= y < 20: g[y][x0 + j] = ch

def bike_down(pedal, electric):
    g = [list(r) for r in HERO[:11]] + [list("." * 16) for _ in range(9)]
    g[11] = list("okkrrrrrrrrrrkko")                 # 握把（兩手握著）
    for y, row in ((12, "bBbBbB"), (13, "BbBbBb"), (14, "LooooL" if electric else "oooooo")):
        g[y][5:11] = list(row)                       # 鐵絲菜籃
    for y in range(15, 19): g[y][6:10] = list("oRRo")   # 前輪
    g[19][6:10] = list(".oo.")
    legs(g, pedal)
    return ["".join(r) for r in g]

BACK = [
    "......ooooo.....",
    "....oooooooo....",
    "...oohhhhhhoo...",
    "..oohhhhhhhhoo..",
    "..oohhhhhhhhoo..",
    "..oohhhhhhhhoo..",
    "..oohhhhhhhhoo..",
    "..ooghhhhhhgoo..",
    "..ooghhhhhhgoo..",
    "..oookssssooo...",
    ".ooopWWWWWWpooo.",
    "okkPppppppppPkko",
    "ookPppppppppPkoo",
]
def bike_up(pedal, electric):
    g = [list(r) for r in BACK] + [list("." * 16) for _ in range(7)]
    g[13][4:12] = list("ohhhhhho")                               # 皮帶（背面）
    g[14][5:11] = list("VVvVVV" if electric else "rrrrrr")       # 後貨架（電動版放電池）
    g[15][6:10] = list("offo")                                   # 紅色反光片
    for y in range(16, 19): g[y][6:10] = list("oRRo")            # 後輪
    g[19][6:10] = list(".oo.")
    legs(g, pedal)
    return ["".join(r) for r in g]

# 排法（x=128 以後見下面）：x=0 走路、x=16 騎車的人、x=32 起四台車（各 24 寬：菜籃車兩格、電動兩格）
PARTS = [(0, HERO), (16, RIDER + ["." * 16] * 2), (32, bike(0, False)), (56, bike(1, False)), (80, bike(0, True)), (104, bike(1, True))]
# x=128 起：往下騎 ×2、往上騎 ×2、電動往下 ×2、電動往上 ×2（各 16 寬）
for i, (fn, e) in enumerate(((bike_down, False), (bike_up, False), (bike_down, True), (bike_up, True))):
    PARTS += [(128 + i * 32, fn(0, e)), (144 + i * 32, fn(1, e))]
sheet = Image.new("RGBA", (256, 20), (0, 0, 0, 0))
for ox, rows in PARTS:
    assert len(rows) in (16, 20) and len(set(map(len, rows))) == 1, (ox, rows)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".": sheet.putpixel((ox + x, y), (*C[ch], 255))
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../assets/art/hero.png")
sheet.save(out)
if "--preview" in sys.argv:
    pv = Image.new("RGBA", (16 * 8 + 4 * 8, 24), (120, 170, 90, 255))
    for i in range(8):
        pv.alpha_composite(sheet.crop((128 + i * 16, 0, 144 + i * 16, 20)), (i * 20 + 2, 2))
    pv.resize((pv.width * 10, pv.height * 10), Image.NEAREST).save(os.path.expanduser("~/mnt/nova/.hero2.png"))
    old = Image.open(os.path.join(os.path.dirname(out), "../kenney/tiny-dungeon/tilemap.png")).convert("RGBA").crop((64, 144, 80, 160))
    pv = Image.new("RGBA", (16 + 4 + 16 + 4 + 4 * 28, 20), (120, 170, 90, 255))
    pv.alpha_composite(old, (0, 4)); pv.alpha_composite(sheet.crop((0, 0, 16, 16)), (20, 4))
    for i in range(4):
        bx = 40 + i * 28
        pv.alpha_composite(sheet.crop((32 + i * 24, 0, 56 + i * 24, 16)), (bx, 4))
        pv.alpha_composite(sheet.crop((16, 0, 32, 14)), (bx + RIDER_DX, 2 + RIDER_DY + 2))
    pv.resize((pv.width * 10, pv.height * 10), Image.NEAREST).save(os.path.expanduser("~/mnt/nova/.hero.png"))
