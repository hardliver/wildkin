# 火山洞的地圖草稿（W70）：python3 tools/maps/volcano_map.py → maps/volcano.json
# 產生一次之後就在 Studio 的地圖編輯器裡改；這支程式只是第一版的草稿（重跑會蓋掉 Studio 的修改）。
# 40 × 30 格。用 Tiny Dungeon 的圖塊，畫的時候整張換色成火山的紅黑（season.lua 的 RECOLOR）；
# 岩漿、裂縫、溫泉、蒸氣孔是港灣圖塊第 5 列（48～51）。
#   南：入口（海岸的洞口）→ 主洞（岩漿池、碎石區）
#   東北：大碎石洞（爐背牛）
#   中：鐵輪公司的施工區（范經理，C3-5）
#   北：溫泉（炭爺，C3-6）、營火
import json, os, sys

W, H = 40, 30
HB = lambda n: 265 + n
D = lambda n: n + 133
FLOOR, RUBBLE1, RUBBLE2, WALL = D(0), D(12), D(24), D(40)
LAVA, CRACK, SPRING, VENT = HB(48), HB(49), HB(50), HB(51)
BARREL, CRATE, CRATE2 = D(82), D(63), D(75)
FENCE = [D(76), D(77), D(78)]

def h(x, y, s=0):
    v = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
    v ^= v >> 13
    return (v * 1274126177 >> 16) & 0xffff

open_cells, rubble, lava, spring = set(), set(), set(), set()
def rect(x0, y0, x1, y1, s):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            s.add((x, y))

rect(34, 22, 38, 29, open_cells)     # 入口（南）
rect(20, 17, 37, 23, open_cells)     # 主洞
rect(26, 19, 28, 21, lava)           # 主洞中間的岩漿池
rect(31, 18, 36, 20, rubble)         # 主洞的碎石區
rect(30, 11, 32, 16, open_cells)     # 往東北
rect(25, 3, 37, 10, open_cells)      # 東北的大碎石洞（爐背牛）
rect(26, 4, 36, 9, rubble)
rect(29, 6, 30, 7, lava)
rect(20, 13, 24, 16, open_cells)     # 往施工區
rect(6, 11, 24, 18, open_cells)      # 鐵輪的施工區
rect(8, 4, 10, 10, open_cells)       # 往北（溫泉）
rect(2, 1, 16, 7, open_cells)        # 溫泉
rect(4, 2, 8, 4, spring)

ground = [[WALL] * W for _ in range(H)]
deco = [[0] * W for _ in range(H)]
solid = [[1] * W for _ in range(H)]
glayer = [[0] * W for _ in range(H)]
for (x, y) in open_cells:
    solid[y][x] = 0
    v = h(x, y, 2) % 12
    ground[y][x] = FLOOR if v < 7 else (CRACK if v < 9 else (RUBBLE1 if v < 11 else RUBBLE2))
for (x, y) in rubble:
    ground[y][x] = RUBBLE1 if h(x, y, 3) % 2 else RUBBLE2
    glayer[y][x] = 1
for (x, y) in lava:
    ground[y][x] = LAVA; solid[y][x] = 1; glayer[y][x] = 0
for (x, y) in spring:
    ground[y][x] = SPRING; solid[y][x] = 1
for (x, y) in ((22, 22), (35, 25), (14, 3), (3, 6), (12, 12), (33, 4)):
    ground[y][x] = VENT
# 施工區：柵欄、木箱、木桶
for x in range(13, 21):
    deco[11][x] = FENCE[1]; solid[11][x] = 1
deco[11][13] = FENCE[0]; deco[11][20] = FENCE[2]
for (x, y, t) in ((7, 12, CRATE), (8, 12, BARREL), (7, 17, CRATE2), (23, 12, BARREL), (22, 18, CRATE), (19, 17, CRATE2)):
    deco[y][x] = t; solid[y][x] = 1

objects = [
    {"type": "door", "x": 36, "y": 29, "to": "coast", "tx": 1, "ty": 4},
    {"type": "door", "x": 37, "y": 29, "to": "coast", "tx": 2, "ty": 4},
    {"type": "fire", "x": 13, "y": 3},
    {"type": "event", "x": 18, "y": 12, "scene": "c3_exec"}, {"type": "event", "x": 18, "y": 13, "scene": "c3_exec"},
    {"type": "event", "x": 18, "y": 14, "scene": "c3_exec"}, {"type": "event", "x": 18, "y": 15, "scene": "c3_exec"},
    {"type": "event", "x": 18, "y": 16, "scene": "c3_exec"}, {"type": "event", "x": 18, "y": 17, "scene": "c3_exec"},
    {"type": "npc", "x": 13, "y": 14, "name": "exec2", "tile": D(98), "talk": "exec2", "look": "right"},
    {"type": "npc", "x": 9, "y": 3, "name": "charcoal", "tile": D(111), "talk": "fire_keeper"},
    {"type": "sign", "x": 21, "y": 12, "text": "鐵輪公司　施工中\\n危險！高溫！（勿近岩漿）"},
    {"type": "gather", "x": 36, "y": 9, "item": "ore", "amount": 3, "tile": D(24)},
    {"type": "gather", "x": 25, "y": 3, "item": "ore", "amount": 2, "tile": D(24)},
    {"type": "gather", "x": 20, "y": 22, "item": "stone", "amount": 3, "tile": D(12)},
    {"type": "gather", "x": 15, "y": 7, "item": "ore", "amount": 2, "tile": D(24)},
]
for o in objects:
    if o["type"] == "sign":
        deco[o["y"]][o["x"]] = 84; solid[o["y"]][o["x"]] = 1
    if o["type"] == "door":
        solid[o["y"]][o["x"]] = 0

def rows(a):
    return ",\n".join("      " + json.dumps(r, separators=(",", ":")) for r in a)
out = ["{", f'  "width": {W},', f'  "height": {H},', '  "tilesets": ["town", "dungeon", "harbor"],', '  "objects": [']
out.append(",\n".join("    " + json.dumps(o, ensure_ascii=False, separators=(",", ":")) for o in objects))
out.append("  ],")
out.append('  "layers": {')
layers = [("ground", ground), ("deco", deco), ("plants", [[0] * W for _ in range(H)]), ("solid", solid), ("grass", glayer)]
for i, (name, a) in enumerate(layers):
    out.append(f'    "{name}": [')
    out.append(rows(a))
    out.append("    ]" + ("," if i < len(layers) - 1 else ""))
out.append("  }")
out.append("}")
target = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../maps/volcano.json")
open(target, "w").write("\n".join(out) + "\n")
print("ok", target)
