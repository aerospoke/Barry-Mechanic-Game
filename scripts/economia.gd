extends RefCounted
class_name Economia

# Reglas de la economia del juego en un solo lugar: niveles de mecanico y
# bonos de pago. Los precios y requisitos de cada trabajo / articulo viven en
# la base (WorkList y shop_items, ver sql/economia.sql); aca esta como se
# combinan.
#
# Ciclo: trabajos -> plata y puntos -> los puntos suben el nivel -> el nivel
# desbloquea trabajos que pagan mas y articulos de la tienda.

# Puntos necesarios para cada nivel (indice 0 = nivel 1).
const NIVELES := [
	{"puntos": 0, "nombre": "Aprendiz"},
	{"puntos": 15, "nombre": "Ayudante"},
	{"puntos": 40, "nombre": "Mecanico"},
	{"puntos": 80, "nombre": "Tecnico"},
	{"puntos": 140, "nombre": "Especialista"},
	{"puntos": 220, "nombre": "Jefe de taller"},
	{"puntos": 320, "nombre": "Maestro"},
	{"puntos": 450, "nombre": "Experto"},
	{"puntos": 620, "nombre": "Leyenda"},
	{"puntos": 850, "nombre": "Barry Supremo"},
]

# Primer trabajo de cada dia: paga el doble.
const MULTIPLICADOR_DIARIO := 2.0
# Racha de dias seguidos trabajando: +5% por dia, hasta +50%.
const RACHA_POR_DIA := 0.05
const RACHA_MAXIMA := 0.5
# Experiencia: +4% por cada nivel por encima del que pide el trabajo.
const EXPERIENCIA_POR_NIVEL := 0.04

static func nivel(puntos: int) -> int:
	var n := 1
	for i in NIVELES.size():
		if puntos >= int(NIVELES[i]["puntos"]):
			n = i + 1
	return n

static func nombre_nivel(n: int) -> String:
	return NIVELES[clampi(n, 1, NIVELES.size()) - 1]["nombre"]

static func es_nivel_maximo(n: int) -> bool:
	return n >= NIVELES.size()

# Puntos del nivel actual y del siguiente (para barras de progreso).
static func rango_nivel(puntos: int) -> Vector2i:
	var n := nivel(puntos)
	var desde: int = NIVELES[n - 1]["puntos"]
	var hasta: int = NIVELES[n]["puntos"] if n < NIVELES.size() else desde
	return Vector2i(desde, hasta)

# "Nivel 3 · Mecanico"
static func texto_nivel(puntos: int) -> String:
	var n := nivel(puntos)
	return "Nivel %d · %s" % [n, nombre_nivel(n)]

# Pago final de un trabajo con todos los bonos. Devuelve
# {"pago": int, "puntos": int, "bonos": Array[String]} (los bonos son
# textos para mostrar: "¡Primer trabajo del dia! x2", ...).
static func calcular_pago(pago_base: int, puntos_base: int, nivel_jugador: int, nivel_trabajo: int,
		primer_trabajo_del_dia: bool, racha_dias: int) -> Dictionary:
	var multiplicador := 1.0
	var bonos: Array[String] = []

	var niveles_extra := maxi(0, nivel_jugador - nivel_trabajo)
	if niveles_extra > 0:
		var extra := niveles_extra * EXPERIENCIA_POR_NIVEL
		multiplicador += extra
		bonos.append("Experiencia: +%d%%" % int(round(extra * 100)))

	var racha := minf((racha_dias - 1) * RACHA_POR_DIA, RACHA_MAXIMA)
	if racha > 0.0:
		multiplicador += racha
		bonos.append("Racha de %d dias: +%d%%" % [racha_dias, int(round(racha * 100))])

	if primer_trabajo_del_dia:
		multiplicador *= MULTIPLICADOR_DIARIO
		bonos.append("¡Primer trabajo del dia! x2")

	return {
		"pago": int(round(pago_base * multiplicador)),
		# Los puntos tambien se duplican el primer trabajo del dia.
		"puntos": puntos_base * (2 if primer_trabajo_del_dia else 1),
		"bonos": bonos,
	}
