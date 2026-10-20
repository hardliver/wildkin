# pals2.py：第二批 5 種野伴（W37）。畫法和 pals.py 一樣，設計說明見 DESIGN.md
import numpy as np
from r3d import *
from paint import *
from pals import Pal, V, fib

# ============================================================
# 02 林角羊：芽角羊長大。四腳站穩、低頭；角長成分岔的樹枝；背上長苔
# ============================================================
class ForestRam(Pal):
    FUR = Mat([(120, 92, 66), (162, 128, 94), (196, 162, 122), (220, 192, 152)], line=(126, 96, 70))
    MOSS = Mat([(48, 92, 52), (72, 128, 62), (104, 160, 78), (146, 192, 102)], line=(52, 96, 54))
    WOOD = Mat([(70, 48, 36), (104, 72, 50), (140, 102, 70), (170, 132, 92)], line=(74, 52, 40))
    LEAF = Mat([(40, 112, 58), (70, 156, 66), (118, 198, 84), (178, 230, 120)], line=(46, 110, 56))
    MUZZLE = Mat([(176, 140, 108), (212, 180, 146), (236, 210, 178)])
    HOOF = Mat([(44, 34, 36), (76, 58, 56), (108, 86, 78)])
    NOSE = Mat([(60, 40, 44), (100, 70, 72)], gloss=0.05)
    HEAD = V(-17, -6, 0)

    def model(self):
        m = Model(); H = self.HEAD
        m.ell((3, 0, 0), (15, 9.5, 9), self.FUR, tag="body")
        m.ell((-8, -1, 0), (8, 8.5, 8), self.FUR, tag="chest")
        # 背上的苔：一團一團的
        for i, d in enumerate(fib(26)):
            if d[1] > -0.25: continue
            m.sph(V(3, 0, 0) + d * V(14, 9, 8.5), 4.0, self.MOSS, tag=f"moss{i}")
        for i, (x, y, z) in enumerate(((-11, -4, 5), (-11, -4, -5), (-13, 0, 0), (-9, -8, 3), (-9, -8, -3))):
            m.sph((x, y, z), 4.0, self.MOSS, tag=f"collar{i}")              # 脖子一圈苔（芽角羊的羊毛變的）
        m.tuft((17, -3, 0), (4, -3, 0), 2.8, self.MOSS, tag="tail")
        # 腳：粗壯
        for (x, z) in ((-8, 5), (-8, -5), (12, 5), (12, -5)):
            m.tube([(x, 6, z), (x - 0.5, 14, z), (x, 20, z)], [3.6, 3.0, 2.8], self.FUR, tag=f"leg{x}{z}")
            m.ell((x, 21.3, z), (3.0, 1.8, 2.8), self.HOOF, tag=f"leg{x}{z}")
        # 頭：低下來
        m.tube([(-10, -3, 0), (-14, -5, 0)], [5.5, 5], self.FUR, tag="neck")
        m.ell(H, (7.5, 6.5, 6.5), self.FUR, rot_z(deg(-15)), tag="head")
        m.ell(H + (-6, 3, 0), (4.6, 3.8, 4.4), self.MUZZLE, tag="head")
        m.ell(H + (-10, 2.6, 0), (1.3, 1.3, 2.2), self.NOSE, tag="nose")
        for s in (1, -1):
            m.ell(H + (2, 0, 6.5 * s), (4.4, 1.5, 2.4), self.FUR, rot_x(deg(20 * s)) @ rot_z(deg(-15)), tag=f"ear{s}")
            # 角：往上、往後長的樹枝，分兩叉，每叉頂端一叢葉子
            b = H + (1, -5, 3 * s)
            mid = b + V(3, -7, 2 * s)
            m.tube([b, mid], [2.2, 1.7], self.WOOD, tag=f"horn{s}")
            for j, d in enumerate((V(5, -5, 1.5 * s), V(-2, -6, 2 * s), V(6, -1, 3 * s))):
                tip = mid + d
                m.tube([mid, tip], [1.5, 0.9], self.WOOD, tag=f"horn{s}{j}")
                for kk in range(3):
                    a = deg(kk * 120 + j * 40)
                    m.ell(tip + V(np.cos(a) * 2, -1 + np.sin(a) * 1.5, 0), (2.6, 1.3, 1.0), self.LEAF,
                          rot_z(a), tag=f"lf{s}{j}{kk}")
        return m

    def paint_front(self, im, info):
        H = self.HEAD
        x, y = project(info, H + (-3, -1.5, 5))
        eye_round(im, x, y, 1, 2, (196, 140, 60), big_hi=1)
        if visible(info, H + (-3, -1.5, -5), 2.5):
            x2, y2 = project(info, H + (-3, -1.5, -5))
            eye_round(im, x2, y2, 1, 2, (196, 140, 60), big_hi=1)

# ============================================================
# 04 爐火狸：炭毛狸長大。四腳著地，身體變成鑄鐵火爐（爐門透火光），背上長出煙囪冒火冒煙
# ============================================================
class StoveTanuki(Pal):
    FUR = Mat([(96, 54, 36), (140, 82, 50), (186, 118, 68), (220, 156, 94)], line=(104, 60, 40))
    CREAM = Mat([(172, 142, 110), (214, 188, 150), (240, 222, 188), (252, 244, 222)], line=(178, 150, 118))
    DARK = Mat([(30, 24, 28), (52, 42, 44), (78, 64, 62), (104, 88, 82)])
    IRON = Mat([(34, 34, 42), (54, 54, 64), (80, 80, 92), (116, 116, 128)], gloss=0.03, spec=(170, 170, 184),
               line=(30, 30, 38))
    RIVET = Mat([(100, 92, 84), (150, 140, 126), (196, 186, 170)])
    EMBER = Mat([(190, 50, 30), (236, 104, 40), (255, 170, 58), (255, 228, 120)])
    SMOKE = Mat([(120, 116, 120), (160, 156, 160), (196, 192, 196), (224, 222, 226)])
    NOSE = Mat([(24, 20, 24), (62, 52, 56)], gloss=0.06)
    HEAD = V(-16, -3, 0)
    BODY = V(3, 1, 0)

    def model(self):
        m = Model(); H, C = self.HEAD, self.BODY
        # 爐身：一個圓滾滾的鑄鐵爐，兩圈鉚釘
        m.ell(C, (13, 10, 10.5), self.IRON, tag="stove")
        for ring_x in (-5, 9):
            rr = 10 * (1 - (ring_x - C[0]) ** 2 / 13 ** 2) ** 0.5
            for i in range(14):
                a = deg(i * 360 / 14)
                m.sph(C + V(ring_x - C[0], np.cos(a) * rr, np.sin(a) * rr * 1.05), 1.0, self.RIVET, tag=f"rv{ring_x}{i}")
        # 煙囪：從背上往上長，頂端冒火、再上面是煙
        m.tube([C + V(6, -8, 0), C + V(7, -16, 0), C + V(8, -21, 0)], [3.0, 2.6, 2.6], self.IRON, tag="chimney")
        m.ell(C + V(8, -22, 0), (3.8, 1.4, 3.8), self.IRON, tag="cap")
        for i, (d, r) in enumerate(((V(-1, -7, 0), 2.8), (V(-3, -5, 1), 2.0), (V(2, -6, -1), 2.0))):
            m.tuft(C + V(8, -23, 0), d, r, self.EMBER, tag=f"flame{i}")
        for i, (p, r) in enumerate(((V(6, -33, 0), 3.0), (V(3, -37, 1), 3.6), (V(-1, -40, 0), 2.8))):
            m.sph(C + p, r, self.SMOKE, tag=f"smoke{i}")
        # 脖子一圈毛（頭和爐身的接縫）
        for i in range(9):
            a = deg(-90 + i * 22.5)
            m.tuft(V(-9, -1, 0) + V(0, np.sin(a) * 7, np.cos(a) * 7), V(2, np.sin(a) * 3, np.cos(a) * 3), 2.8, self.FUR,
                   tag=f"collar{i}")
        # 腳：四隻短短的黑腳（像火爐的爐腳）
        for (x, z) in ((-6, 6.5), (-6, -6.5), (11, 6.5), (11, -6.5)):
            m.tube([(x, 7, z), (x, 13, z)], [3.4, 3.0], self.DARK, tag=f"leg{x}{z}")
            m.ell((x - 1, 14, z), (3.4, 1.6, 3.0), self.DARK, tag=f"leg{x}{z}")
        # 尾巴：毛茸茸往上捲，尾尖燒紅
        pts = [V(15, 2, 0), V(20, -2, 0), V(22, -8, 0), V(19, -12, 0)]
        radii = [3.5, 4.8, 4.6, 3.4]
        k = 0
        for i in range(len(pts) - 1):
            for t in np.linspace(0, 1, 5, endpoint=False):
                p = pts[i] + (pts[i + 1] - pts[i]) * t
                r = radii[i] + (radii[i + 1] - radii[i]) * t
                m.sph(p, r, self.EMBER if k >= 11 else (self.DARK if (k // 3) % 2 else self.FUR), tag=f"tail{k // 3}")
                k += 1
        # 頭：往前伸、低低的
        m.ell(H, (8.5, 7.5, 8), self.FUR, tag="head")
        for s in (1, -1):
            m.ell(H + (1, 3.5, 6 * s), (4.2, 3.6, 3.2), self.CREAM, tag=f"cheek{s}")
            m.tuft(H + (2, 4.5, 7 * s), (2, 4, 3 * s), 2.2, self.CREAM, tag=f"ct{s}")
            m.ell(H + (3, -7, 4.5 * s), (3.0, 3.2, 1.8), self.DARK, rot_x(deg(-20 * s)), tag=f"ear{s}")
            m.ell(H + (2.6, -6.6, 5.1 * s), (1.8, 2.0, 1.2), self.EMBER, rot_x(deg(-20 * s)), tag=f"eari{s}")
        m.ell(H + (-7, 2, 0), (4.4, 3.2, 3.8), self.CREAM, tag="snout")
        m.ell(H + (-11, 1, 0), (1.6, 1.4, 2.2), self.NOSE, tag="nose")
        return m

    def paint_front(self, im, info):
        H, C = self.HEAD, self.BODY
        # 爐門：爐身側面一個小門，門縫透出火光
        cx, cy = project(info, C + V(1, 2, 10.6))
        for y in range(cy - 4, cy + 5):
            for x in range(cx - 4, cx + 5):
                put(im, x, y, (26, 24, 30))
        for x in range(cx - 5, cx + 6):
            put(im, x, cy - 5, (130, 130, 142)); put(im, x, cy + 5, (54, 54, 64))
        for y in range(cy - 5, cy + 6):
            put(im, cx - 5, y, (116, 116, 128)); put(im, cx + 5, y, (54, 54, 64))
        for y in (cy - 2, cy, cy + 2):
            for x in range(cx - 3, cx + 4): put(im, x, y, (255, 170, 58) if (x + y) % 3 else (255, 228, 120))
        put(im, cx + 3, cy - 3, (210, 210, 220))     # 門把
        # 面罩、眼睛、嘴（炭毛狸的特徵留著）
        x, y = project(info, H + (-5.5, -2, 5.6))
        for (px, py) in ell_pts(x, y + 1, 4, 3) + ell_pts(x + 2, y + 2, 3, 3):
            if 0 <= px < 64 and 0 <= py < 64 and im.getpixel((px, py))[3]:
                c = im.getpixel((px, py))[:3]
                if c in self.FUR.ramp or c == self.FUR.line:
                    put(im, px, py, self.DARK.ramp[1] if py > y else self.DARK.ramp[2])
        eye_round(im, x, y, 1, 2, (250, 186, 64), big_hi=1)
        if visible(info, H + (-5.5, -2, -5.6), 3):
            x2, y2 = project(info, H + (-5.5, -2, -5.6))
            eye_round(im, x2, y2, 1, 2, (250, 186, 64), big_hi=1)
        mx, my = project(info, H + (-7.5, 5, 3.4))
        line(im, [(mx - 2, my - 1), (mx, my), (mx + 2, my - 1)], (70, 40, 34))

# ============================================================
# 06 河伯鯰：鬚鬚鯰長大。直立坐著、雙手抱胸；長鬍鬚垂到肩後像披風
# ============================================================
class RiverLord(Pal):
    SKIN = Mat([(26, 56, 86), (42, 86, 120), (64, 120, 156), (100, 160, 190)], line=(32, 66, 98))
    BELLY = Mat([(150, 150, 120), (196, 190, 150), (226, 220, 178), (244, 240, 208)])
    FIN = Mat([(36, 78, 112), (62, 116, 152), (104, 160, 192)], line=(32, 70, 104))
    GOLD = Mat([(150, 110, 30), (204, 160, 52), (238, 204, 92), (255, 236, 160)], gloss=0.05)
    SPOT = Mat([(20, 40, 64), (32, 60, 90)])
    WHISK = Mat([(24, 36, 52), (48, 66, 86), (76, 98, 120)])
    MOUTH = Mat([(80, 36, 50), (120, 60, 72)])
    HEAD = V(-4, -12, 0)

    def model(self):
        m = Model(); H = self.HEAD
        # 身體：直立的大鯰魚，屁股坐在地上，尾巴繞到前面
        m.ell((1, 4, 0), (11, 13, 10.5), self.SKIN, tag="body")
        m.ell((-4.5, 6, 0), (7, 10.5, 8.5), self.BELLY, tag="belly")
        m.tube([(8, 14, -2), (14, 17, -6), (16, 18, -12), (12, 19, -17)], [6, 4.5, 3.4, 2.2], self.SKIN, tag="tail")
        m.ell((9, 18, -20), (4.5, 1.2, 5), self.FIN, rot_y(deg(40)), tag="tailfin")
        m.ell((6, -6, 0), (7, 3.5, 1.2), self.FIN, rot_z(deg(70)), tag="dorsal")
        for i, (x, y, z) in enumerate(((3, -4, 7), (6, 2, -8), (5, 9, 9), (8, 6, -6), (2, 0, -10), (7, -1, 6))):
            m.ell((x, y, z), (1.6, 1.3, 1.6), self.SPOT, tag=f"spot{i}")
        # 腳：短短的，坐著往前伸
        for s in (1, -1):
            m.tube([(0, 13, 6 * s), (-5, 17, 7 * s)], [4, 3.4], self.SKIN, tag=f"leg{s}")
            m.ell((-8, 18.5, 7 * s), (4, 1.4, 3.4), self.FIN, tag=f"leg{s}")
        # 手：抱在胸前
        for s in (1, -1):
            m.tube([(-1, -2, 9.5 * s), (-7, 2, 8 * s), (-9, 3, -2 * s)], [3.2, 2.8, 2.6], self.SKIN, tag=f"arm{s}")
        # 頭：又寬又扁，嘴角兩條很長的鬍鬚往後垂到肩膀，像披風
        m.ell(H, (10, 6, 11), self.SKIN, tag="head")
        m.ell(H + (-1, 3.5, 0), (7.5, 2.6, 8.5), self.BELLY, tag="chin")
        m.ell(H + (-9.4, 2.2, 0), (1.3, 1.2, 7.5), self.MOUTH, tag="mouth")
        for s in (1, -1):
            pts = [H + (-8, 2.5, 6.5 * s), H + (-11, 7, 9 * s), H + (-9, 13, 11.5 * s), H + (-3, 16, 13 * s),
                   H + (5, 18, 13 * s), H + (12, 24, 11 * s), H + (15, 30, 8 * s)]
            m.tube(pts, [2.4, 2.8, 3.0, 3.0, 2.6, 2.0, 1.2], self.WHISK, tag=f"wh{s}")
            m.tube([H + (-8, -1, 3.5 * s), H + (-11, -4, 5 * s), H + (-12, -7, 5 * s)], [0.9, 0.7, 0.4], self.WHISK, tag=f"wh2{s}")
        # 頭頂一片金色的鰭冠（河的主人）
        for i, (x, y) in enumerate(((-2, -7), (2, -8), (6, -6))):
            m.tuft(H + (x, y + 2, 0), (1, -5, 0), 2.0, self.GOLD, tag=f"crown{i}")
        return m

    def paint_front(self, im, info):
        H = self.HEAD
        for s in (1, -1):
            p = H + (-5, -3.5, 6.5 * s)
            if s == 1 or visible(info, p, 3):
                x, y = project(info, p)
                eye_round(im, x, y, 1, 2 if s == 1 else 1, (238, 204, 92), big_hi=1)

# ============================================================
# 09 菇菇蟹：寄居蟹，背著一朵香菇當殼；眼睛長在眼柄上
# ============================================================
class MushroomCrab(Pal):
    SHELL = Mat([(110, 70, 46), (150, 98, 62), (186, 130, 84), (212, 162, 112)], line=(116, 74, 50))
    CRACK = Mat([(214, 196, 164), (238, 226, 200)])
    GILL = Mat([(170, 150, 120), (210, 192, 160)])
    STALK = Mat([(196, 184, 160), (226, 216, 196), (244, 238, 224)])
    CRAB = Mat([(176, 86, 54), (214, 120, 72), (238, 158, 100), (250, 196, 140)], line=(180, 90, 58))
    CLAW = Mat([(160, 70, 46), (204, 106, 64), (234, 146, 92)], line=(164, 74, 50))
    EYE = Mat([(20, 16, 22), (50, 42, 50)], gloss=0.12)

    def model(self):
        m = Model()
        # 香菇殼：一朵大香菇蓋在背上（菇柄當殼的主體），旁邊再長兩朵小的
        m.ell((5, 0, 0), (10, 9, 9), self.STALK, tag="stalk")
        m.ell((6, -9, 0), (15, 6, 14), self.SHELL, rot_z(deg(-12)), tag="cap")
        m.ell((5, -5.5, 0), (13.5, 2, 12.5), self.GILL, rot_z(deg(-12)), tag="gill")
        # 菇傘上的白色裂紋（香菇的龜裂花紋）
        for i, d in enumerate(fib(16)):
            if d[1] > -0.35: continue
            m.ell(V(6, -9, 0) + d * V(14.5, 5.7, 13.5), (1.8, 0.8, 1.0), self.CRACK, tag=f"crack{i}")
        for i, (p, r) in enumerate((((16, -1, 6), 4.5), ((15, 2, -7), 3.6))):
            m.tube([V(*p) + (0, 5, 0), V(*p)], [1.4, 1.2], self.STALK, tag=f"small{i}")
            m.ell(V(*p) + (0, -1, 0), (r, r * 0.45, r), self.SHELL, tag=f"smallcap{i}")
        # 蟹的身體（從殼裡探出來）
        m.ell((-7, 5, 0), (7, 5, 7.5), self.CRAB, tag="crab")
        # 眼柄＋眼睛
        for s in (1, -1):
            m.tube([(-10, 2, 3 * s), (-12, -4, 4 * s)], [1.2, 1.0], self.CRAB, tag=f"stalk{s}")
            m.sph((-12.2, -5.5, 4 * s), 1.9, self.EYE, tag=f"eye{s}")
            # 大螯：前面那隻比較大（寄居蟹的特徵）
            big = 1.0 if s == 1 else 0.7
            m.tube([(-9, 7, 6 * s), (-14, 8, 9 * s)], [2.2, 2.0], self.CRAB, tag=f"arm{s}")
            m.ell((-18, 7, 10 * s), (5 * big, 3.6 * big, 3 * big), self.CLAW, rot_z(deg(-10)), tag=f"claw{s}")
            m.ell((-21 * big, 9.5, 10 * s), (3.4 * big, 1.4 * big, 2.4 * big), self.CLAW, rot_z(deg(20)), tag=f"pinch{s}")
            # 腳：每邊三隻
            for j in range(3):
                x = -6 + j * 4
                m.tube([(x, 8, 5 * s), (x - 2, 12, 9 * s), (x - 3, 16, 10 * s)], [1.4, 1.2, 0.9], self.CRAB, tag=f"leg{s}{j}")
        return m

# ============================================================
# 10 燈蛾：翅膀張開懸停；羽毛狀觸角、毛茸茸的領子；翅膀上的斑點像亮著的燈泡
# ============================================================
class LampMoth(Pal):
    WING = Mat([(64, 54, 86), (92, 80, 120), (124, 110, 150), (160, 146, 180)], line=(70, 58, 92))
    WING2 = Mat([(50, 42, 70), (76, 64, 100), (104, 92, 130)], line=(56, 46, 78))
    FLUFF = Mat([(196, 182, 150), (228, 216, 186), (246, 238, 214), (255, 252, 236)], line=(200, 186, 156))
    BODY = Mat([(70, 60, 74), (100, 88, 102), (130, 116, 130)])
    GLOW = Mat([(250, 200, 60), (255, 230, 110), (255, 248, 190), (255, 255, 240)])
    ANT = Mat([(150, 120, 60), (196, 164, 90), (226, 198, 120)])

    def model(self):
        m = Model()
        # 翅膀：上翅大、下翅小，往兩邊張開
        for s in (1, -1):
            for (c, r, rz, mat, tag) in (((6, -10, 10 * s), (13, 9, 1.0), -35, self.WING, "up"),
                                         ((9, 4, 9 * s), (9, 6.5, 1.0), 30, self.WING2, "low")):
                R = rot_x(deg(-55 * s)) @ rot_z(deg(rz))
                m.ell(c, r, mat, R, tag=f"wing{tag}{s}")
                # 燈泡斑：在翅膀上，稍微凸出來（亮的）
                if tag == "up":
                    for j, (u, v, rr) in enumerate(((5, -2, 3.2), (-2, 3, 2.2))):
                        p = V(*c) + R @ V(u, v, 0.9 * (1 if s == 1 else -1))
                        m.ell(p, (rr, rr, 0.8), self.GLOW, R, tag=f"glow{s}{j}")
                else:
                    p = V(*c) + R @ V(2, 1, 0.9 * (1 if s == 1 else -1))
                    m.ell(p, (2, 2, 0.8), self.GLOW, R, tag=f"glowl{s}")
        # 身體：毛茸茸的胸、細長的腹部
        m.tube([(2, 0, 0), (9, 8, 0), (13, 15, 0)], [4.5, 3.6, 2.2], self.BODY, tag="abdomen")
        for i, d in enumerate(fib(18)):
            m.sph(V(-2, -2, 0) + d * V(5, 5, 5), 3.0, self.FLUFF, tag=f"fl{i}")
        # 頭
        m.ell((-7, -5, 0), (4.6, 4.4, 5), self.BODY, tag="head")
        for s in (1, -1):
            m.sph((-10, -6, 3 * s), 2.4, self.GLOW, tag=f"eye{s}")     # 大大的複眼，微微發光
            # 羽毛狀觸角：一根往上往後彎，兩邊長出細毛
            pts = [V(-8, -9, 2 * s), V(-9, -15, 4 * s), V(-6, -21, 6 * s)]
            m.tube(pts, [0.8, 0.7, 0.5], self.ANT, tag=f"ant{s}")
            for j in range(5):
                t = 0.2 + j * 0.15
                p = pts[0] + (pts[2] - pts[0]) * t + V(-1 * (1 - t), 0, 0)
                m.tuft(p, V(-2.5, -0.5, 1.2 * s), 0.6, self.ANT, tag=f"antf{s}{j}")
                m.tuft(p, V(2.0, -1.0, 0.6 * s), 0.6, self.ANT, tag=f"antg{s}{j}")
        # 細細的腳（懸停時垂著）
        for s in (1, -1):
            for j in range(2):
                m.tube([(-3 + j * 4, 3, 2 * s), (-4 + j * 4, 9, 3 * s)], [0.7, 0.5], self.BODY, tag=f"leg{s}{j}")
        return m

ALL2 = [ForestRam(), StoveTanuki(), RiverLord(), MushroomCrab(), LampMoth()]
NAMES2 = ["02 林角羊", "04 爐火狸", "06 河伯鯰", "09 菇菇蟹", "10 燈蛾"]

if __name__ == "__main__":
    fs = [p.front() for p in ALL2]; bs = [p.back() for p in ALL2]
    for f, b in zip(fs, bs): print(f.getbbox(), b.getbbox())
    a = sheet(fs, 4); b = sheet([x.resize((64, 64), Image.NEAREST) for x in bs], 4)
    W = Image.new("RGBA", (a.width, a.height + b.height)); W.paste(a, (0, 0)); W.paste(b, (0, a.height))
    W.save("/home/claude/art2/v5.png")
