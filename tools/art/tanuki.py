from lib import *
FUR=(176,112,70,255); FUR_D=(132,78,52,255); FUR_L=(210,150,96,255)
BELLY=(240,214,170,255); MASK=(70,48,44,255); EYE=(40,30,44,255); WHITE=(255,255,255,255)
COAL=(60,52,58,255); EMBER=(255,120,40,255); EMBER_L=(255,210,90,255); NOSE=(40,30,44,255)

def front():
    s = Sprite(64, 64)
    # 尾巴（在身體後面）：粗粗地往右上翹，尾尖是悶燒的炭（黑炭裡透出橘紅的裂紋）
    s.ellipse((38, 12, 60, 46), FUR)
    s.shade(FUR, (36, 32, 66, 52), FUR_D)
    s.shade(FUR, (44, 8, 66, 26), COAL)
    s.shade(FUR_D, (44, 8, 66, 26), COAL)
    s.shade(COAL, (49, 12, 59, 20), EMBER)
    s.shade(EMBER, (51, 13, 56, 17), EMBER_L)
    s.px(47, 22, EMBER); s.px(48, 23, EMBER); s.px(57, 22, EMBER)    # 裂紋
    # 身體：圓滾滾
    s.ellipse((12, 28, 48, 60), FUR)
    s.shade(FUR, (20, 48, 60, 72), FUR_D)
    s.ellipse((18, 38, 38, 58), BELLY)
    # 腳
    for x in (16, 34): s.ellipse((x, 54, x+10, 62), FUR_D)
    # 頭
    s.ellipse((8, 8, 40, 38), FUR)
    s.shade(FUR, (20, 28, 46, 46), FUR_D)
    # 耳朵
    s.poly([(12, 14), (12, 3), (21, 10)], FUR); s.poly([(14, 11), (14, 6), (18, 10)], MASK)
    s.poly([(29, 9), (36, 2), (37, 13)], FUR); s.poly([(31, 9), (35, 5), (35, 11)], MASK)
    # 眼罩（狸貓的黑眼圈）＋ 白色口鼻
    s.ellipse((9, 18, 22, 28), MASK); s.ellipse((24, 18, 37, 28), MASK)
    s.ellipse((15, 24, 31, 35), BELLY)
    s.rect((13, 21, 16, 24), WHITE); s.px(14, 22, EYE); s.px(15, 22, EYE); s.px(14, 23, EYE); s.px(15, 23, EYE)
    s.rect((28, 21, 31, 24), WHITE); s.px(29, 22, EYE); s.px(30, 22, EYE); s.px(29, 23, EYE); s.px(30, 23, EYE)
    s.rect((21, 26, 25, 28), NOSE)
    s.line([(20, 31), (23, 32), (26, 31)], MASK)
    s.outline()
    return s.im

def back():
    s = Sprite(32, 32)
    # 從背後：圓背、大尾巴翹起來（尾尖的炭最顯眼），頭在右上
    s.ellipse((3, 13, 23, 31), FUR)
    s.shade(FUR, (-2, 24, 30, 40), FUR_D)
    s.ellipse((12, 3, 29, 19), FUR)
    s.shade(FUR, (10, 12, 26, 24), FUR_D)
    s.poly([(14, 7), (14, 0), (19, 5)], FUR); s.poly([(23, 5), (28, 0), (28, 8)], FUR)
    s.ellipse((0, 6, 11, 24), FUR)                        # 尾巴（翹起來）
    s.shade(FUR, (-2, 2, 10, 12), COAL)
    s.shade(COAL, (1, 5, 7, 10), EMBER); s.px(3, 7, EMBER_L)
    s.outline()
    return s.im

if __name__ == "__main__":
    preview([front(), back()], "../../build/kin_tanuki.png", 5)
