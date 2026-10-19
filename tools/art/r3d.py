# r3d.py：用簡單的 3D 形狀（橢球）組出野伴，再「算」成像素圖
#
# 為什麼不直接畫 2D：同一隻要有正面（64×64）和背面（32×32）兩張圖，
# 用 3D 模型轉個方向就能得到背面，兩張一定是同一隻；而且光影（亮面、陰影、
# 反光）是算出來的，比手畫的扁平色塊有立體感。
#
# 座標：x 往右、y 往下、z 朝向觀看者（數字越大越靠近鏡頭）。
# 每個形狀有材質（一串由暗到亮的顏色），依照受光量選第幾個顏色。
import numpy as np
from PIL import Image

def rot_x(a):
    c, s = np.cos(a), np.sin(a); return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
def rot_y(a):
    c, s = np.cos(a), np.sin(a); return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
def rot_z(a):
    c, s = np.cos(a), np.sin(a); return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])
def deg(d): return d * np.pi / 180

class Mat:
    """材質：ramp 由暗到亮；gloss 有光澤（眼睛、鼻頭）會出現白色反光點；
    rough 表面粗糙度（毛、石頭）：受光量加一點雜訊，邊界會參差不齊"""
    def __init__(s, ramp, gloss=0.0, rough=0.0, line=None, spec=(255, 255, 255)):
        s.ramp = [tuple(c) for c in ramp]
        s.gloss, s.rough = gloss, rough
        s.line = line or s.ramp[0]          # 這個材質的內部線條色
        s.spec = spec

class Model:
    def __init__(s):
        s.parts = []   # (center, radii, R, mat, tag)
    def tuft(s, base, d, r, mat, tag=None):
        """一撮尖尖的毛（或火舌）：從 base 往 d 方向，半徑從 r 變到很細"""
        b = np.array(base, float)
        s.tube([b, b + np.array(d, float)], [r, r * 0.15], mat, tag=tag)
    def ell(s, c, r, mat, R=None, tag=None):
        s.parts.append((np.array(c, float), np.array(r, float), np.eye(3) if R is None else R, mat, tag))
    def sph(s, c, r, mat, tag=None):
        s.ell(c, (r, r, r), mat, None, tag)
    def tube(s, pts, radii, mat, steps=None, tag=None):
        """沿著折線放一串球（腳、角、尾巴）；radii 是每個點的半徑，中間內插"""
        pts = [np.array(p, float) for p in pts]
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            ra, rb = radii[i], radii[i + 1]
            n = steps or max(2, int(np.linalg.norm(b - a) / max(min(ra, rb) * 0.5, 0.4)) + 1)
            for k in range(n + (1 if i == len(pts) - 2 else 0)):
                t = k / n
                s.sph(a + (b - a) * t, ra + (rb - ra) * t, mat, tag)

def render(model, size, view, scale=1.0, offset=(0, 0), light=(-0.55, -0.75, 0.55), ambient=0.18,
           outline=(36, 26, 34), seed=1, depth_dark=0.22):
    """view：3×3 旋轉矩陣（整個模型轉成要看的方向）；scale：縮放；offset：畫面上的中心點"""
    W = H = size
    zbuf = np.full((H, W), -1e9)
    nbuf = np.zeros((H, W, 3))
    mbuf = np.full((H, W), -1, int)
    tbuf = np.full((H, W), -1, int)
    mats, tags = [], []
    ys, xs = np.mgrid[0:H, 0:W]
    px = (xs + 0.5 - offset[0]) / scale
    py = (ys + 0.5 - offset[1]) / scale
    for (c, r, R, mat, tag) in model.parts:
        if mat not in mats: mats.append(mat)
        if tag not in tags: tags.append(tag)
        mi, ti = mats.index(mat), tags.index(tag)
        cw = view @ c
        Rw = view @ R
        # 只算附近的像素
        rmax = r.max()
        x0 = int(max(0, np.floor(cw[0] * scale + offset[0] - rmax * scale - 1)))
        x1 = int(min(W, np.ceil(cw[0] * scale + offset[0] + rmax * scale + 2)))
        y0 = int(max(0, np.floor(cw[1] * scale + offset[1] - rmax * scale - 1)))
        y1 = int(min(H, np.ceil(cw[1] * scale + offset[1] + rmax * scale + 2)))
        if x0 >= x1 or y0 >= y1: continue
        dx = px[y0:y1, x0:x1] - cw[0]
        dy = py[y0:y1, x0:x1] - cw[1]
        inv = 1.0 / (r * r)
        RT = Rw.T
        v = RT[:, 2]                                  # 本地座標裡的 z 方向
        u = RT[:, 0][None, None, :] * dx[..., None] + RT[:, 1][None, None, :] * dy[..., None]
        A = np.sum(v * v * inv)
        B = 2 * np.sum(u * v * inv, axis=-1)
        C = np.sum(u * u * inv, axis=-1) - 1
        disc = B * B - 4 * A * C
        hit = disc >= 0
        z = np.where(hit, (-B + np.sqrt(np.maximum(disc, 0))) / (2 * A), -1e9)
        q = u + z[..., None] * v
        nl = q * inv
        nw = nl @ RT                                   # 回到世界座標：n_world = R n_local
        zz = z + cw[2]
        sub = zbuf[y0:y1, x0:x1]
        better = hit & (zz > sub)
        sub[better] = zz[better]
        nbuf[y0:y1, x0:x1][better] = nw[better]
        mbuf[y0:y1, x0:x1][better] = mi
        tbuf[y0:y1, x0:x1][better] = ti
    # 打光
    L = np.array(light, float); L /= np.linalg.norm(L)
    n = nbuf / np.maximum(np.linalg.norm(nbuf, axis=-1, keepdims=True), 1e-9)
    diff = np.clip(np.sum(n * L, axis=-1), 0, 1)
    rim = np.clip(1 - n[..., 2], 0, 1) ** 3 * 0.25 * (n[..., 0] > 0.2)   # 右後方一點反光，不會黑成一團
    I = ambient + (1 - ambient) * diff + rim
    # 越遠越暗一點（後面那隻腳、另一邊的角），前後比較分得出來
    hitz = zbuf > -1e8
    if hitz.any():
        zmin, zmax = zbuf[hitz].min(), zbuf[hitz].max()
        I = I - depth_dark * (zmax - zbuf) / max(zmax - zmin, 1e-6)
    rng = np.random.default_rng(seed)
    noise = rng.random((H, W)) - 0.5
    Hv = L + np.array([0, 0, 1.0]); Hv /= np.linalg.norm(Hv)
    specv = np.sum(n * Hv, axis=-1)
    img = np.zeros((H, W, 4), np.uint8)
    for mi, mat in enumerate(mats):
        m = mbuf == mi
        if not m.any(): continue
        Ii = I + noise * mat.rough
        k = len(mat.ramp)
        idx = np.clip((Ii * k).astype(int), 0, k - 1)
        cols = np.array(mat.ramp, np.uint8)
        img[m, :3] = cols[idx[m]]
        img[m, 3] = 255
        if mat.gloss > 0:
            sp = m & (specv > 1 - mat.gloss)
            img[sp, :3] = mat.spec
    # 內部線條：比較遠的那一邊、和比較近的形狀交界的地方（深度差大）
    out = img.copy()
    dz = 2.5 / scale
    for y in range(H):
        for x in range(W):
            if mbuf[y, x] < 0: continue
            for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + ddx, y + ddy
                if 0 <= xx < W and 0 <= yy < H and mbuf[yy, xx] >= 0:
                    if zbuf[yy, xx] - zbuf[y, x] > dz * scale and tbuf[yy, xx] != tbuf[y, x]:
                        out[y, x, :3] = mats[mbuf[y, x]].line
                        break
    # 外框：透明像素旁邊有東西就畫外框色
    final = out.copy()
    for y in range(H):
        for x in range(W):
            if out[y, x, 3]: continue
            for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + ddx, y + ddy
                if 0 <= xx < W and 0 <= yy < H and out[yy, xx, 3]:
                    if outline == "sel" and mbuf[yy, xx] >= 0:
                        d = mats[mbuf[yy, xx]].ramp[0]
                        final[y, x] = (d[0] * 55 // 100, d[1] * 55 // 100, d[2] * 55 // 100, 255)
                    else:
                        final[y, x] = (*(outline if outline != "sel" else (36, 26, 34)), 255)
                    break
    return Image.fromarray(final, "RGBA"), dict(z=zbuf, m=mbuf, mats=mats, view=view, scale=scale, offset=offset)

def project(info, p):
    """3D 座標 → 畫面像素（之後在圖上補畫細節用）"""
    w = info["view"] @ np.array(p, float)
    return int(round(w[0] * info["scale"] + info["offset"][0] - 0.5)), int(round(w[1] * info["scale"] + info["offset"][1] - 0.5))

def visible(info, p, tol=1.5):
    w = info["view"] @ np.array(p, float)
    x, y = project(info, p)
    H, W = info["z"].shape
    if not (0 <= x < W and 0 <= y < H): return False
    return info["z"][y, x] <= w[2] + tol

def sheet(images, scale=4, bg=(150, 190, 140, 255), gap=8):
    w = sum(i.width for i in images) + gap * (len(images) + 1)
    h = max(i.height for i in images) + gap * 2
    out = Image.new("RGBA", (w, h), bg)
    x = gap
    for i in images:
        out.paste(i, (x, gap + (h - 2 * gap - i.height)), i); x += i.width + gap
    return out.resize((w * scale, h * scale), Image.NEAREST)
