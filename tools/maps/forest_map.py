# 霧林的地圖草稿（W57）：python3 tools/maps/forest_map.py → maps/forest.json
# 產生一次之後就在 Studio 的地圖編輯器裡改；這支程式只是第一版的草稿（重跑會蓋掉 Studio 的修改）。
# 60 × 30 格（3 × 2 個畫面）。一條彎曲的泥土路從西邊（苔石村）通到東邊的森之祠，
# 路旁留一格草地，其他都是樹；兩個被小樹擋住的角落（要伐木）放礦石、菇。
import json, os, sys

W, H = 60, 30

def h(x, y, s=0):
    v = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
    v ^= v >> 13
    return (v * 1274126177 >> 16) & 0xffff

path = set()
def hseg(x0, x1, y):   # 橫的路，兩格寬：y、y+1
    for x in range(min(x0, x1), max(x0, x1) + 1):
        path.add((x, y)); path.add((x, y + 1))
def vseg(x, y0, y1):   # 直的路，兩格寬：x、x+1
    for y in range(min(y0, y1), max(y0, y1) + 1):
        path.add((x, y)); path.add((x + 1, y))

hseg(0, 9, 14)      # 西邊入口（苔石村）
vseg(8, 6, 15)
hseg(8, 27, 6)
vseg(26, 6, 22)
hseg(26, 43, 21)
vseg(42, 14, 22)
hseg(42, 50, 14)

open_cells = set(path)
for (x, y) in list(path):   # 路旁留一格草地
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            open_cells.add((x + dx, y + dy))
def rect(x0, y0, x1, y1, s):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            s.add((x, y))
rect(48, 8, 57, 21, open_cells)      # 森之祠的空地
rect(14, 2, 18, 4, open_cells)       # 角落 A（上面）：伐木進去
rect(33, 25, 38, 27, open_cells)     # 角落 B（下面）
open_cells.add((15, 5)); open_cells.add((35, 24))   # 角落的入口（擋路的小樹在這裡）
rect(11, 8, 20, 11, open_cells)      # 遇敵草叢的空地
rect(28, 9, 31, 18, open_cells)
rect(30, 17, 40, 20, open_cells)
rect(44, 16, 47, 20, open_cells)

grass = set()                        # 遇敵草叢（grass 圖層）
rect(12, 9, 19, 11, grass)
rect(29, 10, 31, 17, grass)
rect(31, 18, 39, 20, grass)
rect(45, 17, 47, 20, grass)
grass -= path

rect(51, 11, 55, 17, path)           # 森之祠前面的泥土空地（和路接在一起）
stone = set()

ground = [[0] * W for _ in range(H)]
deco = [[0] * W for _ in range(H)]
plants = [[0] * W for _ in range(H)]
solid = [[0] * W for _ in range(H)]
glayer = [[0] * W for _ in range(H)]

# 泥土路的邊：上下左右哪邊不是路，就用那一邊的邊框格子（Tiny Town 的 3×3 泥土）
DIRT = {(1, 1): 13, (1, 0): 14, (1, 2): 15, (0, 1): 25, (0, 0): 26, (0, 2): 27, (2, 1): 37, (2, 0): 38, (2, 2): 39}
for y in range(H):
    for x in range(W):
        c = (x, y)
        if c in path:
            top = (x, y - 1) not in path and y > 0
            bot = (x, y + 1) not in path and y < H - 1
            left = (x - 1, y) not in path and x > 0
            right = (x + 1, y) not in path and x < W - 1
            r = 1 if top else (2 if bot else 0)
            k = 1 if left else (2 if right else 0)
            ground[y][x] = DIRT[(r, k)]
        elif c in stone:
            ground[y][x] = 44
        else:
            v = h(x, y) % 10
            ground[y][x] = 1 if v < 6 else (2 if v < 9 else 3)
        if c in grass:
            glayer[y][x] = 1
        inside = 0 < x < W - 1 and 0 < y < H - 1
        if (c not in open_cells or not inside) and not (x == 0 and c in path):
            v = h(x, y, 1) % 12
            plants[y][x] = 28 if v == 0 else (6 if v == 1 else 29)
            solid[y][x] = 1

# 森之祠：大樹（兩格高，橘色）、兩邊各一棵綠的
for (x, top, bottom) in ((53, 4, 16), (50, 5, 17), (56, 5, 17)):
    plants[9][x], plants[10][x] = top, bottom
    solid[9][x] = solid[10][x] = 1

objects = [
    {"type": "fire", "x": 49, "y": 15},   # 營火（W71）
    {"type": "sign", "x": 5, "y": 13, "text": "鐵輪公司　土地測量中\n閒人勿近"},
    {"type": "event", "x": 3, "y": 14, "scene": "c1_ironwheel"},
    {"type": "event", "x": 3, "y": 15, "scene": "c1_ironwheel"},
    {"type": "event", "x": 18, "y": 6, "scene": "c1_moth"},
    {"type": "event", "x": 18, "y": 7, "scene": "c1_moth"},
    {"type": "sign", "x": 49, "y": 13, "text": "森之祠"},
    {"type": "npc", "x": 47, "y": 14, "name": "asui", "tile": 221, "talk": "rival", "trainer": "rival2", "look": "left"},
    {"type": "npc", "x": 53, "y": 12, "name": "keeper", "tile": 219, "talk": "forest_keeper"},
    {"type": "block", "x": 15, "y": 5, "tile": 29, "need": "lumber"},
    {"type": "block", "x": 35, "y": 24, "tile": 29, "need": "lumber"},
    {"type": "gather", "x": 14, "y": 2, "item": "ore", "amount": 2, "tile": 44},
    {"type": "gather", "x": 18, "y": 3, "item": "ore", "amount": 1, "tile": 44},
    {"type": "gather", "x": 16, "y": 2, "item": "mushroom", "amount": 2, "tile": 30},
    {"type": "gather", "x": 33, "y": 27, "item": "ore", "amount": 2, "tile": 44},
    {"type": "gather", "x": 38, "y": 26, "item": "fiber", "amount": 2, "tile": 18},
    {"type": "gather", "x": 36, "y": 27, "item": "berry", "amount": 2, "tile": 6},
    {"type": "gather", "x": 10, "y": 10, "item": "mushroom", "amount": 1, "tile": 30},
    {"type": "gather", "x": 24, "y": 5, "item": "wood", "amount": 2, "tile": 107},
    {"type": "gather", "x": 28, "y": 8, "item": "mushroom", "amount": 1, "tile": 30},
    {"type": "gather", "x": 41, "y": 17, "item": "fiber", "amount": 1, "tile": 18},
    {"type": "gather", "x": 47, "y": 13, "item": "ore", "amount": 1, "tile": 44},
    {"type": "door", "x": 0, "y": 14, "to": "village", "tx": 38, "ty": 14},
    {"type": "door", "x": 0, "y": 15, "to": "village", "tx": 38, "ty": 15},
]
for o in objects:   # 採集點、擋路物站的格子不能是樹
    plants[o["y"]][o["x"]] = 0
    if o["type"] != "block": solid[o["y"]][o["x"]] = 0

def rows(a):
    return ",\n".join("      " + json.dumps(r, separators=(",", ":")) for r in a)

out = ["{", f'  "width": {W},', f'  "height": {H},', '  "tilesets": ["town", "dungeon"],', '  "objects": [']
out.append(",\n".join("    " + json.dumps(o, ensure_ascii=False, separators=(",", ":")) for o in objects))
out.append("  ],")
out.append('  "layers": {')
layers = [("ground", ground), ("deco", deco), ("plants", plants), ("solid", solid), ("grass", glayer)]
for i, (name, a) in enumerate(layers):
    out.append(f'    "{name}": [')
    out.append(rows(a))
    out.append("    ]" + ("," if i < len(layers) - 1 else ""))
out.append("  }")
out.append("}")
target = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../maps/forest.json")
open(target, "w").write("\n".join(out) + "\n")
