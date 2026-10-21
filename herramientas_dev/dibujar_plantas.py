#!/usr/bin/env python3
# Dibuja las 10 plantas en maceta de objetos/plantas/ en pixel art, con el
# mismo estilo que los muebles: perspectiva isometrica (bocas de maceta como
# elipses 2:1), luz desde arriba a la izquierda y contorno oscuro.
#
#   python3 herramientas_dev/dibujar_plantas.py
import math, random, struct, zlib, os

W, H = 48, 64
ESCALA = 4
CARPETA = os.path.join(os.path.dirname(__file__), "..", "objetos", "plantas")
CONTORNO = (24, 20, 26, 255)
SOMBRA = (0, 0, 0, 70)

def tono(c, k):
    """Aclara (k>0) u oscurece (k<0) un color."""
    if k >= 0:
        return tuple(int(v + (255 - v) * k) for v in c[:3]) + (255,)
    return tuple(int(v * (1 + k)) for v in c[:3]) + (255,)

class Lienzo:
    def __init__(self):
        self.px = [[(0, 0, 0, 0)] * W for _ in range(H)]

    def punto(self, x, y, c):
        if len(c) == 3:
            c = tuple(c) + (255,)
        x, y = int(round(x)), int(round(y))
        if 0 <= x < W and 0 <= y < H:
            self.px[y][x] = c

    def elipse(self, cx, cy, rx, ry, c, sombreado=0.0):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx, dy = (x + 0.5 - cx) / max(rx, 0.01), (y + 0.5 - cy) / max(ry, 0.01)
                if dx * dx + dy * dy <= 1:
                    # Luz de arriba a la izquierda.
                    self.punto(x, y, tono(c, -sombreado * (dx * 0.6 + dy * 0.4)) if sombreado else c)

    def linea(self, p0, p1, c, grosor=1):
        pasos = int(max(abs(p1[0] - p0[0]), abs(p1[1] - p0[1])) * 2) + 1
        for k in range(pasos + 1):
            t = k / pasos
            x, y = p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t
            for gx in range(grosor):
                for gy in range(grosor):
                    self.punto(x + gx - grosor // 2, y + gy - grosor // 2, c)

    def hoja(self, base, angulo, largo, ancho, color, nervio=True, cortes=0):
        """Hoja con forma de gota, sombreada a lo largo y con nervio central.
        `cortes` le hace las aberturas de la monstera."""
        ux, uy = math.cos(angulo), math.sin(angulo)
        vx, vy = -uy, ux
        for i in range(int(largo * 2.2)):
            t = i / (largo * 2.2)
            a = ancho * math.sin(math.pi * t) ** 0.8
            for j in range(-int(a * 2) - 1, int(a * 2) + 2):
                s = j / 2.0
                if abs(s) > a:
                    continue
                if cortes and abs(s) > a * 0.35 and int(t * cortes * 2) % 2 == 1:
                    continue
                x = base[0] + ux * largo * t + vx * s
                y = base[1] + uy * largo * t + vy * s
                luz = 0.25 - 0.5 * t if s < 0 else -0.15 - 0.3 * t
                self.punto(x, y, tono(color, luz))
        if nervio:
            self.linea(base, (base[0] + ux * largo * 0.9, base[1] + uy * largo * 0.9), tono(color, -0.35))

    def contorno(self):
        """Borde oscuro de 1 pixel alrededor de todo lo dibujado."""
        nuevo = [fila[:] for fila in self.px]
        for y in range(H):
            for x in range(W):
                if self.px[y][x][3] > 100:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < W and 0 <= yy < H and self.px[yy][xx][3] > 200:
                        nuevo[y][x] = CONTORNO
                        break
        self.px = nuevo

    def guardar(self, nombre):
        raw = b""
        for y in range(H * ESCALA):
            raw += b"\x00" + b"".join(bytes(self.px[y // ESCALA][x // ESCALA]) for x in range(W * ESCALA))
        def chunk(t, d):
            return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
        with open(os.path.join(CARPETA, nombre + ".png"), "wb") as f:
            f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W * ESCALA, H * ESCALA, 8, 6, 0, 0, 0))
                    + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
        print("  ", nombre)

# --- Macetas -----------------------------------------------------------------

def maceta(l, color, arriba=15, abajo=11, alto=16, piso=60, tierra=(70, 48, 34)):
    """Maceta redonda vista desde arriba en isometrico: cuerpo que se angosta,
    borde grueso y la tierra como elipse. Devuelve la altura de la boca."""
    l.elipse(24, piso, abajo + 4, (abajo + 4) / 2, SOMBRA)
    boca = piso - alto
    for y in range(boca, piso + 1):
        t = (y - boca) / alto
        r = arriba + (abajo - arriba) * t
        for x in range(int(24 - r), int(24 + r) + 1):
            dx = (x + 0.5 - 24) / r
            l.punto(x, y, tono(color, 0.18 - 0.45 * (dx + 1) / 2))
    l.elipse(24, piso, abajo, abajo / 2, tono(color, -0.3))
    l.elipse(24, boca, arriba + 1.5, (arriba + 1.5) / 2, tono(color, 0.1))
    l.elipse(24, boca, arriba - 0.5, (arriba - 0.5) / 2, tierra)
    return boca

def maceta_baja(l, color, piso=60):
    """Bandeja rectangular baja (bonsai), como caja isometrica chata."""
    l.elipse(24, piso, 20, 7, SOMBRA)
    for y in range(piso - 6, piso + 1):
        for x in range(5, 44):
            l.punto(x, y, tono(color, 0.15 - 0.4 * (x - 5) / 39))
    for y in range(piso - 12, piso - 5):
        ancho = 19 - abs(y - (piso - 9)) * 2.2
        for x in range(int(24 - ancho), int(24 + ancho) + 1):
            l.punto(x, y, tono(color, 0.15))
    l.elipse(24, piso - 9, 15, 3.5, (70, 48, 34))
    return piso - 9

# --- Plantas -----------------------------------------------------------------

TERRACOTA = (196, 104, 64)
CREMA = (226, 214, 190)
AZUL = (70, 110, 170)
NEGRO = (52, 52, 60)
BLANCO = (214, 216, 222)
AMARILLO = (226, 186, 70)
VERDE = (60, 150, 70)
VERDE_OSC = (38, 112, 60)
VERDE_CLARO = (110, 180, 80)

def monstera():
    l = Lienzo()
    boca = maceta(l, CREMA)
    for ang, largo in ((-2.4, 20), (-0.75, 20), (-1.6, 24), (-2.0, 16), (-1.1, 17)):
        base = (24, boca)
        punta = (24 + math.cos(ang) * largo * 0.55, boca + math.sin(ang) * largo * 0.55)
        l.linea(base, punta, tono(VERDE_OSC, -0.2))
        l.hoja(punta, ang, largo * 0.65, 7, VERDE_OSC, cortes=3)
    l.contorno()
    return l

def cactus():
    l = Lienzo()
    boca = maceta(l, TERRACOTA, arriba=11, abajo=9, alto=13)
    c = (80, 160, 90)
    def columna(x, y0, y1, r):
        for y in range(int(y1), int(y0) + 1):
            for xx in range(int(x - r), int(x + r) + 1):
                d = (xx + 0.5 - x) / r
                l.punto(xx, y, tono(c, 0.25 - 0.55 * (d + 1) / 2))
        l.elipse(x, y1, r, r * 0.6, tono(c, 0.2))
        for y in range(int(y1) + 2, int(y0), 3):
            l.punto(x - r * 0.4, y, (240, 236, 210, 255))
            l.punto(x + r * 0.4, y + 1, (240, 236, 210, 255))
    columna(24, boca, boca - 30, 5)
    columna(15, boca - 12, boca - 22, 3)
    l.linea((15, boca - 12), (20, boca - 12), tono(c, -0.1), 3)
    columna(33, boca - 16, boca - 26, 3)
    l.linea((28, boca - 16), (33, boca - 16), tono(c, -0.1), 3)
    l.elipse(24, boca - 31, 2.5, 2, (240, 90, 130))
    l.contorno()
    return l

def suculenta():
    l = Lienzo()
    boca = maceta(l, AZUL, arriba=12, abajo=9, alto=11)
    c = (120, 170, 140)
    # Roseta: tres anillos de hojas gorditas, de afuera hacia adentro.
    for anillo, (n, largo, ancho) in enumerate(((11, 15, 4.2), (9, 11, 3.8), (7, 7, 3.2))):
        for k in range(n):
            ang = -math.pi * k / (n - 1) + (0.15 if anillo % 2 else 0.0)
            l.hoja((24, boca - 2 - anillo * 3), ang, largo, ancho, tono(c, anillo * 0.1), nervio=False)
    l.elipse(24, boca - 10, 2.5, 2, (214, 120, 150))
    l.contorno()
    return l

def palmera():
    l = Lienzo()
    boca = maceta(l, NEGRO)
    for x0, ang0 in ((22, -1.75), (26, -1.4)):
        tope = (x0 + math.cos(ang0) * 26, boca + math.sin(ang0) * 26)
        l.linea((x0, boca), tope, (110, 140, 70), 2)
        for k in range(7):
            ang = ang0 - 1.4 + k * 0.45
            for j in range(9):
                t = j / 8
                p = (tope[0] + math.cos(ang) * 14 * t, tope[1] + math.sin(ang) * 10 * t + 6 * t * t)
                l.linea(p, (p[0] + math.cos(ang + 1.3) * 3, p[1] + math.sin(ang + 1.3) * 3), tono(VERDE, 0.1 - t * 0.3))
                l.linea(p, (p[0] + math.cos(ang - 1.3) * 3, p[1] + math.sin(ang - 1.3) * 3), tono(VERDE, -0.1 - t * 0.3))
    l.contorno()
    return l

def sansevieria():
    l = Lienzo()
    boca = maceta(l, BLANCO, arriba=12, abajo=10)
    c = (60, 120, 70)
    for x, alto, incl in ((18, 26, -0.15), (22, 34, -0.05), (26, 30, 0.08), (30, 24, 0.18), (24, 22, 0.0)):
        for y in range(alto):
            t = y / alto
            ancho = 2.6 * math.sin(math.pi * (0.15 + t * 0.85)) + 0.5
            cx = x + incl * y
            for xx in range(int(cx - ancho), int(cx + ancho) + 1):
                franja = int((boca - y) / 3) % 2
                color = tono(c, 0.2 if franja else -0.1)
                if abs(xx + 0.5 - cx) > ancho - 0.8:
                    color = (210, 200, 90, 255)
                l.punto(xx, boca - y, color)
    l.contorno()
    return l

def helecho():
    l = Lienzo()
    boca = maceta(l, TERRACOTA)
    for k in range(9):
        ang = -math.pi + 0.2 + k * (math.pi - 0.4) / 8
        largo = 20 if k % 2 else 16
        puntos = []
        for j in range(12):
            t = j / 11
            puntos.append((24 + math.cos(ang) * largo * t, boca - 2 + math.sin(ang) * largo * t + 10 * t * t))
        for j in range(11):
            l.linea(puntos[j], puntos[j + 1], VERDE_OSC)
            p = puntos[j]
            hojita = 3 * (1 - j / 11) + 1
            l.linea(p, (p[0] + math.cos(ang - 1.2) * hojita, p[1] + math.sin(ang - 1.2) * hojita), tono(VERDE_CLARO, -0.1 * (j % 2)))
            l.linea(p, (p[0] + math.cos(ang + 1.2) * hojita, p[1] + math.sin(ang + 1.2) * hojita), tono(VERDE, -0.1))
    l.contorno()
    return l

def ficus():
    l = Lienzo()
    boca = maceta(l, (150, 90, 60), arriba=13, abajo=10)
    tronco = (120, 86, 60)
    l.linea((24, boca), (23, boca - 16), tronco, 3)
    l.linea((23, boca - 12), (17, boca - 20), tronco, 2)
    l.linea((24, boca - 13), (30, boca - 22), tronco, 2)
    random.seed(4)
    for cx, cy, r in ((24, boca - 32, 11), (15, boca - 26, 8), (33, boca - 27, 8), (24, boca - 24, 9)):
        l.elipse(cx, cy, r, r * 0.85, VERDE, sombreado=0.5)
        for _ in range(int(r * 2)):
            a = random.uniform(0, math.tau)
            d = random.uniform(0, r * 0.8)
            l.punto(cx + math.cos(a) * d, cy + math.sin(a) * d * 0.85, tono(VERDE_CLARO, 0.1))
    l.contorno()
    return l

def bonsai():
    l = Lienzo()
    boca = maceta_baja(l, (90, 70, 110))
    tronco = (110, 80, 56)
    pts = [(22, boca), (20, boca - 6), (24, boca - 12), (21, boca - 18), (26, boca - 24)]
    for a, b in zip(pts, pts[1:]):
        l.linea(a, b, tronco, 3)
    l.linea((24, boca - 12), (33, boca - 16), tronco, 2)
    l.linea((21, boca - 18), (13, boca - 21), tronco, 2)
    for cx, cy, rx in ((34, boca - 19, 7), (12, boca - 24, 7), (26, boca - 29, 9)):
        l.elipse(cx, cy, rx, rx * 0.45, VERDE_OSC, sombreado=0.4)
        l.elipse(cx - 1, cy - 1.5, rx * 0.7, rx * 0.3, tono(VERDE, 0.1))
    l.contorno()
    return l

def girasoles():
    l = Lienzo()
    boca = maceta(l, AMARILLO, arriba=13, abajo=10)
    for x, alto, incl in ((18, 26, -0.2), (30, 22, 0.25), (24, 32, 0.0)):
        tope = (x + incl * alto, boca - alto)
        l.linea((x, boca), tope, VERDE_OSC, 2)
        l.hoja((x + incl * alto * 0.5, boca - alto * 0.5), -0.3 if incl >= 0 else -2.8, 6, 2.5, VERDE)
        for k in range(12):
            a = k * math.tau / 12
            l.elipse(tope[0] + math.cos(a) * 4, tope[1] + math.sin(a) * 3, 2, 1.4, (250, 205, 50))
        l.elipse(tope[0], tope[1], 3, 2.4, (110, 70, 40), sombreado=0.4)
    l.contorno()
    return l

def bambu():
    l = Lienzo()
    boca = maceta(l, (60, 130, 120), arriba=11, abajo=9, alto=14)
    c = (150, 190, 80)
    for x, alto in ((19, 34), (24, 40), (29, 30)):
        for y in range(alto):
            nudo = y % 9 == 8
            for xx in range(x - 1, x + 2):
                l.punto(xx, boca - y, tono(c, -0.35 if nudo else (0.2 if xx == x - 1 else -0.05)))
        for k, alto_hoja in enumerate((alto - 2, alto - 12)):
            lado = 1 if (x + k) % 2 else -1
            l.hoja((x, boca - alto_hoja), -1.57 + lado * 0.9, 9, 2.2, VERDE)
    l.contorno()
    return l

PLANTAS = {
    "monstera": monstera,
    "cactus": cactus,
    "suculenta": suculenta,
    "palmera": palmera,
    "sansevieria": sansevieria,
    "helecho": helecho,
    "ficus": ficus,
    "bonsai": bonsai,
    "girasoles": girasoles,
    "bambu": bambu,
}

if __name__ == "__main__":
    os.makedirs(CARPETA, exist_ok=True)
    for nombre, dibujo in PLANTAS.items():
        random.seed(nombre)
        dibujo().guardar(nombre)
