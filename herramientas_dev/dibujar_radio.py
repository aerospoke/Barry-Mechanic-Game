#!/usr/bin/env python3
# Dibuja objetos/radio.png: el equipo de sonido en isometrico (mismo angulo
# que los estantes). Se rasteriza como una caja 3D: cada pixel se pasa a
# coordenadas de su cara (frente, costado, tapa) y se pinta segun un
# "dibujo" de esa cara, asi los parlantes salen como elipses en perspectiva.
#
#   python3 herramientas_dev/dibujar_radio.py
import math, struct, zlib, os

W, H = 72, 64
ESCALA = 4
SALIDA = os.path.join(os.path.dirname(__file__), "..", "objetos", "radio.png")

K = (18, 16, 22, 255)
FRENTE = (52, 54, 66, 255)
FRENTE_L = (70, 73, 88, 255)
COSTADO = (36, 38, 48, 255)
TAPA = (82, 86, 102, 255)
CONO = (26, 26, 32, 255)
CONO_L = (110, 112, 128, 255)
CENTRO = (160, 162, 178, 255)
DECK = (24, 24, 30, 255)
CINTA = (220, 90, 60, 255)
LED_V = (80, 230, 120, 255)
LED_R = (240, 80, 80, 255)
ORO = (240, 190, 70, 255)
METAL = (170, 172, 185, 255)
SOMBRA = (0, 0, 0, 70)

# Caja: largo L hacia arriba-derecha, fondo P hacia arriba-izquierda, alto A.
L, P, A = 44, 15, 26
EJE_L = (1.0, -0.5)
EJE_P = (-1.0, -0.5)
O = (22.0, 56.0)  # esquina de abajo mas cercana

def mas(a, b, k=1.0):
    return (a[0] + b[0] * k, a[1] + b[1] * k)

U_FRENTE = (EJE_L[0] * L, EJE_L[1] * L)
U_COSTADO = (EJE_P[0] * P, EJE_P[1] * P)
ARRIBA = (0.0, -A)

def coords(p, origen, u, v):
    """Resuelve p = origen + a*u + b*v."""
    dx, dy = p[0] - origen[0], p[1] - origen[1]
    det = u[0] * v[1] - u[1] * v[0]
    return (dx * v[1] - dy * v[0]) / det, (u[0] * dy - u[1] * dx) / det

def borde(a, b, la, lb, grosor=0.9):
    return a * la < grosor or (1 - a) * la < grosor or b * lb < grosor or (1 - b) * lb < grosor

def frente(a, b):
    largo = math.hypot(*U_FRENTE)
    x, y = a * largo, b * A
    if borde(a, b, largo, A):
        return K
    for cx in (largo * 0.22, largo * 0.78):
        d = math.hypot(x - cx, y - A * 0.45)
        if d < 1.6: return CENTRO
        if d < 3.2: return CONO_L
        if d < 7.0: return CONO
        if d < 8.0: return CONO_L
        if d < 9.0: return K
    # Casetera al medio.
    if largo * 0.40 < x < largo * 0.60 and A * 0.18 < y < A * 0.72:
        if abs(x - largo * 0.40) < 1 or abs(x - largo * 0.60) < 1 or abs(y - A * 0.18) < 1 or abs(y - A * 0.72) < 1:
            return K
        if A * 0.42 < y < A * 0.58:
            return CINTA if A * 0.47 < y < A * 0.52 else (60, 60, 72, 255)
        # Ecualizador de luces abajo.
        if y < A * 0.34:
            col = int((x - largo * 0.40) / 2)
            alto = [3, 5, 4, 6, 3][col % 5]
            if (y - A * 0.18) < alto * 0.6:
                return LED_R if col % 5 == 3 else (ORO if col % 5 == 2 else LED_V)
        return DECK
    # Botones arriba del deck y logo.
    if A * 0.80 < y < A * 0.88 and largo * 0.40 < x < largo * 0.60 and int(x) % 3 == 0:
        return ORO if x < largo * 0.46 else METAL
    if A * 0.82 < y < A * 0.88 and 2.5 < x < 7:
        return ORO
    return FRENTE_L if y > A * 0.9 else FRENTE

def costado(a, b):
    ancho = math.hypot(*U_COSTADO)
    x, y = a * ancho, b * A
    if borde(a, b, ancho, A):
        return K
    # Rejilla de ventilacion.
    if 3 < x < ancho - 3 and A * 0.3 < y < A * 0.7 and int(y) % 3 == 0:
        return K
    return COSTADO

def tapa(a, b):
    largo, ancho = math.hypot(*U_FRENTE), math.hypot(*U_COSTADO)
    if borde(a, b, largo, ancho, 0.8):
        return K
    # Base de la manija.
    if 0.2 < a < 0.8 and 0.4 < b < 0.6 and (a < 0.25 or a > 0.75):
        return K
    return TAPA

CARAS = [
    (O, U_COSTADO, ARRIBA, costado),
    (O, U_FRENTE, ARRIBA, frente),
    (mas(O, ARRIBA), U_FRENTE, U_COSTADO, tapa),
]

px = [[(0, 0, 0, 0)] * W for _ in range(H)]

def punto(x, y, c):
    if 0 <= x < W and 0 <= y < H:
        px[y][x] = c

# Sombra en el piso.
for y in range(H):
    for x in range(W):
        a, b = coords((x + 0.5, y + 0.5), mas(O, (0, 2)), U_FRENTE, U_COSTADO)
        if -0.04 < a < 1.06 and -0.1 < b < 1.15:
            px[y][x] = SOMBRA

for origen, u, v, dibujo in CARAS:
    for y in range(H):
        for x in range(W):
            a, b = coords((x + 0.5, y + 0.5), origen, u, v)
            if 0 <= a <= 1 and 0 <= b <= 1:
                px[y][x] = dibujo(a, b)

def linea(p0, p1, c, grosor=1):
    pasos = int(max(abs(p1[0] - p0[0]), abs(p1[1] - p0[1])) * 2) + 1
    for k in range(pasos + 1):
        t = k / pasos
        x, y = p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t
        for gx in range(grosor):
            punto(int(x) + gx, int(y), c)

# Manija: dos postes sobre la tapa y la barra arriba.
tope = mas(O, ARRIBA)
centro_fondo = mas(tope, U_COSTADO, 0.5)
p_izq = mas(centro_fondo, U_FRENTE, 0.22)
p_der = mas(centro_fondo, U_FRENTE, 0.78)
alto_manija = (0, -6)
linea(p_izq, mas(p_izq, alto_manija), K, 2)
linea(p_der, mas(p_der, alto_manija), K, 2)
linea(mas(p_izq, alto_manija), mas(p_der, alto_manija), K, 2)
linea(mas(mas(p_izq, alto_manija), (1, 1)), mas(mas(p_der, alto_manija), (0, 1)), (60, 62, 76, 255))

# Antena desde la esquina de atras a la derecha.
base_antena = mas(mas(tope, U_FRENTE, 0.95), U_COSTADO, 0.8)
linea(base_antena, mas(base_antena, (-8, -16)), METAL)

raw = b""
for y in range(H * ESCALA):
    raw += b"\x00" + b"".join(bytes(px[y // ESCALA][x // ESCALA]) for x in range(W * ESCALA))

def chunk(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

with open(SALIDA, "wb") as f:
    f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W * ESCALA, H * ESCALA, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
print("ok", SALIDA)
