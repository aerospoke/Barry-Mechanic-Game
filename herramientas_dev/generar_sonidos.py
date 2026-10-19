#!/usr/bin/env python3
# Genera todos los efectos y la musica del juego en res://sonidos/ (WAV mono
# 16 bits), sintetizados por codigo en estilo chiptune para que combinen con
# el pixel art. Sin dependencias: solo la libreria estandar de Python.
#
#   python3 herramientas_dev/generar_sonidos.py
#
# Para cambiar un sonido se edita su funcion aca y se vuelve a correr.
import math, random, struct, wave, os

SR = 22050
random.seed(7)
SALIDA = os.path.join(os.path.dirname(__file__), "..", "sonidos")

# --- Osciladores y envolventes ---------------------------------------------

def onda(tipo, fase):
    f = fase % 1.0
    if tipo == "sine":
        return math.sin(2 * math.pi * f)
    if tipo == "square":
        return 1.0 if f < 0.5 else -1.0
    if tipo == "pulse":  # cuadrada al 25%, mas "nintendo"
        return 1.0 if f < 0.25 else -1.0
    if tipo == "tri":
        return 4 * abs(f - 0.5) - 1
    if tipo == "saw":
        return 2 * f - 1
    return random.uniform(-1, 1)  # ruido

def tono(dur, f0, f1=None, tipo="square", vol=0.5, ataque=0.005, caida=None, vibrato=0.0):
    """Nota con barrido de frecuencia f0->f1 y envolvente lineal."""
    f1 = f0 if f1 is None else f1
    n = int(dur * SR)
    caida = dur if caida is None else caida
    fase, out = 0.0, []
    for i in range(n):
        t = i / SR
        p = i / max(n - 1, 1)
        f = f0 * (f1 / f0) ** p if f0 > 0 and f1 > 0 else f0 + (f1 - f0) * p
        if vibrato:
            f *= 1 + 0.03 * math.sin(2 * math.pi * vibrato * t)
        fase += f / SR
        env = min(1.0, t / ataque) if ataque > 0 else 1.0
        env *= max(0.0, 1 - t / caida)
        out.append(onda(tipo, fase) * env * vol)
    return out

def ruido(dur, vol=0.5, caida=None, pasa_bajos=0.0, crujido=0.0):
    """Ruido blanco; pasa_bajos (0..0.99) lo hace mas sordo; crujido corta al azar."""
    n = int(dur * SR)
    caida = dur if caida is None else caida
    prev, out = 0.0, []
    for i in range(n):
        t = i / SR
        x = random.uniform(-1, 1)
        prev = prev * pasa_bajos + x * (1 - pasa_bajos)
        env = max(0.0, 1 - t / caida)
        if crujido and random.random() < crujido:
            env *= random.choice([0, 0.2, 1.5])
        out.append(prev * env * vol)
    return out

def silencio(dur):
    return [0.0] * int(dur * SR)

def mezclar(*pistas):
    n = max(len(p) for p in pistas)
    out = [0.0] * n
    for p in pistas:
        for i, v in enumerate(p):
            out[i] += v
    return out

def seguido(*partes):
    out = []
    for p in partes:
        out += p
    return out

def en(t, pista):
    """Pista que arranca a los t segundos."""
    return silencio(t) + pista

def guardar(nombre, muestras, vol=0.9):
    pico = max(1e-6, max(abs(v) for v in muestras))
    escala = vol / pico if pico > vol else 1.0
    with wave.open(os.path.join(SALIDA, nombre + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * escala)) * 32767)) for v in muestras))
    print("  ", nombre, f"{len(muestras) / SR:.2f}s")

def roce(dur, sube=True, vol=0.5):
    """Roce de mano/tela: ruido filtrado que se abre (o se cierra) y se
    apaga suave. Es el "fuuh" de mover algo rapido."""
    n = int(dur * SR)
    out, y = [], 0.0
    for i in range(n):
        p = i / n
        corte = 0.03 + (0.25 * p if sube else 0.25 * (1 - p))
        y += corte * (random.uniform(-1, 1) - y)
        env = math.sin(math.pi * p) ** 1.5
        out.append(y * env * vol * 3)
    return out

def golpecito(f=170, dur=0.07, vol=0.6, brillo=0.25):
    """Toque de un objeto chico contra la mano o una mesa: cuerpo grave muy
    corto + un click apenas brillante."""
    n = int(dur * SR)
    cuerpo = [math.sin(2 * math.pi * f * (1 - 0.3 * i / n) * i / SR) * math.exp(-i / SR / 0.02) for i in range(n)]
    click = [random.uniform(-1, 1) * math.exp(-i / SR / 0.003) * brillo for i in range(n)]
    return [(c + k) * vol for c, k in zip(cuerpo, click)]

def pop_suave(f0, f1, dur=0.08, vol=0.4):
    """Seno redondo que sube de tono, con forma de campana: un "pop" de
    juego sin sonar a consola."""
    n = int(dur * SR)
    fase, out = 0.0, []
    for i in range(n):
        fase += (f0 + (f1 - f0) * i / n) / SR
        out.append(math.sin(2 * math.pi * fase) * math.sin(math.pi * i / n) * vol)
    return out

def burbuja(f0, f1, dur, vol=0.5):
    """Burbuja: seno cuyo tono SUBE rapido mientras se apaga (asi suenan las
    burbujas de verdad al reventar). Ataque suave para que no haga click."""
    n = int(dur * SR)
    fase, out = 0.0, []
    for i in range(n):
        t = i / SR
        p = i / n
        f = f0 * (f1 / f0) ** (p ** 0.6)
        fase += f / SR
        env = min(1.0, t / 0.004) * math.exp(-t / (dur * 0.35))
        out.append(math.sin(2 * math.pi * fase) * env * vol)
    return out

def agarrar():
    # "Blup-blip": una burbuja grande y otra chiquita mas aguda.
    return mezclar(burbuja(260, 820, 0.12, 0.55), en(0.07, burbuja(520, 1400, 0.08, 0.3)))

def soltar():
    # Lo contrario de agarrar: "blip-blup", una burbuja chiquita y otra
    # grande que BAJAN de tono, como algo que se deja caer en el agua.
    return mezclar(burbuja(1100, 520, 0.07, 0.3), en(0.05, burbuja(700, 220, 0.14, 0.55)))

# --- Efectos -----------------------------------------------------------------

def efectos():
    guardar("boton", tono(0.06, 700, 1100, "pulse", 0.35, caida=0.06))
    guardar("moneda", seguido(tono(0.07, 988, tipo="square", vol=0.35), tono(0.28, 1319, tipo="square", vol=0.35, caida=0.28)))
    guardar("acierto", seguido(*[tono(0.06, f, tipo="pulse", vol=0.35, caida=0.09) for f in (784, 988, 1175, 1568)]))
    guardar("error", mezclar(tono(0.28, 220, 120, "saw", 0.35), tono(0.28, 226, 124, "square", 0.2)))
    guardar("victoria", seguido(
        *[tono(0.1, f, tipo="square", vol=0.3, caida=0.14) for f in (523, 659, 784)],
        mezclar(tono(0.5, 1047, tipo="square", vol=0.3, vibrato=6), tono(0.5, 523, tipo="tri", vol=0.4)),
    ))
    guardar("confeti", mezclar(ruido(0.12, 0.5, pasa_bajos=0.3), *[en(0.03 * i, tono(0.08, random.uniform(1500, 2600), tipo="sine", vol=0.25)) for i in range(6)]))
    guardar("gota", tono(0.09, 950, 420, "sine", 0.5, ataque=0.002))
    guardar("splash", mezclar(ruido(0.18, 0.4, pasa_bajos=0.6), tono(0.1, 300, 150, "sine", 0.3)))
    guardar("click", mezclar(ruido(0.025, 0.6), tono(0.03, 2400, 1800, "square", 0.25)))
    guardar("abrir", seguido(
        mezclar(ruido(0.03, 0.6), tono(0.04, 1800, tipo="square", vol=0.2)), silencio(0.05),
        mezclar(ruido(0.05, 0.6, pasa_bajos=0.4), tono(0.25, 160, 90, "sine", 0.6)),
    ))
    guardar("chispazo", mezclar(ruido(0.35, 0.7, crujido=0.15), tono(0.35, 120, 60, "saw", 0.25)))
    guardar("pum", mezclar(ruido(0.55, 0.9, pasa_bajos=0.85), tono(0.5, 90, 35, "sine", 0.9)))
    guardar("aire", ruido(0.18, 0.45, pasa_bajos=0.5))
    guardar("spray", ruido(0.1, 0.3, pasa_bajos=0.1))
    guardar("encajar", seguido(tono(0.06, 200, 120, "sine", 0.7), mezclar(ruido(0.02, 0.5), tono(0.05, 1600, tipo="pulse", vol=0.25))))
    guardar("tirar", seguido(tono(0.12, 180, 70, "sine", 0.7), ruido(0.15, 0.35, crujido=0.3)))
    guardar("agarrar", agarrar())
    guardar("soltar", soltar())
    guardar("miau", mezclar(
        tono(0.45, 560, 880, "sine", 0.4, ataque=0.04, vibrato=7),
        tono(0.45, 1120, 1760, "tri", 0.12, ataque=0.04, vibrato=7),
    ))

# --- Musica ------------------------------------------------------------------
# Instrumentos "de banda" (bajo, guitarra con distorsion, organo, piano
# electrico, bateria) en vez de ondas chiptune puras: suena a taller, no a
# consola. Cada cancion es un loop que empalma sin corte (las colas de las
# notas que pasan del final se mezclan al principio).

NOTAS = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

def freq(nota):
    """'C4', 'F#3', 'Bb2'... -> Hz."""
    base = NOTAS[nota[0]]
    resto = nota[1:]
    if resto[0] == "#":
        base, resto = base + 1, resto[1:]
    elif resto[0] == "b":
        base, resto = base - 1, resto[1:]
    return 440.0 * 2 ** ((base + 12 * (int(resto) + 1) - 69) / 12)

def pasa_bajos(muestras, corte):
    """Filtro de un polo; corte 0..1 (mas bajo = mas sordo)."""
    out, y = [], 0.0
    for x in muestras:
        y += corte * (x - y)
        out.append(y)
    return out

def pasa_altos(muestras, corte):
    bajo = pasa_bajos(muestras, corte)
    return [x - b for x, b in zip(muestras, bajo)]

def env_exp(n, caida):
    """Envolvente de pluck: ataque instantaneo y caida exponencial."""
    return [math.exp(-i / SR / caida) for i in range(n)]

def osc(tipo, f, dur, detune=0.0):
    n = int(dur * SR)
    fase, fase2, out = random.random(), random.random(), []
    for i in range(n):
        fase += f / SR
        v = onda(tipo, fase)
        if detune:
            fase2 += f * (1 + detune) / SR
            v = (v + onda(tipo, fase2)) * 0.5
        out.append(v)
    return out

# Instrumentos: cada uno devuelve muestras para una nota.

def bajo_electrico(nota, dur, brillo=0.06, vol=0.55):
    f = freq(nota)
    m = pasa_bajos(osc("saw", f, dur), brillo)
    m = [v + 0.6 * math.sin(2 * math.pi * f * i / SR) for i, v in enumerate(m)]
    return [v * e * vol for v, e in zip(m, env_exp(len(m), dur * 0.7))]

def bajo_slap(nota, dur, vol=0.55):
    # Ataque brillante que se apaga rapido: el "slap".
    f = freq(nota)
    crudo = osc("saw", f, dur)
    sordo = pasa_bajos(crudo, 0.04)
    n = len(crudo)
    return [(s + c * math.exp(-i / SR / 0.03) * 0.6) * math.exp(-i / SR / (dur * 0.5)) * vol
            for i, (c, s) in enumerate(zip(crudo, sordo))]

def guitarra(notas, dur, distorsion=4.0, apagada=False, vol=0.25, brillo=0.25, tremolo=0.0):
    # Acorde de guitarra electrica: sierras levemente desafinadas, saturadas.
    n = int(dur * SR)
    m = [0.0] * n
    for nota in notas:
        for i, v in enumerate(osc("saw", freq(nota), dur, detune=0.004)):
            m[i] += v
    m = [math.tanh(v * distorsion) for v in m]
    m = pasa_bajos(m, brillo)
    caida = 0.07 if apagada else dur * 0.9
    env = env_exp(n, caida)
    if tremolo:
        env = [e * (0.6 + 0.4 * math.sin(2 * math.pi * tremolo * i / SR)) for i, e in enumerate(env)]
    return [v * e * vol for v, e in zip(m, env)]

def organo(notas, dur, vol=0.12):
    n = int(dur * SR)
    m = [0.0] * n
    for nota in notas:
        f = freq(nota)
        for i in range(n):
            t = i / SR
            m[i] += (math.sin(2 * math.pi * f * t) + 0.5 * math.sin(4 * math.pi * f * t)
                     + 0.25 * math.sin(6 * math.pi * f * t))
    ataque = int(0.02 * SR)
    return [v * vol * min(1, i / ataque) * min(1, (n - i) / ataque) * (0.85 + 0.15 * math.sin(2 * math.pi * 6 * i / SR))
            for i, v in enumerate(m)]

def piano_e(notas, dur, vol=0.18, caida=None):
    # Piano electrico (tipo Rhodes): seno + armonico con caida.
    n = int(dur * SR)
    caida = caida or dur * 0.6
    m = [0.0] * n
    for nota in notas:
        f = freq(nota)
        for i in range(n):
            t = i / SR
            m[i] += (math.sin(2 * math.pi * f * t) + 0.35 * math.sin(4 * math.pi * f * t) * math.exp(-t / 0.08)) * math.exp(-t / caida)
    return [v * vol for v in m]

def marimba(nota, dur, vol=0.3):
    f = freq(nota)
    n = int(dur * SR)
    return [(math.sin(2 * math.pi * f * i / SR) + 0.15 * math.sin(2 * math.pi * f * 4 * i / SR) * math.exp(-i / SR / 0.02))
            * math.exp(-i / SR / 0.25) * vol for i in range(n)]

def sinte(nota, dur, vol=0.18, brillo=0.15):
    m = pasa_bajos(osc("saw", freq(nota), dur, detune=0.006), brillo)
    return [v * e * vol for v, e in zip(m, env_exp(len(m), dur * 0.8))]

def bombo(vol=0.8):
    n = int(0.3 * SR)
    fase, out = 0.0, []
    for i in range(n):
        t = i / SR
        fase += (45 + 110 * math.exp(-t / 0.03)) / SR
        out.append(math.sin(2 * math.pi * fase) * math.exp(-t / 0.12) * vol)
    return out

def caja(vol=0.45, cepillo=False):
    n = int(0.2 * SR)
    r = pasa_altos([random.uniform(-1, 1) for _ in range(n)], 0.08)
    if cepillo:
        return [v * math.exp(-i / SR / 0.09) * vol * 0.5 for i, v in enumerate(pasa_bajos(r, 0.3))]
    return [(v * 0.8 + 0.5 * math.sin(2 * math.pi * 190 * i / SR)) * math.exp(-i / SR / 0.06) * vol
            for i, v in enumerate(r)]

def platillo(abierto=False, vol=0.12):
    n = int((0.25 if abierto else 0.05) * SR)
    r = pasa_altos([random.uniform(-1, 1) for _ in range(n)], 0.5)
    return [v * math.exp(-i / SR / (0.12 if abierto else 0.015)) * vol for i, v in enumerate(r)]

def palmas(vol=0.35):
    out = []
    for k in range(3):
        out += [random.uniform(-1, 1) * math.exp(-i / SR / 0.004) * vol for i in range(int(0.012 * SR))]
    cola = [random.uniform(-1, 1) * math.exp(-i / SR / 0.05) * vol * 0.6 for i in range(int(0.12 * SR))]
    return pasa_altos(out + cola, 0.15)

def metal(vol=0.12):
    # Golpe de llave sobre metal: parciales inarmonicos. Ambiente de taller.
    f = random.uniform(1800, 3200)
    n = int(0.5 * SR)
    return [(math.sin(2 * math.pi * f * i / SR) + 0.6 * math.sin(2 * math.pi * f * 2.76 * i / SR)
             + 0.4 * math.sin(2 * math.pi * f * 5.4 * i / SR)) * math.exp(-i / SR / 0.12) * vol for i in range(n)]

class Cancion:
    """Loop de `compases` compases de 4/4 a `bpm`. Se ubica todo en
    semicorcheas (16 por compas); se aceptan pasos con decimales (swing)."""

    def __init__(self, bpm, compases):
        self.semi = 60 / bpm / 4
        self.n = int(compases * 16 * self.semi * SR)
        self.buf = [0.0] * self.n
        self.compases = compases

    def poner(self, paso, muestras, vol=1.0):
        inicio = int(paso * self.semi * SR)
        for i, v in enumerate(muestras):
            self.buf[(inicio + i) % self.n] += v * vol

    def dur(self, semis):
        return semis * self.semi

    def bateria(self, patron, swing=0.0, vol=1.0, cepillo=False):
        """Patron de 16 pasos por compas: k bombo, s caja, h platillo,
        o platillo abierto, c palmas, m metal, '.' nada."""
        for compas in range(self.compases):
            for i, g in enumerate(patron):
                paso = compas * 16 + i + (swing if i % 2 else 0)
                if g == "k": self.poner(paso, bombo(), vol)
                elif g == "s": self.poner(paso, caja(cepillo=cepillo), vol)
                elif g == "h": self.poner(paso, platillo(), vol)
                elif g == "o": self.poner(paso, platillo(True), vol)
                elif g == "c": self.poner(paso, palmas(), vol)
                elif g == "m": self.poner(paso, metal(0.2), vol)

    def doble(self):
        """Repite el loop dos veces y cierra la segunda con un redoble de
        caja que crece: la cancion dura el doble y no se siente tan corta."""
        largo = self.n
        self.buf = self.buf + self.buf
        self.n = largo * 2
        ultimo = self.compases * 2 * 16 - 8
        for k in range(8):
            self.poner(ultimo + k, caja(), 0.35 + k * 0.08)
        return self.buf

    def ambiente_taller(self, golpes=6, vol=1.0):
        # Llaves y herramientas que suenan de fondo, al azar.
        for _ in range(golpes):
            self.poner(random.uniform(0, self.compases * 16), metal(), vol)

def bajo_808(nota, dur, vol=0.7):
    """808 de reggaeton: seno grave con golpe de tono al inicio y un poco
    saturado para que se escuche en parlantes de telefono."""
    f = freq(nota)
    n = int(dur * SR)
    fase, out = 0.0, []
    for i in range(n):
        t = i / SR
        fase += f * (1 + 1.5 * math.exp(-t / 0.015)) / SR
        v = math.tanh(2.2 * math.sin(2 * math.pi * fase))
        out.append(v * math.exp(-t / max(dur * 0.8, 0.05)) * min(1, (n - i) / 200) * vol)
    return out

def aro(vol=0.35):
    """Aro de caja ("rim"), el "chick" del dembow."""
    n = int(0.06 * SR)
    r = pasa_altos([random.uniform(-1, 1) for _ in range(n)], 0.3)
    return [(v * 0.6 + 0.5 * math.sin(2 * math.pi * 1700 * i / SR)) * math.exp(-i / SR / 0.012) * vol
            for i, v in enumerate(r)]

def taller():
    # Reggaeton de taller, en La menor, 94 BPM: dembow, 808, gancho de
    # sintetizador y golpes de herramientas metidos como percusion.
    c = Cancion(94, 8)
    progresion = [("A", ["A3", "C4", "E4"]), ("F", ["F3", "A3", "C4"]),
                  ("C", ["C4", "E4", "G4"]), ("G", ["G3", "B3", "D4"])]
    gancho = [  # (paso dentro del compas, nota)
        [(0, "E5"), (3, "C5"), (6, "E5"), (8, "D5"), (11, "C5"), (14, "A4")],
        [(0, "C5"), (3, "A4"), (6, "C5"), (8, "C5"), (11, "D5"), (14, "C5")],
        [(0, "E5"), (3, "G5"), (6, "E5"), (8, "D5"), (11, "C5"), (14, "D5")],
        [(0, "B4"), (3, "D5"), (6, "B4"), (8, "G4"), (12, "A4"), (14, "B4")],
    ]
    for compas in range(8):
        raiz, acorde = progresion[compas % 4]
        base = compas * 16
        # 808 con el ritmo "pum... pum-pum".
        for paso, largo in ((0, 6), (6, 4), (10, 6)):
            c.poner(base + paso, bajo_808(raiz + "1", c.dur(largo)))
        # Acorde de fondo suave y gancho de sinte (la primera vuelta solo
        # acordes, la segunda entra el gancho).
        c.poner(base, piano_e(acorde, c.dur(16), vol=0.05, caida=1.2))
        if compas >= 4:
            for paso, nota in gancho[compas % 4]:
                c.poner(base + paso, sinte(nota, c.dur(2), vol=0.13, brillo=0.2))
        else:
            for paso in (0, 3, 6, 8, 11, 14):
                c.poner(base + paso, marimba(acorde[(paso // 3) % 3][:-1] + "5", c.dur(2), vol=0.12))
        # Llave que golpea metal en el contratiempo cada dos compases.
        if compas % 2 == 1:
            c.poner(base + 14, metal(0.18))
    # Dembow: bombo en cada negra, aro en el "chick" (3, 6, 11, 14).
    c.bateria("k...k...k...k...")
    for compas in range(8):
        for paso in (3, 6, 11, 14):
            c.poner(compas * 16 + paso, aro())
    c.bateria("h.h.h.h.h.h.h.h.", vol=0.7)
    c.bateria("..o...o...o...o.", vol=0.35)
    # Redoble para volver a empezar.
    for k in range(8):
        c.poner(8 * 16 - 8 + k, aro(), 0.4 + k * 0.08)
    return c.buf

def aceite():
    # Funk lento y "aceitoso" en Mi menor, 100 BPM: bajo slap y piano electrico.
    c = Cancion(100, 4)
    patron = [(0, "E2"), (3, "E2"), (6, "G2"), (7, "A2"), (10, "E2"), (12, "D3"), (14, "B2")]
    for compas in range(4):
        for paso, nota in patron:
            c.poner(compas * 16 + paso, bajo_slap(nota, c.dur(2)))
        acorde = [["E3", "G3", "B3", "D4"], ["A3", "C4", "E4", "G4"]][compas % 2]
        for paso in (2, 9):
            c.poner(compas * 16 + paso, piano_e(acorde, c.dur(3), vol=0.09, caida=0.15))
        for paso in range(0, 16, 2):
            c.poner(compas * 16 + paso + 1, guitarra(["E4"], c.dur(1), apagada=True, vol=0.06, brillo=0.5))
    c.bateria("k..k..s...k...s.")
    c.bateria("hhhhhhhohhhhhhho", vol=0.6)
    return c.doble()

def cerradura():
    # Espias / robo, en La menor, 112 BPM: bajo que camina, guitarra con
    # tremolo y platillo que hace tic-tac.
    c = Cancion(112, 4)
    camino = ["A2", "A2", "C3", "A2", "D#3", "E3", "C3", "B2"]
    for compas in range(4):
        for k, nota in enumerate(camino):
            c.poner(compas * 16 + k * 2, bajo_electrico(nota, c.dur(2), brillo=0.08))
    melodia = [(0, "A4", 4), (4, "C5", 2), (6, "B4", 2), (8, "E4", 6), (16, "F4", 4), (20, "E4", 2), (22, "D#4", 2), (24, "E4", 8),
               (32, "A4", 4), (36, "C5", 2), (38, "E5", 2), (40, "D5", 6), (48, "C5", 2), (50, "B4", 2), (52, "G#4", 4), (56, "A4", 8)]
    for paso, nota, largo in melodia:
        c.poner(paso, guitarra([nota], c.dur(largo), distorsion=2.0, vol=0.14, brillo=0.3, tremolo=9))
    c.bateria("k.......k.k.....")
    c.bateria("..s.....s.....s.", vol=0.4)
    c.bateria("h.h.h.h.h.h.h.h.", vol=0.6)
    return c.doble()

def filtro():
    # Rock de garaje alegre, en La, 128 BPM: guitarras en corcheas apagadas.
    c = Cancion(128, 4)
    for compas, (r, q) in enumerate([("A2", "E3"), ("E2", "B2"), ("F#2", "C#3"), ("D2", "A2")]):
        for k in range(8):
            c.poner(compas * 16 + k * 2, bajo_electrico(r, c.dur(2), brillo=0.1))
            c.poner(compas * 16 + k * 2, guitarra([r[:-1] + "3", q[:-1] + "3"], c.dur(2), apagada=k % 4 != 0, vol=0.22))
    c.bateria("k.h.s.h.k.k.s.h.")
    return c.doble()

def cables():
    # Electronica tipo hackeo, en Re menor, 124 BPM: arpegio de sintetizador,
    # bombo a negras y platillo a contratiempo.
    c = Cancion(124, 4)
    acordes = [["D3", "F3", "A3", "D4"], ["Bb2", "D3", "F3", "Bb3"], ["C3", "E3", "G3", "C4"], ["A2", "C#3", "E3", "A3"]]
    for compas, acorde in enumerate(acordes):
        for k in range(16):
            nota = acorde[k % 4]
            nota = nota[:-1] + str(int(nota[-1]) + 1)
            c.poner(compas * 16 + k, sinte(nota, c.dur(1), vol=0.12, brillo=0.1 + 0.15 * (k / 16)))
        c.poner(compas * 16, bajo_electrico(acorde[0][:-1] + "2", c.dur(16), brillo=0.03, vol=0.45))
    c.bateria("k...k...k...k...")
    c.bateria("..o...o...o...o.", vol=0.8)
    c.bateria("....c.......c...", vol=0.8)
    return c.doble()

def herramientas():
    # Lo-fi tranquilo para pensar, en Fa, 85 BPM: piano electrico con
    # acordes de septima y marimba.
    c = Cancion(85, 4)
    acordes = [["F3", "A3", "C4", "E4"], ["D3", "F3", "A3", "C4"], ["G3", "Bb3", "D4", "F4"], ["C3", "E3", "G3", "Bb3"]]
    melodia = ["C5", "A4", "F4", "G4", "A4", "-", "D5", "C5", "Bb4", "-", "A4", "G4", "E4", "-", "G4", "-"]
    for compas, acorde in enumerate(acordes):
        c.poner(compas * 16, piano_e(acorde, c.dur(14), vol=0.08))
        c.poner(compas * 16 + 10, piano_e(acorde[1:], c.dur(5), vol=0.05))
        c.poner(compas * 16, bajo_electrico(acorde[0][:-1] + "2", c.dur(8), brillo=0.03, vol=0.4))
        for k in range(4):
            nota = melodia[(compas * 4 + k) % len(melodia)]
            if nota != "-":
                c.poner(compas * 16 + k * 4 + (2 if k % 2 else 0), marimba(nota, c.dur(4), vol=0.2))
    c.bateria("k.....k...s.....", swing=0.4, vol=0.8)
    c.bateria("h.h.h.h.h.h.h.h.", swing=0.4, vol=0.4)
    # Ruidito de disco viejo.
    for i in range(0, c.n, 40):
        if random.random() < 0.02:
            c.buf[i] += random.uniform(-0.05, 0.05)
    return c.doble()

def inflar():
    # Concurso con tension, en Do, 118 BPM: piano en staccato que sube y
    # palmas.
    c = Cancion(118, 4)
    for compas, (r, acorde) in enumerate([("C2", ["C4", "E4", "G4"]), ("D2", ["D4", "F#4", "A4"]),
                                          ("E2", ["E4", "G#4", "B4"]), ("G2", ["G4", "B4", "D5"])]):
        for k in range(8):
            c.poner(compas * 16 + k * 2, bajo_electrico(r if k % 2 == 0 else r[:-1] + "3", c.dur(2), brillo=0.08, vol=0.45))
        for paso in (0, 3, 6, 10, 12):
            c.poner(compas * 16 + paso, piano_e(acorde, c.dur(1), vol=0.08, caida=0.06))
    c.bateria("k.k...c.k.k...c.")
    c.bateria("hhhhhhhhhhhhhhhh", vol=0.5)
    return c.doble()

def pintura():
    # Jazz suave, ii-V-I en Si bemol, 96 BPM: contrabajo caminando, piano y
    # escobillas.
    c = Cancion(96, 4)
    caminata = [["C3", "D3", "Eb3", "E3"], ["F2", "A2", "C3", "A2"], ["Bb2", "D3", "F3", "D3"], ["Bb2", "C3", "D3", "E3"]]
    acordes = [["C4", "Eb4", "G4", "Bb4"], ["F3", "A3", "Eb4", "G4"], ["Bb3", "D4", "F4", "A4"], ["Bb3", "D4", "F4", "A4"]]
    for compas in range(4):
        for k, nota in enumerate(caminata[compas]):
            c.poner(compas * 16 + k * 4, bajo_electrico(nota, c.dur(4), brillo=0.025, vol=0.5))
        c.poner(compas * 16 + 2.66, piano_e(acordes[compas], c.dur(4), vol=0.07))
        c.poner(compas * 16 + 10.66, piano_e(acordes[compas], c.dur(3), vol=0.06))
    c.bateria("....s.......s...", cepillo=True)
    c.bateria("h...h.h.h...h.h.", swing=0.66, vol=0.6)
    return c.doble()

def reciclaje():
    # Fabrica en marcha, en Sol menor, 120 BPM: bajo sintetizado, bombo
    # constante y golpes metalicos como percusion (la cinta transportadora).
    c = Cancion(120, 4)
    for compas, r in enumerate(["G2", "G2", "Eb2", "F2"]):
        for k, paso in enumerate((0, 3, 6, 8, 11, 14)):
            c.poner(compas * 16 + paso, bajo_slap(r if k != 4 else r[:-1] + "3", c.dur(2), vol=0.45))
    c.bateria("k...k...k...k...")
    c.bateria("..m...m...m..m.m", vol=0.7)
    c.bateria("....s.......s...", vol=0.8)
    c.bateria("hhohhhohhhohhhoh", vol=0.4)
    return c.doble()

CANCIONES = {
    "musica_taller": taller,
    "musica_aceite": aceite,
    "musica_cerradura": cerradura,
    "musica_filtro": filtro,
    "musica_cables": cables,
    "musica_herramientas": herramientas,
    "musica_inflar": inflar,
    "musica_pintura": pintura,
    "musica_reciclaje": reciclaje,
}

if __name__ == "__main__":
    import sys
    os.makedirs(SALIDA, exist_ok=True)
    solo_musica = "--musica" in sys.argv
    if not solo_musica:
        print("Efectos:")
        efectos()
    print("Musica:")
    for nombre, cancion in CANCIONES.items():
        random.seed(nombre)
        guardar(nombre, cancion(), vol=0.75)
