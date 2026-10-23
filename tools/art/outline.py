# 野伴戰鬥圖加 1 像素深色外框（2026-10-22 Neil：戰鬥畫面改版，野伴要跟 GB 一樣有清楚的輪廓）
#   python3 tools/art/outline.py   → 直接改 assets/art/kin_front.png（64×64 一格）、kin_back.png（32×32 一格）
# 外框只畫在「透明、而且上下左右碰到圖（不是外框色）」的格子上，每一格各自算，不會畫到隔壁格。
# 重複執行不會變成兩圈：第二次時，透明的地方只碰得到外框色，不會再加。
# build.py 新算出來的野伴也會先經過這裡再貼上去（凍結的那幾隻已經有外框了）。
# 外框色用 Kenney 的深色外框 (63, 38, 49)，本來就在調色盤裡，不多佔顏色。
import os
from PIL import Image

OUTLINE = (63, 38, 49, 255)

def outline_cell(im, x0, y0, w, h):
    px = im.load()
    add = []
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if x0 <= nx < x0 + w and y0 <= ny < y0 + h:
                    p = px[nx, ny]
                    if p[3] and p != OUTLINE:
                        add.append((x, y))
                        break
    for x, y in add:
        px[x, y] = OUTLINE

def outline_sheet(im, cell):
    im = im.convert("RGBA")
    for cx in range(0, im.width, cell):
        outline_cell(im, cx, 0, cell, im.height)
    return im

if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    art = os.path.join(here, "..", "..", "assets", "art")
    for name, cell in (("kin_front.png", 64), ("kin_back.png", 32)):
        p = os.path.join(art, name)
        outline_sheet(Image.open(p), cell).save(p)
        print("外框：", name)
