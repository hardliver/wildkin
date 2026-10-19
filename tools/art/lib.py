from PIL import Image, ImageDraw
OUT = (40, 30, 44, 255)       # 外框：深紫褐（接近 Kenney 的外框色）

class Sprite:
    def __init__(s, w, h):
        s.w, s.h = w, h
        s.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        s.d = ImageDraw.Draw(s.im)
    def ellipse(s, box, c):
        s.d.ellipse(box, fill=c)
    def rect(s, box, c):
        s.d.rectangle(box, fill=c)
    def poly(s, pts, c):
        s.d.polygon(pts, fill=c)
    def px(s, x, y, c):
        if 0 <= x < s.w and 0 <= y < s.h: s.im.putpixel((x, y), c)
    def line(s, pts, c, w=1):
        s.d.line(pts, fill=c, width=w)
    def shade(s, region_color, box, c):
        """在已經畫好的 region_color 區域內，畫一個橢圓的陰影／亮面（只改那個顏色的像素）"""
        tmp = Image.new("L", (s.w, s.h), 0)
        ImageDraw.Draw(tmp).ellipse(box, fill=255)
        for y in range(s.h):
            for x in range(s.w):
                if tmp.getpixel((x, y)) and s.im.getpixel((x, y)) == region_color:
                    s.im.putpixel((x, y), c)
    def outline(s, c=OUT):
        src = s.im.copy()
        for y in range(s.h):
            for x in range(s.w):
                if src.getpixel((x, y))[3] == 0:
                    for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                        xx, yy = x+dx, y+dy
                        if 0 <= xx < s.w and 0 <= yy < s.h and src.getpixel((xx, yy))[3] and src.getpixel((xx,yy)) != c:
                            s.im.putpixel((x, y), c); break
    def inner_line(s, a, b, c):
        """兩種顏色相鄰的地方畫線（例如肚子和身體的分界）"""
        src = s.im.copy()
        for y in range(s.h):
            for x in range(s.w):
                if src.getpixel((x, y)) == a:
                    for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                        xx, yy = x+dx, y+dy
                        if 0 <= xx < s.w and 0 <= yy < s.h and src.getpixel((xx, yy)) == b:
                            s.im.putpixel((x, y), c); break
    def flip(s):
        s.im = s.im.transpose(Image.FLIP_LEFT_RIGHT); s.d = ImageDraw.Draw(s.im)

def preview(images, path, scale=4, bg=(120, 180, 120, 255)):
    w = sum(i.width for i in images) + 8 * (len(images) + 1)
    h = max(i.height for i in images) + 16
    out = Image.new("RGBA", (w, h), bg)
    x = 8
    for i in images:
        out.paste(i, (x, 8), i); x += i.width + 8
    out = out.resize((w * scale, h * scale), Image.NEAREST)
    out.save(path)
