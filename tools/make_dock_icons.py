"""Ikon seridi simgelerini (Media/dock_*.tga) uretir: 64x64, beyaz uzerine saydam; oyunda tema rengine boyanir.
Kullanim (depo kokunden):  python tools/make_dock_icons.py   (Pillow gerekir)"""
import math
import os
from PIL import Image, ImageDraw

S = 512  # cizim boyutu; 64'e kucultulurken kenarlar yumusar
OUT = 64
HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.join(HERE, '..', 'Media')
W = (255, 255, 255, 255)
CLEAR = (255, 255, 255, 0)
T = 38  # cizgi kalinligi


def canvas():
    im = Image.new('RGBA', (S, S), CLEAR)
    return im, ImageDraw.Draw(im)


def panel():  # gorev listesi: yuvarlak cerceve, uc satir
    im, d = canvas()
    d.rounded_rectangle([88, 60, 424, 452], radius=44, outline=W, width=T)
    for y, x2 in ((165, 360), (255, 360), (345, 280)):
        d.rounded_rectangle([150, y - 16, x2, y + 16], radius=16, fill=W)
    return im


def map_():  # katlanmis harita: uc dilim
    im, d = canvas()
    pts = [(60, 120), (190, 80), (322, 130), (452, 90), (452, 392), (322, 432), (190, 382), (60, 422)]
    d.polygon(pts, outline=W, fill=None)
    d.line(pts + [pts[0]], fill=W, width=T, joint='curve')
    d.line([(190, 80), (190, 382)], fill=W, width=T - 8)
    d.line([(322, 130), (322, 432)], fill=W, width=T - 8)
    return im


def nearest():  # hedef: halka, nokta, dort centik
    im, d = canvas()
    d.ellipse([110, 110, 402, 402], outline=W, width=T)
    d.ellipse([216, 216, 296, 296], fill=W)
    for a in range(4):
        r = math.radians(a * 90)
        x1, y1 = 256 + 190 * math.cos(r), 256 + 190 * math.sin(r)
        x2, y2 = 256 + 250 * math.cos(r), 256 + 250 * math.sin(r)
        d.line([(x1, y1), (x2, y2)], fill=W, width=T - 6)
    return im


def places():  # konum igne
    im, d = canvas()
    cx, cy, r = 256, 200, 140
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=W)
    d.polygon([(cx - 128, cy + 80), (cx + 128, cy + 80), (cx, 482)], fill=W)
    d.ellipse([cx - 58, cy - 58, cx + 58, cy + 58], fill=CLEAR)
    return im


def silent():  # zil + capraz cizgi
    im, d = canvas()
    d.pieslice([120, 70, 392, 342], 180, 360, fill=W)
    d.polygon([(120, 206), (392, 206), (430, 380), (82, 380)], fill=W)
    d.ellipse([216, 392, 296, 462], fill=W)
    d.line([(70, 450), (442, 62)], fill=CLEAR, width=T + 26)
    d.line([(70, 450), (442, 62)], fill=W, width=T - 6)
    return im


def klass():  # besgen yildiz
    im, d = canvas()
    cx, cy = 256, 272
    pts = []
    for i in range(10):
        r = 220 if i % 2 == 0 else 96
        a = math.radians(-90 + i * 36)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    d.polygon(pts, fill=W)
    return im


def bag():  # sirt cantasi
    im, d = canvas()
    d.rounded_rectangle([110, 120, 402, 452], radius=70, outline=W, width=T)
    d.arc([186, 40, 326, 190], 180, 360, fill=W, width=T - 6)
    d.rounded_rectangle([170, 300, 342, 372], radius=22, outline=W, width=T - 12)
    return im


def settings():  # uc kaydirici
    im, d = canvas()
    for y, kx in ((120, 170), (256, 340), (392, 220)):
        d.rounded_rectangle([60, y - 14, 452, y + 14], radius=14, fill=W)
        d.ellipse([kx - 44, y - 44, kx + 44, y + 44], fill=W)
        d.ellipse([kx - 18, y - 18, kx + 18, y + 18], fill=CLEAR)
    return im


def tools():  # 2x2 kare izgara
    im, d = canvas()
    for x, y in ((70, 70), (282, 70), (70, 282), (282, 282)):
        d.rounded_rectangle([x, y, x + 160, y + 160], radius=34, fill=W)
    return im


def lock():  # asma kilit
    im, d = canvas()
    d.arc([146, 40, 366, 270], 180, 360, fill=W, width=T)
    d.line([(166, 155), (166, 230)], fill=W, width=T)
    d.line([(346, 155), (346, 230)], fill=W, width=T)
    d.rounded_rectangle([96, 220, 416, 462], radius=50, fill=W)
    d.ellipse([226, 300, 286, 360], fill=CLEAR)
    d.rectangle([248, 340, 264, 405], fill=CLEAR)
    return im


def rotate():  # yonu cevir: dairesel ok (yatay <-> dikey)
    im, d = canvas()
    box = [96, 96, 416, 416]
    d.arc(box, 40, 320, fill=W, width=T)
    # ok ucu: yayin 320 derecedeki ucunda, cizgiye dik
    a = math.radians(320)
    cx, cy, r = 256, 256, 160
    px, py = cx + r * math.cos(a), cy + r * math.sin(a)
    tx, ty = -math.sin(a), math.cos(a)  # teget (artan aci yonu)
    nx, ny = math.cos(a), math.sin(a)   # dis normal
    tip = (px + tx * 78, py + ty * 78)
    b1 = (px + nx * 70, py + ny * 70)
    b2 = (px - nx * 70, py - ny * 70)
    d.polygon([tip, b1, b2], fill=W)
    return im


def main():
    icons = {'panel': panel, 'map': map_, 'nearest': nearest, 'places': places, 'silent': silent,
             'class': klass, 'bag': bag, 'settings': settings, 'tools': tools, 'lock': lock, 'rotate': rotate}
    for name, fn in icons.items():
        im = fn().resize((OUT, OUT), Image.LANCZOS)
        im.save(os.path.join(MEDIA, 'dock_%s.tga' % name))
        print('dock_%s.tga' % name)


if __name__ == '__main__':
    main()
