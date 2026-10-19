from sheep import *
def back():
    s = Sprite(32, 32)
    # 從背後看：羊毛屁股在左下，頭在右上（往右上方看著對手），看得到後腦勺和嫩芽
    for x in (6, 17): s.rect((x, 26, x+3, 30), FACE_D); s.rect((x, 29, x+3, 31), HOOF)
    s.ellipse((2, 13, 25, 29), WOOL)
    for cx, cy in ((5,17),(10,13),(17,13),(23,18),(22,25),(15,28),(7,27),(3,23)):
        s.ellipse((cx-4, cy-4, cx+4, cy+4), WOOL)
    s.shade(WOOL, (-4, 23, 30, 40), WOOL_D)
    s.ellipse((6, 18, 11, 23), WOOL_L)                   # 小尾巴
    # 頭（後腦勺）
    s.ellipse((14, 8, 29, 22), FACE)
    s.shade(FACE, (12, 15, 25, 28), FACE_D)
    s.poly([(26, 10), (31, 9), (30, 14), (27, 13)], FACE_D)   # 右耳
    for cx in (18, 23): s.ellipse((cx-2, 7, cx+2, 10), WOOL)  # 頭頂羊毛
    # 嫩芽
    s.line([(18, 8), (16, 4)], LEAF_D, 1); s.line([(23, 8), (25, 4)], LEAF_D, 1)
    s.poly([(16, 5), (10, 2), (11, 6)], LEAF); s.poly([(16, 5), (18, 1), (19, 4)], LEAF)
    s.poly([(25, 5), (31, 2), (30, 6)], LEAF); s.poly([(25, 5), (22, 1), (21, 3)], LEAF)
    s.outline()
    return s.im
if __name__ == "__main__":
    preview([front(), back()], "../../build/kin_sheep2.png", 5)
