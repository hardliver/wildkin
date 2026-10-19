from lib import *
EYE=(40,30,44,255); WHITE=(255,255,255,255)

# ---------------- 鬚鬚鯰 ----------------
CF=(92,150,190,255); CF_D=(62,108,150,255); CF_L=(140,192,222,255); CB=(214,232,236,255)
WHISK=(60,70,96,255); FIN=(70,124,168,255)

def catfish_front():
    s = Sprite(64, 64)
    # 尾巴：圓圓的尾鰭，往上翹
    s.ellipse((46, 18, 62, 40), FIN)
    s.shade(FIN, (54, 18, 66, 40), CF_D)
    # 短短的腳
    for x in (22, 36): s.ellipse((x, 50, x+9, 60), CF_D)
    # 身體：頭大大扁扁（左邊），往右變細
    s.ellipse((22, 26, 54, 54), CF)
    s.ellipse((4, 22, 36, 54), CF)
    s.shade(CF, (0, 44, 64, 70), CF_D)
    s.shade(CF, (10, 22, 40, 34), CF_L)
    s.ellipse((14, 40, 42, 56), CB)                     # 白肚子
    # 背鰭：小小圓圓的
    s.ellipse((28, 18, 40, 30), FIN)
    # 小手
    s.ellipse((30, 40, 38, 48), CF_D)
    # 寬寬的嘴、眼睛（眼睛小小的在頭頂）
    s.line([(5, 40), (14, 42), (22, 40)], CF_D)
    s.rect((14, 29, 17, 32), EYE); s.px(15, 30, WHITE)
    # 長鬍鬚：從嘴角往外、往下飄
    s.line([(6, 39), (2, 42), (1, 48), (3, 54), (6, 58)], WHISK)
    s.line([(8, 40), (6, 46), (8, 52)], WHISK)
    s.line([(6, 37), (2, 34), (1, 30)], WHISK)
    s.outline()
    return s.im

def catfish_back():
    s = Sprite(32, 32)
    s.ellipse((0, 10, 9, 22), FIN)                        # 尾鰭（左邊）
    s.ellipse((3, 12, 28, 30), CF)
    s.shade(CF, (0, 23, 32, 36), CF_D)
    s.shade(CF, (8, 12, 22, 18), CF_L)
    s.ellipse((12, 7, 20, 15), FIN)                       # 背鰭
    s.line([(27, 18), (31, 21), (31, 27), (29, 31)], WHISK)   # 鬍鬚（從頭的另一邊露出來）
    s.line([(26, 21), (27, 27)], WHISK)
    s.outline()
    return s.im

# ---------------- 囤囤鼠 ----------------
HF=(222,164,96,255); HF_D=(184,124,72,255); HW=(248,236,214,255); PINK=(232,150,150,255)
WOOD=(150,98,60,255); WOOD_D=(108,70,46,255)

def hamster_front():
    s = Sprite(64, 64)
    # 身體：洋梨形，臉頰鼓鼓的
    s.ellipse((12, 30, 52, 62), HF)
    s.shade(HF, (14, 50, 60, 70), HF_D)
    s.ellipse((20, 40, 44, 62), HW)
    # 頭和超大的臉頰
    s.ellipse((14, 10, 50, 40), HF)
    s.ellipse((6, 22, 26, 42), HW)       # 左臉頰（塞滿東西）
    s.ellipse((38, 22, 58, 42), HW)      # 右臉頰
    s.shade(HW, (4, 34, 60, 48), (232, 214, 186, 255))
    # 耳朵
    s.ellipse((14, 6, 24, 16), HF); s.ellipse((16, 8, 22, 14), PINK)
    s.ellipse((40, 6, 50, 16), HF); s.ellipse((42, 8, 48, 14), PINK)
    # 眼睛、鼻子、門牙
    s.rect((21, 20, 24, 24), EYE); s.px(22, 21, WHITE)
    s.rect((39, 20, 42, 24), EYE); s.px(40, 21, WHITE)
    s.rect((30, 26, 33, 28), PINK)
    s.rect((30, 31, 33, 34), WHITE)
    # 抱著一根小樹枝（愛啃木頭）
    s.line([(14, 48), (50, 42)], WOOD, 3)
    s.line([(15, 50), (49, 44)], WOOD_D, 1)
    s.line([(40, 43), (44, 37)], WOOD, 2)
    s.ellipse((44, 34, 49, 38), (120, 190, 90, 255))
    # 小手抓著樹枝
    s.ellipse((20, 44, 27, 51), HF_D); s.ellipse((36, 42, 43, 49), HF_D)
    s.outline()
    return s.im

def hamster_back():
    s = Sprite(32, 32)
    s.ellipse((4, 10, 28, 31), HF)
    s.shade(HF, (0, 24, 32, 40), HF_D)
    s.ellipse((2, 13, 11, 23), HW); s.ellipse((21, 13, 30, 23), HW)    # 臉頰從頭後面鼓出來
    s.ellipse((7, 3, 25, 20), HF)
    s.ellipse((7, 2, 13, 8), HF); s.ellipse((19, 2, 25, 8), HF)       # 耳朵
    s.ellipse((14, 26, 18, 30), HW)                                    # 小尾巴
    s.outline()
    return s.im

# ---------------- 哨哨雀 ----------------
BF=(196,92,72,255); BF_D=(150,62,56,255); BB=(244,214,170,255); BEAK=(244,180,60,255)
WH=(250,206,70,255); WH_D=(206,150,40,255); WING=(132,56,52,255)

def bird_front():
    s = Sprite(64, 64)
    # 尾羽
    s.poly([(44, 40), (60, 44), (58, 52), (44, 48)], WING)
    # 圓滾滾的身體
    for x in (24, 34): s.rect((x, 54, x+2, 60), BEAK); s.rect((x-2, 59, x+4, 61), BEAK)
    s.ellipse((14, 22, 50, 58), BF)
    s.shade(BF, (14, 46, 60, 70), BF_D)
    s.ellipse((18, 34, 38, 56), BB)
    # 翅膀
    s.ellipse((34, 32, 52, 50), WING)
    s.line([(38, 40), (48, 44)], BF_D)
    # 頭頂：哨子形的羽毛（一根管子 + 吹口）
    s.poly([(24, 24), (22, 18), (28, 20)], BF_D)        # 羽毛的根部
    s.rect((25, 10, 30, 22), WH)
    s.rect((28, 10, 30, 22), WH_D)
    s.ellipse((23, 6, 32, 13), WH)
    s.rect((26, 8, 29, 10), WH_D)         # 吹口的洞
    s.rect((25, 15, 27, 17), WH_D)        # 哨子側面的孔
    # 嘴喙、眼睛
    s.poly([(14, 34), (5, 37), (14, 40)], BEAK)
    s.rect((20, 30, 23, 34), EYE); s.px(21, 31, WHITE)
    s.outline()
    return s.im

def bird_back():
    s = Sprite(32, 32)
    s.poly([(4, 22), (0, 30), (8, 27)], WING)             # 尾羽
    s.ellipse((4, 9, 28, 30), BF)
    s.shade(BF, (0, 24, 32, 40), BF_D)
    s.ellipse((4, 15, 14, 27), WING); s.ellipse((19, 15, 29, 27), WING)   # 兩邊翅膀
    s.rect((15, 3, 18, 11), WH); s.rect((17, 3, 18, 11), WH_D)          # 哨子羽毛
    s.ellipse((13, 1, 19, 5), WH)
    s.outline()
    return s.im

if __name__ == "__main__":
    preview([catfish_front(), catfish_back(), hamster_front(), hamster_back(), bird_front(), bird_back()], "../../build/kin_others.png", 4)
