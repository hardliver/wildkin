# paint.py：在算好的圖上補畫 2D 細節（眼睛、嘴巴、花紋）
# 眼睛是角色的靈魂，用 3D 算出來會糊掉，所以一律手動畫：
#   深色外框 → 虹膜 → 瞳孔 → 兩個反光點 → 上眼瞼（眼皮壓下來的程度決定表情）
from PIL import Image

def put(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), (*c[:3], 255))

def ell_pts(cx, cy, rx, ry):
    pts = []
    for y in range(-ry, ry + 1):
        for x in range(-rx, rx + 1):
            if (x * x) * (ry * ry) + (y * y) * (rx * rx) <= (rx * rx) * (ry * ry) + max(rx, ry):
                pts.append((cx + x, cy + y))
    return pts

def eye(im, cx, cy, rx, ry, iris, iris_d, line=(30, 22, 30), lid=0, lid_slope=0, skin=None,
        pupil=(24, 18, 26), look=(0, 0), hi=(255, 255, 255)):
    """lid：上眼瞼往下蓋幾列（0 = 張大眼、越大越像瞇眼／不屑）；
    lid_slope：眼瞼斜度（正 = 內側比較低，看起來很兇／很有自信）"""
    inside = set(ell_pts(cx, cy, rx, ry))
    for (x, y) in inside:
        # 虹膜：上半部暗、下半部亮（像有光從下面透上來，動畫風格的眼睛）
        put(im, x, y, iris_d if y < cy else iris)
    # 瞳孔
    px, py = cx + look[0], cy + look[1]
    for (x, y) in ell_pts(px, py, max(rx - 2, 0), max(ry - 2, 1)):
        if (x, y) in inside: put(im, x, y, pupil)
    # 反光：左上大的、右下小的
    for (x, y) in ((cx - rx + 2, cy - ry + 2), (cx - rx + 3, cy - ry + 2), (cx - rx + 2, cy - ry + 3), (cx - rx + 3, cy - ry + 3)):
        if (x, y) in inside: put(im, x, y, hi)
    put(im, cx + rx - 2, cy + ry - 2, hi) if (cx + rx - 2, cy + ry - 2) in inside else None
    # 外框
    for (x, y) in inside:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in inside:
                put(im, x + dx, y + dy, line)
    # 上眼瞼：蓋掉上面幾列，最下面那列畫成粗的睫毛線
    if lid > 0 or lid_slope:
        for x in range(cx - rx - 1, cx + rx + 2):
            cut = cy - ry + lid + (lid_slope * (x - cx)) // max(rx, 1)
            for y in range(cy - ry - 1, cut):
                if skin and ((x, y) in inside or (x, y - 1) in inside or (x, y + 1) in inside):
                    put(im, x, y, skin)
            put(im, x, cut, line)
            put(im, x, cut - 1, line) if (x, cut) in inside else None
    else:
        for x in range(cx - rx + 1, cx + rx):
            put(im, x, cy - ry - 1, line)   # 眼睛上緣粗一點

def line(im, pts, c):
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for k in range(n + 1):
            put(im, x0 + (x1 - x0) * k // n, y0 + (y1 - y0) * k // n, c)

def eye_round(im, cx, cy, rx, ry, iris, pupil=(20, 16, 22), line=(26, 20, 28), hi=(255, 255, 255),
              ring=None, look=(0, 0), big_hi=2):
    """圓眼（第四版）：虹膜 → 大瞳孔 → 左上一個大反光、右下一個小反光；ring = 眼圈顏色（鳥）"""
    inside = set(ell_pts(cx, cy, rx, ry))
    if ring:
        for (x, y) in ell_pts(cx, cy, rx + 1, ry + 1):
            if (x, y) not in inside: put(im, x, y, ring)
    for (x, y) in inside:
        put(im, x, y, iris if y >= cy - ry // 3 else tuple(c * 3 // 4 for c in iris))   # 虹膜上面暗一點
    px, py = cx + look[0], cy + look[1]
    for (x, y) in ell_pts(px, py, max(rx - 1, 0), max(ry - 1, 0)):
        if (x, y) in inside: put(im, x, y, pupil)
    # 反光
    hx, hy = cx - rx // 2 - (0 if rx < 2 else 0), cy - ry // 2
    for dx in range(big_hi):
        for dy in range(big_hi):
            if (hx + dx, hy + dy) in inside: put(im, hx + dx, hy + dy, hi)
    if rx >= 2 and (cx + rx // 2, cy + ry // 2) in inside:
        put(im, cx + rx // 2, cy + ry // 2, hi)
    # 外框（只有上半圈畫粗，下半圈用虹膜的暗色，比較柔和）
    for (x, y) in inside:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in inside:
                put(im, x + dx, y + dy, line if y <= cy else tuple(c // 2 for c in iris))
