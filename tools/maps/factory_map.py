# 鐵輪工廠的地圖草稿（W73）：python3 tools/maps/factory_map.py → maps/factory.json、maps/office.json
# 產生一次之後就在 Studio 的地圖編輯器裡改；這支程式只是第一版的草稿（重跑會蓋掉 Studio 的修改）。
# 用 Tiny Dungeon 的圖塊，畫的時候整張換色成工廠的冷灰（season.lua 的 RECOLOR）；
# 輸送帶、控制台、打卡機、玻璃罩、電梯門是港灣圖塊第 6 列（60～66）。劇本：docs/story.md「終章（上）　鐵輪工廠」
#
# factory（40 × 30）
#   南：貨梯上來的地方（營火、回火山洞的貨梯）→ 打卡機（E-1）
#   中：大廳（社長的海報）；北邊牆上一個缺口是往二樓的樓梯，高處長坐在缺口前面（E-3）
#   東：伐木線（輸送帶＋囤囤鼠，阿德）　西：礦石線（礦車＋礫殼犰狳，品管小姐）　北：照明線（玻璃罩裡的燈蛾，保全大哥）
#   東北：二樓辦公室（范經理睡著了，E-4）、往社長室的電梯（E-5）
# office（20 × 15）：社長室（E-6）
import json, os, sys

HB = lambda n: 265 + n
D = lambda n: n + 133
FLOOR, FLOOR2, WALL = D(0), D(42), D(40)
BELT, CONSOLE, CLOCK, GLASS, ELEVATOR, LIFT = HB(60), HB(62), HB(64), HB(65), HB(66), HB(67)
RAIL_H = [D(79), D(80)]
CART, BARREL, CRATE, CRATE2 = D(54), D(82), D(63), D(75)
DESK, STOOL, PILLAR, IRON_DOOR = D(72), D(73), D(6), D(46)
SIGN = 84


def h(x, y, s=0):
    v = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
    v ^= v >> 13
    return (v * 1274126177 >> 16) & 0xffff


def new_map(W, H):
    return {
        "W": W, "H": H,
        "ground": [[WALL] * W for _ in range(H)],
        "deco": [[0] * W for _ in range(H)],
        "solid": [[1] * W for _ in range(H)],
    }


def open_rect(m, x0, y0, x1, y1):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            m["solid"][y][x] = 0
            m["ground"][y][x] = FLOOR2 if h(x, y, 5) % 31 == 0 else FLOOR   # 偶爾一塊比較亮的地磚


def thing(m, x, y, tile, layer="deco", solid=1):
    m[layer][y][x] = tile
    m["solid"][y][x] = solid


def write(m, objects, name):
    W, H = m["W"], m["H"]
    for o in objects:
        if o["type"] == "sign" and not o.pop("keep", False):   # keep：放在桌子之類的東西上，不畫告示牌（只在這裡用，不寫進地圖檔：地圖物件不能有 true/false）
            thing(m, o["x"], o["y"], SIGN)
        if o["type"] == "door":
            m["solid"][o["y"]][o["x"]] = 0

    def rows(a):
        return ",\n".join("      " + json.dumps(r, separators=(",", ":")) for r in a)
    out = ["{", f'  "width": {W},', f'  "height": {H},', '  "tilesets": ["town", "dungeon", "harbor"],', '  "objects": [']
    out.append(",\n".join("    " + json.dumps(o, ensure_ascii=False, separators=(",", ":")) for o in objects))
    out.append("  ],")
    out.append('  "layers": {')
    layers = [("ground", m["ground"]), ("deco", m["deco"]), ("plants", [[0] * W for _ in range(H)]),
              ("solid", m["solid"]), ("grass", [[0] * W for _ in range(H)])]
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
# 工廠
# ============================================================
f = new_map(40, 30)
open_rect(f, 16, 23, 23, 28)     # 南：貨梯上來的地方
open_rect(f, 18, 22, 21, 22)     # 往大廳
open_rect(f, 12, 12, 27, 21)     # 大廳
open_rect(f, 26, 11, 26, 11)     # 往二樓的缺口（樓梯）
open_rect(f, 28, 16, 28, 17)     # 往東
open_rect(f, 29, 13, 37, 21)     # 東：伐木線
open_rect(f, 11, 16, 11, 17)     # 往西
open_rect(f, 2, 13, 10, 21)      # 西：礦石線
open_rect(f, 19, 10, 20, 11)     # 往北
open_rect(f, 13, 4, 26, 9)       # 北：照明線
open_rect(f, 29, 2, 38, 9)       # 東北：二樓辦公室

# 打卡機（E-1）：大廳入口旁的牆上
thing(f, 17, 22, CLOCK)
# 大廳：柱子、木箱
for (x, y) in ((14, 14), (25, 14), (14, 19), (25, 19)):
    thing(f, x, y, PILLAR)
for (x, y, t) in ((12, 21, CRATE), (13, 21, CRATE2), (27, 20, BARREL)):
    thing(f, x, y, t)
# 東：伐木線的輸送帶（地面層，factory.lua 畫動畫）、控制台
for x in range(30, 37):
    thing(f, x, 17, BELT, "ground")
for (x, y, t) in ((30, 20, CRATE), (31, 20, CRATE), (36, 20, CRATE2), (37, 13, BARREL)):
    thing(f, x, y, t)
thing(f, 36, 14, CONSOLE)
# 西：礦石線的軌道和礦車
for x in range(3, 10):
    thing(f, x, 18, RAIL_H[x % 2], "deco", 1)
for x in (4, 7):
    thing(f, x, 18, CART)
thing(f, 3, 14, CONSOLE)
for (x, y, t) in ((9, 21, BARREL), (10, 21, BARREL), (2, 21, CRATE)):
    thing(f, x, y, t)
# 北：照明線的玻璃罩（裡面關著燈蛾）、控制台
for x in (14, 16, 18, 21, 23, 25):
    thing(f, x, 5, GLASS)
thing(f, 13, 8, CONSOLE)
# 東北：二樓辦公室（桌子、椅子）、往社長室的電梯
for x in (31, 32):
    thing(f, x, 4, DESK)
thing(f, 33, 4, STOOL, "deco", 0)
for (x, y, t) in ((35, 4, DESK), (36, 6, CRATE), (29, 2, BARREL)):
    thing(f, x, y, t)
thing(f, 37, 2, ELEVATOR)
# 貨梯（回火山洞）
thing(f, 19, 28, LIFT)
thing(f, 20, 28, LIFT)

factory_objects = [
    {"type": "lift", "x": 19, "y": 28, "to": "volcano", "tx": 16, "ty": 13},
    {"type": "lift", "x": 20, "y": 28, "to": "volcano", "tx": 16, "ty": 13},
    {"type": "fire", "x": 22, "y": 26},
    {"type": "event", "x": 18, "y": 23, "scene": "e1_clock"}, {"type": "event", "x": 19, "y": 23, "scene": "e1_clock"},
    {"type": "event", "x": 20, "y": 23, "scene": "e1_clock"}, {"type": "event", "x": 21, "y": 23, "scene": "e1_clock"},
    {"type": "sign", "x": 20, "y": 12, "text": "社長的大海報：\\n「野伴就是生產力」"},
    {"type": "sign", "x": 22, "y": 22, "text": "鐵輪公司　雲根工廠\\n「野伴打卡上工　全年無休」"},
    # 高處長：坐在往二樓的缺口前面（E-3）
    {"type": "npc", "x": 26, "y": 12, "name": "exec1", "tile": D(97), "talk": "exec1_factory", "look": "down"},
    # 三條生產線的工人（訓練家）、控制台
    {"type": "npc", "x": 34, "y": 15, "name": "ade", "tile": D(85), "talk": "trainer", "trainer": "factory_wood", "look": "left"},
    {"type": "console", "x": 36, "y": 14, "line": "wood"},
    {"type": "npc", "x": 5, "y": 15, "name": "qc", "tile": D(99), "talk": "trainer", "trainer": "factory_ore", "look": "right"},
    {"type": "console", "x": 3, "y": 14, "line": "ore"},
    {"type": "npc", "x": 19, "y": 7, "name": "security", "tile": D(96), "talk": "trainer", "trainer": "factory_light", "look": "down"},
    {"type": "console", "x": 13, "y": 8, "line": "light"},
    # 二樓：范經理睡在桌上（E-4）、電梯（E-5）
    {"type": "door", "x": 26, "y": 11, "to": "factory", "tx": 30, "ty": 8},
    {"type": "door", "x": 29, "y": 9, "to": "factory", "tx": 26, "ty": 13},
    {"type": "npc", "x": 32, "y": 5, "name": "exec2", "tile": D(98), "talk": "exec2_sleep", "look": "up"},
    {"type": "event", "x": 30, "y": 6, "scene": "e4_sleep"}, {"type": "event", "x": 31, "y": 6, "scene": "e4_sleep"},
    {"type": "event", "x": 30, "y": 7, "scene": "e4_sleep"}, {"type": "event", "x": 31, "y": 7, "scene": "e4_sleep"},
    {"type": "lift", "x": 37, "y": 2, "to": "office", "tx": 10, "ty": 12, "face": "up", "need": "power"},
]
# 往二樓的「門」其實是樓梯：缺口畫成往上的台階（同一張地圖裡傳送）；二樓那頭的樓梯在 (29, 9)
f["ground"][11][26] = D(18)
f["ground"][9][29] = D(18)
f["solid"][9][29] = 0
write(f, factory_objects, "factory")

# ============================================================
# 社長室
# ============================================================
o = new_map(20, 15)
open_rect(o, 2, 2, 17, 13)
for x in range(3, 17, 2):                 # 北邊整面落地窗（看得到山頂）：玻璃罩的圖當窗戶
    thing(o, x, 1, GLASS, "ground", 1)
for x in (8, 9, 11, 12):
    thing(o, x, 4, DESK)
for (x, y, t) in ((3, 3, PILLAR), (16, 3, PILLAR), (3, 12, BARREL), (16, 12, CRATE2), (5, 7, STOOL), (14, 7, STOOL)):
    thing(o, x, y, t)
thing(o, 10, 14, ELEVATOR, "ground", 1)
thing(o, 17, 2, IRON_DOOR, "deco", 1)     # 後門（社長往山頂走的樓梯）
office_objects = [
    {"type": "lift", "x": 10, "y": 14, "to": "factory", "tx": 37, "ty": 3},
    {"type": "door", "x": 17, "y": 2, "to": "ridge", "tx": 9, "ty": 42},     # 後門（W74）：打贏社長才打開（factory.lua）
    # 桌上的舊相框（W74：阿電的伏筆）
    {"type": "sign", "x": 12, "y": 4, "keep": True, "text": "舊相框：一個穿制服的少年，和一隻雷角羚。\f雷角羚的兩根角，都還好好的。\n照片的角落寫著：「第 28 屆大賽　第一輪」"},
    {"type": "npc", "x": 10, "y": 3, "name": "president", "tile": D(100), "talk": "president", "look": "up"},
    {"type": "event", "x": 8, "y": 8, "scene": "e6_boss"}, {"type": "event", "x": 9, "y": 8, "scene": "e6_boss"},
    {"type": "event", "x": 10, "y": 8, "scene": "e6_boss"}, {"type": "event", "x": 11, "y": 8, "scene": "e6_boss"},
    {"type": "event", "x": 12, "y": 8, "scene": "e6_boss"},
]
write(o, office_objects, "office")
