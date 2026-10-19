# pals.py：5 種野伴（第四版）。設計說明見 DESIGN.md
# 每一隻：model() 組 3D 形狀、front() 正面 64×64、back() 背面 32×32
# 座標：x 往右、y 往下、z 朝向鏡頭；野伴的臉朝 -x，轉 34° 之後變成面向左前方（看著玩家的野伴）
import numpy as np
from r3d import *
from paint import *

FRONT_VIEW = rot_x(deg(-12)) @ rot_y(deg(34))
BACK_VIEW = rot_x(deg(-14)) @ rot_y(deg(180 + 30))
OPT = dict(ambient=0.3, outline="sel", depth_dark=0.15)

def fib(n):
    i = np.arange(n) + 0.5
    phi = np.arccos(1 - 2 * i / n); th = np.pi * (1 + 5 ** 0.5) * i
    return np.stack([np.cos(th) * np.sin(phi), np.cos(phi), np.sin(th) * np.sin(phi)], -1)

def V(*a): return np.array(a, float)

class Pal:
    scale_f, off_f = 1.0, (32, 34)
    scale_b, off_b = 0.5, (16, 18)
    def fit(self, size, view, scale, off, max_w, max_h, bottom):
        """先算一次看圖有多大，再調整縮放和位置：剛好放進 max_w × max_h，水平置中、腳貼在 bottom"""
        m = self.model()
        im, _ = render(m, size, view, scale, off, **OPT)
        x0, y0, x1, y1 = im.getbbox()
        k = min(max_w / (x1 - x0), max_h / (y1 - y0))
        cx, by = (x0 + x1) / 2, y1
        # 畫面座標 = 模型 × scale + off；放大 k 倍時，讓 (cx, by) 移到 (size/2, bottom)
        scale2 = scale * k
        off2 = (size / 2 - (cx - off[0]) * k, bottom - (by - off[1]) * k)
        return render(m, size, view, scale2, off2, **OPT)
    def front(self):
        im, info = self.fit(64, FRONT_VIEW, self.scale_f, self.off_f, 58, 58, 62)
        self.paint_front(im, info)
        return im
    def back(self):
        im, info = self.fit(32, BACK_VIEW, self.scale_b, self.off_b, 31, 30, 32)
        self.paint_back(im, info)
        return im
    def paint_front(self, im, info): pass
    def paint_back(self, im, info): pass

# ============================================================
# 01 芽角羊：四腳、細長腿、抬頭挺胸、一隻前腳抬起來
# ============================================================
class Sheep(Pal):
    FUR = Mat([(170, 136, 104), (210, 176, 138), (236, 208, 170), (250, 232, 202)], line=(176, 140, 108))
    WOOL = Mat([(150, 172, 140), (200, 214, 186), (236, 240, 220), (252, 252, 244)], line=(168, 186, 156))
    MUZZLE = Mat([(196, 156, 124), (232, 198, 164), (250, 228, 200)])
    HOOF = Mat([(60, 44, 46), (96, 72, 66), (130, 100, 88)])
    LEAF = Mat([(40, 112, 58), (70, 156, 66), (118, 198, 84), (178, 230, 120)], line=(46, 110, 56))
    STEM = Mat([(52, 104, 52), (86, 146, 64)])
    NOSE = Mat([(120, 70, 76), (168, 104, 106)], gloss=0.05)
    HEAD = V(-15, -13, 0)
    scale_f, off_f = 1.2, (35, 37)
    scale_b, off_b = 0.56, (15, 18)

    def model(self):
        m = Model(); H = self.HEAD
        m.ell((3, 1, 0), (12, 7.5, 7), self.FUR, tag="body")
        m.ell((-6, -1, 0), (6, 6.5, 6), self.FUR, tag="body")                    # 胸
        m.sph((15, -2, 0), 2.6, self.WOOL, tag="tail")
        m.tuft((15, -3, 0), (3, -4, 0), 2.2, self.WOOL, tag="tail")
        # 脖子一圈羊毛（每團不同 tag，團和團之間有線）
        for i, (x, y, z) in enumerate(((-9, -4, 4), (-9, -4, -4), (-11, -1, 0), (-7, -7, 5), (-7, -7, -5),
                                       (-10, 2, 3), (-10, 2, -3), (-6, -9, 0), (-5, 0, 6), (-5, 0, -6))):
            m.sph((x, y, z), 4.2, self.WOOL, tag=f"w{i}")
        m.tube([(-8, -3, 0), (-12, -9, 0)], [4.6, 4.0], self.FUR, tag="neck")
        # 頭：往上抬
        m.ell(H, (6.5, 6, 6), self.FUR, rot_z(deg(15)), tag="head")
        m.ell(H + (-5.5, 3, 0), (4.2, 3.4, 3.8), self.MUZZLE, tag="head")
        m.ell(H + (-9.2, 2.4, 0), (1.2, 1.2, 2.0), self.NOSE, tag="nose")
        for s in (1, -1):
            m.ell(H + (2, -1, 6 * s), (4, 1.4, 2.2), self.FUR, rot_x(deg(20 * s)) @ rot_z(deg(-20)), tag=f"ear{s}")
            # 角：兩片大葉子，從頭頂往後上方長
            b = H + (0.5, -5, 2.2 * s)
            m.tube([b, b + (2, -3, 0.5 * s)], [1.2, 1.0], self.STEM, tag=f"stem{s}")
            m.ell(b + (6, -6.5, 1.5 * s), (7.5, 3.2, 1.1), self.LEAF, rot_x(deg(25 * s)) @ rot_z(deg(-40)), tag=f"leaf{s}")
        for i, p in enumerate(((1, -5, 0), (-1, -5.5, 1.5))):                     # 瀏海
            m.sph(H + p, 2.6, self.WOOL, tag=f"bang{i}")
        # 腳：細長；一隻前腳抬起來彎著
        def leg(pts, tag):
            m.tube(pts, [2.6, 2.1, 1.9], self.FUR, tag=tag)
            e = np.array(pts[-1], float)
            m.ell(e + (0, 1, 0), (2.1, 1.4, 1.9), self.HOOF, tag=tag)
        leg([(-6, 5, 4), (-6.5, 13, 4), (-6, 20, 4)], "lf")
        leg([(-7, 5, -4), (-11, 10, -4), (-10, 14.5, -4)], "lf2")            # 抬起來的前腳
        leg([(11, 5, 4), (13, 13, 4), (11.5, 20, 4)], "lb")
        leg([(11, 5, -4), (13, 13, -4), (11.5, 20, -4)], "lb2")
        return m

    def paint_front(self, im, info):
        H = self.HEAD
        x, y = project(info, H + (-2.8, -1.2, 4.8))
        eye_round(im, x, y, 2, 3, (110, 70, 44), look=(-1, 0))
        if visible(info, H + (-2.8, -1.2, -4.8), 2.5):
            x2, y2 = project(info, H + (-2.8, -1.2, -4.8))
            eye_round(im, x2, y2, 1, 3, (110, 70, 44), big_hi=1)
        mx, my = project(info, H + (-7, 5.6, 2.5))
        line(im, [(mx - 1, my), (mx + 1, my + 1)], (140, 96, 84))

# ============================================================
# 03 炭毛狸：兩腳站立、大肚子、兩手捧著燒紅的炭、身後超大尾巴
# ============================================================
class Tanuki(Pal):
    FUR = Mat([(108, 62, 40), (156, 94, 56), (202, 134, 76), (234, 172, 104)], line=(118, 70, 44))
    CREAM = Mat([(172, 142, 110), (214, 188, 150), (240, 222, 188), (252, 244, 222)], line=(178, 150, 118))
    DARK = Mat([(32, 26, 30), (54, 44, 46), (80, 66, 64), (106, 90, 84)])
    EMBER = Mat([(190, 50, 30), (236, 104, 40), (255, 170, 58), (255, 228, 120)])
    NOSE = Mat([(24, 20, 24), (62, 52, 56)], gloss=0.06)
    HEAD = V(-1, -11, 0)
    scale_f, off_f = 1.2, (30, 36)
    scale_b, off_b = 0.52, (16, 18)

    def model(self):
        m = Model(); H = self.HEAD
        # 尾巴（在身後，從屁股往上翹到頭的高度）
        pts = [V(7, 12, -3), V(15, 8, -4), V(20, 0, -4), V(19, -9, -3), V(15, -15, -2)]
        radii = [4.5, 6.5, 7.0, 6.2, 4.5]
        k = 0
        for i in range(len(pts) - 1):
            for t in np.linspace(0, 1, 6, endpoint=False):
                p = pts[i] + (pts[i + 1] - pts[i]) * t
                r = radii[i] + (radii[i + 1] - radii[i]) * t
                mat = self.EMBER if k >= 20 else (self.DARK if (k // 4) % 2 else self.FUR)
                m.sph(p, r, mat, tag=f"tail{k // 4}")
                k += 1
        for i, (b, d, r) in enumerate((((14, -17, -2), (-2, -7, 0), 3.2), ((12, -15, 0), (-4, -4, 1), 2.2),
                                       ((17, -15, -3), (3, -5, 0), 2.2))):
            m.tuft(b, d, r, self.EMBER, tag=f"flame{i}")
        # 身體：圓肚子
        m.ell((0, 4, 0), (9, 10.5, 9), self.FUR, tag="body")
        m.ell((-4.5, 6, 0), (5.5, 7.5, 6.5), self.CREAM, tag="belly")
        # 腳：短短的
        for s in (1, -1):
            m.tube([(0, 12, 5 * s), (-1, 18, 5 * s)], [4, 3.4], self.DARK, tag=f"leg{s}")
            m.ell((-3, 19.5, 5 * s), (4.2, 2.0, 3.2), self.DARK, tag=f"leg{s}")
        # 手：捧著一顆燒紅的炭
        m.sph((-10.5, 4, 0), 3.6, self.EMBER, tag="coal")
        for s in (1, -1):
            m.tube([(-2, -1, 7.5 * s), (-6, 3, 7 * s), (-9.5, 5, 3.5 * s)], [3.0, 2.6, 2.4], self.DARK, tag=f"arm{s}")
        # 頭（大）
        m.ell(H, (10, 9, 9.5), self.FUR, tag="head")
        for i, (b, d) in enumerate((((5, -6, 0), (4, -4, 0)), ((6, -4, 4), (4, -2, 2)), ((6, -4, -4), (4, -2, -2)))):
            m.tuft(H + b, d, 2.6, self.FUR, tag=f"hair{i}")
        for s in (1, -1):
            m.ell(H + (0, 4, 7 * s), (4.8, 4.2, 3.8), self.CREAM, tag=f"cheek{s}")
            for j, d in enumerate(((1, 5, 2.5 * s), (3, 3, 4 * s), (-1, 5, 1.5 * s))):
                m.tuft(H + (1, 5, 7.5 * s), d, 2.3, self.CREAM, tag=f"ct{s}{j}")
            m.ell(H + (3, -8.5, 5.5 * s), (3.4, 3.6, 2.0), self.DARK, rot_x(deg(-20 * s)), tag=f"ear{s}")
            m.ell(H + (2.6, -8, 6.2 * s), (2.0, 2.2, 1.4), self.CREAM, rot_x(deg(-20 * s)), tag=f"eari{s}")
        m.ell(H + (-8, 2.5, 0), (5, 3.6, 4.4), self.CREAM, tag="snout")
        m.ell(H + (-12.6, 1.2, 0), (1.8, 1.5, 2.4), self.NOSE, tag="nose")
        return m

    def paint_front(self, im, info):
        H = self.HEAD
        x, y = project(info, H + (-6.6, -2, 6.6))
        for (px, py) in ell_pts(x, y + 1, 5, 4) + ell_pts(x + 2, y + 3, 4, 3):      # 黑色面罩
            if 0 <= px < 64 and 0 <= py < 64 and im.getpixel((px, py))[3]:
                c = im.getpixel((px, py))[:3]
                if c in self.FUR.ramp or c == self.FUR.line:
                    put(im, px, py, self.DARK.ramp[1] if py > y else self.DARK.ramp[2])
        eye_round(im, x, y, 2, 3, (250, 186, 64), look=(-1, 0))
        if visible(info, H + (-6.6, -2, -6.6), 3):
            x2, y2 = project(info, H + (-6.6, -2, -6.6))
            eye_round(im, x2, y2, 1, 3, (250, 186, 64), big_hi=1)
        mx, my = project(info, H + (-8.5, 6.2, 3.8))
        line(im, [(mx - 2, my), (mx, my + 1), (mx + 2, my)], (70, 40, 34))

# ============================================================
# 05 鬚鬚鯰：橫的魚身、短手短腳站在地上、扁平大頭、大嘴、長鬍鬚
# ============================================================
class Catfish(Pal):
    SKIN = Mat([(34, 70, 104), (54, 104, 142), (80, 140, 176), (118, 178, 206)], line=(40, 78, 112))
    BELLY = Mat([(130, 164, 170), (176, 206, 204), (214, 234, 226), (238, 248, 240)])
    FIN = Mat([(46, 96, 132), (76, 136, 172), (120, 180, 210)], line=(40, 84, 120))
    SPOT = Mat([(26, 50, 78), (38, 70, 104)])
    WHISK = Mat([(30, 44, 60), (60, 80, 100)])
    MOUTH = Mat([(90, 40, 54), (130, 64, 76)])
    HEAD = V(-8, -3, 0)
    scale_f, off_f = 1.12, (32, 33)
    scale_b, off_b = 0.58, (15, 17)

    def model(self):
        m = Model(); H = self.HEAD
        # 姿勢像彈塗魚：兩隻前手撐著，抬頭挺胸；身體和尾巴往後趴在地上
        m.ell(H, (9.5, 7.5, 10), self.SKIN, tag="head")
        m.ell(H + (0.5, 4.5, 0), (8.5, 3.6, 9), self.BELLY, tag="belly")
        m.tube([(0, 0, 0), (7, 6, 0), (14, 10, 0), (21, 10, 0)], [8, 6.5, 4.4, 2.6], self.SKIN, tag="body")
        m.ell((5, 7, 0), (6, 3, 6.5), self.BELLY, tag="belly2")
        m.ell((25, 7, 0), (4.5, 5.5, 1.1), self.FIN, rot_z(deg(-25)), tag="tailfin")
        m.ell((5, -3, 0), (5, 3, 1.0), self.FIN, rot_z(deg(30)), tag="dorsal")
        for i, (x, y, z) in enumerate(((-6, -9, 5), (-11, -8, -3), (-2, -8, -5), (2, -4, 5), (7, 1, -4), (10, 4, 3),
                                       (15, 6, -1), (-3, -5, 8.5), (-8, -9, 1), (12, 6, 4))):
            m.ell((x, y, z), (1.5, 1.1, 1.5), self.SPOT, tag=f"spot{i}")
        m.ell(H + (-9, 2.6, 0), (1.4, 1.2, 7.2), self.MOUTH, tag="mouth")
        for s in (1, -1):
            m.tube([H + (-8, 2.5, 7 * s), H + (-12, 6, 9 * s), H + (-13, 12, 10 * s), H + (-11.5, 17, 10.5 * s)],
                   [1.2, 1.0, 0.8, 0.6], self.WHISK, tag=f"wh{s}")
            m.tube([H + (-8.5, -1.5, 3.5 * s), H + (-12, -4, 5 * s)], [0.8, 0.4], self.WHISK, tag=f"wh2{s}")
            # 前手：撐在地上
            m.tube([H + (1, 4, 8 * s), H + (-1, 10, 9.5 * s), H + (-3, 15, 9.5 * s)], [3.0, 2.6, 2.4], self.SKIN, tag=f"arm{s}")
            m.ell(H + (-4, 16.3, 9.5 * s), (3.6, 1.3, 3.0), self.FIN, tag=f"arm{s}")
            # 後腳：短短的，收在身體旁邊
            m.tube([(9, 7, 5.5 * s), (8, 12, 6.5 * s)], [2.6, 2.3], self.SKIN, tag=f"leg{s}")
            m.ell((6.5, 13.2, 6.5 * s), (3.2, 1.2, 2.6), self.FIN, tag=f"leg{s}")
        return m

    def paint_front(self, im, info):
        H = self.HEAD
        for s, big in ((1, True), (-1, False)):
            p = H + (-6, -3.5, 6 * s)
            if s == 1 or visible(info, p, 3):
                x, y = project(info, p)
                eye_round(im, x, y, 1, 2 if big else 1, (232, 204, 96), big_hi=1)

# ============================================================
# 07 囤囤鼠：坐著、梨形身體、臉頰塞到鼓起來、抱著橡實
# ============================================================
class Hamster(Pal):
    FUR = Mat([(150, 92, 46), (200, 132, 66), (232, 170, 96), (248, 204, 136)], line=(160, 100, 52))
    CREAM = Mat([(188, 164, 136), (226, 206, 178), (246, 234, 214), (255, 250, 240)], line=(196, 172, 144))
    PINK = Mat([(186, 110, 116), (226, 150, 150), (246, 190, 186)])
    NUT = Mat([(92, 54, 34), (140, 86, 48), (184, 124, 70), (214, 162, 100)])
    CAP = Mat([(70, 50, 40), (110, 82, 60), (146, 114, 84)], rough=0.2)
    NOSE = Mat([(150, 70, 80), (200, 110, 120)], gloss=0.08)
    HEAD = V(-2, -8, 0)
    scale_f, off_f = 1.4, (32, 34)
    scale_b, off_b = 0.56, (16, 16)

    def model(self):
        m = Model(); H = self.HEAD
        m.ell((2, 5, 0), (10, 11, 10), self.FUR, tag="body")
        m.ell((-4, 7, 0), (6.5, 8, 7.5), self.CREAM, tag="belly")
        for s in (1, -1):
            m.ell((-3, 15, 6 * s), (4.4, 2, 3.2), self.PINK, tag=f"foot{s}")
            m.ell((4, 12, 8 * s), (5, 4, 3), self.FUR, tag=f"thigh{s}")
        m.sph((12, 12, 0), 2.2, self.FUR, tag="tail")
        # 頭 + 鼓鼓的臉頰
        m.ell(H, (8.5, 7.5, 8.5), self.FUR, tag="head")
        for s in (1, -1):
            m.sph(H + (-2, 4, 7 * s), 6.2, self.FUR, tag=f"cheek{s}")
            m.ell(H + (-4, 6, 6 * s), (4.5, 4, 4.5), self.CREAM, tag=f"cheekw{s}")
            m.ell(H + (3, -7, 5 * s), (2.6, 2.8, 1.5), self.FUR, tag=f"ear{s}")
            m.ell(H + (2.6, -6.6, 5.8 * s), (1.6, 1.8, 1.0), self.PINK, tag=f"eari{s}")
        m.ell(H + (-7.5, 1.5, 0), (3.6, 3, 3.6), self.CREAM, tag="snout")
        m.sph(H + (-10.6, 0.6, 0), 1.3, self.NOSE, tag="nose")
        # 橡實（抱在胸前）
        m.ell((-10, 1, 0), (3.4, 3.8, 3.4), self.NUT, tag="nut")
        m.ell((-10.4, -2.4, 0), (3.6, 1.8, 3.6), self.CAP, tag="cap")
        m.tube([(-10.6, -4, 0), (-11, -5.5, 0)], [0.7, 0.5], self.CAP, tag="cap")
        for s in (1, -1):
            m.tube([(-3, 1, 6.5 * s), (-7, 2, 5 * s), (-9, 2, 3 * s)], [2.2, 1.9, 1.7], self.FUR, tag=f"arm{s}")
            m.sph((-9.5, 2.2, 2.8 * s), 1.6, self.PINK, tag=f"hand{s}")
        return m

    def paint_front(self, im, info):
        H = self.HEAD
        x, y = project(info, H + (-5, -2.5, 5.2))
        eye_round(im, x, y, 2, 2, (40, 30, 34), look=(0, 0))
        if visible(info, H + (-5, -2.5, -5.2), 3):
            x2, y2 = project(info, H + (-5, -2.5, -5.2))
            eye_round(im, x2, y2, 1, 2, (40, 30, 34), big_hi=1)
        # 兩顆大門牙
        tx, ty = project(info, H + (-9, 4, 0.5))
        for dx in (0, 1, 2):
            for dy in (0, 1, 2):
                put(im, tx + dx, ty + dy, (255, 252, 240) if dx != 1 else ((200, 190, 180) if dy < 2 else (255, 252, 240)))
        for dx in (-1, 3):
            for dy in (0, 1, 2): put(im, tx + dx, ty + dy, (90, 50, 50))
        for dx in range(-1, 4): put(im, tx + dx, ty + 3, (90, 50, 50))

# ============================================================
# 08 哨哨雀：翅膀往上張開、像要起飛；頭頂羽毛捲成哨子
# ============================================================
class Bird(Pal):
    BROWN = Mat([(96, 50, 40), (140, 76, 54), (184, 106, 70), (214, 140, 96)], line=(104, 56, 44))
    CHEST = Mat([(196, 140, 96), (232, 180, 128), (248, 212, 160), (255, 236, 198)], line=(200, 146, 102))
    WING = Mat([(70, 44, 40), (112, 68, 52), (152, 96, 66), (188, 128, 86)], line=(76, 46, 40))
    TIP = Mat([(40, 34, 40), (70, 60, 66), (104, 92, 96)])
    BEAK = Mat([(186, 120, 30), (234, 172, 50), (252, 214, 100)])
    LEG = Mat([(180, 110, 40), (226, 156, 70)])
    BRASS = Mat([(150, 104, 30), (204, 156, 52), (238, 200, 90), (255, 238, 160)], gloss=0.06)
    HEAD = V(-4, -8, 0)
    scale_f, off_f = 1.25, (31, 38)
    scale_b, off_b = 0.54, (16, 18)

    def model(self):
        m = Model(); H = self.HEAD
        # 翅膀：往上張開，三層羽毛
        for s in (1, -1):
            for j, (len_, ang, mat) in enumerate(((12, 55, self.WING), (11, 70, self.WING), (9, 85, self.TIP))):
                R = rot_x(deg(-50 * s)) @ rot_z(deg(-ang - 20))
                c = V(3, -2, 6 * s) + R @ V(len_ * 0.85, 0, 0)
                m.ell(c, (len_, 3, 1.1), mat, R, tag=f"wing{s}{j}")
        m.ell((1, 3, 0), (8, 9.5, 7.5), self.BROWN, rot_z(deg(-15)), tag="body")
        m.ell((-4, 4, 0), (5, 7.5, 6.2), self.CHEST, tag="chest")
        for i, (x, y, z) in enumerate(((-7, 1, 3), (-7, 1, -3), (-7.5, 5, 0), (-6, 8, 3), (-6, 8, -3))):  # 胸口蓬起來的羽毛
            m.sph((x, y, z), 3, self.CHEST, tag=f"ch{i}")
        # 尾羽
        for j, a in enumerate((-15, 0, 15)):
            m.ell((11, 10, a * 0.15), (7, 1.6, 2.2), self.WING, rot_y(deg(a)) @ rot_z(deg(35)), tag=f"tail{j}")
        # 腳
        for s in (1, -1):
            m.tube([(0, 11, 2.5 * s), (0, 17, 2.5 * s)], [1.1, 0.9], self.LEG, tag=f"leg{s}")
            for d in ((-3, 0.5, 0), (2, 0.5, 0), (-2, 0.5, 1.5 * s)):
                m.tube([(0, 17, 2.5 * s), V(0, 17, 2.5 * s) + d], [0.8, 0.6], self.LEG, tag=f"toe{s}")
        # 頭
        m.ell(H, (6.2, 5.8, 5.8), self.BROWN, tag="head")
        m.ell(H + (-1.5, 3, 0), (4.5, 3.4, 4.6), self.CHEST, tag="throat")
        m.tuft(H + (-5.5, 0.5, 0), (-5, 1.5, 0), 1.9, self.BEAK, tag="beak")
        # 頭頂的哨子：一根往後上方彎的羽毛管，尾端是喇叭口
        m.tube([H + (1, -5, 0), H + (3, -10, 0), H + (7, -12, 0)], [1.8, 1.5, 1.3], self.BRASS, tag="whistle")
        m.ell(H + (8.5, -12.5, 0), (1.8, 3.2, 3.2), self.BRASS, rot_z(deg(-15)), tag="whistle")
        m.ell(H + (9.6, -12.7, 0), (0.6, 2.2, 2.2), self.TIP, rot_z(deg(-15)), tag="hole")
        return m

    def paint_front(self, im, info):
        H = self.HEAD
        x, y = project(info, H + (-2, -1.2, 4.6))
        eye_round(im, x, y, 1, 2, (30, 24, 28), ring=(250, 246, 236), big_hi=1)
        if visible(info, H + (-2, -1.2, -4.6), 2.5):
            x2, y2 = project(info, H + (-2, -1.2, -4.6))
            eye_round(im, x2, y2, 1, 1, (30, 24, 28), ring=(250, 246, 236), big_hi=1)

ALL = [Sheep(), Tanuki(), Catfish(), Hamster(), Bird()]
NAMES = ["01 芽角羊", "03 炭毛狸", "05 鬚鬚鯰", "07 囤囤鼠", "08 哨哨雀"]

if __name__ == "__main__":
    import sys
    fs = [p.front() for p in ALL]; bs = [p.back() for p in ALL]
    for f, b in zip(fs, bs): print(f.getbbox(), b.getbbox())
    sheet(fs, 4).save("/home/claude/art2/v4_front.png")
    sheet([b.resize((64, 64), Image.NEAREST) for b in bs], 4).save("/home/claude/art2/v4_back.png")
