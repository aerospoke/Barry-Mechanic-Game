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
    """Cancion de `compases` compases de 4/4 a `bpm`, en loop: se ubica todo
    en semicorcheas (16 por compas, se aceptan decimales para el swing) y
    las colas que pasan del final se mezclan al principio."""

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

    def bateria(self, compas, patron, swing=0.0, vol=1.0, cepillo=False):
        """Un compas de bateria. Patron de 16 pasos: k bombo, s caja,
        h platillo, o platillo abierto, c palmas, r aro, m metal, '.' nada."""
        for i, g in enumerate(patron):
            paso = compas * 16 + i + (swing if i % 2 else 0)
            if g == "k": self.poner(paso, bombo(), vol)
            elif g == "s": self.poner(paso, caja(cepillo=cepillo), vol)
            elif g == "h": self.poner(paso, platillo(), vol)
            elif g == "o": self.poner(paso, platillo(True), vol)
            elif g == "c": self.poner(paso, palmas(), vol)
            elif g == "r": self.poner(paso, aro(), vol)
            elif g == "m": self.poner(paso, metal(0.2), vol)

    def redoble(self, compas, golpe=None):
        """Redoble que crece en la segunda mitad del compas: avisa que viene
        otra parte de la cancion."""
        for k in range(8):
            self.poner(compas * 16 + 8 + k, golpe() if golpe else caja(), 0.3 + k * 0.08)

# --- Estructura ----------------------------------------------------------------
# Todas las canciones duran ~1 minuto y tienen partes, para no cansar:
#   intro -> A -> B -> puente (sin bombo) -> A -> B ... -> vuelta al inicio.
# Las melodias de cada parte se componen a partir de los acordes con una
# semilla por cancion y parte: siempre salen iguales, pero A y B son distintas.

def plan(total):
    partes = [("intro", 2), ("A", 8), ("B", 8), ("puente", 4)]
    resto = total - 22
    if resto >= 12:
        partes += [("A", 8), ("B", resto - 8)]
    else:
        partes.append(("A", max(resto, 2)))
    compases = []
    for nombre, largo in partes:
        for i in range(largo):
            compases.append((nombre, i, i == largo - 1))
    return compases

RITMOS = [
    [0, 3, 6, 8, 11, 14],
    [0, 2, 4, 7, 10, 12],
    [0, 4, 6, 10, 12, 14],
    [0, 3, 4, 7, 8, 12],
    [2, 4, 6, 10, 14],
    [0, 6, 8, 10, 12],
]

def subir(nota, octavas):
    return nota[:-1] + str(int(nota[-1]) + octavas)

class Melodista:
    """Inventa la melodia de cada parte: un ritmo y una secuencia de grados
    del acorde, que se adapta solo a cada acorde del compas."""

    def __init__(self, cancion):
        self.cancion = cancion
        self.partes = {}

    def compas(self, parte, i, notas_acorde):
        if parte not in self.partes:
            rnd = random.Random(self.cancion + "-" + parte)
            ritmo = rnd.choice(RITMOS)
            grados = [rnd.choice([0, 1, 2, 2, 1, 3]) for _ in range(len(ritmo) * 2)]
            self.partes[parte] = (ritmo, grados)
        ritmo, grados = self.partes[parte]
        escala = notas_acorde + [subir(n, 1) for n in notas_acorde]
        salida = []
        for k, paso in enumerate(ritmo):
            # Compases pares e impares usan mitades distintas de la secuencia.
            g = grados[k + (i % 2) * len(ritmo)]
            siguiente = ritmo[k + 1] if k + 1 < len(ritmo) else 16
            # Cada 4 compases la ultima nota se estira: respira la frase.
            largo = siguiente - paso if not (i % 4 == 3 and k == len(ritmo) - 1) else 4
            salida.append((paso, escala[min(g, len(escala) - 1)], largo))
        return salida

def componer(nombre, bpm, progresion, capas):
    """`progresion`: lista de acordes, uno por compas (se repite).
    Cada acorde: (raiz con octava para el bajo, [notas del acorde]).
    `capas`: funciones f(c, compas, parte, i, acorde, melodista)."""
    total = max(16, round(bpm / 4))
    c = Cancion(bpm, total)
    melodista = Melodista(nombre)
    random.seed(nombre)
    for compas, (parte, i, ultimo) in enumerate(plan(total)):
        acorde = progresion[compas % len(progresion)]
        for capa in capas:
            capa(c, compas, parte, i, acorde, melodista)
        if ultimo and parte != "intro":
            c.redoble(compas)
    return c.buf

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


# --- Instrumentos de los generos de la radio -----------------------------------

def cuerda(nota, dur, vol=0.3, brillo=0.5, apagar=0.996):
    """Cuerda pulsada real (algoritmo Karplus-Strong): guitarra acustica,
    requinto. `brillo` alto = mas metalica."""
    f = freq(nota)
    largo = max(2, int(SR / f))
    buf = [random.uniform(-1, 1) for _ in range(largo)]
    out, idx = [], 0
    for _ in range(int(dur * SR)):
        v = buf[idx]
        sig = buf[(idx + 1) % largo]
        buf[idx] = apagar * (brillo * v + (1 - brillo) * 0.5 * (v + sig))
        out.append(v * vol)
        idx = (idx + 1) % largo
    return out

def rasgueo(notas, dur, vol=0.18, hacia_arriba=False, brillo=0.5):
    """Acorde rasgueado: cada cuerda entra unos milisegundos despues."""
    orden = list(reversed(notas)) if hacia_arriba else notas
    pistas = [en(k * 0.012, cuerda(n, dur, vol, brillo)) for k, n in enumerate(orden)]
    return mezclar(*pistas)

def acordeon(notas, dur, vol=0.07):
    n = int(dur * SR)
    m = [0.0] * n
    for nota in notas:
        for k, v in enumerate(osc("saw", freq(nota), dur, detune=0.007)):
            m[k] += v
    m = pasa_bajos(m, 0.18)
    ataque = int(0.025 * SR)
    return [v * vol * min(1, k / ataque) * min(1, (n - k) / ataque) * (0.85 + 0.15 * math.sin(2 * math.pi * 5.5 * k / SR))
            for k, v in enumerate(m)]

def raspado(vol=0.25, dur=0.07, brillo=0.35):
    """Guacharaca / guira: ruido agudo que crece y se corta (rascar)."""
    n = int(dur * SR)
    r = pasa_altos([random.uniform(-1, 1) for _ in range(n)], brillo)
    return [v * (k / n) ** 0.7 * vol for k, v in enumerate(r)]

def cencerro(vol=0.18):
    n = int(0.12 * SR)
    return [((1 if (k * 562 / SR) % 1 < 0.5 else -1) + (1 if (k * 845 / SR) % 1 < 0.5 else -1))
            * math.exp(-k / SR / 0.04) * vol * 0.5 for k in range(n)]

def conga(f=210, vol=0.4, golpe=False):
    n = int(0.25 * SR)
    fase, out = 0.0, []
    for k in range(n):
        t = k / SR
        fase += f * (1 + 0.3 * math.exp(-t / 0.01)) / SR
        out.append(math.sin(2 * math.pi * fase) * math.exp(-t / (0.06 if golpe else 0.14)) * vol)
    if golpe:
        out = mezclar(out, [random.uniform(-1, 1) * math.exp(-k / SR / 0.008) * vol * 0.6 for k in range(n)])
    return out

def maracas(vol=0.12):
    n = int(0.05 * SR)
    r = pasa_altos([random.uniform(-1, 1) for _ in range(n)], 0.5)
    return [v * math.sin(math.pi * k / n) * vol for k, v in enumerate(r)]

def metales(notas, dur, vol=0.09):
    """Seccion de metales (trompetas): sierras con filtro que se abre."""
    n = int(dur * SR)
    m = [0.0] * n
    for nota in notas:
        for k, v in enumerate(osc("saw", freq(nota), dur, detune=0.005)):
            m[k] += v
    out, y = [], 0.0
    for k, x in enumerate(m):
        corte = 0.04 + 0.25 * min(1, k / (0.05 * SR))
        y += corte * (x - y)
        out.append(y * vol * min(1, (n - k) / 300))
    return out

def campana(nota, dur=0.8, vol=0.18):
    f = freq(nota)
    n = int(dur * SR)
    return [(math.sin(2 * math.pi * f * k / SR) + 0.4 * math.sin(2 * math.pi * f * 2.76 * k / SR) * math.exp(-k / SR / 0.1))
            * math.exp(-k / SR / (dur * 0.4)) * vol for k in range(n)]

def log_drum(nota, dur=0.35, vol=0.45):
    """Log drum del amapiano/afrobeats: grave con caida de tono y saturado."""
    f = freq(nota)
    n = int(dur * SR)
    fase, out = 0.0, []
    for k in range(n):
        t = k / SR
        fase += f * (1 + 0.6 * math.exp(-t / 0.02)) / SR
        out.append(math.tanh(1.8 * math.sin(2 * math.pi * fase)) * math.exp(-t / (dur * 0.5)) * vol)
    return out

# --- Canciones -------------------------------------------------------------------

def taller():
    # Reggaeton de taller, La menor, 94 BPM: dembow, 808, marimba/sinte y
    # golpes de herramientas.
    prog = [("A1", ["A3", "C4", "E4"]), ("F1", ["F3", "A3", "C4"]),
            ("C2", ["C4", "E4", "G4"]), ("G1", ["G3", "B3", "D4"])]

    def bajo(c, compas, parte, i, acorde, m):
        if parte == "intro":
            return
        figura = ((0, 6), (6, 4), (10, 6)) if parte != "puente" else ((0, 16),)
        for paso, largo in figura:
            c.poner(compas * 16 + paso, bajo_808(acorde[0], c.dur(largo)))

    def armonia(c, compas, parte, i, acorde, m):
        c.poner(compas * 16, piano_e(acorde[1], c.dur(16), vol=0.05, caida=1.2))

    def melodia(c, compas, parte, i, acorde, m):
        if parte == "intro":
            return
        notas = [subir(n, 1) for n in acorde[1]]
        for paso, nota, largo in m.compas(parte, i, notas):
            if parte == "A":
                c.poner(compas * 16 + paso, marimba(nota, c.dur(largo + 1), vol=0.14))
            elif parte == "B":
                c.poner(compas * 16 + paso, sinte(nota, c.dur(largo), vol=0.12, brillo=0.2))
            elif parte == "puente" and paso % 4 == 0:
                c.poner(compas * 16 + paso, piano_e([nota], c.dur(4), vol=0.08))

    def bateria(c, compas, parte, i, acorde, m):
        if parte == "intro":
            c.bateria(compas, "h.h.h.h.h.h.h.h.", vol=0.5)
            return
        if parte != "puente":
            c.bateria(compas, "k...k...k...k...")
        c.bateria(compas, "...r..r....r..r.")
        c.bateria(compas, "h.h.h.h.h.h.h.h." if parte != "B" else "hhh.hhh.hhh.hhh.", vol=0.6)
        if parte == "B":
            c.bateria(compas, "..o...o...o...o.", vol=0.35)
        if i % 2 == 1:
            c.poner(compas * 16 + 14, metal(0.18))

    return componer("taller", 94, prog, [bajo, armonia, melodia, bateria])

def aceite():
    # Funk aceitoso, Mi menor, 100 BPM: bajo slap, piano electrico, guitarra
    # rascada.
    prog = [("E2", ["E3", "G3", "B3", "D4"]), ("A2", ["A3", "C4", "E4", "G4"]),
            ("E2", ["E3", "G3", "B3", "D4"]), ("B2", ["B3", "D4", "F#4", "A4"])]

    def bajo(c, compas, parte, i, acorde, m):
        if parte == "intro":
            return
        r = acorde[0]
        figura = [(0, r), (3, r), (6, subir(r, 1)), (7, r), (10, r), (12, subir(r, 1)), (14, r)]
        if parte == "puente":
            figura = [(0, r), (10, r)]
        for paso, nota in figura:
            c.poner(compas * 16 + paso, bajo_slap(nota, c.dur(2)))

    def armonia(c, compas, parte, i, acorde, m):
        for paso in ((2, 9) if parte != "puente" else (0,)):
            c.poner(compas * 16 + paso, piano_e(acorde[1], c.dur(3 if parte != "puente" else 14), vol=0.08, caida=0.2 if parte != "puente" else 1.0))
        if parte in ("A", "B"):
            for paso in range(1, 16, 2):
                c.poner(compas * 16 + paso, guitarra([subir(acorde[1][0], 1)], c.dur(1), apagada=True, vol=0.05, brillo=0.5))

    def melodia(c, compas, parte, i, acorde, m):
        if parte not in ("B", "puente"):
            return
        for paso, nota, largo in m.compas(parte, i, [subir(n, 1) for n in acorde[1][:3]]):
            c.poner(compas * 16 + paso, piano_e([nota], c.dur(largo), vol=0.09, caida=0.3))

    def bateria(c, compas, parte, i, acorde, m):
        if parte == "intro":
            c.bateria(compas, "hhhhhhhohhhhhhho", vol=0.5)
        elif parte == "puente":
            c.bateria(compas, "....s.......s...", vol=0.6)
            c.bateria(compas, "h.h.h.h.h.h.h.h.", vol=0.4)
        else:
            c.bateria(compas, "k..k..s...k...s.")
            c.bateria(compas, "hhhhhhhohhhhhhho", vol=0.6)

    return componer("aceite", 100, prog, [bajo, armonia, melodia, bateria])

def cerradura():
    # Espias / robo, La menor, 112 BPM: bajo que camina, guitarra con tremolo.
    prog = [("A2", ["A3", "C4", "E4"]), ("A2", ["A3", "C4", "E4"]),
            ("D3", ["D4", "F4", "A4"]), ("E2", ["E3", "G#3", "B3"])]

    def bajo(c, compas, parte, i, acorde, m):
        r = acorde[0]
        notas = {"A2": ["A2", "A2", "C3", "A2", "D#3", "E3", "C3", "B2"],
                 "D3": ["D3", "D3", "F3", "D3", "G#3", "A3", "F3", "E3"],
                 "E2": ["E2", "E2", "G#2", "E2", "A#2", "B2", "G#2", "F#2"]}[r]
        if parte == "intro":
            for k, n in enumerate(notas[::2]):
                c.poner(compas * 16 + k * 4, bajo_electrico(n, c.dur(4), brillo=0.08))
            return
        for k, n in enumerate(notas):
            c.poner(compas * 16 + k * 2, bajo_electrico(n, c.dur(2), brillo=0.08))

    def melodia(c, compas, parte, i, acorde, m):
        if parte == "intro":
            return
        trem = 9 if parte != "puente" else 5
        for paso, nota, largo in m.compas(parte, i, [subir(n, 1) for n in acorde[1]]):
            c.poner(compas * 16 + paso, guitarra([nota], c.dur(largo), distorsion=2.0, vol=0.12, brillo=0.3, tremolo=trem))

    def bateria(c, compas, parte, i, acorde, m):
        c.bateria(compas, "h.h.h.h.h.h.h.h.", vol=0.6)
        if parte in ("A", "B"):
            c.bateria(compas, "k.......k.k.....")
            c.bateria(compas, "..s.....s.....s." if parte == "A" else "....s.......s.s.", vol=0.4)

    return componer("cerradura", 112, prog, [bajo, melodia, bateria])

def filtro():
    # Rock de garaje alegre, La, 128 BPM.
    prog = [("A2", ["A3", "E4"]), ("E2", ["E3", "B3"]), ("F#2", ["F#3", "C#4"]), ("D2", ["D3", "A3"])]

    def bajo(c, compas, parte, i, acorde, m):
        if parte == "intro":
            return
        for k in range(8 if parte != "puente" else 2):
            c.poner(compas * 16 + k * (2 if parte != "puente" else 8), bajo_electrico(acorde[0], c.dur(2 if parte != "puente" else 8), brillo=0.1))

    def guitarras(c, compas, parte, i, acorde, m):
        if parte == "puente":
            c.poner(compas * 16, guitarra(acorde[1], c.dur(16), vol=0.15))
            return
        for k in range(8):
            c.poner(compas * 16 + k * 2, guitarra(acorde[1], c.dur(2), apagada=(k % 4 != 0) and parte != "B", vol=0.2))

    def melodia(c, compas, parte, i, acorde, m):
        if parte != "B":
            return
        notas = [subir(acorde[1][0], 1), subir(acorde[1][1], 1), subir(acorde[1][0], 2)]
        for paso, nota, largo in m.compas(parte, i, notas):
            c.poner(compas * 16 + paso, guitarra([nota], c.dur(largo), distorsion=5, vol=0.1, brillo=0.35))

    def bateria(c, compas, parte, i, acorde, m):
        if parte == "intro":
            c.bateria(compas, "k...k...k...k...")
        elif parte == "puente":
            c.bateria(compas, "o.......o.......", vol=0.5)
        else:
            c.bateria(compas, "k.h.s.h.k.k.s.h." if parte == "A" else "k.o.s.o.k.k.s.o.")

    return componer("filtro", 128, prog, [bajo, guitarras, melodia, bateria])

def cables():
    # Electronica de hackeo, Re menor, 124 BPM.
    prog = [("D2", ["D3", "F3", "A3", "D4"]), ("Bb1", ["Bb2", "D3", "F3", "Bb3"]),
            ("C2", ["C3", "E3", "G3", "C4"]), ("A1", ["A2", "C#3", "E3", "A3"])]

    def arpegio(c, compas, parte, i, acorde, m):
        notas = [subir(n, 1) for n in acorde[1]]
        orden = [0, 1, 2, 3] if parte != "B" else [0, 2, 1, 3, 2, 3, 1, 2]
        for k in range(16):
            brillo = 0.08 + 0.2 * (k / 16) if parte != "puente" else 0.05
            c.poner(compas * 16 + k, sinte(notas[orden[k % len(orden)]], c.dur(1), vol=0.1, brillo=brillo))

    def bajo(c, compas, parte, i, acorde, m):
        if parte == "intro":
            return
        c.poner(compas * 16, bajo_electrico(acorde[0], c.dur(16), brillo=0.03, vol=0.45))

    def melodia(c, compas, parte, i, acorde, m):
        if parte != "B":
            return
        for paso, nota, largo in m.compas(parte, i, [subir(n, 2) for n in acorde[1][:3]]):
            c.poner(compas * 16 + paso, sinte(nota, c.dur(largo), vol=0.09, brillo=0.25))

    def bateria(c, compas, parte, i, acorde, m):
        if parte == "intro":
            c.bateria(compas, "..o...o...o...o.", vol=0.6)
        elif parte == "puente":
            c.bateria(compas, "....c.......c...", vol=0.6)
        else:
            c.bateria(compas, "k...k...k...k...")
            c.bateria(compas, "..o...o...o...o.", vol=0.8)
            c.bateria(compas, "....c.......c...", vol=0.8)
            if parte == "B":
                c.bateria(compas, "hhhhhhhhhhhhhhhh", vol=0.3)

    return componer("cables", 124, prog, [arpegio, bajo, melodia, bateria])

def herramientas():
    # Lo-fi para pensar, Fa, 85 BPM.
    prog = [("F2", ["F3", "A3", "C4", "E4"]), ("D2", ["D3", "F3", "A3", "C4"]),
            ("G2", ["G3", "Bb3", "D4", "F4"]), ("C2", ["C3", "E3", "G3", "Bb3"])]

    def armonia(c, compas, parte, i, acorde, m):
        c.poner(compas * 16, piano_e(acorde[1], c.dur(14), vol=0.08))
        c.poner(compas * 16 + 10, piano_e(acorde[1][1:], c.dur(5), vol=0.05))
        if parte != "intro":
            c.poner(compas * 16, bajo_electrico(acorde[0], c.dur(8), brillo=0.03, vol=0.4))

    def melodia(c, compas, parte, i, acorde, m):
        if parte == "intro":
            return
        for paso, nota, largo in m.compas(parte, i, [subir(n, 1) for n in acorde[1][:3]]):
            c.poner(compas * 16 + paso, marimba(nota, c.dur(largo + 2), vol=0.16 if parte != "puente" else 0.1))

    def bateria(c, compas, parte, i, acorde, m):
        if parte in ("A", "B"):
            c.bateria(compas, "k.....k...s....." if parte == "A" else "k.....k.k.s.....", swing=0.4, vol=0.8)
        c.bateria(compas, "h.h.h.h.h.h.h.h.", swing=0.4, vol=0.35)

    buf = componer("herramientas", 85, prog, [armonia, melodia, bateria])
    # Ruidito de disco viejo.
    for i in range(0, len(buf), 40):
        if random.random() < 0.02:
            buf[i] += random.uniform(-0.05, 0.05)
    return buf

def inflar():
    # Concurso con tension, Do, 118 BPM.
    prog = [("C2", ["C4", "E4", "G4"]), ("D2", ["D4", "F#4", "A4"]),
            ("E2", ["E4", "G#4", "B4"]), ("G2", ["G4", "B4", "D5"])]

    def bajo(c, compas, parte, i, acorde, m):
        if parte == "intro":
            return
        r = acorde[0]
        for k in range(8 if parte != "puente" else 4):
            paso = k * (2 if parte != "puente" else 4)
            c.poner(compas * 16 + paso, bajo_electrico(r if k % 2 == 0 else subir(r, 1), c.dur(2), brillo=0.08, vol=0.45))

    def piano(c, compas, parte, i, acorde, m):
        golpes = (0, 3, 6, 10, 12) if parte != "B" else (0, 2, 4, 6, 8, 10, 12, 14)
        for paso in golpes:
            c.poner(compas * 16 + paso, piano_e(acorde[1], c.dur(1), vol=0.07, caida=0.06))

    def melodia(c, compas, parte, i, acorde, m):
        if parte not in ("B", "puente"):
            return
        for paso, nota, largo in m.compas(parte, i, [subir(n, 1) for n in acorde[1]]):
            c.poner(compas * 16 + paso, marimba(nota, c.dur(largo), vol=0.14))

    def bateria(c, compas, parte, i, acorde, m):
        if parte == "intro":
            c.bateria(compas, "hhhhhhhhhhhhhhhh", vol=0.4)
            return
        if parte != "puente":
            c.bateria(compas, "k.k...c.k.k...c.")
        else:
            c.bateria(compas, "......c.......c.")
        c.bateria(compas, "hhhhhhhhhhhhhhhh", vol=0.45)

    return componer("inflar", 118, prog, [bajo, piano, melodia, bateria])

def pintura():
    # Jazz suave, ii-V-I en Si bemol, 96 BPM.
    prog = [("C3", ["C4", "Eb4", "G4", "Bb4"]), ("F2", ["F3", "A3", "Eb4", "G4"]),
            ("Bb2", ["Bb3", "D4", "F4", "A4"]), ("G2", ["G3", "Bb3", "D4", "F4"])]

    def bajo(c, compas, parte, i, acorde, m):
        notas = {"C3": ["C3", "D3", "Eb3", "E3"], "F2": ["F2", "A2", "C3", "A2"],
                 "Bb2": ["Bb2", "D3", "F3", "D3"], "G2": ["G2", "A2", "Bb2", "B2"]}[acorde[0]]
        for k, nota in enumerate(notas if parte != "intro" else notas[:1]):
            c.poner(compas * 16 + k * 4, bajo_electrico(nota, c.dur(4 if parte != "intro" else 16), brillo=0.025, vol=0.5))

    def piano(c, compas, parte, i, acorde, m):
        c.poner(compas * 16 + 2.66, piano_e(acorde[1], c.dur(4), vol=0.07))
        c.poner(compas * 16 + 10.66, piano_e(acorde[1], c.dur(3), vol=0.06))

    def melodia(c, compas, parte, i, acorde, m):
        if parte in ("intro", "puente"):
            return
        for paso, nota, largo in m.compas(parte, i, [subir(n, 1) for n in acorde[1]]):
            c.poner(compas * 16 + paso + (0.66 if paso % 2 else 0), piano_e([nota], c.dur(largo), vol=0.07, caida=0.4))

    def bateria(c, compas, parte, i, acorde, m):
        c.bateria(compas, "h...h.h.h...h.h.", swing=0.66, vol=0.55)
        if parte != "intro":
            c.bateria(compas, "....s.......s...", cepillo=True)

    return componer("pintura", 96, prog, [bajo, piano, melodia, bateria])

def reciclaje():
    # Fabrica en marcha, Sol menor, 120 BPM: bajo slap, golpes metalicos.
    prog = [("G2", ["G3", "Bb3", "D4"]), ("G2", ["G3", "Bb3", "D4"]),
            ("Eb2", ["Eb3", "G3", "Bb3"]), ("F2", ["F3", "A3", "C4"])]

    def bajo(c, compas, parte, i, acorde, m):
        if parte == "intro":
            return
        r = acorde[0]
        for k, paso in enumerate((0, 3, 6, 8, 11, 14) if parte != "puente" else (0, 8)):
            c.poner(compas * 16 + paso, bajo_slap(r if k != 4 else subir(r, 1), c.dur(2), vol=0.45))

    def melodia(c, compas, parte, i, acorde, m):
        if parte not in ("B", "puente"):
            return
        for paso, nota, largo in m.compas(parte, i, [subir(n, 1) for n in acorde[1]]):
            c.poner(compas * 16 + paso, sinte(nota, c.dur(largo), vol=0.1, brillo=0.18))

    def bateria(c, compas, parte, i, acorde, m):
        c.bateria(compas, "..m...m...m..m.m", vol=0.6)
        if parte == "intro":
            return
        if parte != "puente":
            c.bateria(compas, "k...k...k...k...")
            c.bateria(compas, "....s.......s...", vol=0.8)
        c.bateria(compas, "hhohhhohhhohhhoh", vol=0.4)

    return componer("reciclaje", 120, prog, [bajo, melodia, bateria])

# --- Generos de la radio ---------------------------------------------------------

def tropipop():
    # Tropipop colombiano, Sol, 104 BPM: guitarra rasgueada, acordeon,
    # guacharaca y bateria pop.
    prog = [("G2", ["G3", "B3", "D4", "G4"]), ("D2", ["D3", "A3", "D4", "F#4"]),
            ("E2", ["E3", "B3", "E4", "G4"]), ("C2", ["C3", "G3", "C4", "E4"])]

    def guitarra_ac(c, compas, parte, i, acorde, m):
        for paso, arriba in ((0, False), (3, True), (6, False), (8, False), (10, True), (12, False), (14, True)):
            c.poner(compas * 16 + paso, rasgueo(acorde[1], c.dur(3), vol=0.12, hacia_arriba=arriba))

    def bajo(c, compas, parte, i, acorde, m):
        if parte == "intro":
            return
        for paso, oct in ((0, 0), (6, 0), (8, 1), (12, 0)):
            c.poner(compas * 16 + paso, bajo_electrico(subir(acorde[0], oct), c.dur(3), brillo=0.06, vol=0.45))

    def acordeon_mel(c, compas, parte, i, acorde, m):
        if parte == "intro":
            return
        for paso, nota, largo in m.compas(parte, i, [subir(n, 1) for n in acorde[1][1:]]):
            c.poner(compas * 16 + paso, acordeon([nota], c.dur(largo), vol=0.09 if parte != "puente" else 0.05))

    def bateria(c, compas, parte, i, acorde, m):
        for paso in range(0, 16, 2):
            c.poner(compas * 16 + paso + 1, raspado(0.18))
        if parte in ("A", "B"):
            c.bateria(compas, "k.....k.k...s..." if parte == "A" else "k...s.k.k...s...")
            c.bateria(compas, "....s.......s...", vol=0.7)

    return componer("tropipop", 104, prog, [guitarra_ac, bajo, acordeon_mel, bateria])

def kpop():
    # K-pop brillante, 124 BPM: bombo a negras, palmas, bajo en octavas y
    # gancho de sinte con campanitas.
    prog = [("C2", ["C4", "E4", "G4", "B4"]), ("G1", ["G3", "B3", "D4", "F#4"]),
            ("A1", ["A3", "C4", "E4", "G4"]), ("B1", ["B3", "D#4", "F#4", "A4"])]

    def bajo(c, compas, parte, i, acorde, m):
        if parte == "intro":
            return
        for k in range(8):
            c.poner(compas * 16 + k * 2, sinte(subir(acorde[0], k % 2), c.dur(2), vol=0.16, brillo=0.12))

    def acordes(c, compas, parte, i, acorde, m):
        golpes = (0, 3, 6, 10, 12) if parte != "puente" else (0,)
        largo = c.dur(2 if parte != "puente" else 16)
        for paso in golpes:
            for nota in acorde[1]:
                c.poner(compas * 16 + paso, sinte(nota, largo, vol=0.05, brillo=0.3))

    def gancho(c, compas, parte, i, acorde, m):
        if parte == "intro":
            return
        for paso, nota, largo in m.compas(parte, i, [subir(n, 1) for n in acorde[1][:3]]):
            c.poner(compas * 16 + paso, sinte(nota, c.dur(largo), vol=0.1, brillo=0.35))
            c.poner(compas * 16 + paso, campana(nota, 0.3, vol=0.05))

    def bateria(c, compas, parte, i, acorde, m):
        if parte == "puente":
            c.bateria(compas, "....c.......c...", vol=0.7)
            return
        c.bateria(compas, "k...k...k...k...")
        c.bateria(compas, "....c.......c...")
        c.bateria(compas, "..h...h...h...h." if parte != "B" else "hhhhhhhhhhhhhhhh", vol=0.5)

    return componer("kpop", 124, prog, [bajo, acordes, gancho, bateria])

def reggae():
    # Reggae one-drop, La menor, 76 BPM: "skank" de guitarra en el
    # contratiempo, organo "burbuja", bajo profundo y bombo+caja en el 3.
    prog = [("A1", ["A3", "C4", "E4"]), ("A1", ["A3", "C4", "E4"]),
            ("D2", ["D3", "F3", "A3"]), ("E1", ["E3", "G#3", "B3"])]

    def skank(c, compas, parte, i, acorde, m):
        for paso in (4, 12):
            c.poner(compas * 16 + paso, guitarra(acorde[1], c.dur(1), distorsion=1.2, apagada=True, vol=0.14, brillo=0.5))
        for paso in (2, 6, 10, 14):
            c.poner(compas * 16 + paso, organo(acorde[1], c.dur(1), vol=0.04))

    def bajo(c, compas, parte, i, acorde, m):
        if parte == "intro":
            return
        r = acorde[0]
        for paso, nota, largo in ((0, r, 3), (4, subir(r, 1), 2), (7, r, 2), (10, subir(r, 1), 3), (14, r, 2)):
            c.poner(compas * 16 + paso, bajo_electrico(nota, c.dur(largo), brillo=0.02, vol=0.6))

    def melodia(c, compas, parte, i, acorde, m):
        if parte != "B":
            return
        for paso, nota, largo in m.compas(parte, i, [subir(n, 1) for n in acorde[1]]):
            c.poner(compas * 16 + paso, piano_e([nota], c.dur(largo), vol=0.08, caida=0.5))

    def bateria(c, compas, parte, i, acorde, m):
        c.bateria(compas, "h.h.h.h.h.h.h.h.", swing=0.3, vol=0.45)
        if parte != "intro":
            c.bateria(compas, "........k.......")
            c.bateria(compas, "........r.......")

    return componer("reggae", 76, prog, [skank, bajo, melodia, bateria])

def dancehall():
    # Dancehall, Sol menor, 100 BPM: riddim con bombo sincopado, aro,
    # sub bajo y golpes de sinte.
    prog = [("G1", ["G3", "Bb3", "D4"]), ("Eb2", ["Eb3", "G3", "Bb3"]),
            ("Bb1", ["Bb3", "D4", "F4"]), ("F1", ["F3", "A3", "C4"])]

    def bajo(c, compas, parte, i, acorde, m):
        if parte == "intro":
            return
        for paso, largo in ((0, 3), (3, 3), (8, 2), (11, 5)):
            c.poner(compas * 16 + paso, bajo_808(acorde[0], c.dur(largo), vol=0.6))

    def golpes(c, compas, parte, i, acorde, m):
        for paso in ((2, 6, 10, 14) if parte != "puente" else (0,)):
            for nota in acorde[1]:
                c.poner(compas * 16 + paso, sinte(subir(nota, 1), c.dur(1 if parte != "puente" else 12), vol=0.05, brillo=0.25))

    def melodia(c, compas, parte, i, acorde, m):
        if parte not in ("B", "puente"):
            return
        for paso, nota, largo in m.compas(parte, i, [subir(n, 1) for n in acorde[1]]):
            c.poner(compas * 16 + paso, marimba(nota, c.dur(largo), vol=0.12))

    def bateria(c, compas, parte, i, acorde, m):
        if parte not in ("intro", "puente"):
            c.bateria(compas, "k..k..k...k..k..")
        c.bateria(compas, "....r.......r..r")
        c.bateria(compas, "hhh.hhh.hhh.hhh.", vol=0.45)

    return componer("dancehall", 100, prog, [bajo, golpes, melodia, bateria])

def cumbia():
    # Cumbia, La menor, 96 BPM: guacharaca, bajo "uno-cinco", acordeon,
    # cencerro y congas.
    prog = [("A2", ["A3", "C4", "E4"]), ("D2", ["D3", "F3", "A3"]),
            ("G2", ["G3", "B3", "D4"]), ("E2", ["E3", "G#3", "B3"])]

    def bajo(c, compas, parte, i, acorde, m):
        if parte == "intro":
            return
        quinta = {"A2": "E2", "D2": "A2", "G2": "D2", "E2": "B1"}[acorde[0]]
        for paso, nota in ((0, acorde[0]), (6, quinta), (8, acorde[0]), (14, quinta)):
            c.poner(compas * 16 + paso, bajo_electrico(nota, c.dur(2), brillo=0.05, vol=0.5))

    def guitarra_c(c, compas, parte, i, acorde, m):
        for paso in (2, 6, 10, 14):
            c.poner(compas * 16 + paso, rasgueo(acorde[1], c.dur(1), vol=0.08, brillo=0.6))

    def acordeon_mel(c, compas, parte, i, acorde, m):
        if parte == "intro":
            return
        for paso, nota, largo in m.compas(parte, i, [subir(n, 1) for n in acorde[1]]):
            c.poner(compas * 16 + paso, acordeon([nota], c.dur(largo), vol=0.1))

    def percusion(c, compas, parte, i, acorde, m):
        for paso in range(0, 16, 2):
            c.poner(compas * 16 + paso, raspado(0.12 if paso % 4 else 0.2, 0.06))
        if parte != "puente":
            for paso in (4, 12):
                c.poner(compas * 16 + paso, cencerro())
            c.bateria(compas, "k.......k.......")
            for paso in (6, 14):
                c.poner(compas * 16 + paso, conga(230, 0.3, golpe=True))

    return componer("cumbia", 96, prog, [bajo, guitarra_c, acordeon_mel, percusion])

def salsa():
    # Salsa, Do menor: piano montuno, metales, congas, clave y cencerro.
    # 96 BPM en semicorcheas = salsa a 192 en corcheas.
    prog = [("C2", ["C4", "Eb4", "G4"]), ("F2", ["F3", "Ab3", "C4"]),
            ("G2", ["G3", "B3", "D4", "F4"]), ("C2", ["C4", "Eb4", "G4"])]

    def bajo(c, compas, parte, i, acorde, m):
        # Tumbao: el bajo anticipa el acorde (cae "antes").
        if parte == "intro":
            return
        quinta = {"C2": "G2", "F2": "C3", "G2": "D3"}[acorde[0]]
        for paso in (3, 6, 11, 14):
            c.poner(compas * 16 + paso, bajo_electrico(acorde[0] if paso in (6, 14) else quinta, c.dur(3), brillo=0.04, vol=0.5))

    def montuno(c, compas, parte, i, acorde, m):
        notas = [subir(n, 1) for n in acorde[1][:3]]
        for k, paso in enumerate((0, 2, 3, 5, 6, 8, 10, 11, 13, 14)):
            c.poner(compas * 16 + paso, piano_e([notas[k % 3], notas[(k + 1) % 3]], c.dur(1), vol=0.06, caida=0.12))

    def metales_mel(c, compas, parte, i, acorde, m):
        if parte not in ("B", "A") or (parte == "A" and i % 2 == 0):
            return
        for paso, nota, largo in m.compas(parte, i, [subir(n, 1) for n in acorde[1][:3]]):
            c.poner(compas * 16 + paso, metales([nota, subir(nota, -1)], c.dur(min(largo, 3)), vol=0.06))

    def percusion(c, compas, parte, i, acorde, m):
        for paso in (0, 3, 6, 10, 12):  # clave
            c.poner(compas * 16 + paso, aro(0.25))
        if parte == "intro":
            return
        for paso in (0, 4, 8, 12):
            c.poner(compas * 16 + paso, cencerro(0.12))
        for paso, f, golpe in ((6, 230, True), (7, 190, False), (14, 230, True), (15, 190, False)):
            c.poner(compas * 16 + paso, conga(f, 0.32, golpe))
        if parte != "puente":
            c.bateria(compas, "...k.......k....", vol=0.6)

    return componer("salsa", 96, prog, [bajo, montuno, metales_mel, percusion])

def bachata():
    # Bachata, La menor, 124 BPM: requinto (guitarra aguda) en arpegios,
    # guira constante, bongo y bajo sincopado.
    prog = [("A2", ["A3", "C4", "E4"]), ("D2", ["D3", "F3", "A3"]),
            ("E2", ["E3", "G#3", "B3"]), ("A2", ["A3", "C4", "E4"])]

    def requinto(c, compas, parte, i, acorde, m):
        notas = [subir(n, 1) for n in acorde[1]]
        if parte in ("B", "puente"):
            for paso, nota, largo in m.compas(parte, i, notas):
                c.poner(compas * 16 + paso, cuerda(nota, c.dur(largo + 1), vol=0.22, brillo=0.6))
        else:
            for k in range(8):
                c.poner(compas * 16 + k * 2, cuerda(notas[(0, 1, 2, 1)[k % 4]], c.dur(2), vol=0.18, brillo=0.6))

    def ritmica(c, compas, parte, i, acorde, m):
        for paso in (0, 4, 8, 12):
            c.poner(compas * 16 + paso, rasgueo(acorde[1], c.dur(2), vol=0.07))

    def bajo(c, compas, parte, i, acorde, m):
        if parte == "intro":
            return
        for paso, oct in ((0, 0), (6, 0), (8, 1), (14, 0)):
            c.poner(compas * 16 + paso, bajo_electrico(subir(acorde[0], oct), c.dur(2), brillo=0.04, vol=0.5))

    def percusion(c, compas, parte, i, acorde, m):
        for paso in range(16):
            c.poner(compas * 16 + paso, raspado(0.1 if paso % 2 else 0.16, 0.05, brillo=0.5))
        if parte != "intro":
            for paso, f in ((0, 420), (4, 520), (6, 420), (8, 420), (12, 520), (14, 420)):
                c.poner(compas * 16 + paso, conga(f, 0.2, golpe=f > 500))
            c.bateria(compas, "k.......k.......", vol=0.5)

    return componer("bachata", 124, prog, [requinto, ritmica, bajo, percusion])

def trap():
    # Trap, Do menor, 140 BPM (a medio tiempo): 808 largo, hi-hats con
    # redobles, palmas en el 3 y campana oscura.
    prog = [("C1", ["C4", "Eb4", "G4"]), ("Ab1", ["Ab3", "C4", "Eb4"]),
            ("Eb1", ["Eb4", "G4", "Bb4"]), ("G1", ["G3", "B3", "D4"])]

    def bajo(c, compas, parte, i, acorde, m):
        if parte == "intro":
            return
        for paso, largo in ((0, 7), (7, 3), (10, 6)):
            c.poner(compas * 16 + paso, bajo_808(acorde[0], c.dur(largo), vol=0.7))

    def campanas(c, compas, parte, i, acorde, m):
        for paso, nota, largo in m.compas("A" if parte == "intro" else parte, i, acorde[1]):
            c.poner(compas * 16 + paso, campana(subir(nota, 1), 0.7, vol=0.1))

    def bateria(c, compas, parte, i, acorde, m):
        if parte == "puente":
            c.bateria(compas, "h...h...h...h...", vol=0.4)
            return
        c.bateria(compas, "h.h.h.h.h.h.h.h.", vol=0.4)
        # Redoble de hi-hat en fusas al final de compases impares.
        if i % 2 == 1:
            for k in range(8):
                c.poner(compas * 16 + 12 + k * 0.5, platillo(vol=0.08))
        if parte != "intro":
            c.bateria(compas, "k.........k.....")
            c.bateria(compas, "........c.......")

    return componer("trap", 140, prog, [bajo, campanas, bateria])

def afro():
    # Afrobeats / amapiano, La menor, 108 BPM: log drum, maracas, palmas
    # sincopadas y piano electrico.
    prog = [("A1", ["A3", "C4", "E4", "G4"]), ("F1", ["F3", "A3", "C4", "E4"]),
            ("C2", ["C4", "E4", "G4", "B4"]), ("G1", ["G3", "B3", "D4", "F4"])]

    def logdrum(c, compas, parte, i, acorde, m):
        if parte == "intro":
            return
        for paso, oct in ((0, 1), (3, 1), (7, 2), (10, 1), (13, 2)):
            c.poner(compas * 16 + paso, log_drum(subir(acorde[0], oct)))

    def piano(c, compas, parte, i, acorde, m):
        for paso in ((0, 6, 12) if parte != "puente" else (0,)):
            c.poner(compas * 16 + paso, piano_e(acorde[1], c.dur(4 if parte != "puente" else 16), vol=0.07, caida=0.5))

    def melodia(c, compas, parte, i, acorde, m):
        if parte not in ("B", "puente"):
            return
        for paso, nota, largo in m.compas(parte, i, [subir(n, 1) for n in acorde[1][:3]]):
            c.poner(compas * 16 + paso, marimba(nota, c.dur(largo), vol=0.12))

    def percusion(c, compas, parte, i, acorde, m):
        for paso in range(16):
            c.poner(compas * 16 + paso, maracas(0.12 if paso % 2 else 0.06))
        if parte != "intro":
            c.bateria(compas, "k......k..k.....", vol=0.8)
            c.bateria(compas, "....c..c....c...", vol=0.6)
            for paso in (3, 11):
                c.poner(compas * 16 + paso, conga(260, 0.22, golpe=True))

    return componer("afro", 108, prog, [logdrum, piano, melodia, percusion])

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
    # Generos de la radio.
    "musica_tropipop": tropipop,
    "musica_kpop": kpop,
    "musica_reggae": reggae,
    "musica_dancehall": dancehall,
    "musica_cumbia": cumbia,
    "musica_salsa": salsa,
    "musica_bachata": bachata,
    "musica_trap": trap,
    "musica_afro": afro,
}

if __name__ == "__main__":
    import sys
    os.makedirs(SALIDA, exist_ok=True)
    solo_musica = "--musica" in sys.argv
    if not solo_musica:
        print("Efectos:")
        efectos()
    print("Musica:")
    solo = next((a.split("=")[1].split(",") for a in sys.argv if a.startswith("--solo=")), None)
    for nombre, cancion in CANCIONES.items():
        if solo and nombre not in solo:
            continue
        random.seed(nombre)
        guardar(nombre, cancion(), vol=0.75)
