# 霧（W57）：python3 tools/art/fog.py → assets/art/fog.png
# 引擎沒有半透明，霧用「一部分像素是白的、其他透明」的點陣（dither）來畫：中間比較密、邊緣比較疏。
# 一張 64×32 的霧團，遊戲裡畫好幾個，慢慢往右飄（forest 地圖，fog.lua）
import os, sys
from PIL import Image

W, H = 64, 32
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]   # 4×4 的抖動門檻
C1, C2 = (0xc0, 0xcb, 0xdc), (0xff, 0xff, 0xff)   # Tiny Town 調色盤的淺灰、白

def build():
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for y in range(H):
        for x in range(W):
            dx, dy = (x - W / 2) / (W / 2), (y - H / 2) / (H / 2)
            d = dx * dx + dy * dy                       # 0 = 中心、1 = 邊緣
            density = max(0.0, 1 - d) * 0.55            # 最密的地方也只有一半多一點的點
            if density * 16 > BAYER[y % 4][x % 4]:
                im.putpixel((x, y), (*(C2 if density > 0.35 else C1), 255))
    return im

if __name__ == "__main__":
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../assets/art/fog.png")
    if len(sys.argv) > 1: out = sys.argv[1]
    build().save(out)
