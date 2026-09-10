extends Node2D

# Minijuego de cambio de filtro de aire: mismo esqueleto que mini_game_oil.gd
# y mini_game_keys.gd (cinematica -> tutorial -> desafio -> resultado ->
# vuelta a la sala). El desafio es soplar el filtro sosteniendo el boton:
# la limpieza sube mientras soplas, pero la presion tambien sube y si se
# pasa de tope el filtro "revienta" (penaliza limpieza y te bloquea un
# instante). Hay que soplar en tandas cortas, no de una sola vez.

# --- NODOS DE LA CINEMÁTICA ---
@onready var filtro_cine = $FiltroCine
@onready var filtro_oscuro = $FiltroOscuro

# --- NODOS DEL MINIJUEGO ---
@onready var contenedor_juego = $ContenedorJuego
@onready var filtro_sprite = $ContenedorJuego/FiltroSprite
@onready var label_limpieza = $ContenedorJuego/LabelLimpieza
@onready var label_presion = $ContenedorJuego/LabelPresion
@onready var relleno_limpieza = $ContenedorJuego/RellenoLimpieza
@onready var relleno_presion = $ContenedorJuego/RellenoPresion
@onready var button_action = $ContenedorJuego/buttonAction

const TutorialModal = preload("res://scripts/tutorial_modal.gd")

# Id en el catalogo `tutorials` (ver sql/tutorials_minigame_filter.sql).
const ID_TUTORIAL := "minigame_filter"

const TUTORIAL := [
	{
		"titulo": "Cambio de filtro de aire",
		"texto": "Tu trabajo es limpiar el filtro soplandolo hasta el 100%.\n\nManten pulsado el boton para soplar.",
	},
	{
		"titulo": "Los dos niveles",
		"texto": "LIMPIEZA: tu objetivo, solo sube mientras soplas.\n\nPRESION: sube mientras soplas y baja cuando soltas. Si llega al tope el filtro revienta.",
	},
	{
		"titulo": "El truco",
		"texto": "Sopla en tandas cortas: soltando a tiempo la presion baja y podes seguir sin reventar el filtro.\n\nCada reventon te resta limpieza y te bloquea un instante.",
	},
]

# --- TIEMPOS DE LA CINEMÁTICA (segundos), mismos valores que los otros dos.
const CINE_FADE_IN: float = 1.2
const CINE_VISIBLE: float = 2.2
const CINE_FADE_OUT: float = 1.0
const CINE_NEGRO: float = 0.6
const CINE_REVELAR: float = 1.0
const CINE_SALIDA: float = 1.4

# --- DESAFIO ---
const TASA_LIMPIEZA: float = 22.0
const TASA_PRESION_SUBE: float = 30.0
const TASA_PRESION_BAJA: float = 45.0
const PRESION_MAX: float = 100.0
const PENALIZACION_LIMPIEZA: float = 15.0
const PRESION_TRAS_REVENTON: float = 40.0
const BLOQUEO_TRAS_REVENTON: float = 0.4

const RIEL_ANCHO: float = 340.0

const TRAMOS_PRECISION := [
	{"max_reventones": 0, "pago": 0.5, "puntos": 3, "titulo": "¡Perfecto!", "detalle": "Ni un reventon."},
	{"max_reventones": 1, "pago": 0.25, "puntos": 2, "titulo": "Muy bien", "detalle": "Casi sin sobresaltos."},
	{"max_reventones": 3, "pago": 0.1, "puntos": 1, "titulo": "Aceptable", "detalle": "Se te resistio un poco."},
	{"max_reventones": 999999, "pago": 0.0, "puntos": 0, "titulo": "Costo, pero quedo limpio", "detalle": "Reventaste bastante, pero terminaste."},
]

var limpieza: float = 0.0
var presion: float = 0.0
var reventones: int = 0

var bloqueado: bool = false
var bloqueo_timer: float = 0.0

var juego_terminado: bool = false
var tutorial_activo: bool = false

func _ready() -> void:
	contenedor_juego.visible = false
	contenedor_juego.modulate.a = 0.0

	filtro_oscuro.modulate.a = 1.0
	filtro_oscuro.visible = true
	filtro_oscuro.z_index = 100

	filtro_sprite.modulate = Color(0.55, 0.45, 0.38)

	iniciar_cinematica()

func iniciar_cinematica() -> void:
	filtro_cine.scale = Vector2(0.7, 0.7)

	var tween_pulso := create_tween()
	tween_pulso.set_trans(Tween.TRANS_SINE)
	tween_pulso.set_ease(Tween.EASE_IN_OUT)
	tween_pulso.set_loops()
	tween_pulso.tween_property(filtro_cine, "rotation", deg_to_rad(-4), 0.5)
	tween_pulso.tween_property(filtro_cine, "rotation", deg_to_rad(4), 0.5)

	var tween_filtro := create_tween()
	tween_filtro.set_trans(Tween.TRANS_SINE)
	tween_filtro.tween_property(filtro_oscuro, "modulate:a", 0.0, CINE_FADE_IN).set_ease(Tween.EASE_OUT)
	tween_filtro.tween_interval(CINE_VISIBLE)
	tween_filtro.tween_property(filtro_oscuro, "modulate:a", 1.0, CINE_FADE_OUT).set_ease(Tween.EASE_IN)
	tween_filtro.tween_interval(CINE_NEGRO)
	tween_filtro.tween_callback(func():
		tween_pulso.kill()
		iniciar_juego_filtro()
	)

func iniciar_juego_filtro() -> void:
	filtro_cine.visible = false

	contenedor_juego.visible = true
	contenedor_juego.modulate.a = 0.0

	_actualizar_ui()

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

	if bloqueado:
		bloqueo_timer -= delta
		presion = max(0.0, presion - TASA_PRESION_BAJA * delta)
		if bloqueo_timer <= 0.0:
			bloqueado = false
	else:
		var soplando: bool = button_action.is_pressed()

		if soplando:
			limpieza = min(100.0, limpieza + TASA_LIMPIEZA * delta)
			presion += TASA_PRESION_SUBE * delta
		else:
			presion = max(0.0, presion - TASA_PRESION_BAJA * delta)

		if presion >= PRESION_MAX:
			_reventar()

	filtro_sprite.modulate = Color(0.55, 0.45, 0.38).lerp(Color(1, 1, 1), limpieza / 100.0)
	_actualizar_ui()

	if limpieza >= 100.0 and not juego_terminado:
		_terminar_juego()

func _reventar() -> void:
	reventones += 1
	limpieza = max(0.0, limpieza - PENALIZACION_LIMPIEZA)
	presion = PRESION_TRAS_REVENTON
	bloqueado = true
	bloqueo_timer = BLOQUEO_TRAS_REVENTON
	_flash(relleno_presion, Color(1.0, 0.3, 0.2))

# Pulso corto de color para marcar el reventon, sin depender de sprites nuevos.
func _flash(nodo: ColorRect, color: Color) -> void:
	var original := nodo.color
	var tween := create_tween()
	tween.tween_property(nodo, "color", color, 0.08)
	tween.tween_property(nodo, "color", original, 0.3)

func _actualizar_ui() -> void:
	relleno_limpieza.offset_right = relleno_limpieza.offset_left + RIEL_ANCHO * (limpieza / 100.0)
	relleno_presion.offset_right = relleno_presion.offset_left + RIEL_ANCHO * (presion / 100.0)
	label_limpieza.text = "Limpieza: %d%%" % int(limpieza)
	label_presion.text = "Presion: %d%%" % int(presion)

func _terminar_juego() -> void:
	juego_terminado = true
	button_action.visible = false

	var resultado := _evaluar_precision(reventones)

	var payment = Supabase.active_work_payment
	var points = Supabase.active_work_points
	label_presion.text = "Guardando..."

	var ok = await Supabase.complete_active_work(resultado["bono_pago"], resultado["bono_puntos"])
	label_presion.text = ""

	var modal = TutorialModal.crear(self, [_pagina_resultado(ok, payment, points, resultado)])
	await modal.terminado

	var tween_salida := create_tween()
	tween_salida.set_trans(Tween.TRANS_SINE)
	tween_salida.set_ease(Tween.EASE_IN)
	tween_salida.tween_property(filtro_oscuro, "modulate:a", 1.0, CINE_SALIDA)
	tween_salida.parallel().tween_property(contenedor_juego, "modulate:a", 0.0, CINE_SALIDA * 0.9)
	tween_salida.tween_interval(CINE_NEGRO)
	tween_salida.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/room.tscn"))

func _evaluar_precision(total_reventones: int) -> Dictionary:
	for tramo in TRAMOS_PRECISION:
		if total_reventones <= tramo["max_reventones"]:
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
			"texto": "Limpiaste el filtro, pero no se pudo guardar el pago.\n\nRevisa tu conexion e intentalo de nuevo.",
			"boton": "Continuar",
		}

	var bono_pago: int = resultado["bono_pago"]
	var bono_puntos: int = resultado["bono_puntos"]

	var texto := "%s\nReventones: %d\n\n+ $%d\n+ %d puntos" % [
		resultado["detalle"], reventones, payment, points
	]

	if bono_pago != 0 or bono_puntos != 0:
		texto += "\n\nPrecision: +$%d  |  +%d pts" % [bono_pago, bono_puntos]

	return {
		"titulo": resultado["titulo"],
		"texto": texto,
		"boton": "Continuar",
	}
