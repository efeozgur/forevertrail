"""Yolculuk kartı simgelerini (Media/route_*.tga) üretir: 64x64, beyaz üzerine saydam; oyunda renklendirilir.
Kullanım (depo kökünden):  python tools/make_route_icons.py   (Pillow gerekir)"""
import math
import os
from PIL import Image, ImageDraw

S = 512  # çizim boyutu; 64'e küçültülürken kenarlar yumuşar
OUT = 64
HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.join(HERE, '..', 'Media')
W = (255, 255, 255, 255)


def canvas():
    im = Image.new('RGBA', (S, S), (255, 255, 255, 0))
    return im, ImageDraw.Draw(im)


def mirror(points):
    return [(S - x, y) for x, y in points]


def flight():  # uçak: gövde, süpürme kanatlar, kuyruk
    im, d = canvas()
    d.polygon([(256, 30), (284, 190), (284, 420), (256, 482), (228, 420), (228, 190)], fill=W)
    wing = [(228, 215), (40, 345), (40, 392), (228, 330)]
    d.polygon(wing, fill=W); d.polygon(mirror(wing), fill=W)
    tail = [(228, 410), (140, 470), (140, 500), (228, 462)]
    d.polygon(tail, fill=W); d.polygon(mirror(tail), fill=W)
    return im


def zeppelin():  # hava gemisi: gövde, kuyruk yüzgeçleri, sepet
    im, d = canvas()
    d.ellipse([70, 100, 470, 300], fill=W)
    d.polygon([(95, 160), (30, 80), (30, 150), (95, 205)], fill=W)
    d.polygon([(95, 240), (30, 320), (30, 250), (95, 195)], fill=W)
    d.rectangle([195, 312, 335, 372], fill=W)
    d.line([(225, 296), (225, 316)], fill=W, width=14); d.line([(305, 296), (305, 316)], fill=W, width=14)
    d.ellipse([440, 190, 500, 250], fill=W)
    return im


def ship():  # gemi: gövde, direk, iki yelken
    im, d = canvas()
    d.polygon([(55, 340), (457, 340), (395, 440), (117, 440)], fill=W)
    d.rectangle([249, 70, 263, 345], fill=W)
    d.polygon([(275, 90), (275, 315), (415, 315)], fill=W)
    d.polygon([(237, 130), (237, 315), (105, 315)], fill=W)
    d.polygon([(263, 70), (263, 100), (320, 85)], fill=W)
    return im


def walk():  # iki ayak izi
    im, d = canvas()

    def foot(cx, cy, tilt):
        pts = []
        for a in range(0, 360, 6):
            r = math.radians(a)
            pts.append((cx + 52 * math.cos(r), cy + 88 * math.sin(r)))
        pts = [(cx + (x - cx) * math.cos(tilt) - (y - cy) * math.sin(tilt), cy + (x - cx) * math.sin(tilt) + (y - cy) * math.cos(tilt)) for x, y in pts]
        d.polygon(pts, fill=W)
        for i, (dx, dy, rr) in enumerate([(-38, -118, 21), (-12, -132, 19), (16, -132, 17), (42, -118, 15)]):
            x = cx + dx * math.cos(tilt) - dy * math.sin(tilt)
            y = cy + dx * math.sin(tilt) + dy * math.cos(tilt)
            d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=W)
    foot(180, 330, -0.12)
    foot(335, 200, 0.12)
    return im


def door():  # kapı + ok: giriş / çıkış
    im, d = canvas()
    d.rectangle([90, 50, 330, 462], fill=W)
    d.rectangle([130, 90, 290, 462], fill=(255, 255, 255, 0))
    d.ellipse([245, 270, 275, 300], fill=W)
    d.rectangle([300, 235, 400, 285], fill=W)
    d.polygon([(390, 190), (390, 330), (480, 260)], fill=W)
    return im


def flag():  # varış bayrağı
    im, d = canvas()
    d.rectangle([110, 60, 134, 460], fill=W)
    d.polygon([(134, 70), (400, 120), (134, 235)], fill=W)
    d.ellipse([84, 440, 160, 480], fill=W)
    return im


def step():  # genel adım: şerit ok
    im, d = canvas()
    d.polygon([(110, 120), (250, 120), (400, 256), (250, 392), (110, 392), (260, 256)], fill=W)
    return im


def main():
    icons = {'flight': flight, 'zeppelin': zeppelin, 'ship': ship, 'walk': walk, 'door': door, 'flag': flag, 'step': step}
    for name, fn in icons.items():
        im = fn().resize((OUT, OUT), Image.LANCZOS)
        im.save(os.path.join(MEDIA, 'route_%s.tga' % name))
        print('route_%s.tga' % name)


if __name__ == '__main__':
    main()
