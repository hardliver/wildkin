# 海岸的地圖草稿（W69）：python3 tools/maps/coast_map.py → maps/coast.json
# 產生一次之後就在 Studio 的地圖編輯器裡改；這支程式只是第一版的草稿（重跑會蓋掉 Studio 的修改）。
# 60 × 15 格（3 × 1 個畫面）。北邊是長草的崖（擋路），中間沙灘，南邊是海。
#   東：從港灣鎮拖筏上岸、漁村小屋（阿婆、傳音石、休息）、營火
#   中：崖邊看得到鐵輪公司的運輸船（C3-2）
#   西：火山洞口（W70）
# 沿路 3 位訓練家（C3-3）；靠海的兩排沙灘會遇敵（shore 圖層）
import json, os, sys

W, H = 60, 15
HB = lambda n: 265 + n
D = lambda n: n + 133
SAND, SAND2 = HB(16), HB(17)
PLANK_H = HB(18)
RAFT, POOL, ROCK, CLIFF, DRIFT, CAGE = HB(36), HB(37), HB(38), HB(39), HB(40), HB(41)

def h(x, y, s=0):
    v = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
    v ^= v >> 13
    return (v * 1274126177 >> 16) & 0xffff

land = {(x, y) for x in range(W) for y in range(0, 10)}     # y 0～9 是陸地，10 以後是海
ground = [[0] * W for _ in range(H)]
deco = [[0] * W for _ in range(H)]
plants = [[0] * W for _ in range(H)]
solid = [[0] * W for _ in range(H)]
shore = [[0] * W for _ in range(H)]

for y in range(H):
    for x in range(W):
        if (x, y) not in land:
            m = 0
            if (x, y - 1) in land: m |= 1
            if (x + 1, y) in land and x + 1 < W: m |= 2
            if (x, y + 1) in land: m |= 4
            if (x - 1, y) in land and x > 0: m |= 8
            ground[y][x] = HB(m); solid[y][x] = 1
        elif y <= 2:                                   # 崖上：草和樹
            v = h(x, y) % 10
            ground[y][x] = 1 if v < 6 else (2 if v < 9 else 3)
            plants[y][x] = 29 if h(x, y, 1) % 4 else 28
            solid[y][x] = 1
        elif y == 3:                                   # 崖邊
            ground[y][x] = CLIFF; solid[y][x] = 1
        else:
            ground[y][x] = SAND2 if h(x, y, 4) % 11 == 0 else SAND
            if y >= 8: shore[y][x] = 1                 # 靠海的兩排會遇敵

# 潮池（可以走）、礁岩、漂流木（擋路）
for (x, y) in ((8, 8), (19, 9), (36, 8), (44, 9)):
    ground[y][x] = POOL
for (x, y) in ((6, 5), (15, 6), (24, 5), (33, 6), (39, 4), (27, 9)):
    deco[y][x] = ROCK; solid[y][x] = 1
for (x, y) in ((11, 7), (29, 7), (41, 8)):
    deco[y][x] = DRIFT; solid[y][x] = 1

# 東：漁村小屋（Tiny Town 紅屋頂，門在 47, 6）
for i in range(4):
    k = 0 if i == 0 else (2 if i == 3 else 1)
    deco[4][46 + i] = (53, 54, 55)[k]; deco[5][46 + i] = (65, 66, 67)[k]
    deco[6][46 + i] = 85 if i == 1 else 74
    for yy in (4, 5, 6): solid[yy][46 + i] = 1
# 東：木筏（海上；回港灣鎮）
ground[10][56] = RAFT

# 中：鐵輪公司的運輸船（海上）
for x in range(26, 34):
    ground[11][x] = CAGE if 27 <= x <= 32 else PLANK_H
    ground[12][x] = PLANK_H
for x in range(25, 35):
    if ground[13][x] < HB(16): pass
ground[12][25] = HB(30); ground[12][34] = HB(31)

# 西：火山洞口（崖上的洞；W70 起走進去就到火山洞）
for x in (1, 2):
    ground[3][x] = D(10); solid[3][x] = 0

objects = [
    {"type": "fire", "x": 51, "y": 7},
    {"type": "raft", "x": 56, "y": 10, "to": "harbor", "tx": 9, "ty": 19},
    {"type": "npc", "x": 48, "y": 7, "name": "granny", "tile": D(100), "talk": "coast_granny"},
    {"type": "sign", "x": 45, "y": 7, "text": "海岸漁村\n（只剩阿婆一個人住）"},
    {"type": "event", "x": 31, "y": 4, "scene": "c3_ship"}, {"type": "event", "x": 31, "y": 5, "scene": "c3_ship"},
    {"type": "event", "x": 31, "y": 6, "scene": "c3_ship"}, {"type": "event", "x": 31, "y": 7, "scene": "c3_ship"},
    {"type": "event", "x": 31, "y": 8, "scene": "c3_ship"}, {"type": "event", "x": 31, "y": 9, "scene": "c3_ship"},
    {"type": "npc", "x": 42, "y": 4, "name": "angler", "tile": D(86), "talk": "trainer", "trainer": "coast1", "look": "down"},
    {"type": "npc", "x": 22, "y": 9, "name": "surfer", "tile": D(88), "talk": "trainer", "trainer": "coast2", "look": "up"},
    {"type": "npc", "x": 12, "y": 4, "name": "shell", "tile": D(99), "talk": "trainer", "trainer": "coast3", "look": "down"},
    {"type": "sign", "x": 4, "y": 4, "text": "火山洞\n（洞口吹出來的風，熱得像三溫暖）"},
    {"type": "door", "x": 1, "y": 3, "to": "volcano", "tx": 36, "ty": 27},
    {"type": "door", "x": 2, "y": 3, "to": "volcano", "tx": 37, "ty": 27},
    {"type": "gather", "x": 18, "y": 4, "item": "fiber", "amount": 2, "tile": SAND2},
    {"type": "gather", "x": 35, "y": 9, "item": "stone", "amount": 2, "tile": SAND2},
    {"type": "gather", "x": 9, "y": 6, "item": "ore", "amount": 2, "tile": SAND2},
    {"type": "gather", "x": 53, "y": 5, "item": "berry", "amount": 2, "tile": 6},
]
for o in objects:
    if o["type"] == "sign":
        deco[o["y"]][o["x"]] = 84; solid[o["y"]][o["x"]] = 1

def rows(a):
    return ",\n".join("      " + json.dumps(r, separators=(",", ":")) for r in a)
out = ["{", f'  "width": {W},', f'  "height": {H},', '  "tilesets": ["town", "dungeon", "harbor"],', '  "objects": [']
out.append(",\n".join("    " + json.dumps(o, ensure_ascii=False, separators=(",", ":")) for o in objects))
out.append("  ],")
out.append('  "layers": {')
layers = [("ground", ground), ("deco", deco), ("plants", plants), ("solid", solid), ("shore", shore)]
for i, (name, a) in enumerate(layers):
    out.append(f'    "{name}": [')
    out.append(rows(a))
    out.append("    ]" + ("," if i < len(layers) - 1 else ""))
out.append("  }")
out.append("}")
target = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../maps/coast.json")
open(target, "w").write("\n".join(out) + "\n")
print("ok", target)
