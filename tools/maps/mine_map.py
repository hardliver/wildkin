# 舊礦坑的地圖草稿（W67）：python3 tools/maps/mine_map.py → maps/mine.json
# 產生一次之後就在 Studio 的地圖編輯器裡改；這支程式只是第一版的草稿（重跑會蓋掉 Studio 的修改）。
# 44 × 30 格。東邊（苔石村西口）進來是「礦坑口」，有光、沙地；往西走就是暗的（dark 圖層）。
#   東：礦坑口、工頭（C2-2 之前）、右下的碎石洞（礫殼犰狳住這裡）
#   中：暗的通道，北邊一個碎石房間；通道盡頭兩顆落石（要採礦）
#   西：鐵輪公司的工作區（有燈）：礦車和被使喚的野伴（C2-4）、高處長（C2-5）、往港灣鎮的鐵門（W68 才開）
# 格子編號：Tiny Dungeon 的第 n 格 = n + 133（Tiny Town 有 132 格，從 1 開始）
import json, os, sys

W, H = 44, 30
D = lambda n: n + 133         # Tiny Dungeon 的格子
FLOOR, RUBBLE1, RUBBLE2 = D(0), D(12), D(24)
SAND = [D(48), D(49), D(50), D(51)]
WALL = D(40)
TORCH = D(29)
RAIL_H = [D(79), D(80)]
BARREL, CRATE, CRATE2 = D(82), D(63), D(75)
BOULDER = D(66)
IRON_DOOR = D(46)
CART = 58                     # Tiny Town 的礦車

def h(x, y, s=0):
    v = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
    v ^= v >> 13
    return (v * 1274126177 >> 16) & 0xffff

open_cells, rubble = set(), set()
def rect(x0, y0, x1, y1, s):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            s.add((x, y))

rect(30, 14, 43, 15, open_cells)     # 從苔石村進來的路
rect(30, 9, 41, 19, open_cells)      # 礦坑口（有光）
rect(31, 20, 37, 24, open_cells)     # 右下的碎石洞
rect(31, 20, 37, 24, rubble)
rect(17, 14, 29, 15, open_cells)     # 暗的通道
rect(23, 11, 24, 13, open_cells)     # 往北的岔路
rect(18, 5, 28, 10, open_cells)      # 北邊的碎石房間
rect(19, 6, 27, 9, rubble)
rect(16, 14, 16, 15, open_cells)     # 落石的位置（擋路物）
rect(3, 8, 15, 20, open_cells)       # 西邊的大廳
rect(0, 14, 2, 15, open_cells)       # 往港灣鎮的鐵門

ground = [[WALL] * W for _ in range(H)]
deco = [[0] * W for _ in range(H)]
solid = [[1] * W for _ in range(H)]
glayer = [[0] * W for _ in range(H)]
dark = [[0] * W for _ in range(H)]
for (x, y) in open_cells:
    solid[y][x] = 0
    if x >= 30:
        ground[y][x] = SAND[h(x, y) % 4]
    else:
        v = h(x, y, 2) % 10
        ground[y][x] = FLOOR if v < 7 else (RUBBLE1 if v < 9 else RUBBLE2)
for (x, y) in rubble:
    ground[y][x] = RUBBLE1 if h(x, y, 3) % 2 else RUBBLE2
    glayer[y][x] = 1
for y in range(H):
    for x in range(W):
        # 暗的：中間的通道和北邊的碎石房間（x 16～29）。礦坑口（x 30 以後）有天光；
        # 西邊大廳（x 15 以前）是鐵輪公司的工作區，裝了工作燈（劇情在這裡，要看得到人）
        if 16 <= x <= 29: dark[y][x] = 1

# 礦坑口的火把（牆上）、木箱木桶
for (x, y) in ((32, 8), (38, 8), (35, 8)):
    ground[y][x] = TORCH
for (x, y, t) in ((40, 10, BARREL), (41, 10, CRATE), (41, 11, BARREL), (31, 18, CRATE2), (30, 10, BARREL)):
    deco[y][x] = t; solid[y][x] = 1
# 西邊大廳：牆上的工作燈、鐵軌、礦車
for (x, y) in ((5, 7), (9, 7), (13, 7)):
    ground[y][x] = TORCH
for x in range(4, 15):
    deco[11][x] = RAIL_H[x % 2]
for x in (8, 11, 14):
    deco[11][x] = CART; solid[11][x] = 1
for (x, y, t) in ((4, 18, BARREL), (5, 18, CRATE), (14, 19, CRATE2), (3, 9, BARREL)):
    deco[y][x] = t; solid[y][x] = 1
# 往港灣鎮的鐵門（W68 才開）
for y in (14, 15):
    deco[y][0] = IRON_DOOR; solid[y][0] = 1

objects = [
    {"type": "fire", "x": 36, "y": 11},   # 營火（W71）
    {"type": "door", "x": 43, "y": 14, "to": "village", "tx": 1, "ty": 14},
    {"type": "door", "x": 43, "y": 15, "to": "village", "tx": 1, "ty": 15},
    {"type": "door", "x": 0, "y": 14, "to": "harbor", "tx": 38, "ty": 14},
    {"type": "door", "x": 0, "y": 15, "to": "harbor", "tx": 38, "ty": 15},
    {"type": "event", "x": 39, "y": 14, "scene": "c2_foreman"},
    {"type": "event", "x": 39, "y": 15, "scene": "c2_foreman"},
    {"type": "npc", "x": 35, "y": 14, "name": "foreman", "tile": D(87), "talk": "mine_foreman", "look": "right"},
    {"type": "sign", "x": 33, "y": 13, "text": "舊礦坑\n鐵輪公司　施工中"},
    {"type": "event", "x": 29, "y": 14, "scene": "c2_dark"},
    {"type": "event", "x": 29, "y": 15, "scene": "c2_dark"},
    {"type": "block", "x": 16, "y": 14, "tile": BOULDER, "need": "mine"},
    {"type": "block", "x": 16, "y": 15, "tile": BOULDER, "need": "mine"},
    {"type": "event", "x": 15, "y": 14, "scene": "c2_carts"},
    {"type": "event", "x": 15, "y": 15, "scene": "c2_carts"},
    {"type": "npc", "x": 6, "y": 14, "name": "exec", "tile": D(97), "talk": "exec1", "look": "right"},   # 不用 trainer 欄位：對戰在劇情 c2_exec 裡
    {"type": "event", "x": 10, "y": 14, "scene": "c2_exec"},
    {"type": "event", "x": 10, "y": 15, "scene": "c2_exec"},
    {"type": "sign", "x": 2, "y": 13, "text": "往港灣鎮\n鐵輪公司　員工專用"},
    {"type": "gather", "x": 36, "y": 23, "item": "ore", "amount": 2, "tile": D(24)},
    {"type": "gather", "x": 32, "y": 21, "item": "stone", "amount": 2, "tile": D(12)},
    {"type": "gather", "x": 27, "y": 6, "item": "ore", "amount": 2, "tile": D(24)},
    {"type": "gather", "x": 19, "y": 9, "item": "stone", "amount": 2, "tile": D(12)},
    {"type": "gather", "x": 4, "y": 20, "item": "ore", "amount": 3, "tile": D(24)},
]
for o in objects:
    if o["type"] in ("gather",):
        glayer[o["y"]][o["x"]] = 0

for o in objects:          # 告示牌：地圖上也要放告示牌的圖（Tiny Town 第 84 格），會擋路
    if o["type"] == "sign":
        deco[o["y"]][o["x"]] = 84; solid[o["y"]][o["x"]] = 1

def rows(a):
    return ",\n".join("      " + json.dumps(r, separators=(",", ":")) for r in a)

out = ["{", f'  "width": {W},', f'  "height": {H},', '  "tilesets": ["town", "dungeon"],', '  "objects": [']
out.append(",\n".join("    " + json.dumps(o, ensure_ascii=False, separators=(",", ":")) for o in objects))
out.append("  ],")
out.append('  "layers": {')
layers = [("ground", ground), ("deco", deco), ("plants", [[0] * W for _ in range(H)]), ("solid", solid), ("grass", glayer), ("dark", dark)]
for i, (name, a) in enumerate(layers):
    out.append(f'    "{name}": [')
    out.append(rows(a))
    out.append("    ]" + ("," if i < len(layers) - 1 else ""))
out.append("  }")
out.append("}")
target = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../maps/mine.json")
open(target, "w").write("\n".join(out) + "\n")
print("ok", target)
