#!/usr/bin/env python3
# Dibuja objetos/radio_pro.png: torre de sonido profesional en isometrico
# (mismo angulo y tecnica que dibujar_radio.py): caja alta, subwoofer con
# anillo de LEDs, woofer medio, tweeter de bocina y logo PRO.
#
#   python3 herramientas_dev/dibujar_parlante_pro.py
import math, struct, zlib, os

W, H = 64, 96
ESCALA = 4
SALIDA = os.path.join(os.path.dirname(__file__), "..", "objetos", "radio_pro.png")

K = (14, 12, 18, 255)
FRENTE = (34, 34, 42, 255)
FRENTE_L = (48, 48, 58, 255)
COSTADO = (24, 24, 30, 255)
TAPA = (62, 62, 74, 255)
CONO = (20, 20, 26, 255)
CONO_L = (96, 98, 112, 255)
CENTRO = (150, 152, 168, 255)
LED = (70, 220, 255, 255)
LED2 = (255, 80, 200, 255)
ORO = (245, 195, 70, 255)
METAL = (175, 178, 190, 255)
SOMBRA = (0, 0, 0, 80)

L, P, A = 26, 20, 58
EJE_L = (1.0, -0.5)
EJE_P = (-1.0, -0.5)
O = (24.0, 86.0)

def mas(a, b, k=1.0):
    return (a[0] + b[0] * k, a[1] + b[1] * k)

U_FRENTE = (EJE_L[0] * L, EJE_L[1] * L)
U_COSTADO = (EJE_P[0] * P, EJE_P[1] * P)
ARRIBA = (0.0, -A)

def coords(p, origen, u, v):
    dx, dy = p[0] - origen[0], p[1] - origen[1]
    det = u[0] * v[1] - u[1] * v[0]
    return (dx * v[1] - dy * v[0]) / det, (u[0] * dy - u[1] * dx) / det

def borde(a, b, la, lb, g=0.9):
    return a * la < g or (1 - a) * la < g or b * lb < g or (1 - b) * lb < g

def parlante(x, y, cx, cy, r, anillo=None):
    d = math.hypot(x - cx, y - cy)
    if anillo and r + 0.2 < d < r + 1.6:
        return anillo
    if d < r * 0.18: return CENTRO
    if d < r * 0.35: return CONO_L
    if d < r * 0.85: return CONO
    if d < r * 0.95: return CONO_L
    if d < r + 0.2: return K
    return None

def frente(a, b):
    largo = math.hypot(*U_FRENTE)
    x, y = a * largo, b * A
    if borde(a, b, largo, A):
        return K
    cx = largo / 2
    for cy, r, anillo in ((A * 0.24, 10.0, LED), (A * 0.58, 6.5, LED2)):
        c = parlante(x, y, cx, cy, r, anillo)
        if c:
            return c
    # Tweeter de bocina (trapecio) arriba.
    if A * 0.74 < y < A * 0.86:
        mitad = 3 + (y - A * 0.74) * 0.6
        if abs(x - cx) < mitad:
            return K if abs(abs(x - cx) - mitad) < 1 or abs(y - A * 0.74) < 1 or abs(y - A * 0.86) < 1 else CONO
    # Logo PRO en dorado y franja de luz abajo.
    if A * 0.90 < y < A * 0.95 and cx - 4 < x < cx + 4:
        return ORO
    if A * 0.04 < y < A * 0.07 and 2 < x < largo - 2:
        return LED if int(x) % 4 < 2 else LED2
    return FRENTE_L if y > A * 0.96 else FRENTE

def costado(a, b):
    ancho = math.hypot(*U_COSTADO)
    x, y = a * ancho, b * A
    if borde(a, b, ancho, A):
        return K
    if 3 < x < ancho - 3 and (A * 0.55 < y < A * 0.62):
        return METAL if abs(y - A * 0.585) < 1 else K
    return COSTADO

def tapa(a, b):
    largo, ancho = math.hypot(*U_FRENTE), math.hypot(*U_COSTADO)
    if borde(a, b, largo, ancho, 0.8):
        return K
    return TAPA

CARAS = [
    (O, U_COSTADO, ARRIBA, costado),
    (O, U_FRENTE, ARRIBA, frente),
    (mas(O, ARRIBA), U_FRENTE, U_COSTADO, tapa),
]

px = [[(0, 0, 0, 0)] * W for _ in range(H)]
for y in range(H):
    for x in range(W):
        a, b = coords((x + 0.5, y + 0.5), mas(O, (0, 2)), U_FRENTE, U_COSTADO)
        if -0.05 < a < 1.1 and -0.1 < b < 1.15:
            px[y][x] = SOMBRA
for origen, u, v, dibujo in CARAS:
    for y in range(H):
        for x in range(W):
            a, b = coords((x + 0.5, y + 0.5), origen, u, v)
            if 0 <= a <= 1 and 0 <= b <= 1:
                px[y][x] = dibujo(a, b)

raw = b""
for y in range(H * ESCALA):
    raw += b"\x00" + b"".join(bytes(px[y // ESCALA][x // ESCALA]) for x in range(W * ESCALA))

def chunk(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

with open(SALIDA, "wb") as f:
    f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W * ESCALA, H * ESCALA, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
print("ok", SALIDA)
