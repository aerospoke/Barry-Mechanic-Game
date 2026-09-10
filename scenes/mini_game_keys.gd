extends Node2D

# Minijuego de cerrajeria: forzar una cerradura pin por pin. Mismo esqueleto
# que mini_game_oil.gd (cinematica -> tutorial -> desafio -> resultado ->
# vuelta a la sala) pero con un desafio mas simple: una aguja rebota entre
# 0 y 100 y hay que pulsar el boton cuando esta dentro de la zona marcada.
# Cada pin acertado achica la zona y acelera la aguja; el puntaje final sale
# de cuantos fallos tuviste en total.

# --- NODOS DE LA CINEMÁTICA ---
@onready var candado_cine = $CandadoCine
@onready var filtro_oscuro = $FiltroOscuro

# --- NODOS DEL MINIJUEGO ---
@onready var contenedor_juego = $ContenedorJuego
@onready var candado = $ContenedorJuego/Candado
@onready var label_pin = $ContenedorJuego/LabelPin
@onready var label_fallos = $ContenedorJuego/LabelFallos
@onready var zona_objetivo = $ContenedorJuego/ZonaObjetivo
@onready var aguja = $ContenedorJuego/Aguja
@onready var button_action = $ContenedorJuego/buttonAction

const TutorialModal = preload("res://scripts/tutorial_modal.gd")

const TEXTURA_CERRADA := preload("res://buttons_ui/locked_normal.png")
const TEXTURA_ABIERTA := preload("res://buttons_ui/unlocked_normal.png")

# Id en el catalogo `tutorials` (ver sql/tutorials_minigame_keys.sql): se
# muestra una unica vez por cuenta, no cada vez que se entra al minijuego.
const ID_TUTORIAL := "minigame_keys"

const TUTORIAL := [
	{
		"titulo": "Forzar la cerradura",
		"texto": "Tu trabajo es abrir los %d pines de la cerradura, uno por uno." % 5,
	},
	{
		"titulo": "La aguja",
		"texto": "La barra de abajo tiene una aguja que se mueve sola de un lado al otro.\n\nPulsa el boton cuando la aguja este sobre la zona marcada para acertar el pin.",
	},
	{
		"titulo": "Cuidado",
		"texto": "Si pulsas fuera de la zona, es un fallo: el pin no avanza y lo tenes que reintentar.\n\nCada pin que acertas achica la zona y acelera la aguja del siguiente.",
	},
	{
		"titulo": "El resultado",
		"texto": "Al final se paga segun cuantos fallos tuviste en total.\n\nCuantos menos fallos, mejor bono sobre el pago y los puntos del trabajo.",
	},
]

# --- TIEMPOS DE LA CINEMÁTICA (segundos), mismos valores que mini_game_oil.
const CINE_FADE_IN: float = 1.2
const CINE_VISIBLE: float = 2.2
const CINE_FADE_OUT: float = 1.0
const CINE_NEGRO: float = 0.6
const CINE_REVELAR: float = 1.0
const CINE_SALIDA: float = 1.4

# --- DESAFIO ---
const TOTAL_PINES := 5

const ANCHO_ZONA_INICIAL := 26.0
const ANCHO_ZONA_PASO := 3.0
const ANCHO_ZONA_MIN := 12.0

const VELOCIDAD_INICIAL := 55.0
const VELOCIDAD_PASO := 10.0

# Extremos del riel en pixeles (ver ContenedorJuego/Riel en la escena): la
# aguja y la zona se calculan sobre este rango, no sobre coordenadas propias.
const RIEL_X0 := 40.0
const RIEL_ANCHO := 340.0

const TRAMOS_PRECISION := [
	{"max_fallos": 0, "pago": 0.5, "puntos": 3, "titulo": "¡Ni un fallo!", "detalle": "Cerrajero de primera."},
	{"max_fallos": 2, "pago": 0.25, "puntos": 2, "titulo": "Muy bien", "detalle": "Pocos fallos."},
	{"max_fallos": 5, "pago": 0.1, "puntos": 1, "titulo": "Aceptable", "detalle": "Se te resistio un poco."},
	{"max_fallos": 999999, "pago": 0.0, "puntos": 0, "titulo": "Costo, pero abrio", "detalle": "La forzaste igual."},
]

var pin_actual: int = 0
var fallos: int = 0

var aguja_pos: float = 0.0
var aguja_dir: float = 1.0
var velocidad_aguja: float = VELOCIDAD_INICIAL

var zona_inicio: float = 0.0
var ancho_zona: float = ANCHO_ZONA_INICIAL

var juego_terminado: bool = false
var tutorial_activo: bool = false

func _ready() -> void:
	contenedor_juego.visible = false
	contenedor_juego.modulate.a = 0.0

	filtro_oscuro.modulate.a = 1.0
	filtro_oscuro.visible = true
	filtro_oscuro.z_index = 100

	candado.texture = TEXTURA_CERRADA
	candado_cine.texture = TEXTURA_CERRADA

	iniciar_cinematica()

func iniciar_cinematica() -> void:
	candado_cine.scale = Vector2(4.5, 4.5)

	var tween_pulso := create_tween()
	tween_pulso.set_trans(Tween.TRANS_SINE)
	tween_pulso.set_ease(Tween.EASE_IN_OUT)
	tween_pulso.set_loops()
	tween_pulso.tween_property(candado_cine, "scale", Vector2(4.8, 4.8), 0.6)
	tween_pulso.tween_property(candado_cine, "scale", Vector2(4.5, 4.5), 0.6)

	var tween_filtro := create_tween()
	tween_filtro.set_trans(Tween.TRANS_SINE)
	tween_filtro.tween_property(filtro_oscuro, "modulate:a", 0.0, CINE_FADE_IN).set_ease(Tween.EASE_OUT)
	tween_filtro.tween_interval(CINE_VISIBLE)
	tween_filtro.tween_property(filtro_oscuro, "modulate:a", 1.0, CINE_FADE_OUT).set_ease(Tween.EASE_IN)
	tween_filtro.tween_interval(CINE_NEGRO)
	tween_filtro.tween_callback(func():
		tween_pulso.kill()
		iniciar_juego_llaves()
	)

func iniciar_juego_llaves() -> void:
	candado_cine.visible = false

	contenedor_juego.visible = true
	contenedor_juego.modulate.a = 0.0

	_preparar_pin(0)

	var tween_revelar := create_tween()
	tween_revelar.set_trans(Tween.TRANS_SINE)
	tween_revelar.set_ease(Tween.EASE_OUT)
	tween_revelar.tween_property(filtro_oscuro, "modulate:a", 0.0, CINE_REVELAR)
	tween_revelar.parallel().tween_property(contenedor_juego, "modulate:a", 1.0, CINE_REVELAR * 0.8)
	tween_revelar.tween_callback(mostrar_tutorial)

func mostrar_tutorial() -> void:
	if await Supabase.tutorial_fue_visto(ID_TUTORIAL):
		return
	Supabase.marcar_tutorial_visto(ID_TUTORIAL)

	tutorial_activo = true
	var modal = TutorialModal.crear(self, TUTORIAL)
	await modal.terminado
	tutorial_activo = false

func _process(delta: float) -> void:
	if not contenedor_juego.visible or juego_terminado or tutorial_activo:
		return

	aguja_pos += velocidad_aguja * aguja_dir * delta
	if aguja_pos >= 100.0:
		aguja_pos = 100.0
		aguja_dir = -1.0
	elif aguja_pos <= 0.0:
		aguja_pos = 0.0
		aguja_dir = 1.0

	var x := RIEL_X0 + (aguja_pos / 100.0) * RIEL_ANCHO
	aguja.offset_left = x - 3.0
	aguja.offset_right = x + 3.0

	if Input.is_action_just_pressed("ui_accept"):
		_intentar_pin()

func _intentar_pin() -> void:
	if aguja_pos >= zona_inicio and aguja_pos <= zona_inicio + ancho_zona:
		pin_actual += 1
		_flash(zona_objetivo, Color(0.4, 0.9, 0.45, 0.85))
		if pin_actual >= TOTAL_PINES:
			_terminar_juego()
		else:
			_preparar_pin(pin_actual)
	else:
		fallos += 1
		_flash(zona_objetivo, Color(0.9, 0.35, 0.35, 0.85))
		label_fallos.text = "Fallos: %d" % fallos

func _preparar_pin(indice: int) -> void:
	ancho_zona = max(ANCHO_ZONA_MIN, ANCHO_ZONA_INICIAL - indice * ANCHO_ZONA_PASO)
	velocidad_aguja = VELOCIDAD_INICIAL + indice * VELOCIDAD_PASO
	zona_inicio = randf_range(0.0, 100.0 - ancho_zona)

	var zx0 := RIEL_X0 + (zona_inicio / 100.0) * RIEL_ANCHO
	var zx1 := RIEL_X0 + ((zona_inicio + ancho_zona) / 100.0) * RIEL_ANCHO
	zona_objetivo.offset_left = zx0
	zona_objetivo.offset_right = zx1
	zona_objetivo.color = Color(0.93, 0.76, 0.35, 0.55)

	label_pin.text = "Pin %d / %d" % [indice + 1, TOTAL_PINES]
	label_fallos.text = "Fallos: %d" % fallos

# Pulso corto de color sobre la zona para marcar acierto/fallo, sin
# depender de sprites nuevos.
func _flash(nodo: ColorRect, color: Color) -> void:
	var original := nodo.color
	var tween := create_tween()
	tween.tween_property(nodo, "color", color, 0.08)
	tween.tween_property(nodo, "color", original, 0.25)

func _terminar_juego() -> void:
	juego_terminado = true
	button_action.visible = false
	candado.texture = TEXTURA_ABIERTA
	label_pin.text = "¡Cerradura abierta!"

	var resultado := _evaluar_precision(fallos)

	var payment = Supabase.active_work_payment
	var points = Supabase.active_work_points
	label_fallos.text = "Guardando..."

	var ok = await Supabase.complete_active_work(resultado["bono_pago"], resultado["bono_puntos"])
	label_fallos.text = ""

	var modal = TutorialModal.crear(self, [_pagina_resultado(ok, payment, points, resultado)])
	await modal.terminado

	var tween_salida := create_tween()
	tween_salida.set_trans(Tween.TRANS_SINE)
	tween_salida.set_ease(Tween.EASE_IN)
	tween_salida.tween_property(filtro_oscuro, "modulate:a", 1.0, CINE_SALIDA)
	tween_salida.parallel().tween_property(contenedor_juego, "modulate:a", 0.0, CINE_SALIDA * 0.9)
	tween_salida.tween_interval(CINE_NEGRO)
	tween_salida.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/room.tscn"))

func _evaluar_precision(total_fallos: int) -> Dictionary:
	for tramo in TRAMOS_PRECISION:
		if total_fallos <= tramo["max_fallos"]:
			return {
				"titulo": tramo["titulo"],
				"detalle": tramo["detalle"],
				"bono_pago": int(ceil(Supabase.active_work_payment * tramo["pago"])),
				"bono_puntos": tramo["puntos"],
			}
	return {"titulo": "Terminado", "detalle": "", "bono_pago": 0, "bono_puntos": 0}

func _pagina_resultado(ok: bool, payment: int, points: int, resultado: Dictionary) -> Dictionary:
	if not ok:
		return {
			"titulo": "Trabajo terminado",
			"texto": "Abriste la cerradura, pero no se pudo guardar el pago.\n\nRevisa tu conexion e intentalo de nuevo.",
			"boton": "Continuar",
		}

	var bono_pago: int = resultado["bono_pago"]
	var bono_puntos: int = resultado["bono_puntos"]

	var texto := "%s\nFallos totales: %d\n\n+ $%d\n+ %d puntos" % [
		resultado["detalle"], fallos, payment, points
	]

	if bono_pago != 0 or bono_puntos != 0:
		texto += "\n\nPrecision: +$%d  |  +%d pts" % [bono_pago, bono_puntos]

	return {
		"titulo": resultado["titulo"],
		"texto": texto,
		"boton": "Continuar",
	}
