# 設施圖（W44）：python3 tools/art/facilities.py。32×32，一個設施佔 2×2 格。用 Kenney Tiny Town 的調色盤畫，風格一致、也不會多用顏色
from PIL import Image
OUT = (0x3f, 0x26, 0x31)
W1, W2, W3, W4 = (0x76, 0x3b, 0x36), (0xbd, 0x6c, 0x4a), (0xea, 0xa5, 0x6c), (0xfc, 0xbc, 0x8f)
S1, S2, S3 = (0x5a, 0x69, 0x88), (0x8b, 0x9b, 0xb4), (0xc0, 0xcb, 0xdc)
G1, G2, G3 = (0x47, 0x9f, 0x4a), (0x84, 0xc6, 0x69), (0x8b, 0xd8, 0x7d)
D1 = (0xcf, 0x82, 0x54)
RED, YEL = (0xc3, 0x4b, 0x35), (0xfd, 0xbe, 0x53)
NAVY = (0x26, 0x2b, 0x44)

def new(): return Image.new("RGBA", (32, 32), (0, 0, 0, 0))
def px(im, x, y, c):
    if 0 <= x < 32 and 0 <= y < 32: im.putpixel((x, y), (*c, 255))
def box(im, x, y, w, h, c, line=OUT):
    for j in range(h):
        for i in range(w):
            edge = i in (0, w - 1) or j in (0, h - 1)
            px(im, x + i, y + j, line if (edge and line) else c)
def hline(im, x0, x1, y, c):
    for x in range(x0, x1 + 1): px(im, x, y, c)
def vline(im, x, y0, y1, c):
    for y in range(y0, y1 + 1): px(im, x, y, c)

def log_end(im, x, y):   # 圓木的切面（5×5，相鄰的共用外框）
    for (i, j) in ((1,0),(2,0),(3,0),(0,1),(4,1),(0,2),(4,2),(0,3),(4,3),(1,4),(2,4),(3,4)): px(im, x+i, y+j, OUT)
    for (i, j) in ((1,1),(2,1),(3,1),(1,2),(3,2),(1,3),(2,3),(3,3)): px(im, x+i, y+j, W4)
    px(im, x+2, y+2, D1)

def lot():
    """空地：四角插木樁、拉一圈繩子，中間是翻過的土"""
    im = new()
    for j in range(4, 28):
        for i in range(4, 28):
            px(im, i, j, D1 if (i * 7 + j * 3) % 11 == 0 else W3)
    for c in ((3, 3), (26, 3), (3, 26), (26, 26)):
        box(im, c[0], c[1] - 2, 3, 5, W2)
    hline(im, 6, 25, 3, (0xf2, 0x84, 0x62)); hline(im, 6, 25, 26, (0xf2, 0x84, 0x62))
    vline(im, 4, 6, 23, (0xf2, 0x84, 0x62)); vline(im, 27, 6, 23, (0xf2, 0x84, 0x62))
    return im

def lumber():
    """伐木場：左邊一根大樹樁插著斧頭，右邊堆了三層圓木"""
    im = new()
    # 地上的木屑
    for (x, y) in ((3, 28), (6, 29), (10, 27), (14, 29), (19, 28), (24, 29), (28, 27)): px(im, x, y, W3)
    # 圓木堆（側面）：底層 3 根、中間 2 根、上面 1 根
    rows = [(14, 23, 3), (16, 18, 3), (18, 13, 2), (20, 8, 1)]
    for (x0, y0, n) in rows:
        for k in range(n): log_end(im, x0 + k * 4 + (k > 0) * 0, y0)
    # 樹樁
    box(im, 2, 18, 10, 10, W2)
    for i in range(3, 11): px(im, i, 27, W1)
    vline(im, 4, 21, 26, W1); vline(im, 8, 22, 26, W1)
    box(im, 1, 15, 12, 5, W4)
    hline(im, 3, 10, 17, D1); px(im, 6, 16, D1); px(im, 7, 18, D1)
    # 斧頭：柄斜插在樹樁上，鐵的部分
    for k in range(9): px(im, 9 - k // 2, 15 - k, W1); px(im, 10 - k // 2, 15 - k, W3)
    box(im, 2, 5, 6, 5, S3)
    vline(im, 3, 6, 8, S2); hline(im, 3, 6, 8, S2)
    return im

def farm():
    """田：一塊翻過的土，三排小芽，旁邊插一個稻草人（很小）"""
    im = new()
    box(im, 1, 4, 30, 26, W2)
    for j in range(5, 29):
        for i in range(2, 30):
            px(im, i, j, W3 if (j - 5) % 6 < 3 else D1)    # 田埂和溝
    for row in range(4):
        y = 6 + row * 6
        for x in (5, 11, 17, 23):
            px(im, x, y + 1, G1); px(im, x + 1, y + 1, G1)
            px(im, x - 1, y, G2); px(im, x, y - 1, G3); px(im, x + 2, y, G2); px(im, x + 1, y - 1, G3)
    return im

def storage():
    """倉庫：小木屋，紅屋頂，正面一扇雙開門"""
    im = new()
    # 牆
    box(im, 3, 13, 26, 17, W3)
    for y in range(14, 29, 3): hline(im, 4, 27, y, D1)
    # 門
    box(im, 10, 17, 12, 13, W2)
    vline(im, 15, 18, 28, OUT); vline(im, 16, 18, 28, OUT)
    for k in range(9):
        px(im, 11 + k // 2 + 0, 18 + k, W1); px(im, 20 - k // 2, 18 + k, W1)
    px(im, 14, 23, YEL); px(im, 17, 23, YEL)
    # 屋頂（往外凸一點）
    for j in range(10):
        x0, x1 = 12 - j * 3 // 2, 19 + j * 3 // 2
        x0 = max(x0, 0); x1 = min(x1, 31)
        hline(im, x0, x1, 3 + j, RED if (j % 3) else (0xe8, 0x45, 0x37))
        px(im, x0, 3 + j, OUT); px(im, x1, 3 + j, OUT)
    hline(im, 12, 19, 2, OUT); hline(im, 0, 31, 13, OUT)
    # 屋頂上的小窗
    box(im, 13, 6, 6, 5, NAVY); px(im, 15, 7, S3)
    return im

if __name__ == "__main__":
    # 輸出到 assets/art/facilities.png：第 0 格空地、1 伐木場、2 田、3 倉庫（每格 32×32）
    import os
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../assets/art/facilities.png")
    sheet = Image.new("RGBA", (32 * 4, 32), (0, 0, 0, 0))
    for i, f in enumerate((lot, lumber, farm, storage)):
        sheet.paste(f(), (i * 32, 0))
    sheet.save(out)
