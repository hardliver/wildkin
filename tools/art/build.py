# 野伴戰鬥圖產生器（W24）。在 wildkin/tools/art 執行：python3 build.py
# 輸出 assets/art/kin_front.png（64×64 × 5）與 kin_back.png（32×32 × 5），預覽在 build/kin_preview.png
from PIL import Image
import sheep, back_sheep, tanuki, others
fronts = [sheep.front(), tanuki.front(), others.catfish_front(), others.hamster_front(), others.bird_front()]
backs = [back_sheep.back(), tanuki.back(), others.catfish_back(), others.hamster_back(), others.bird_back()]
F = Image.new("RGBA", (64 * 5, 64), (0, 0, 0, 0)); B = Image.new("RGBA", (32 * 5, 32), (0, 0, 0, 0))
for i, im in enumerate(fronts): F.paste(im, (i * 64, 0))
for i, im in enumerate(backs): B.paste(im, (i * 32, 0))
F.save("../../assets/art/kin_front.png"); B.save("../../assets/art/kin_back.png")
cols = set()
for im in (F, B):
    for p in im.getdata():
        if p[3] >= 128: cols.add(p[:3])
print("colors:", len(cols))
# 預覽：上排正面，下排背面（放大 2 倍，和遊戲裡一樣）
names = ["01 芽角羊", "03 炭毛狸", "05 鬚鬚鯰", "07 囤囤鼠", "08 哨哨雀"]
P = Image.new("RGBA", (5 * 80 + 10, 64 + 64 + 30), (160, 200, 150, 255))
for i in range(5):
    P.paste(fronts[i], (10 + i * 80, 8), fronts[i])
    b2 = backs[i].resize((64, 64), Image.NEAREST)
    P.paste(b2, (10 + i * 80, 84), b2)
P.resize((P.width * 3, P.height * 3), Image.NEAREST).save("../../build/kin_preview.png")
