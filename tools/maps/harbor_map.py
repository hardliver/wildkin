# 港灣鎮的地圖草稿（W68）：python3 tools/maps/harbor_map.py → maps/harbor.json
# 產生一次之後就在 Studio 的地圖編輯器裡改；這支程式只是第一版的草稿（重跑會蓋掉 Studio 的修改）。
# 40 × 30 格（2 × 2 個畫面）。tilesets = town、dungeon、harbor（港灣圖塊的第 n 格 = 265 + n）
#   東口（礦坑的鐵門出來）→ 鎮上：旅店、商店、鐵輪公司辦事處、海鮮攤
#   南邊：沙灘（淺灘是遇敵的地方：shore 圖層）、往南伸進海裡的碼頭（阿穗第 3 戰）
#   西邊：海上的防波堤，盡頭是燈塔（岩之守礁嬤）
#   西南：往海岸的路被海隔開（第 3 章 W69：灌溉拖筏渡水）
import json, os, sys

W, H = 40, 30
HB = lambda n: 265 + n
SAND, SAND2 = HB(16), HB(17)
PLANK_H, PLANK_V, POST = HB(18), HB(19), HB(20)
BREAK, BREAK2, BOLLARD = HB(21), HB(22), HB(23)
FISH, BUOY, NET, REEF = HB(32), HB(33), HB(34), HB(35)
D = lambda n: n + 133

def h(x, y, s=0):
    v = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
    v ^= v >> 13
    return (v * 1274126177 >> 16) & 0xffff

def rect(x0, y0, x1, y1, s):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            s.add((x, y))

# 陸地／海
land = set()
rect(9, 0, 39, 19, land)          # 鎮上＋沙灘
rect(0, 12, 8, 13, land)          # 防波堤（兩格寬）
rect(0, 9, 4, 15, land)           # 燈塔的平台
rect(23, 20, 24, 27, land)        # 碼頭（往南）
rect(19, 26, 28, 27, land)        # 碼頭的盡頭（T 字）
sand = set()
rect(9, 17, 39, 19, sand)         # 沙灘
breakwater = set()
rect(0, 12, 8, 13, breakwater); rect(0, 9, 4, 15, breakwater)
pier = set()
rect(23, 20, 24, 27, pier); rect(19, 26, 28, 27, pier)
shore = set()                      # 遇敵：沙灘靠海的兩排
rect(10, 18, 21, 19, shore); rect(27, 18, 37, 19, shore)

dirt = set()
def hroad(x0, x1, y):
    for x in range(min(x0, x1), max(x0, x1) + 1): dirt.add((x, y)); dirt.add((x, y + 1))
def vroad(x, y0, y1):
    for y in range(min(y0, y1), max(y0, y1) + 1): dirt.add((x, y)); dirt.add((x + 1, y))
hroad(10, 39, 14)                  # 東口 → 鎮上 → 往西到防波堤
vroad(23, 8, 16)                   # 往北（辦事處）、往南（碼頭）
hroad(14, 32, 8)                   # 旅店、商店、辦事處門口

ground = [[0] * W for _ in range(H)]
deco = [[0] * W for _ in range(H)]
plants = [[0] * W for _ in range(H)]
solid = [[0] * W for _ in range(H)]
shore_l = [[0] * W for _ in range(H)]
DIRT = {(1, 1): 13, (1, 0): 14, (1, 2): 15, (0, 1): 25, (0, 0): 26, (0, 2): 27, (2, 1): 37, (2, 0): 38, (2, 2): 39}
for y in range(H):
    for x in range(W):
        c = (x, y)
        if c not in land:
            # 海：哪幾邊靠岸（1 北、2 東、4 南、8 西），靠岸那邊有浪花
            m = 0
            if (x, y - 1) in land: m |= 1
            if (x + 1, y) in land: m |= 2
            if (x, y + 1) in land: m |= 4
            if (x - 1, y) in land: m |= 8
            ground[y][x] = HB(m)
            solid[y][x] = 1
        elif c in pier:
            ground[y][x] = PLANK_V if y < 26 else PLANK_H
        elif c in breakwater:
            ground[y][x] = BREAK2 if h(x, y) % 4 == 0 else BREAK
        elif c in dirt and c not in sand:
            top = (x, y - 1) not in dirt; bot = (x, y + 1) not in dirt
            left = (x - 1, y) not in dirt and x > 0; right = (x + 1, y) not in dirt and x < W - 1
            ground[y][x] = DIRT[(1 if top else (2 if bot else 0), 1 if left else (2 if right else 0))]
        elif c in sand:
            ground[y][x] = SAND2 if h(x, y, 4) % 9 == 0 else SAND
        else:
            v = h(x, y) % 10
            ground[y][x] = 1 if v < 6 else (2 if v < 9 else 3)
        if c in shore: shore_l[y][x] = 1

# 北邊、東邊的邊界：樹（東口留路）
for x in range(9, W):
    for y in (0, 1):
        if not (x, y) in dirt:
            plants[y][x] = 29 if h(x, y, 1) % 5 else 28; solid[y][x] = 1
for y in range(2, 17):
    if y not in (14, 15):
        plants[y][39] = 29; solid[y][39] = 1
for y in range(2, 12):
    plants[y][9] = 29; solid[y][9] = 1

def building(x0, y0, w, roof, wall, door_x, door):
    """roof：(左, 中, 右) 兩列；wall：牆；門在 door_x"""
    (r1, r2) = roof
    for i in range(w):
        k = 0 if i == 0 else (2 if i == w - 1 else 1)
        deco[y0][x0 + i] = r1[k]; deco[y0 + 1][x0 + i] = r2[k]
        deco[y0 + 2][x0 + i] = door if x0 + i == door_x else wall
        for dy in range(3): solid[y0 + dy][x0 + i] = 1
RED = ((53, 54, 55), (65, 66, 67))
GREY = ((49, 50, 51), (61, 62, 63))
building(12, 5, 5, RED, 74, 14, 85)        # 港灣旅店（門 14, 7）
building(19, 5, 4, RED, 74, 20, 86)        # 商店（門 20, 7）
building(26, 4, 6, GREY, 78, 28, 90)       # 鐵輪公司辦事處（門 28, 6）：兩層樓高
for i in range(6):
    deco[3][26 + i] = (49, 50, 50, 50, 50, 51)[i]; solid[3][26 + i] = 1
    deco[4][26 + i] = (61, 62, 62, 62, 62, 63)[i]
for x in (26, 31): deco[6][x] = 78
deco[5][26] = 78; deco[5][31] = 78
# 辦事處門口的海報（告示牌）
# 海鮮攤：幾箱魚
for (x, y) in ((33, 11), (34, 11), (35, 11)):
    deco[y][x] = FISH; solid[y][x] = 1
# 沙灘上的漁網、碼頭的繫船柱、海上的浮標、礁石、小船
deco[17][12] = NET; solid[17][12] = 1
deco[17][36] = NET; solid[17][36] = 1
for (x, y) in ((22, 26), (25, 26)):
    deco[y][x] = BOLLARD; solid[y][x] = 1
ground[24][31] = BUOY; ground[28][14] = REEF; ground[22][35] = REEF; ground[5][6] = BUOY
ground[22][26], ground[22][27] = HB(30), HB(31)    # 碼頭旁的小船
ground[19][8] = HB(36)                               # 往海岸的木筏（W69）
# 燈塔（2 × 3）：(1, 9)～(2, 11)
for i, n in enumerate((24, 25, 26, 27, 28, 29)):
    x, y = 1 + i % 2, 9 + i // 2
    deco[y][x] = HB(n); solid[y][x] = 1

objects = [
    {"type": "fire", "x": 20, "y": 12},   # 營火（W71）
    {"type": "door", "x": 39, "y": 14, "to": "mine", "tx": 1, "ty": 14},
    {"type": "door", "x": 39, "y": 15, "to": "mine", "tx": 1, "ty": 15},
    {"type": "sign", "x": 37, "y": 13, "text": "港灣鎮"},
    {"type": "sign", "x": 11, "y": 7, "text": "港灣旅店"},
    {"type": "npc", "x": 15, "y": 8, "name": "harbor_inn", "tile": 231, "talk": "harbor_innkeeper"},
    {"type": "sign", "x": 18, "y": 7, "text": "港灣商店"},
    {"type": "npc", "x": 21, "y": 8, "name": "harbor_shop", "tile": 220, "talk": "harbor_shopkeeper"},
    {"type": "sign", "x": 25, "y": 6, "text": "鐵輪公司　港灣辦事處\\n「野伴就是生產力」——社長"},
    {"type": "npc", "x": 29, "y": 7, "name": "receptionist", "tile": D(99), "talk": "harbor_reception"},
    {"type": "npc", "x": 32, "y": 8, "name": "worker", "tile": D(85), "talk": "harbor_worker"},
    {"type": "npc", "x": 35, "y": 12, "name": "seafood", "tile": 230, "talk": "harbor_seafood"},
    {"type": "npc", "x": 17, "y": 12, "name": "insurance", "tile": D(98), "talk": "harbor_insurance"},
    {"type": "npc", "x": 26, "y": 25, "name": "fisher", "tile": D(112), "talk": "harbor_fisher"},
    {"type": "npc", "x": 30, "y": 16, "name": "harbor_kid", "tile": 218, "talk": "harbor_kid"},
    {"type": "npc", "x": 25, "y": 18, "name": "asui", "tile": 221, "talk": "rival", "trainer": "rival3", "look": "left"},
    {"type": "npc", "x": 36, "y": 18, "name": "rou", "tile": 232, "talk": "trainer", "trainer": "youth_rou", "look": "left"},   # 年輕訓練家（W71j）
    {"type": "npc", "x": 14, "y": 12, "name": "salaryman", "tile": 230, "talk": "trainer", "trainer": "youth_xiang", "look": "up"},   # 傍晚、晚上才在（talk.lua 的 NPC_HOURS）
    {"type": "npc", "x": 3, "y": 11, "name": "reef", "tile": D(100), "talk": "rock_keeper"},
    {"type": "event", "x": 37, "y": 14, "scene": "c2_harbor"},
    {"type": "event", "x": 37, "y": 15, "scene": "c2_harbor"},
    {"type": "sign", "x": 10, "y": 16, "text": "往海岸\\n（西邊海邊有木筏，要有會游泳的野伴拖）"},
    {"type": "raft", "x": 8, "y": 19, "to": "coast", "tx": 56, "ty": 9},
    {"type": "gather", "x": 15, "y": 17, "item": "fiber", "amount": 2, "tile": SAND2},
    {"type": "gather", "x": 32, "y": 17, "item": "stone", "amount": 2, "tile": SAND2},
]
for o in objects:          # 告示牌：地圖上也要放告示牌的圖（Tiny Town 第 84 格），會擋路
    if o["type"] == "sign":
        deco[o["y"]][o["x"]] = 84; solid[o["y"]][o["x"]] = 1

def rows(a):
    return ",\n".join("      " + json.dumps(r, separators=(",", ":")) for r in a)
out = ["{", f'  "width": {W},', f'  "height": {H},', '  "tilesets": ["town", "dungeon", "harbor"],', '  "objects": [']
out.append(",\n".join("    " + json.dumps(o, ensure_ascii=False, separators=(",", ":")) for o in objects))
out.append("  ],")
out.append('  "layers": {')
layers = [("ground", ground), ("deco", deco), ("plants", plants), ("solid", solid), ("shore", shore_l)]
for i, (name, a) in enumerate(layers):
    out.append(f'    "{name}": [')
    out.append(rows(a))
    out.append("    ]" + ("," if i < len(layers) - 1 else ""))
out.append("  }")
out.append("}")
target = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../maps/harbor.json")
open(target, "w").write("\n".join(out) + "\n")
print("ok", target)
