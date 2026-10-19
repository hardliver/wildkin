from lib import *
WOOL=(244,236,214,255); WOOL_D=(212,198,168,255); WOOL_L=(255,252,240,255)
FACE=(228,196,150,255); FACE_D=(196,160,116,255); NOSE=(222,136,136,255)
HOOF=(92,64,54,255); LEAF=(124,204,84,255); LEAF_D=(70,150,60,255); EYE=(40,30,44,255); WHITE=(255,255,255,255)

def front():
    s = Sprite(64, 64)
    # 腳（後面兩隻先畫，顏色暗一點）
    for x in (40, 50): s.rect((x, 46, x+5, 58), FACE_D); s.rect((x, 56, x+5, 59), HOOF)
    # 羊毛身體：一個大橢圓 + 一圈小圓，邊緣蓬蓬的
    s.ellipse((20, 26, 58, 54), WOOL)
    for cx, cy in ((24,30),(32,25),(41,24),(50,27),(56,34),(57,44),(52,51),(42,53),(31,52),(22,46)):
        s.ellipse((cx-5, cy-5, cx+5, cy+5), WOOL)
    s.shade(WOOL, (12, 46, 64, 72), WOOL_D)     # 下半部陰影
    s.shade(WOOL, (28, 22, 48, 34), WOOL_L)     # 上面亮一點
    # 前腳
    for x in (24, 32): s.rect((x, 48, x+5, 60), FACE); s.rect((x, 58, x+5, 61), HOOF)
    # 尾巴
    s.ellipse((55, 28, 62, 36), WOOL)
    # 頭
    s.ellipse((6, 14, 32, 40), FACE)
    s.shade(FACE, (20, 33, 40, 50), FACE_D)
    # 耳朵（往後垂）
    s.poly([(27, 19), (38, 21), (35, 26), (27, 25)], FACE_D)
    s.poly([(29, 21), (35, 22), (33, 24), (29, 23)], NOSE)
    # 嘴巴前端
    s.ellipse((4, 28, 18, 39), FACE)
    s.ellipse((5, 30, 10, 34), NOSE)
    # 眼睛
    s.rect((15, 22, 18, 27), EYE); s.px(16, 23, WHITE); s.px(17, 23, WHITE)
    # 頭頂的羊毛瀏海
    for cx in (16, 22, 27): s.ellipse((cx-4, 12, cx+4, 19), WOOL)
    # 嫩芽角：兩根莖 + 兩片葉子
    s.line([(15, 13), (13, 6)], LEAF_D, 2)
    s.line([(24, 12), (27, 5)], LEAF_D, 2)
    s.poly([(13, 7), (5, 2), (4, 6), (9, 9)], LEAF)
    s.poly([(13, 7), (16, 1), (19, 3), (15, 8)], LEAF)
    s.poly([(27, 5), (34, 0), (36, 4), (30, 7)], LEAF)
    s.poly([(27, 5), (23, 0), (21, 2), (25, 6)], LEAF)
    s.px(8, 5, LEAF_D); s.px(32, 3, LEAF_D)
    s.outline()
    return s.im

if __name__ == "__main__":
    preview([front()], "../../build/kin_sheep.png", 6)
