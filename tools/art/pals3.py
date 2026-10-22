# pals3.py：第三批野伴（W66）。畫法和 pals.py 一樣，設計說明見 DESIGN.md
import numpy as np
from r3d import *
from paint import *
from pals import Pal, V, fib

# ============================================================
# 11 搧火蝠：小蝙蝠。翅膀張開懸停；翼膜像風箱，一道道摺骨，搧一搧就把火搧旺；
# 翼緣有點點餘燼、頭頂一小撮火苗。圓滾滾的炭色身體、胸口一團灰白的「灰燼」毛
# ============================================================
class FanBat(Pal):
    FUR = Mat([(48, 40, 44), (74, 62, 64), (102, 88, 86), (130, 114, 108)], line=(52, 42, 46))
    ASH = Mat([(150, 140, 134), (186, 176, 166), (214, 206, 196), (236, 230, 220)], line=(150, 140, 134))
    WING = Mat([(120, 46, 40), (156, 66, 46), (192, 96, 58), (220, 130, 74)], line=(110, 40, 36))
    BONE = Mat([(56, 40, 40), (82, 60, 56), (110, 84, 76)])
    EAR_IN = Mat([(196, 90, 70), (230, 126, 90)])
    EMBER = Mat([(240, 110, 40), (255, 156, 54), (255, 204, 90), (255, 240, 170)])
    NOSE = Mat([(60, 40, 44), (100, 70, 72)], gloss=0.05)
    HEAD = V(-6, -9, 0)
    scale_f, off_f = 1.1, (32, 34)

    # 翅膀的平面：e1 往外上方、e2 往後；骨頭從肩膀放射出去
    BONES = ((-58, 16), (-24, 20), (10, 18), (44, 13))   # （角度、長度）

    def wing_basis(self, s):
        e1 = V(0.45, -0.6, 0.66 * s); e1 = e1 / np.linalg.norm(e1)
        e2 = V(1, 0, 0)
        n = np.cross(e1, e2); n = n / np.linalg.norm(n)
        return e1, e2, n

    def model(self):
        m = Model(); H = self.HEAD
        for s in (1, -1):
            e1, e2, n = self.wing_basis(s)
            base = V(4, -3, 3.5 * s)
            tips = []
            for (a, L) in self.BONES:
                d = np.cos(deg(a)) * e1 + np.sin(deg(a)) * e2
                tips.append(base + d * L)
            # 翼膜：每兩根骨頭之間一片，下緣自然變成一個一個的弧（蝙蝠的波浪邊）
            for j in range(len(tips) - 1):
                t0, t1 = tips[j], tips[j + 1]
                mid = (base + t0 + t1) / 3
                u = (t0 + t1) / 2 - base; Lu = np.linalg.norm(u); u = u / Lu
                v = np.cross(n, u)
                R = np.column_stack([u, v, n])
                w = np.linalg.norm(t1 - t0) / 2
                m.ell(mid + u * 1.0, (Lu * 0.56, w * 0.78, 0.8), self.WING, R, tag=f"wing{s}{j}")
            for j, t in enumerate(tips):
                m.tube([base, t], [1.0, 0.5], self.BONE, tag=f"wingb{s}{j}")
            # 摺骨之間的翼緣：點點餘燼
            for j in range(len(tips) - 1):
                p = base + ((tips[j] + tips[j + 1]) / 2 - base) * 0.8
                m.sph(p + n * 0.6 * s, 1.5, self.EMBER, tag=f"wingE{s}{j}")
        # 身體：圓滾滾
        m.ell((2, 0, 0), (6.5, 7.5, 6), self.FUR, tag="body")
        for i, d in enumerate(fib(14)):
            if d[0] > -0.2: continue
            m.sph(V(-2, 1, 0) + d * V(4.2, 4.8, 4.6), 2.5, self.ASH, tag=f"ash{i}")   # 胸口灰白的毛
        # 頭
        m.ell(H, (5.2, 4.8, 5.2), self.FUR, tag="head")
        m.ell(H + (-4.2, 1.6, 0), (2.4, 2.0, 2.8), self.FUR, tag="head")          # 短短的吻部
        m.ell(H + (-6.2, 1.1, 0), (1.0, 1.0, 1.5), self.NOSE, tag="nose")
        for s in (1, -1):
            R = rot_x(deg(-38 * s)) @ rot_z(deg(-8))
            m.ell(H + (1, -4.6, 3.8 * s), (3.0, 3.8, 1.3), self.FUR, R, tag=f"ear{s}")
            m.ell(H + (0.4, -4.4, 4.7 * s), (1.8, 2.6, 0.6), self.EAR_IN, R, tag=f"eari{s}")
        # 頭頂一小撮火苗
        m.tuft(H + (0.5, -4.5, 0), V(1.5, -4.5, 0), 1.8, self.EMBER, tag="flame")
        m.tuft(H + (-1, -4.5, 0), V(-0.5, -3.2, 0), 1.3, self.EMBER, tag="flame2")
        # 小腳（懸停時垂著）
        for s in (1, -1):
            m.tube([(3, 6.5, 2.5 * s), (3.5, 10.5, 2.8 * s)], [0.9, 0.6], self.BONE, tag=f"leg{s}")
        return m

    def paint_front(self, im, info):
        H = self.HEAD
        x, y = project(info, H + (-3.0, -1.0, 4.0))
        eye_round(im, x, y, 2, 3, (250, 180, 60), big_hi=2)
        if visible(info, H + (-3.0, -1.0, -4.0), 3):
            x2, y2 = project(info, H + (-3.0, -1.0, -4.0))
            eye_round(im, x2, y2, 2, 3, (250, 180, 60), big_hi=2)
        # 嘴：小小的，露一顆白色小牙
        mx, my = project(info, H + (-5.0, 3.0, 2))
        line(im, [(mx - 2, my), (mx + 1, my)], (40, 26, 30))
        put(im, mx - 1, my + 1, (250, 246, 236))

    def paint_back(self, im, info):
        pass

# ============================================================
# 12 礫殼犰狳：四腳、背上一圈一圈的殼帶，每一圈都是碎石拼的，嵌著小石子；
# 尖鼻子、小圓耳；淺色的肚子毛；尾巴也是一節一節的石頭。站著，頭微微低下來嗅地面
# ============================================================
class StoneArmadillo(Pal):
    STONE = Mat([(92, 86, 90), (130, 122, 122), (168, 160, 156), (204, 198, 190)], line=(70, 64, 70))
    STONE2 = Mat([(112, 86, 66), (150, 116, 86), (184, 148, 110), (214, 182, 140)], line=(90, 68, 54))
    SKIN = Mat([(150, 112, 96), (190, 148, 124), (222, 184, 156), (242, 214, 188)], line=(150, 112, 96))
    BELLY = Mat([(196, 170, 140), (226, 204, 172), (244, 230, 204)], line=(190, 164, 136))
    STONE3 = Mat([(70, 70, 82), (98, 98, 112), (130, 130, 144), (164, 164, 176)], line=(64, 64, 76))
    GROUT = Mat([(40, 34, 36), (58, 50, 50)])
    CLAW = Mat([(54, 44, 44), (86, 70, 66)])
    NOSE = Mat([(60, 40, 44), (100, 70, 72)], gloss=0.05)
    HEAD = V(-14, -1, 0)
    scale_f, off_f = 1.15, (34, 36)

    def model(self):
        m = Model(); H = self.HEAD
        # 肚子、身體的底
        m.ell((1, 2, 0), (11, 6.5, 7.5), self.BELLY, tag="belly")
        # 殼帶：從前到後 5 圈，中間的最高。每一圈是一顆顆石頭排成的拱，石頭之間露出深色的縫
        for i, (x, ry) in enumerate(((-7, 6.2), (-2.5, 7.8), (2, 8.4), (6.5, 7.8), (10.5, 6.2))):
            m.ell((x, -1.0, 0), (3.0, ry - 1.2, 8.0), self.GROUT, tag=f"band{i}")
            n = 7
            for j in range(n):
                a = deg(-80 + 160 * j / (n - 1))
                pos = (x + (0.5 if j % 2 else -0.5), -1.0 - np.cos(a) * (ry - 0.6), np.sin(a) * 8.2)
                mat = (self.STONE, self.STONE2, self.STONE3)[(i * 2 + j) % 3]
                m.sph(pos, 2.5 if j % 2 else 2.8, mat, tag=f"st{i}{j}")
        # 尾巴：一節一節變細
        for i in range(4):
            m.sph((14 + i * 2.6, 0.5 + i * 1.6, 0), 2.6 - i * 0.45, self.STONE if i % 2 == 0 else self.STONE2, tag=f"tail{i}")
        # 腳：短而粗，有爪
        for (x, z) in ((-6, 5), (-6, -5), (7, 5), (7, -5)):
            m.tube([(x, 4, z), (x - 0.3, 8.5, z)], [2.6, 2.3], self.SKIN, tag=f"leg{x}{z}")
            m.ell((x - 1.0, 9.6, z), (2.4, 1.2, 2.2), self.CLAW, tag=f"leg{x}{z}")
        # 頭：前面的頭盔（石頭）＋尖尖的鼻子
        m.ell(H, (4.6, 4.2, 4.4), self.SKIN, tag="head")
        m.ell(H + (0.8, -2.4, 0), (3.6, 2.4, 4.0), self.STONE, tag="helm")
        m.tube([H + (-3, 1, 0), H + (-8, 2.6, 0)], [2.4, 1.2], self.SKIN, tag="snout")
        m.ell(H + (-8.4, 2.6, 0), (0.9, 0.9, 1.0), self.NOSE, tag="nose")
        for s in (1, -1):
            m.ell(H + (1.8, -3.4, 3.4 * s), (1.6, 2.2, 1.0), self.SKIN, rot_x(deg(-25 * s)), tag=f"ear{s}")
        return m

    def paint_front(self, im, info):
        H = self.HEAD
        x, y = project(info, H + (-2.4, -0.6, 3.8))
        eye_round(im, x, y, 1, 1, (40, 30, 30), big_hi=1)
        if visible(info, H + (-2.4, -0.6, -3.8), 3):
            x2, y2 = project(info, H + (-2.4, -0.6, -3.8))
            eye_round(im, x2, y2, 1, 1, (40, 30, 30), big_hi=1)

# ============================================================
# 13 霧傘水母：傘蓋像一把撐開的小雨傘（扇形一片片、邊緣波浪、傘骨），飄在空中；
# 下面一根捲起來的「傘柄」觸手，旁邊幾條短觸手；傘頂一個小尖。眼睛在傘蓋前面
# ============================================================
class MistJelly(Pal):
    BELL = Mat([(92, 120, 176), (128, 160, 210), (170, 200, 236), (214, 232, 250)], line=(82, 106, 160))
    BELL2 = Mat([(110, 104, 170), (148, 140, 204), (186, 180, 230), (222, 218, 248)], line=(96, 90, 152))
    RIB = Mat([(60, 70, 110), (90, 104, 146)])
    UNDER = Mat([(150, 176, 214), (196, 214, 238), (230, 240, 252)])
    TENT = Mat([(120, 150, 200), (166, 194, 230), (210, 228, 248)], line=(96, 122, 172))
    HANDLE = Mat([(150, 104, 74), (190, 140, 100), (220, 178, 132)], line=(120, 82, 60))
    HEAD = V(-6, -6, 0)
    scale_f, off_f = 1.1, (32, 34)

    def model(self):
        m = Model()
        # 傘蓋：8 片扇形，兩種顏色交錯，往下垂一點（邊緣的波浪）
        for i in range(8):
            a = deg(i * 45 + 22)
            d = V(np.cos(a), 0, np.sin(a))
            mat = self.BELL if i % 2 == 0 else self.BELL2
            # 每一片往外往下斜（像撐開的傘面），邊緣比中間低
            m.ell(V(0, -8, 0) + d * 6.0 + V(0, 2.2, 0), (6.4, 1.6, 4.2), mat, rot_y(-a) @ rot_z(deg(-24)), tag=f"bell{i}")
            m.tube([V(0, -11.5, 0), V(0, -8, 0) + d * 11 + V(0, 5.0, 0)], [0.6, 0.4], self.RIB, tag=f"rib{i}")  # 傘骨
        m.ell((0, -9.5, 0), (4.5, 2.6, 4.5), self.BELL, tag="top")
        m.ell((0, -12.5, 0), (1.2, 1.8, 1.2), self.RIB, tag="tip")       # 傘頂的小尖
        m.ell((0, -4.2, 0), (7.5, 2.4, 7.5), self.UNDER, tag="under")     # 傘的內側（眼睛畫在這裡）
        # 傘柄：一根捲起來的觸手（J 字形）
        pts = [V(0, -3, 0), V(0, 4, 0), V(0, 10, 0), V(-1.5, 13.5, 0), V(-4.5, 14, 0), V(-5.5, 11.5, 0)]
        m.tube(pts, [1.6, 1.5, 1.4, 1.3, 1.2, 1.1], self.HANDLE, tag="handle")
        # 短觸手：圍一圈
        for i in range(6):
            a = deg(i * 60 + 30)
            b = V(np.cos(a) * 5, -2.5, np.sin(a) * 5)
            m.tube([b, b + V(np.cos(a) * 0.8, 4.5, np.sin(a) * 0.8), b + V(np.cos(a) * 0.2, 8, np.sin(a) * 0.2)],
                   [0.9, 0.7, 0.5], self.TENT, tag=f"tent{i}")
        return m

    def paint_front(self, im, info):
        # 眼睛：傘蓋的內側、面向鏡頭的那一面，兩隻都看得到
        for p in (V(-6.5, -3.2, 0.5), V(-4.6, -3.2, 4.6)):
            x, y = project(info, p)
            eye_round(im, x, y, 1, 2, (40, 36, 70), big_hi=1)

# ============================================================
# 14 爐背牛：矮壯的四腳牛，紅褐色的毛、短而粗的角、胸口一圈淺色的毛；
# 背上長著一根磚砌的煙囪（頂端冒火星），像一座會走路的窯。低頭、前腳踏穩
# ============================================================
class StoveOx(Pal):
    FUR = Mat([(104, 50, 40), (144, 74, 54), (182, 104, 72), (210, 138, 96)], line=(96, 44, 36))
    MANE = Mat([(176, 150, 120), (210, 186, 150), (234, 214, 182)], line=(160, 134, 104))
    HORN = Mat([(150, 140, 120), (196, 186, 160), (230, 222, 200)], line=(120, 110, 96))
    BRICK = Mat([(110, 56, 46), (150, 80, 60), (186, 110, 80)], line=(84, 40, 36))
    EMBER = Mat([(240, 110, 40), (255, 156, 54), (255, 204, 90), (255, 240, 170)])
    HOOF = Mat([(44, 34, 36), (76, 58, 56), (108, 86, 78)])
    NOSE = Mat([(60, 40, 44), (120, 80, 76)], gloss=0.05)
    HEAD = V(-15, -2, 0)
    scale_f, off_f = 1.1, (34, 36)

    def model(self):
        m = Model(); H = self.HEAD
        m.ell((2, 0, 0), (13, 9, 9), self.FUR, tag="body")
        m.ell((-8, 0, 0), (7, 8.5, 8.5), self.FUR, tag="chest")
        for i, d in enumerate(fib(16)):
            if d[0] > -0.3 or d[1] < -0.3: continue
            m.sph(V(-10, 2, 0) + d * V(4, 5, 6), 3.0, self.MANE, tag=f"mane{i}")     # 胸口淺色的毛
        # 煙囪：背上一根磚柱，一段一段，頂端冒火星
        for i in range(4):
            m.ell((4, -10 - i * 3.2, 0), (3.6, 1.8, 3.6), self.BRICK, tag=f"brick{i}")
        m.ell((4, -22.5, 0), (4.2, 1.2, 4.2), self.BRICK, tag="chimtop")
        for j, (x, y, z, r) in enumerate(((4, -24.5, 0, 1.8), (5.5, -26.5, 1, 1.2), (2.8, -27.5, -0.8, 1.0))):
            m.sph((x, y, z), r, self.EMBER, tag=f"ember{j}")
        # 腳：粗短
        for (x, z) in ((-9, 5.5), (-9, -5.5), (10, 5.5), (10, -5.5)):
            m.tube([(x, 6, z), (x, 13, z)], [3.4, 3.0], self.FUR, tag=f"leg{x}{z}")
            m.ell((x, 14, z), (3.0, 1.4, 3.0), self.HOOF, tag=f"leg{x}{z}")
        m.tuft((15, -2, 0), (4, 4, 0), 1.6, self.FUR, tag="tail")
        # 頭：低下來，大鼻子，短角往兩邊
        m.ell(H, (6.5, 6, 6.5), self.FUR, tag="head")
        m.ell(H + (-5, 3, 0), (4, 3.4, 4.6), self.MANE, tag="head")
        for s in (1, -1):
            m.ell(H + (-7.5, 3, 1.8 * s), (0.9, 0.9, 0.9), self.NOSE, tag=f"nose{s}")
            m.tube([H + (1, -5, 4 * s), H + (2, -8, 8 * s), H + (0, -10, 9 * s)], [1.6, 1.2, 0.7], self.HORN, tag=f"horn{s}")
            m.ell(H + (1, -2, 6.5 * s), (2.6, 1.4, 1.8), self.FUR, rot_x(deg(30 * s)), tag=f"ear{s}")
        return m

    def paint_front(self, im, info):
        H = self.HEAD
        x, y = project(info, H + (-3, -1.5, 5.2))
        eye_round(im, x, y, 1, 2, (250, 170, 60), big_hi=1)
        if visible(info, H + (-3, -1.5, -5.2), 3):
            x2, y2 = project(info, H + (-3, -1.5, -5.2))
            eye_round(im, x2, y2, 1, 2, (250, 170, 60), big_hi=1)

ALL3 = [FanBat(), StoneArmadillo(), MistJelly(), StoveOx()]
NAMES3 = ["11 搧火蝠", "12 礫殼犰狳", "13 霧傘水母", "14 爐背牛"]

if __name__ == "__main__":
    fs = [p.front() for p in ALL3]; bs = [p.back() for p in ALL3]
    a = sheet(fs, 4); b = sheet([x.resize((64, 64), Image.NEAREST) for x in bs], 4)
    W = Image.new("RGBA", (a.width + b.width, max(a.height, b.height))); W.paste(a, (0, 0)); W.paste(b, (a.width, 0))
    import sys
    W.save(sys.argv[1] if len(sys.argv) > 1 else "pals3_preview.png")
