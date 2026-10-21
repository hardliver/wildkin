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

ALL3 = [FanBat()]
NAMES3 = ["11 搧火蝠"]

if __name__ == "__main__":
    fs = [p.front() for p in ALL3]; bs = [p.back() for p in ALL3]
    a = sheet(fs, 4); b = sheet([x.resize((64, 64), Image.NEAREST) for x in bs], 4)
    W = Image.new("RGBA", (a.width + b.width, max(a.height, b.height))); W.paste(a, (0, 0)); W.paste(b, (a.width, 0))
    import sys
    W.save(sys.argv[1] if len(sys.argv) > 1 else "pals3_preview.png")
