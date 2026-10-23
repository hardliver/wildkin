# 山脊、山頂聖所的地圖草稿（W74）：python3 tools/maps/ridge_map.py → maps/ridge.json、maps/summit.json
# 產生一次之後就在 Studio 的地圖編輯器裡改；這支程式只是第一版的草稿（重跑會蓋掉 Studio 的修改）。
# 劇本：docs/story.md「終章（下）　山脊與山頂聖所」
#
# ridge（20 × 45，1 × 3 個畫面）：南端接社長室的後門，一條彎彎曲曲的山路往北爬，兩旁是岩壁（港灣圖塊 72、73）。
#   下段：雷角羚的影子（E-9）　中段：觀景台（阿穗一家，E-10；營火）　北端：往聖所
#   遇敵草叢四塊（哨哨雀、礫殼犰狳、搧火蝠、稀有的雷角羚）
# summit（20 × 15）：雲海上的一塊草地，中間一圈立石，北邊一棵老榕樹（3 × 3），雲根和老雷角羚在這裡（E-11～E-13）
import json, os, sys

HB = lambda n: 265 + n
ROCK, CLIFF, BOULDER, CLOUD_EDGE, STONE, CLOUDS = HB(72), HB(73), HB(74), HB(75), HB(76), HB(77)
BANYAN = [[HB(84), HB(85), HB(86)], [HB(96), HB(97), HB(98)], [HB(108), HB(109), HB(110)]]
DIRT = {(1, 1): 13, (1, 0): 14, (1, 2): 15, (0, 1): 25, (0, 0): 26, (0, 2): 27, (2, 1): 37, (2, 0): 38, (2, 2): 39}


def h(x, y, s=0):
    v = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
    v ^= v >> 13
    return (v * 1274126177 >> 16) & 0xffff


def rect(x0, y0, x1, y1, s):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            s.add((x, y))


def paint_path(ground, path, W, H):
    """泥土路的邊：上下左右哪邊不是路，就用那一邊的邊框格子（Tiny Town 的 3×3 泥土）"""
    for (x, y) in path:
        if not (0 <= x < W and 0 <= y < H): continue
        top = (x, y - 1) not in path and y > 0
        bot = (x, y + 1) not in path and y < H - 1
        left = (x - 1, y) not in path and x > 0
        right = (x + 1, y) not in path and x < W - 1
        r = 1 if top else (2 if bot else 0)
        k = 1 if left else (2 if right else 0)
        ground[y][x] = DIRT[(r, k)]


def write(name, W, H, ground, deco, solid, glayer, objects):
    for o in objects:
        if o["type"] == "sign" and not o.pop("keep", False):   # keep 只在這裡用，不寫進地圖檔
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
    for i, (lname, a) in enumerate(layers):
        out.append(f'    "{lname}": [')
        out.append(rows(a))
        out.append("    ]" + ("," if i < len(layers) - 1 else ""))
    out.append("  }")
    out.append("}")
    folder = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../maps")
    target = os.path.join(folder, name + ".json")
    open(target, "w").write("\n".join(out) + "\n")
    print("ok", target)


# ============================================================
# 山脊
# ============================================================
W, H = 20, 45
path = set()
def vseg(x, y0, y1):   # 直的路，兩格寬
    rect(x, min(y0, y1), x + 1, max(y0, y1), path)
def hseg(x0, x1, y):   # 橫的路，兩格寬
    rect(min(x0, x1), y, max(x0, x1), y + 1, path)
vseg(9, 37, 44)       # 南端：社長室的後門上來
hseg(4, 10, 37)
vseg(4, 26, 38)
hseg(4, 11, 26)
vseg(10, 14, 27)
hseg(10, 15, 14)
vseg(14, 0, 15)       # 北端：往聖所

open_cells = set(path)
for (x, y) in list(path):              # 路旁留一格
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            open_cells.add((x + dx, y + dy))
rect(13, 17, 18, 22, open_cells)       # 觀景台（阿穗一家）
grass = set()
for r in ((1, 29, 3, 35), (12, 31, 17, 36), (5, 5, 12, 11), (16, 5, 18, 11)):
    rect(*r, grass)
    rect(*r, open_cells)
grass -= path

ground = [[ROCK] * W for _ in range(H)]
deco = [[0] * W for _ in range(H)]
solid = [[1] * W for _ in range(H)]
glayer = [[0] * W for _ in range(H)]
for y in range(H):
    for x in range(W):
        if (x, y) in open_cells and 0 < x < W - 1:
            solid[y][x] = 0
            v = h(x, y) % 10
            ground[y][x] = 1 if v < 6 else (2 if v < 9 else 3)
            if (x, y) in grass: glayer[y][x] = 1
        elif y > 0 and (x, y - 1) in open_cells and 0 < x < W - 1:
            ground[y][x] = CLIFF          # 岩壁的上緣：上面是草地
paint_path(ground, path, W, H)
# 草地上零星的大石頭（不擋路、不在草叢裡）
for y in range(1, H - 1):
    for x in range(1, W - 1):
        c = (x, y)
        near_path = any((x + dx, y + dy) in path for dx in (-1, 0, 1) for dy in (-1, 0, 1))
        if not solid[y][x] and c not in grass and not near_path and h(x, y, 4) % 19 == 0:
            deco[y][x] = BOULDER; solid[y][x] = 1

ridge_objects = [
    {"type": "door", "x": 9, "y": 44, "to": "office", "tx": 16, "ty": 2},
    {"type": "door", "x": 10, "y": 44, "to": "office", "tx": 16, "ty": 2},
    {"type": "door", "x": 14, "y": 0, "to": "summit", "tx": 9, "ty": 12},
    {"type": "door", "x": 15, "y": 0, "to": "summit", "tx": 10, "ty": 12},
    {"type": "event", "x": 3, "y": 33, "scene": "e9_antelope"}, {"type": "event", "x": 4, "y": 33, "scene": "e9_antelope"},
    {"type": "event", "x": 5, "y": 33, "scene": "e9_antelope"}, {"type": "event", "x": 6, "y": 33, "scene": "e9_antelope"},
    # 觀景台：阿穗一家（E-10）。走過觀景台下面那一段路就開始
    {"type": "npc", "x": 14, "y": 19, "name": "asui", "tile": 221, "talk": "rival4_after", "look": "left"},
    {"type": "npc", "x": 16, "y": 18, "name": "kid1", "tile": 218, "talk": "asui_kid1", "look": "left"},
    {"type": "npc", "x": 17, "y": 20, "name": "kid2", "tile": 245, "talk": "asui_kid2", "look": "left"},
    {"type": "event", "x": 9, "y": 23, "scene": "e10_rival"}, {"type": "event", "x": 10, "y": 23, "scene": "e10_rival"},
    {"type": "event", "x": 11, "y": 23, "scene": "e10_rival"}, {"type": "event", "x": 12, "y": 23, "scene": "e10_rival"},
    {"type": "fire", "x": 18, "y": 21},
    {"type": "sign", "x": 13, "y": 23, "text": "觀景台\\n天氣好的時候，看得到整座雲根島。"},
]
write("ridge", W, H, ground, deco, solid, glayer, ridge_objects)

# ============================================================
# 山頂聖所
# ============================================================
W, H = 20, 15
inside = set()
for y in range(H):
    for x in range(W):
        if ((x - 9.5) / 8.5) ** 2 + ((y - 7.5) / 6.8) ** 2 <= 1:
            inside.add((x, y))
rect(9, 12, 10, 14, inside)                 # 南邊：往山脊的路
ground = [[CLOUDS] * W for _ in range(H)]
deco = [[0] * W for _ in range(H)]
solid = [[1] * W for _ in range(H)]
glayer = [[0] * W for _ in range(H)]
for y in range(H):
    for x in range(W):
        if (x, y) in inside:
            solid[y][x] = 0
            v = h(x, y, 8) % 10
            ground[y][x] = 1 if v < 7 else 2
        elif y > 0 and (x, y - 1) in inside:
            ground[y][x] = CLOUD_EDGE                # 草地的邊緣，下面是雲
spath = set()
rect(9, 8, 10, 14, spath)
paint_path(ground, spath, W, H)
for j in range(3):                                  # 老榕樹：北邊正中間
    for i in range(3):
        deco[1 + j][8 + i] = BANYAN[j][i]
        solid[1 + j][8 + i] = 1
for (x, y) in ((4, 4), (15, 4), (3, 8), (16, 8), (5, 11), (14, 11)):   # 一圈立石
    deco[y][x] = STONE; solid[y][x] = 1
summit_objects = [
    {"type": "door", "x": 9, "y": 14, "to": "ridge", "tx": 14, "ty": 2},
    {"type": "door", "x": 10, "y": 14, "to": "ridge", "tx": 15, "ty": 2},
    {"type": "npc", "x": 9, "y": 5, "name": "president", "tile": 233, "talk": "president_summit", "look": "up"},
    {"type": "event", "x": 7, "y": 9, "scene": "e11_summit"}, {"type": "event", "x": 8, "y": 9, "scene": "e11_summit"},
    {"type": "event", "x": 9, "y": 9, "scene": "e11_summit"}, {"type": "event", "x": 10, "y": 9, "scene": "e11_summit"},
    {"type": "event", "x": 11, "y": 9, "scene": "e11_summit"}, {"type": "event", "x": 12, "y": 9, "scene": "e11_summit"},
]
write("summit", W, H, ground, deco, solid, glayer, summit_objects)
