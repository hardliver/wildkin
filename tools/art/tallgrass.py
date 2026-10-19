# 遇敵草叢（W28）：16×16 × 3 格（正常、往左晃、往右晃），顏色配 Kenney 的草地
# 在 wildkin/tools/art 執行：python3 tallgrass.py → assets/art/tallgrass.png
import os
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
C = {"d": (62, 122, 70), "m": (101, 165, 86), "l": (139, 216, 125), "o": (40, 86, 56)}
# 一叢草（8 寬 × 9 高）：上面是尖尖的葉子，越下面越密、越暗
TUFT = [
    "..l...l.",
    ".lm..lm.",
    ".mm.lmm.",
    "lmmdlmmd",
    "mmdmmmdd",
    "mdddmddd",
    "dddddddo",
    "oddddddo",
    ".oooooo.",
]
def frame(shift):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    # 兩排錯開的草叢：上排在 (0,0)、(8,0)，下排在 (4,7)、(-4,7)、(12,7)
    for (ox, oy) in ((0, 0), (8, 0), (-4, 7), (4, 7), (12, 7)):
        for r, row in enumerate(TUFT):
            dx = shift if r < 3 else 0          # 只有尖端跟著風晃
            for c, ch in enumerate(row):
                if ch == ".": continue
                x, y = ox + c + dx, oy + r
                if 0 <= x < 16 and 0 <= y < 16:
                    im.putpixel((x, y), (*C[ch], 255))
    return im
out = Image.new("RGBA", (48, 16), (0, 0, 0, 0))
for i, s in enumerate((0, -1, 1)):
    out.paste(frame(s), (i * 16, 0))
path = os.path.join(HERE, "..", "..", "assets", "art", "tallgrass.png")
os.makedirs(os.path.dirname(path), exist_ok=True)
out.save(path)
