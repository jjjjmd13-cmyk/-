"""게임 패스 아이콘 5개(512x512)를 만듭니다.  사용법: python3 tools/make_gamepass_icons.py assets/gamepasses"""
import math, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
OUT = sys.argv[1]
S = 1024
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

def bg(c1, c2):
    img = Image.new("RGB", (S, S), c2)
    d = ImageDraw.Draw(img)
    for r in range(int(S*0.75), 0, -4):  # 가운데가 밝은 원형 그라데이션
        t = r / (S*0.75)
        col = tuple(int(c1[i]*(1-t) + c2[i]*t) for i in range(3))
        d.ellipse([S/2-r, S/2-r, S/2+r, S/2+r], fill=col)
    # 은은한 광선
    rays = Image.new("RGBA", (S, S), (0,0,0,0))
    rd = ImageDraw.Draw(rays)
    for k in range(16):
        a = k * math.pi / 8
        p = [(S/2, S/2), (S/2+math.cos(a-0.09)*S, S/2+math.sin(a-0.09)*S), (S/2+math.cos(a+0.09)*S, S/2+math.sin(a+0.09)*S)]
        rd.polygon(p, fill=(255,255,255,22))
    img = Image.alpha_composite(img.convert("RGBA"), rays)
    return img

def shadowed(img, draw_fn, offset=(0, 18), blur=18):
    layer = Image.new("RGBA", (S, S), (0,0,0,0))
    draw_fn(ImageDraw.Draw(layer))
    alpha = layer.split()[3]
    sh = Image.new("RGBA", (S, S), (0,0,0,0))
    sh.putalpha(alpha.point(lambda v: int(v*0.45)))
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    img.alpha_composite(sh, offset)
    img.alpha_composite(layer)

def badge(img, text, fill=(255,255,255), stroke=(40,20,0), y=0.74, size=230):
    f = ImageFont.truetype(FONT, size)
    def fn(d):
        w = d.textlength(text, font=f)
        d.text((S/2 - w/2, S*y - size/2), text, font=f, fill=fill, stroke_width=22, stroke_fill=stroke)
    shadowed(img, fn)

def save(img, name):
    img.convert("RGB").resize((512, 512), Image.LANCZOS).save(f"{OUT}/{name}.png")

# 1) 발굴 속도 2배: 번개
img = bg((255, 200, 70), (230, 80, 20))
def bolt(d):
    pts = [(560,120),(300,560),(490,560),(400,900),(740,420),(540,420),(640,120)]
    d.polygon(pts, fill=(255,240,90), outline=(120,50,0), width=26)
shadowed(img, bolt)
badge(img, "2X", y=0.80, size=200)
save(img, "DoubleSpeed")

# 2) 행운 2배: 네잎클로버
img = bg((170, 255, 150), (20, 140, 60))
def clover(d):
    c = (S/2, S*0.42)
    for k in range(4):
        a = math.pi/4 + k*math.pi/2
        # 하트 모양 잎: 둥근 두 덩이 + 가운데로 모이는 삼각형
        lobes = []
        for off in (-0.38, 0.38):
            x = c[0] + math.cos(a+off)*175; y = c[1] + math.sin(a+off)*175
            lobes.append((x, y))
        tri = [c, (lobes[0][0]+math.cos(a-1.2)*60, lobes[0][1]+math.sin(a-1.2)*60), (lobes[1][0]+math.cos(a+1.2)*60, lobes[1][1]+math.sin(a+1.2)*60)]
        d.polygon(tri, fill=(10,80,30))
        for x, y in lobes:
            d.ellipse([x-92, y-92, x+92, y+92], fill=(10,80,30))
    for k in range(4):
        a = math.pi/4 + k*math.pi/2
        lobes = []
        for off in (-0.38, 0.38):
            x = c[0] + math.cos(a+off)*175; y = c[1] + math.sin(a+off)*175
            lobes.append((x, y))
        tri = [(c[0]+math.cos(a)*12, c[1]+math.sin(a)*12), (lobes[0][0]+math.cos(a-1.2)*44, lobes[0][1]+math.sin(a-1.2)*44), (lobes[1][0]+math.cos(a+1.2)*44, lobes[1][1]+math.sin(a+1.2)*44)]
        d.polygon(tri, fill=(70,200,80))
        for x, y in lobes:
            d.ellipse([x-74, y-74, x+74, y+74], fill=(70,200,80))
        # 잎맥
        d.line([c, (c[0]+math.cos(a)*190, c[1]+math.sin(a)*190)], fill=(40,150,55), width=12)
    d.line([(c[0], c[1]), (c[0]+110, c[1]+330)], fill=(10,80,30), width=50)
    d.line([(c[0], c[1]), (c[0]+110, c[1]+330)], fill=(60,170,70), width=26)
    d.ellipse([c[0]-40, c[1]-40, c[0]+40, c[1]+40], fill=(90,215,95))
shadowed(img, clover)
badge(img, "2X", y=0.80, size=200, stroke=(0,60,20))
save(img, "DoubleLuck")

# 3) 박물관 수입 2배: 박물관 + 동전
img = bg((130, 200, 255), (25, 70, 170))
def museum(d):
    d.polygon([(S/2,170),(220,380),(804,380)], fill=(245,240,230), outline=(60,50,40), width=20)
    d.rectangle([230,380,794,430], fill=(230,220,200), outline=(60,50,40), width=16)
    for x in (280, 420, 560, 700):
        d.rectangle([x-35,440,x+35,640], fill=(245,240,230), outline=(60,50,40), width=14)
    d.rectangle([200,640,824,700], fill=(230,220,200), outline=(60,50,40), width=16)
shadowed(img, museum)
def coins(d):
    for (x,y) in ((300,650),(724,650)):
        for dy in (60, 30, 0):
            d.ellipse([x-90,y-30+dy,x+90,y+30+dy], fill=(255,200,40), outline=(120,70,0), width=12)
shadowed(img, coins)
badge(img, "2X", y=0.85, size=170, stroke=(10,30,90))
save(img, "DoubleIncome")

# 4) 자동 발굴: 톱니바퀴 + 삽
img = bg((210, 150, 255), (80, 30, 160))
def gear(d):
    c = (S*0.42, S*0.42); R = 230
    teeth = []
    for k in range(24):
        a = k * math.pi / 12
        r = R if k % 2 == 0 else R - 60
        teeth.append((c[0]+math.cos(a)*r, c[1]+math.sin(a)*r))
    d.polygon(teeth, fill=(200,205,220), outline=(50,40,80), width=18)
    d.ellipse([c[0]-80,c[1]-80,c[0]+80,c[1]+80], fill=(110,60,190), outline=(50,40,80), width=16)
shadowed(img, gear)
def shovel(d):
    d.line([(380,860),(760,420)], fill=(60,35,15), width=70)
    d.line([(380,860),(760,420)], fill=(170,115,60), width=44)
    # 삽날
    cx, cy = 800, 360
    blade = [(cx-120,cy+40),(cx-30,cy-150),(cx+110,cy-110),(cx+90,cy+60)]
    d.polygon(blade, fill=(220,225,235), outline=(50,50,70), width=18)
    d.rectangle([340,830,420,900], fill=(170,115,60), outline=(60,35,15), width=14)
shadowed(img, shovel)
badge(img, "AUTO", y=0.82, size=150, stroke=(40,10,80))
save(img, "AutoDig")

# 5) 조수 칸 +2: 귀여운 조수 두 마리
img = bg((190, 255, 170), (40, 150, 90))
def buddy(d, x, y, s, color, flip=1):
    dark = tuple(max(0, c-90) for c in color)
    light = tuple(min(255, c+25) for c in color)
    # 꼬리
    d.polygon([(x-90*s*flip, y+60*s), (x-260*s*flip, y+150*s), (x-60*s*flip, y+140*s)], fill=color, outline=dark, width=int(14*s)+2)
    # 몸통
    d.ellipse([x-150*s, y-110*s, x+150*s, y+170*s], fill=color, outline=dark, width=int(16*s)+2)
    # 배
    d.ellipse([x-80*s, y-20*s, x+80*s, y+150*s], fill=(255,240,200))
    # 머리 위 가시 3개
    for k, sx in enumerate((-55, 0, 55)):
        h = 70 if k == 1 else 52
        d.polygon([(x+sx*s-26*s, y-268*s), (x+sx*s, y-268*s-h*s), (x+sx*s+26*s, y-268*s)], fill=dark)
    # 머리
    d.ellipse([x-115*s, y-300*s, x+115*s, y-80*s], fill=light, outline=dark, width=int(14*s)+2)
    for ex in (-45, 45):
        d.ellipse([x+ex*s-24*s, y-220*s, x+ex*s+24*s, y-172*s], fill=(20,20,20))
        d.ellipse([x+ex*s-8*s, y-214*s, x+ex*s+6*s, y-200*s], fill=(255,255,255))
    d.arc([x-40*s, y-190*s, x+40*s, y-128*s], 20, 160, fill=dark, width=int(10*s)+2)
    # 볼터치
    for ex in (-80, 80):
        d.ellipse([x+ex*s-20*s, y-160*s, x+ex*s+20*s, y-140*s], fill=(255,150,150))
def buddies(d):
    buddy(d, 330, 570, 0.95, (120,200,90), 1)
    buddy(d, 694, 570, 0.95, (255,190,60), -1)
shadowed(img, buddies)
badge(img, "+2", y=0.82, size=210, stroke=(0,60,20))
save(img, "ExtraHelpers")
print("ok")
