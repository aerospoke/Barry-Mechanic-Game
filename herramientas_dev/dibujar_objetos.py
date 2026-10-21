#!/usr/bin/env python3
# Dibuja los 50 objetos de ambientacion del taller (objetos/ambiente/) en
# pixel art isometrico, con el mismo estilo que los muebles, y escribe solo:
#   - scripts/objetos_ambiente.gd  (catalogo que lee RoomObjectCatalog)
#   - sql/objetos_ambiente.sql     (los articulos de la tienda)
# Asi la lista de objetos vive en un solo lugar: OBJETOS, al final.
#
#   python3 herramientas_dev/dibujar_objetos.py
#
# Piezas reutilizables: caja() (muebles con frente/costado/tapa), cilindro()
# (barriles, postes), piso() (tapetes y lineas, que se pisan) y bandera().
import math, random, struct, zlib, os

RAIZ = os.path.join(os.path.dirname(__file__), "..")
CARPETA = os.path.join(RAIZ, "objetos", "ambiente")
ESCALA = 4
K = (22, 18, 24, 255)
SOMBRA = (0, 0, 0, 70)
EJE_L = (1.0, -0.5)   # largo: hacia arriba a la derecha
EJE_P = (-1.0, -0.5)  # fondo: hacia arriba a la izquierda

def rgba(c):
    return tuple(c) + (255,) if len(c) == 3 else tuple(c)

def tono(c, k):
    if k >= 0:
        return tuple(int(v + (255 - v) * k) for v in c[:3]) + (255,)
    return tuple(int(v * (1 + k)) for v in c[:3]) + (255,)

def mas(a, b, k=1.0):
    return (a[0] + b[0] * k, a[1] + b[1] * k)

def coords(p, o, u, v):
    dx, dy = p[0] - o[0], p[1] - o[1]
    det = u[0] * v[1] - u[1] * v[0]
    return (dx * v[1] - dy * v[0]) / det, (u[0] * dy - u[1] * dx) / det

class Lienzo:
    def __init__(self, alto=64):
        self.W, self.H = 64, alto
        self.piso = (32, alto - 10)  # centro de la base del objeto
        self.px = [[(0, 0, 0, 0)] * self.W for _ in range(self.H)]
        self.brillos = []  # (cx, cy, radio, color): halos de luz, al final

    def punto(self, x, y, c):
        x, y = int(math.floor(x)), int(math.floor(y))
        if 0 <= x < self.W and 0 <= y < self.H:
            self.px[y][x] = rgba(c)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.punto(x, y, c)

    def elipse(self, cx, cy, rx, ry, c, sombreado=0.0):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx, dy = (x + 0.5 - cx) / max(rx, 0.01), (y + 0.5 - cy) / max(ry, 0.01)
                if dx * dx + dy * dy <= 1:
                    self.punto(x, y, tono(c, -sombreado * (dx * 0.6 + dy * 0.4)) if sombreado else c)

    def linea(self, p0, p1, c, grosor=1):
        pasos = int(max(abs(p1[0] - p0[0]), abs(p1[1] - p0[1])) * 2) + 1
        for k in range(pasos + 1):
            t = k / pasos
            x, y = p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t
            for g in range(grosor):
                self.punto(x + g - grosor // 2, y, c)

    def sombra(self, rx=18, ry=8):
        self.elipse(self.piso[0], self.piso[1], rx, ry, SOMBRA)

    def brillo(self, cx, cy, radio, color=(255, 230, 140)):
        self.brillos.append((cx, cy, radio, color))

    def contorno(self):
        nuevo = [fila[:] for fila in self.px]
        for y in range(self.H):
            for x in range(self.W):
                if self.px[y][x][3] > 100:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < self.W and 0 <= yy < self.H and self.px[yy][xx][3] > 200:
                        nuevo[y][x] = K
                        break
        self.px = nuevo

    def _aplicar_brillos(self):
        # Halo suave por encima (sin contorno): la luz de las lamparas.
        for cx, cy, radio, color in self.brillos:
            for y in range(self.H):
                for x in range(self.W):
                    d = math.hypot(x + 0.5 - cx, (y + 0.5 - cy) * 1.2) / radio
                    if d < 1:
                        a = (1 - d) ** 2 * 0.75
                        r, g, b, al = self.px[y][x]
                        if al == 0:
                            self.px[y][x] = (color[0], color[1], color[2], int(a * 255))
                        else:
                            self.px[y][x] = (int(r + (color[0] - r) * a * 0.6), int(g + (color[1] - g) * a * 0.6),
                                             int(b + (color[2] - b) * a * 0.6), al)

    def guardar(self, nombre):
        self._aplicar_brillos()
        raw = b""
        for y in range(self.H * ESCALA):
            raw += b"\x00" + b"".join(bytes(self.px[y // ESCALA][x // ESCALA]) for x in range(self.W * ESCALA))
        def chunk(t, d):
            return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
        with open(os.path.join(CARPETA, nombre + ".png"), "wb") as f:
            f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", self.W * ESCALA, self.H * ESCALA, 8, 6, 0, 0, 0))
                    + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))

# --- Piezas ------------------------------------------------------------------

def caja(l, largo, fondo, alto, color, centro=None, elevacion=0, frente=None, costado=None, tapa=None,
         c_costado=None, c_tapa=None):
    """Caja isometrica apoyada en el piso (o elevada). frente/costado/tapa:
    funciones (a, b) -> color o None para dibujar detalles en esa cara."""
    centro = centro or l.piso
    u_f = (EJE_L[0] * largo, EJE_L[1] * largo)
    u_c = (EJE_P[0] * fondo, EJE_P[1] * fondo)
    arriba = (0, -alto)
    o = mas(mas(mas(centro, u_f, -0.5), u_c, -0.5), (0, -elevacion))
    caras = [
        (o, u_c, arriba, costado, c_costado or tono(color, -0.3)),
        (o, u_f, arriba, frente, color),
        (mas(o, arriba), u_f, u_c, tapa, c_tapa or tono(color, 0.18)),
    ]
    for origen, u, v, deco, base in caras:
        lu, lv = math.hypot(*u), math.hypot(*v)
        for y in range(l.H):
            for x in range(l.W):
                a, b = coords((x + 0.5, y + 0.5), origen, u, v)
                if 0 <= a <= 1 and 0 <= b <= 1:
                    c = deco(a, b) if deco else None
                    if c is None:
                        borde = a * lu < 0.8 or (1 - a) * lu < 0.8 or b * lv < 0.8 or (1 - b) * lv < 0.8
                        c = tono(base, -0.45) if borde else base
                    l.punto(x, y, c)
    return o

def cilindro(l, cx, piso_y, r, alto, color, bandas=(), tapa=None):
    """Cilindro vertical (barril, poste, extintor) con luz de la izquierda."""
    ry = r * 0.5
    for y in range(int(piso_y - alto), int(piso_y) + 1):
        for x in range(int(cx - r), int(cx + r) + 1):
            dx = (x + 0.5 - cx) / r
            if abs(dx) > 1:
                continue
            c = color
            for frac, cb in bandas:
                if abs((piso_y - y) - alto * frac) < 1.2:
                    c = cb
            l.punto(x, y, tono(c, 0.2 - 0.5 * (dx + 1) / 2))
    l.elipse(cx, piso_y, r, ry, tono(color, -0.35))
    l.elipse(cx, piso_y - alto, r, ry, tapa or tono(color, 0.15))

def piso(l, largo, fondo, fn):
    """Decoracion plana sobre el piso (tapete, lineas): fn(a, b) -> color o
    None. Centrada en la base del lienzo."""
    u_f = (EJE_L[0] * largo, EJE_L[1] * largo)
    u_c = (EJE_P[0] * fondo, EJE_P[1] * fondo)
    o = mas(mas(l.piso, u_f, -0.5), u_c, -0.5)
    for y in range(l.H):
        for x in range(l.W):
            a, b = coords((x + 0.5, y + 0.5), o, u_f, u_c)
            if 0 <= a <= 1 and 0 <= b <= 1:
                c = fn(a, b)
                if c is not None:
                    l.punto(x, y, c)

def poste(l, x, y0, y1, color, grosor=2):
    for y in range(int(y1), int(y0) + 1):
        for g in range(grosor):
            l.punto(x + g, y, tono(color, 0.15 if g == 0 else -0.15))

# --- Objetos -------------------------------------------------------------------
# Cada funcion devuelve un Lienzo (o (apagado, prendido) si es una luz).

ROJO = (196, 52, 46); AZUL = (52, 96, 170); VERDE = (60, 140, 72); AMARILLO = (232, 188, 48)
NEGRO = (44, 44, 52); GRIS = (128, 132, 140); BLANCO = (226, 228, 232); MADERA = (150, 98, 58)
CUERO = (120, 70, 40); NARANJA = (234, 120, 40); ORO = (240, 190, 60); PLATA = (196, 200, 210)
BRONCE = (184, 116, 60); METAL = (150, 156, 168)

def sofa(color):
    def f():
        l = Lienzo(); l.sombra(22, 9)
        caja(l, 34, 14, 8, color)                                 # asiento
        caja(l, 34, 4, 18, tono(color, -0.1), centro=mas(l.piso, EJE_P, 6))  # respaldo
        caja(l, 4, 14, 13, tono(color, -0.05), centro=mas(l.piso, EJE_L, -15))
        caja(l, 4, 14, 13, tono(color, -0.05), centro=mas(l.piso, EJE_L, 15))
        l.contorno(); return l
    return f

def sillon():
    l = Lienzo(); l.sombra(14, 7)
    caja(l, 18, 14, 8, CUERO)
    caja(l, 18, 4, 18, tono(CUERO, -0.1), centro=mas(l.piso, EJE_P, 6))
    caja(l, 3, 14, 12, CUERO, centro=mas(l.piso, EJE_L, -8))
    caja(l, 3, 14, 12, CUERO, centro=mas(l.piso, EJE_L, 8))
    l.contorno(); return l

def mesa_centro():
    l = Lienzo(); l.sombra(16, 7)
    for dl, dp in ((-10, -5), (10, -5), (-10, 5), (10, 5)):
        caja(l, 2, 2, 8, NEGRO, centro=mas(mas(l.piso, EJE_L, dl), EJE_P, dp))
    caja(l, 26, 14, 2, MADERA, elevacion=8)
    l.contorno(); return l

def banco():
    l = Lienzo(); l.sombra(16, 6)
    for d in (-11, 11):
        caja(l, 3, 8, 9, tono(MADERA, -0.2), centro=mas(l.piso, EJE_L, d))
    caja(l, 30, 9, 3, MADERA, elevacion=9,
         tapa=lambda a, b: tono(MADERA, -0.15) if int(a * 6) % 2 else None)
    l.contorno(); return l

def taburete():
    l = Lienzo(); l.sombra(8, 4)
    cilindro(l, 32, l.piso[1], 1.6, 14, METAL)
    l.elipse(32, l.piso[1], 6, 3, NEGRO)
    cilindro(l, 32, l.piso[1] - 14, 7, 3, ROJO)
    l.contorno(); return l

def nevera():
    l = Lienzo(alto=96); l.sombra(14, 7)
    def frente(a, b):
        if abs(b - 0.62) < 0.015: return tono(BLANCO, -0.4)
        if 0.82 < a < 0.88 and (0.68 < b < 0.85 or 0.3 < b < 0.55): return METAL
        return None
    caja(l, 18, 16, 46, BLANCO, frente=frente)
    l.contorno(); return l

def maquina_cafe():
    l = Lienzo(); l.sombra(10, 5)
    def frente(a, b):
        if 0.25 < a < 0.75 and 0.15 < b < 0.45: return (30, 30, 34)
        if 0.35 < a < 0.65 and 0.15 < b < 0.24: return BLANCO
        if 0.2 < a < 0.4 and 0.7 < b < 0.82: return (230, 70, 60)
        return None
    caja(l, 14, 12, 22, (70, 60, 64), frente=frente)
    l.contorno(); return l

def dispensador():
    l = Lienzo(alto=96); l.sombra(9, 5)
    caja(l, 12, 12, 26, BLANCO, frente=lambda a, b: (60, 130, 220) if 0.4 < a < 0.6 and 0.5 < b < 0.62 else None)
    cilindro(l, 32, l.piso[1] - 26, 6, 16, (120, 190, 240), bandas=((0.5, (90, 160, 220)),))
    l.contorno(); return l

def maquina_snacks():
    l = Lienzo(alto=96); l.sombra(15, 7)
    def frente(a, b):
        if 0.08 < a < 0.7 and 0.3 < b < 0.92:
            fila = int((b - 0.3) / 0.62 * 5)
            col = int((a - 0.08) / 0.62 * 4)
            return [ROJO, AMARILLO, VERDE, NARANJA, AZUL][(fila + col) % 5] if (b * 40) % 3 > 1 else (40, 46, 60)
        if 0.76 < a < 0.92 and 0.5 < b < 0.75: return (40, 40, 48)
        if 0.1 < a < 0.65 and 0.08 < b < 0.2: return (30, 30, 36)
        return None
    caja(l, 20, 14, 44, ROJO, frente=frente)
    l.contorno(); return l

def arcade():
    l = Lienzo(alto=96); l.sombra(12, 6)
    def frente(a, b):
        if 0.15 < a < 0.85 and 0.55 < b < 0.85: return (40, 200, 220) if (a * 20 + b * 30) % 4 > 2 else (20, 40, 90)
        if 0.3 < a < 0.4 and 0.38 < b < 0.46: return ROJO
        if 0.55 < a < 0.62 and 0.38 < b < 0.45: return AMARILLO
        if 0.1 < a < 0.9 and 0.9 < b < 0.98: return (240, 80, 200)
        return None
    caja(l, 16, 14, 42, (70, 40, 140), frente=frente)
    l.contorno(); return l

def tapete(color, patron):
    def f():
        l = Lienzo()
        def fn(a, b):
            if a < 0.05 or a > 0.95 or b < 0.07 or b > 0.93: return tono(color, -0.35)
            return patron(a, b, color)
        piso(l, 40, 24, fn)
        return l
    return f

def lineas_parqueo():
    l = Lienzo()
    piso(l, 34, 22, lambda a, b: AMARILLO if (a < 0.08 or a > 0.92 or b < 0.1) else None)
    return l

def cebra():
    l = Lienzo()
    piso(l, 34, 22, lambda a, b: BLANCO if int(a * 7) % 2 == 0 else None)
    return l

def mancha_aceite():
    l = Lienzo()
    random.seed(9)
    blobs = [(0.5, 0.5, 0.35), (0.3, 0.6, 0.2), (0.7, 0.35, 0.22), (0.62, 0.7, 0.15)]
    def fn(a, b):
        for x, y, r in blobs:
            if math.hypot(a - x, (b - y) * 1.3) < r:
                return (26, 22, 30, 230) if math.hypot(a - x - 0.05, b - y + 0.05) > r * 0.5 else (60, 50, 80, 230)
        return None
    piso(l, 30, 22, fn)
    return l

def tope_parqueo():
    l = Lienzo(); l.sombra(18, 6)
    caja(l, 32, 6, 5, AMARILLO, frente=lambda a, b: NEGRO if int(a * 8) % 2 else None)
    l.contorno(); return l

def cono():
    l = Lienzo(); l.sombra(9, 5)
    caja(l, 14, 14, 2, NARANJA)
    for y in range(22):
        r = 6 - y * 0.24
        for x in range(int(32 - r), int(32 + r) + 1):
            dx = (x + 0.5 - 32) / max(r, 0.5)
            c = BLANCO if 7 < y < 11 or 14 < y < 17 else NARANJA
            l.punto(x, l.piso[1] - 2 - y, tono(c, 0.2 - 0.5 * (dx + 1) / 2))
    l.contorno(); return l

def barrera():
    l = Lienzo(); l.sombra(20, 7)
    caja(l, 34, 10, 6, GRIS)
    caja(l, 34, 5, 12, GRIS, elevacion=6,
         frente=lambda a, b: ROJO if int(a * 8 + b * 2) % 2 == 0 and b > 0.5 else None)
    l.contorno(); return l

def senal_pare():
    l = Lienzo(alto=96); l.sombra(6, 3)
    caja(l, 8, 8, 3, GRIS)
    poste(l, 31, l.piso[1] - 3, l.piso[1] - 52, METAL)
    cx, cy = 32, l.piso[1] - 58
    for y in range(-10, 11):
        for x in range(-10, 11):
            if abs(x) + abs(y) * 0.6 <= 11 and abs(x) <= 9 and abs(y) <= 9:
                c = BLANCO if (abs(x) <= 7 and abs(y) <= 1) else ROJO
                if abs(x) > 8 or abs(y) > 8 or abs(x) + abs(y) * 0.6 > 10: c = BLANCO
                l.punto(cx + x, cy + y, c)
    l.contorno(); return l

def delineador():
    l = Lienzo(alto=96); l.sombra(6, 3)
    cilindro(l, 32, l.piso[1], 4, 34, NARANJA, bandas=((0.75, BLANCO), (0.8, BLANCO), (0.5, BLANCO), (0.55, BLANCO)))
    l.contorno(); return l

def reja():
    l = Lienzo(alto=96); l.sombra(20, 5)
    o = mas(l.piso, EJE_L, -18)
    for k in range(10):
        base = mas(o, EJE_L, k * 4)
        poste(l, base[0], base[1], base[1] - 34, NEGRO, 1)
        l.punto(base[0], base[1] - 35, tono(NEGRO, 0.3))
    for h in (6, 28):
        l.linea(mas(o, (0, -h)), mas(mas(o, EJE_L, 36), (0, -h)), NEGRO, 1)
    l.contorno(); return l

def reja_malla():
    l = Lienzo(alto=96); l.sombra(20, 5)
    o = mas(l.piso, EJE_L, -18)
    for k in (0, 18, 36):
        b = mas(o, EJE_L, k)
        poste(l, b[0], b[1], b[1] - 40, METAL)
    u = (EJE_L[0] * 36, EJE_L[1] * 36)
    for y in range(l.H):
        for x in range(l.W):
            a, h = coords((x + 0.5, y + 0.5), o, u, (0, -38))
            if 0 <= a <= 1 and 0 <= h <= 1 and int((a * 36 + h * 38)) % 4 == 0 or (0 <= a <= 1 and 0 <= h <= 1 and int((a * 36 - h * 38)) % 4 == 0):
                l.punto(x, y, tono(METAL, 0.1))
    l.contorno(); return l

def pallet():
    l = Lienzo(); l.sombra(18, 8)
    for d in (-9, 0, 9):
        caja(l, 30, 3, 4, tono(MADERA, -0.2), centro=mas(l.piso, EJE_P, d))
    caja(l, 30, 22, 2, MADERA, elevacion=4, tapa=lambda a, b: tono(MADERA, -0.25) if int(b * 5) % 2 else None)
    l.contorno(); return l

def escalera():
    l = Lienzo(alto=96); l.sombra(12, 5)
    for d in (-7, 7):
        b = mas(l.piso, EJE_L, d)
        l.linea(b, (b[0] + 6, b[1] - 46), METAL, 2)
    for k in range(1, 7):
        y = k * 6.5
        l.linea(mas(mas(l.piso, EJE_L, -7), (y / 46 * 6, -y)), mas(mas(l.piso, EJE_L, 7), (y / 46 * 6, -y)), tono(METAL, -0.2), 1)
    l.contorno(); return l

def barril(color):
    def f():
        l = Lienzo(); l.sombra(10, 5)
        cilindro(l, 32, l.piso[1], 9, 26, color, bandas=((0.25, tono(color, -0.35)), (0.75, tono(color, -0.35))))
        l.elipse(28, l.piso[1] - 26, 2, 1, tono(color, -0.5))
        l.contorno(); return l
    return f

def pila_llantas():
    l = Lienzo(); l.sombra(12, 6)
    for k in range(4):
        y = l.piso[1] - k * 6
        l.elipse(32, y, 11, 5.5, (30, 30, 36))
        for x in range(21, 44):
            for yy in range(int(y - 6), int(y)):
                l.punto(x, yy, tono((40, 40, 48), 0.15 - 0.4 * (x - 21) / 22))
        l.elipse(32, y - 6, 11, 5.5, (52, 52, 60))
        l.elipse(32, y - 6, 5, 2.5, (18, 18, 22))
    l.contorno(); return l

def caja_herramientas():
    l = Lienzo(alto=96); l.sombra(14, 6)
    def frente(a, b):
        if any(abs(b - y) < 0.02 for y in (0.25, 0.45, 0.65, 0.85)): return tono(ROJO, -0.45)
        if abs(a - 0.5) < 0.12 and any(abs(b - y) < 0.03 for y in (0.15, 0.35, 0.55, 0.75)): return METAL
        return None
    caja(l, 22, 14, 34, ROJO, frente=frente)
    l.contorno(); return l

def bidon():
    l = Lienzo(); l.sombra(8, 4)
    caja(l, 12, 7, 16, ROJO, frente=lambda a, b: tono(ROJO, -0.3) if abs(a - b) < 0.08 or abs(a + b - 1) < 0.08 else None)
    cilindro(l, 36, l.piso[1] - 16, 1.8, 4, AMARILLO)
    l.contorno(); return l

def extintor():
    l = Lienzo(); l.sombra(6, 3)
    cilindro(l, 32, l.piso[1], 5, 22, ROJO, bandas=((0.55, BLANCO), (0.6, BLANCO)))
    cilindro(l, 32, l.piso[1] - 22, 2, 4, NEGRO)
    l.linea((33, l.piso[1] - 25), (38, l.piso[1] - 18), NEGRO, 1)
    l.contorno(); return l

def lampara_pie(encendida):
    l = Lienzo(alto=96); l.sombra(7, 3)
    l.elipse(32, l.piso[1], 6, 3, NEGRO)
    poste(l, 31, l.piso[1], l.piso[1] - 44, NEGRO)
    for y in range(12):
        r = 4 + y * 0.6
        for x in range(int(32 - r), int(32 + r) + 1):
            l.punto(x, l.piso[1] - 56 + y, tono((240, 220, 170) if encendida else (200, 190, 160), 0.1 - 0.4 * (x - 32 + r) / (2 * r)))
    l.contorno()
    if encendida: l.brillo(32, l.piso[1] - 48, 22)
    return l

def foco_trabajo(encendida):
    l = Lienzo(alto=96); l.sombra(10, 4)
    top = (32, l.piso[1] - 36)
    for dx in (-9, 0, 9):
        l.linea((32 + dx, l.piso[1] - (2 if dx else 0)), top, METAL, 1)
    caja(l, 10, 6, 8, AMARILLO, centro=(32, l.piso[1] - 36),
         frente=lambda a, b: ((255, 250, 210) if encendida else (150, 150, 140)) if 0.15 < a < 0.85 and 0.15 < b < 0.85 else None)
    l.contorno()
    if encendida: l.brillo(36, l.piso[1] - 40, 24)
    return l

def poste_luz(encendida):
    l = Lienzo(alto=96); l.sombra(6, 3)
    caja(l, 7, 7, 3, GRIS)
    poste(l, 31, l.piso[1] - 3, l.piso[1] - 70, (60, 64, 72), 3)
    l.linea((32, l.piso[1] - 70), (42, l.piso[1] - 72), (60, 64, 72), 2)
    caja(l, 9, 6, 4, (60, 64, 72), centro=(43, l.piso[1] - 72),
         frente=lambda a, b: (255, 245, 190) if encendida and b < 0.4 else None)
    l.contorno()
    if encendida: l.brillo(43, l.piso[1] - 66, 26)
    return l

def neon(encendida):
    l = Lienzo(alto=96); l.sombra(10, 4)
    caja(l, 4, 4, 22, NEGRO, centro=mas(l.piso, EJE_L, -6))
    caja(l, 4, 4, 22, NEGRO, centro=mas(l.piso, EJE_L, 6))
    caja(l, 24, 3, 18, (30, 30, 40), elevacion=22)
    rayo = [(28, -50), (34, -50), (31, -45), (36, -45), (27, -35), (30, -42), (26, -42)]
    color = (90, 240, 255) if encendida else (60, 90, 100)
    for a, b in zip(rayo, rayo[1:] + rayo[:1]):
        l.linea((a[0], l.piso[1] + a[1]), (b[0], l.piso[1] + b[1]), color, 2)
    l.contorno()
    if encendida: l.brillo(31, l.piso[1] - 43, 20, (120, 240, 255))
    return l

def farol(encendida):
    l = Lienzo(); l.sombra(7, 3)
    caja(l, 10, 10, 3, NEGRO)
    caja(l, 8, 8, 14, (40, 40, 48), elevacion=3,
         frente=lambda a, b: ((255, 210, 110) if encendida else (90, 80, 70)) if 0.2 < a < 0.8 and 0.15 < b < 0.85 else None,
         costado=lambda a, b: ((240, 190, 90) if encendida else (70, 64, 58)) if 0.2 < a < 0.8 and 0.15 < b < 0.85 else None)
    caja(l, 10, 10, 2, NEGRO, elevacion=17)
    l.contorno()
    if encendida: l.brillo(32, l.piso[1] - 10, 18, (255, 200, 110))
    return l

def trofeo(color, grande=False):
    def f():
        l = Lienzo(alto=96 if grande else 64); l.sombra(9, 4)
        caja(l, 12, 12, 6, (60, 40, 30))
        poste(l, 31, l.piso[1] - 6, l.piso[1] - 14, color, 3)
        r = 9 if grande else 7
        alto = 14 if grande else 10
        base_y = l.piso[1] - 14
        for y in range(alto):
            rr = r * (0.55 + 0.45 * (y / alto) ** 0.6)
            for x in range(int(32 - rr), int(32 + rr) + 1):
                l.punto(x, base_y - y, tono(color, 0.35 - 0.6 * (x - 32 + rr) / (2 * rr)))
        l.elipse(32, base_y - alto, r, r * 0.4, tono(color, 0.25))
        l.elipse(32, base_y - alto, r - 2, (r - 2) * 0.4, tono(color, -0.3))
        for lado in (-1, 1):
            l.linea((32 + lado * r, base_y - alto + 3), (32 + lado * (r + 4), base_y - alto + 6), color, 2)
            l.linea((32 + lado * (r + 4), base_y - alto + 6), (32 + lado * (r - 1), base_y - 4), color, 2)
        l.contorno(); return l
    return f

def placa_mes():
    l = Lienzo(alto=96); l.sombra(10, 4)
    for dx in (-6, 6):
        l.linea((32 + dx, l.piso[1]), (32, l.piso[1] - 40), MADERA, 2)
    caja(l, 22, 2, 26, ORO, elevacion=18,
         frente=lambda a, b: (BLANCO if 0.12 < a < 0.88 and 0.12 < b < 0.88 and not (0.35 < a < 0.65 and 0.35 < b < 0.75) else
                              ((60, 96, 170) if 0.35 < a < 0.65 and 0.35 < b < 0.75 else None)))
    l.contorno(); return l

def vitrina():
    l = Lienzo(alto=96); l.sombra(14, 6)
    def frente(a, b):
        if 0.08 < a < 0.92 and 0.08 < b < 0.92:
            for fila_y, col in ((0.25, ORO), (0.55, PLATA), (0.8, BRONCE)):
                for x in (0.25, 0.5, 0.75):
                    if math.hypot(a - x, (b - fila_y) * 1.5) < 0.07: return col
            if any(abs(b - y) < 0.015 for y in (0.4, 0.68)): return tono(MADERA, -0.2)
            return (150, 200, 220, 255)
        return None
    caja(l, 22, 12, 40, MADERA, frente=frente)
    l.contorno(); return l

def gato_hidraulico():
    l = Lienzo(); l.sombra(14, 5)
    caja(l, 24, 10, 5, ROJO)
    for k, d in enumerate((-8, 8)):
        b = mas(l.piso, EJE_L, d)
        l.elipse(b[0], b[1] + 1, 2.5, 1.5, NEGRO)
    l.linea(mas(l.piso, EJE_L, -10), (12, l.piso[1] - 22), METAL, 2)
    cilindro(l, 36, l.piso[1] - 5, 3, 9, METAL)
    l.contorno(); return l

def motor_soporte():
    l = Lienzo(alto=96); l.sombra(14, 6)
    for dx in (-10, 10):
        l.linea((32 + dx, l.piso[1]), (32, l.piso[1] - 22), ROJO, 2)
    caja(l, 18, 12, 16, GRIS, centro=(32, l.piso[1] - 22),
         frente=lambda a, b: tono(GRIS, -0.3) if int(a * 6) % 2 and b > 0.3 else None)
    cilindro(l, 32, l.piso[1] - 38, 3, 6, NEGRO)
    l.contorno(); return l

def caja_registradora():
    l = Lienzo(); l.sombra(10, 5)
    caja(l, 16, 12, 8, GRIS)
    caja(l, 16, 8, 6, (70, 74, 82), elevacion=8, centro=mas(l.piso, EJE_P, 2),
         tapa=lambda a, b: BLANCO if int(a * 5 + b * 3) % 2 == 0 and 0.1 < a < 0.9 else None)
    caja(l, 8, 3, 6, (30, 30, 36), elevacion=14, centro=mas(l.piso, EJE_P, 4),
         frente=lambda a, b: (90, 230, 120) if 0.15 < a < 0.85 and 0.3 < b < 0.8 else None)
    l.contorno(); return l

def llanta_parada():
    l = Lienzo(); l.sombra(8, 5)
    cx, cy = 32, l.piso[1] - 13
    for y in range(-14, 15):
        for x in range(-8, 9):
            d = math.hypot(x / 8, y / 14)
            if d <= 1:
                c = (34, 34, 40) if d > 0.55 else (METAL if d > 0.25 else GRIS)
                l.punto(cx + x, cy + y, tono(c, 0.15 - 0.3 * (x + 8) / 16))
    l.contorno(); return l

# --- Banderas --------------------------------------------------------------------

def franjas_h(*colores):
    return lambda u, v: colores[min(int(v * len(colores)), len(colores) - 1)]

def franjas_v(*colores):
    return lambda u, v: colores[min(int(u * len(colores)), len(colores) - 1)]

BANDERAS = {
    "colombia": ("Colombia", lambda u, v: AMARILLO if v < 0.5 else ((40, 70, 160) if v < 0.75 else ROJO)),
    "mexico": ("Mexico", lambda u, v: (110, 90, 50) if math.hypot(u - 0.5, (v - 0.5) * 0.7) < 0.08 else franjas_v((0, 120, 70), BLANCO, (200, 30, 40))(u, v)),
    "argentina": ("Argentina", lambda u, v: AMARILLO if math.hypot(u - 0.5, (v - 0.5) * 0.7) < 0.07 else franjas_h((116, 172, 223), BLANCO, (116, 172, 223))(u, v)),
    "espana": ("Espana", lambda u, v: AMARILLO if 0.25 <= v < 0.75 else (200, 30, 40)),
    "brasil": ("Brasil", lambda u, v: (30, 60, 150) if math.hypot(u - 0.5, (v - 0.5) * 0.7) < 0.15 else (AMARILLO if abs(u - 0.5) + abs(v - 0.5) * 0.9 < 0.42 else (0, 150, 60))),
    "peru": ("Peru", franjas_v((210, 20, 40), BLANCO, (210, 20, 40))),
    "chile": ("Chile", lambda u, v: (BLANCO if math.hypot(u - 0.16, v - 0.25) < 0.06 else (30, 60, 160)) if (u < 0.33 and v < 0.5) else (BLANCO if v < 0.5 else (210, 20, 40))),
    "venezuela": ("Venezuela", lambda u, v: BLANCO if (0.36 < v < 0.64 and abs(math.hypot(u - 0.5, (v - 0.75) * 1.6) - 0.28) < 0.04 and int(u * 16) % 2 == 0) else franjas_h(AMARILLO, (30, 50, 140), (200, 20, 40))(u, v)),
    "ecuador": ("Ecuador", lambda u, v: (110, 90, 50) if math.hypot(u - 0.5, (v - 0.5) * 0.7) < 0.08 else (AMARILLO if v < 0.5 else ((30, 60, 150) if v < 0.75 else (210, 20, 40)))),
    "usa": ("Estados Unidos", lambda u, v: ((BLANCO if (int(u * 14) + int(v * 10)) % 2 == 0 else (40, 50, 120)) if u < 0.42 and v < 0.54 else ((190, 30, 50) if int(v * 13) % 2 == 0 else BLANCO))),
    "carreras": ("Carreras", lambda u, v: NEGRO if (int(u * 8) + int(v * 6)) % 2 else BLANCO),
    "arcoiris": ("Arcoiris", franjas_h((228, 3, 3), (255, 140, 0), (255, 237, 0), (0, 128, 38), (36, 64, 142), (115, 41, 130))),
    "pirata": ("Pirata", lambda u, v: BLANCO if (math.hypot(u - 0.5, (v - 0.42) * 1.2) < 0.14 or abs(abs(u - 0.5) - abs(v - 0.72) * 1.4) < 0.03 and 0.6 < v < 0.85) else NEGRO),
}

def bandera(diseno):
    def f():
        l = Lienzo(alto=96); l.sombra(8, 3)
        caja(l, 8, 8, 4, GRIS)
        poste(l, 22, l.piso[1] - 4, l.piso[1] - 66, METAL)
        l.elipse(23, l.piso[1] - 67, 1.6, 1.6, ORO)
        ancho, alto = 30, 20
        x0, y0 = 24, l.piso[1] - 64
        for i in range(ancho):
            u = i / ancho
            ola = math.sin(u * 5.0) * 1.6 * u
            luz = 0.12 * math.cos(u * 5.0)
            for j in range(alto):
                v = j / alto
                c = diseno(u, v)
                l.punto(x0 + i, y0 + j + ola + i * 0.15, tono(c, luz))
        l.contorno(); return l
    return f

# --- Lista de objetos -------------------------------------------------------------
# (kind, nombre en tienda, precio, descripcion, dibujo, opciones)
#   opciones: "alto" (lienzo de 96), "piso" (se pisa, sin choque), "luz"
#   (dibujo(encendida)), "variantes" (banderas), "balanceo"

OBJETOS = [
    ("sofa_rojo", "Sofa rojo", 120, "Un sofa para descansar entre trabajo y trabajo.", sofa(ROJO), {}),
    ("sofa_azul", "Sofa azul", 120, "Sofa comodo en azul taller.", sofa(AZUL), {}),
    ("sillon_cuero", "Sillon de cuero", 90, "El sillon del jefe del taller.", sillon, {}),
    ("mesa_centro", "Mesa de centro", 50, "Mesita para el cafe y las revistas de carros.", mesa_centro, {}),
    ("banco_madera", "Banco de madera", 40, "Banco de madera para la sala de espera.", banco, {}),
    ("taburete", "Taburete de taller", 25, "Taburete giratorio de mecanico.", taburete, {}),
    ("nevera", "Nevera", 150, "Bebidas frias para los dias de mucho trabajo.", nevera, {"alto": True}),
    ("maquina_cafe", "Maquina de cafe", 80, "Cafe para arrancar el dia con energia.", maquina_cafe, {}),
    ("dispensador", "Dispensador de agua", 60, "Agua fresquita para los clientes.", dispensador, {"alto": True}),
    ("maquina_snacks", "Maquina de snacks", 180, "Papitas y chocolates para la espera.", maquina_snacks, {"alto": True}),
    ("arcade", "Maquina arcade", 250, "Una maquinita de videojuegos retro. ¡Para las pausas!", arcade, {"alto": True}),
    ("tapete_rojo", "Tapete rojo", 30, "Tapete rojo con rayas, se ve elegante.", tapete(ROJO, lambda a, b, c: tono(c, -0.15) if int(a * 10) % 2 else None), {"piso": True}),
    ("tapete_azul", "Tapete azul", 30, "Tapete azul con borde.", tapete(AZUL, lambda a, b, c: tono(c, 0.15) if 0.15 < a < 0.85 and 0.2 < b < 0.8 else None), {"piso": True}),
    ("tapete_cuadros", "Tapete de cuadros", 45, "Tapete a cuadros como bandera de carreras.", tapete(NEGRO, lambda a, b, c: BLANCO if (int(a * 8) + int(b * 5)) % 2 else None), {"piso": True}),
    ("alfombra_taller", "Alfombra antiderrame", 35, "Alfombra gris que atrapa el aceite.", tapete(GRIS, lambda a, b, c: tono(c, -0.12) if int((a + b) * 14) % 2 else None), {"piso": True}),
    ("lineas_parqueo", "Lineas de parqueo", 20, "Lineas amarillas para estacionar como pro.", lineas_parqueo, {"piso": True}),
    ("paso_cebra", "Paso de cebra", 25, "Paso peatonal para cuidar a los clientes.", cebra, {"piso": True}),
    ("mancha_aceite", "Mancha de aceite", 5, "Una mancha de aceite... para el realismo.", mancha_aceite, {"piso": True}),
    ("tope_parqueo", "Tope de parqueo", 25, "Tope amarillo y negro para que las llantas no pasen.", tope_parqueo, {}),
    ("cono", "Cono de trafico", 15, "Cono naranja: ¡cuidado, mecanico trabajando!", cono, {}),
    ("barrera", "Barrera de concreto", 60, "Barrera de concreto con franjas rojas.", barrera, {}),
    ("senal_pare", "Senal de PARE", 40, "Senal de pare para ordenar el taller.", senal_pare, {"alto": True}),
    ("delineador", "Poste delineador", 20, "Poste naranja con franjas reflectivas.", delineador, {"alto": True}),
    ("reja", "Reja metalica", 55, "Reja negra para cerrar tu taller.", reja, {"alto": True}),
    ("reja_malla", "Reja de malla", 45, "Reja de malla como la de los parqueaderos.", reja_malla, {"alto": True}),
    ("pallet", "Pallet de madera", 20, "Estiba de madera para apoyar repuestos.", pallet, {}),
    ("escalera", "Escalera", 35, "Escalera metalica para llegar a todo.", escalera, {"alto": True}),
    ("barril_azul", "Barril de aceite azul", 40, "Barril metalico de aceite.", barril(AZUL), {}),
    ("barril_rojo", "Barril de aceite rojo", 40, "Barril rojo de aceite de motor.", barril(ROJO), {}),
    ("barril_verde", "Barril verde", 40, "Barril verde para el reciclaje.", barril(VERDE), {}),
    ("pila_llantas", "Pila de llantas", 50, "Llantas apiladas, clasico de todo taller.", pila_llantas, {}),
    ("caja_herramientas", "Gabinete de herramientas", 110, "Gabinete rojo con cajones llenos de herramientas.", caja_herramientas, {"alto": True}),
    ("bidon", "Bidon de gasolina", 20, "Bidon rojo de gasolina.", bidon, {}),
    ("extintor", "Extintor", 30, "La seguridad primero en el taller.", extintor, {}),
    ("lampara_pie", "Lampara de pie", 70, "Lampara calida. Tocala para prenderla o apagarla.", lampara_pie, {"alto": True, "luz": True}),
    ("foco_trabajo", "Foco de trabajo", 80, "Reflector amarillo en tripode. Se prende y se apaga.", foco_trabajo, {"alto": True, "luz": True}),
    ("poste_luz", "Poste de luz", 120, "Farola de calle para tu taller. Se prende y se apaga.", poste_luz, {"alto": True, "luz": True}),
    ("neon_rayo", "Letrero de neon", 150, "Neon en forma de rayo. ¡Prendelo de noche!", neon, {"alto": True, "luz": True}),
    ("farol", "Farol", 45, "Farol de piso con luz calida.", farol, {"luz": True}),
    ("trofeo_oro", "Trofeo de oro", 300, "Para el mejor mecanico de la ciudad.", trofeo(ORO), {}),
    ("trofeo_plata", "Trofeo de plata", 180, "Segundo lugar, pero con orgullo.", trofeo(PLATA), {}),
    ("trofeo_bronce", "Trofeo de bronce", 100, "Tu primer gran logro.", trofeo(BRONCE), {}),
    ("copa_campeon", "Copa de campeon", 500, "La copa gigante de campeon. ¡Solo para leyendas!", trofeo(ORO, grande=True), {"alto": True}),
    ("placa_mes", "Mecanico del mes", 150, "Cuadro de mecanico del mes en caballete.", placa_mes, {"alto": True}),
    ("vitrina_medallas", "Vitrina de medallas", 220, "Vitrina con medallas de oro, plata y bronce.", vitrina, {"alto": True}),
    ("bandera", "Bandera", 60, "Una bandera con asta. Al ponerla eliges cual: tu pais, la de carreras y mas.", bandera(BANDERAS["colombia"][1]), {"alto": True, "variantes": True, "balanceo": True}),
    ("gato_hidraulico", "Gato hidraulico", 70, "Gato de piso para levantar carros.", gato_hidraulico, {}),
    ("motor_soporte", "Motor en soporte", 200, "Un motor en su soporte, listo para reparar.", motor_soporte, {"alto": True}),
    ("caja_registradora", "Caja registradora", 90, "Para cobrar cada trabajo con estilo.", caja_registradora, {}),
    ("llanta_parada", "Llanta de exhibicion", 30, "Llanta con rin brillante para exhibir.", llanta_parada, {}),
]

# Posicion del sprite en la sala (ver RoomObjectCatalog "posicion_sprite"):
# la base del lienzo (Lienzo.piso) cae sobre la base del objeto en la sala.
ESCALA_SALA = 0.5
BASE_SALA_Y = 76

def posicion_sprite(alto_lienzo):
    piso_y = alto_lienzo - 10
    return (-12, BASE_SALA_Y - (piso_y - alto_lienzo / 2) * ESCALA * ESCALA_SALA)

def main():
    os.makedirs(CARPETA, exist_ok=True)
    gd = ["extends RefCounted", "",
          "# GENERADO por herramientas_dev/dibujar_objetos.py: no editar a mano.",
          "# Objetos de ambientacion del taller. RoomObjectCatalog los busca aca",
          "# cuando un kind no esta en su propio catalogo.", "",
          "const OBJETOS := {"]
    sql = ["-- GENERADO por herramientas_dev/dibujar_objetos.py.",
           "-- Objetos de ambientacion del taller para la tienda (ver",
           "-- scripts/objetos_ambiente.gd). El key coincide con el kind del catalogo.",
           "--", "-- Ejecutar en el SQL Editor de Supabase (shop_items_descripcion.sql ya",
           "-- debe haberse corrido antes).", "",
           "insert into public.shop_items (key, name, price, tipo, description) values"]
    filas_sql = []
    for kind, nombre, precio, desc, dibujo, op in OBJETOS:
        random.seed(kind)
        alto = 96 if op.get("alto") else 64
        entrada = ['\t"%s": {' % kind]
        if op.get("luz"):
            dibujo(False).guardar(kind)
            dibujo(True).guardar(kind + "_on")
            entrada.append('\t\t"textura_on": preload("res://objetos/ambiente/%s_on.png"),' % kind)
        else:
            dibujo().guardar(kind)
        entrada.append('\t\t"textura": preload("res://objetos/ambiente/%s.png"),' % kind)
        entrada.append('\t\t"escala": Vector2(%s, %s),' % (ESCALA_SALA, ESCALA_SALA))
        px, py = posicion_sprite(alto)
        entrada.append('\t\t"posicion_sprite": Vector2(%d, %d),' % (px, py))
        if op.get("piso"):
            entrada.append('\t\t"piso": true,')
        if op.get("balanceo"):
            entrada.append('\t\t"balanceo": true,')
        if op.get("variantes"):
            entrada.append('\t\t"variantes": {')
            for vid, (vnombre, diseno) in BANDERAS.items():
                bandera(diseno)().guardar("%s_%s" % (kind, vid))
                entrada.append('\t\t\t"%s": {"nombre": "%s", "textura": preload("res://objetos/ambiente/%s_%s.png")},' % (vid, vnombre, kind, vid))
            entrada.append('\t\t},')
        entrada.append('\t},')
        gd += entrada
        filas_sql.append("\t('%s', '%s', %d, 'decoracion',\n\t '%s')" % (kind, nombre.replace("'", "''"), precio, desc.replace("'", "''")))
        print("  ", kind)
    gd.append("}")
    sql.append(",\n".join(filas_sql))
    sql.append("on conflict (key) do nothing;")
    with open(os.path.join(RAIZ, "scripts", "objetos_ambiente.gd"), "w") as f:
        f.write("\n".join(gd) + "\n")
    with open(os.path.join(RAIZ, "sql", "objetos_ambiente.sql"), "w") as f:
        f.write("\n".join(sql) + "\n")
    print(len(OBJETOS), "objetos")

if __name__ == "__main__":
    main()
