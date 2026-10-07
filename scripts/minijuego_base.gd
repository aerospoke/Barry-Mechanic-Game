extends Node2D

# Esqueleto comun de los minijuegos de trabajo: cinematica del motor ->
# tutorial (una vez por cuenta) -> desafio -> festejo -> pago -> vuelta a la
# sala. Es el mismo flujo que mini_game_oil/keys/filter, pero en un solo
# lugar: un minijuego nuevo hereda de este script y solo programa su desafio.
#
# Uso (ver scenes/mini_game_cables.gd como ejemplo):
#   extends "res://scripts/minijuego_base.gd"
#   func _init():
#       id_tutorial = "minigame_x"   # fila en `tutorials`
#       tutorial = [{"titulo": ..., "texto": ...}]
#   func _construir():  arma los nodos del desafio dentro de `contenedor_juego`
#   func _empezar():    arranca el desafio (despues del tutorial)
#   ...y al terminar llama a terminar(). Los errores se suman con error().
#
# La escena solo necesita la raiz con el script: el fondo, la cinematica y
# los labels se crean aca.

const TutorialModal = preload("res://scripts/tutorial_modal.gd")
const Efectos = preload("res://scripts/efectos.gd")

const ANCHO := 420.0
const ALTO := 780.0

# --- TIEMPOS DE LA CINEMÁTICA (segundos), mismos que los otros minijuegos ---
const CINE_FADE_IN: float = 1.2
const CINE_VISIBLE: float = 2.2
const CINE_FADE_OUT: float = 1.0
const CINE_NEGRO: float = 0.6
const CINE_REVELAR: float = 1.0
const CINE_SALIDA: float = 1.4

const MOTORES := [
	preload("res://enginesCars/engine1.png"),
	preload("res://enginesCars/engine2.png"),
	preload("res://enginesCars/engine3.png"),
	preload("res://enginesCars/engine4.png"),
]
const ESCALA_MOTOR := Vector2(0.28356484, 0.2835648)

const COLOR_OK := Color(0.45, 1.0, 0.55)
const COLOR_ERROR := Color(1.0, 0.4, 0.35)
const COLOR_CHISPA := Color(1.0, 0.9, 0.45)
const COLOR_METAL := Color(0.8, 0.82, 0.86)

# Aciertos seguidos sin error; desde RACHA_MINIMA se festeja en pantalla.
const RACHA_MINIMA := 3

# --- Configuracion de cada minijuego (se pisa en _init) ---
var id_tutorial: String = ""
var tutorial: Array = []
var instruccion: String = ""
var texto_final: String = "¡Listo!"
var tramos: Array = [
	{"max_errores": 0, "pago": 0.5, "puntos": 3, "titulo": "¡Perfecto!", "detalle": "Ningun error."},
	{"max_errores": 2, "pago": 0.25, "puntos": 2, "titulo": "Muy bien", "detalle": "Casi sin errores."},
	{"max_errores": 5, "pago": 0.1, "puntos": 1, "titulo": "Aceptable", "detalle": "Te costo un poco."},
	{"max_errores": 999999, "pago": 0.0, "puntos": 0, "titulo": "Costo, pero quedo", "detalle": "Hubo bastantes errores, pero terminaste."},
]

# --- Estado ---
var contenedor_juego: Node2D
var label_instruccion: Label
var label_errores: Label
var errores: int = 0
var racha: int = 0
var juego_activo: bool = false
var juego_terminado: bool = false

var _motor: Sprite2D
var _filtro_oscuro: ColorRect

func _ready() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.08, 0.08, 0.09)
	fondo.size = Vector2(ANCHO, ALTO)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)

	_motor = Sprite2D.new()
	_motor.texture = MOTORES.pick_random()
	_motor.scale = ESCALA_MOTOR
	add_child(_motor)

	contenedor_juego = Node2D.new()
	contenedor_juego.visible = false
	contenedor_juego.modulate.a = 0.0
	add_child(contenedor_juego)

	label_instruccion = _label(Vector2(20, 30), Vector2(380, 50), 17, HORIZONTAL_ALIGNMENT_CENTER)
	label_instruccion.autowrap_mode = TextServer.AUTOWRAP_WORD
	label_instruccion.text = instruccion
	label_errores = _label(Vector2(20, 88), Vector2(380, 24), 15, HORIZONTAL_ALIGNMENT_CENTER)

	_filtro_oscuro = ColorRect.new()
	_filtro_oscuro.color = Color.BLACK
	_filtro_oscuro.size = Vector2(ANCHO, ALTO)
	_filtro_oscuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_filtro_oscuro.z_index = 100
	add_child(_filtro_oscuro)

	_construir()
	_actualizar_errores()
	_cinematica()

# --- Para pisar en cada minijuego ---

func _construir() -> void:
	pass

func _empezar() -> void:
	pass

# --- Flujo ---

# Mismo paneo del motor que los otros minijuegos.
func _cinematica() -> void:
	var centro := Vector2(ANCHO, ALTO) / 2.0
	var direccion := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	var duracion := CINE_FADE_IN + CINE_VISIBLE + CINE_FADE_OUT

	_motor.scale = ESCALA_MOTOR * 1.15
	_motor.position = centro + direccion * 120.0

	var tween_motor := create_tween()
	tween_motor.set_trans(Tween.TRANS_SINE)
	tween_motor.set_ease(Tween.EASE_IN_OUT)
	tween_motor.tween_property(_motor, "position", centro - direccion * 120.0, duracion)
	tween_motor.parallel().tween_property(_motor, "scale", ESCALA_MOTOR, duracion)

	var tween_filtro := create_tween()
	tween_filtro.set_trans(Tween.TRANS_SINE)
	tween_filtro.tween_property(_filtro_oscuro, "modulate:a", 0.0, CINE_FADE_IN).set_ease(Tween.EASE_OUT)
	tween_filtro.tween_interval(CINE_VISIBLE)
	tween_filtro.tween_property(_filtro_oscuro, "modulate:a", 1.0, CINE_FADE_OUT).set_ease(Tween.EASE_IN)
	tween_filtro.tween_interval(CINE_NEGRO)
	tween_filtro.tween_callback(_revelar)

func _revelar() -> void:
	_motor.visible = false
	contenedor_juego.visible = true

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_filtro_oscuro, "modulate:a", 0.0, CINE_REVELAR)
	tween.parallel().tween_property(contenedor_juego, "modulate:a", 1.0, CINE_REVELAR * 0.8)
	tween.tween_callback(_mostrar_tutorial)

func _mostrar_tutorial() -> void:
	if id_tutorial != "" and not await Supabase.tutorial_fue_visto(id_tutorial):
		Supabase.marcar_tutorial_visto(id_tutorial)
		var modal = TutorialModal.crear(self, tutorial)
		await modal.terminado

	juego_activo = true
	_empezar()

# Festejo, pago del trabajo activo segun los errores y vuelta a la sala.
func terminar() -> void:
	if juego_terminado:
		return
	juego_terminado = true
	juego_activo = false
	label_instruccion.text = texto_final

	Efectos.confeti(contenedor_juego, Vector2(ANCHO / 2.0, 360), 40)
	Efectos.texto_flotante(contenedor_juego, texto_final, Vector2(ANCHO / 2.0, 380), COLOR_CHISPA, 30)
	await get_tree().create_timer(1.2).timeout

	var resultado := _evaluar(errores)
	var payment: int = Supabase.active_work_payment
	var points: int = Supabase.active_work_points
	label_instruccion.text = "Guardando..."
	var ok: bool = await Supabase.complete_active_work(resultado["bono_pago"], resultado["bono_puntos"])
	label_instruccion.text = ""

	var modal = TutorialModal.crear(self, [_pagina_resultado(ok, payment, points, resultado)])
	await modal.terminado

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(_filtro_oscuro, "modulate:a", 1.0, CINE_SALIDA)
	tween.parallel().tween_property(contenedor_juego, "modulate:a", 0.0, CINE_SALIDA * 0.9)
	tween.tween_interval(CINE_NEGRO)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/room.tscn"))

func _evaluar(total_errores: int) -> Dictionary:
	for tramo in tramos:
		if total_errores <= tramo["max_errores"]:
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
			"texto": "Terminaste el trabajo, pero no se pudo guardar el pago.\n\nRevisa tu conexion e intentalo de nuevo.",
			"boton": "Continuar",
		}

	var texto := "%s\nErrores: %d\n\n+ $%d\n+ %d puntos" % [resultado["detalle"], errores, payment, points]
	if resultado["bono_pago"] != 0 or resultado["bono_puntos"] != 0:
		texto += "\n\nPrecision: +$%d  |  +%d pts" % [resultado["bono_pago"], resultado["bono_puntos"]]

	return {"titulo": resultado["titulo"], "texto": texto, "boton": "Continuar"}

# --- Ayudas para los desafios ---

# Paso bien hecho: texto que salta y, si van varios seguidos, la racha.
func acierto(texto: String, pos: Vector2) -> void:
	racha += 1
	Efectos.texto_flotante(contenedor_juego, texto, pos, COLOR_OK)
	if racha >= RACHA_MINIMA:
		Efectos.texto_flotante(contenedor_juego, "¡Racha x%d!" % racha, pos + Vector2(0, 30), COLOR_CHISPA, 18)

# Error: suma, corta la racha, avisa y sacude la pantalla.
func error(texto: String, pos: Vector2) -> void:
	errores += 1
	racha = 0
	Efectos.texto_flotante(contenedor_juego, texto, pos, COLOR_ERROR, 24)
	Efectos.sacudir(contenedor_juego, 4.0, 0.2)
	label_errores.modulate = COLOR_ERROR
	create_tween().tween_property(label_errores, "modulate", Color.WHITE, 0.3)
	_actualizar_errores()

func _actualizar_errores() -> void:
	label_errores.text = "Errores: %d" % errores

func _label(pos: Vector2, tam: Vector2, fuente: int, alineacion: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = tam
	label.horizontal_alignment = alineacion
	label.add_theme_font_size_override("font_size", fuente)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenedor_juego.add_child(label)
	return label

static func circulo(radio: float, color: Color, lados: int = 24) -> Polygon2D:
	var puntos := PackedVector2Array()
	for i in lados:
		puntos.append(Vector2.from_angle(TAU * i / lados) * radio)
	var p := Polygon2D.new()
	p.polygon = puntos
	p.color = color
	return p

static func rectangulo(rect: Rect2, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)
	])
	p.color = color
	return p

# Boton grande que se mantiene pulsado (o la tecla de accion): devuelve el
# Button para conectar button_down / button_up.
func boton_grande(texto: String, pos: Vector2, tam: Vector2 = Vector2(220, 70)) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.position = pos - tam / 2.0
	boton.size = tam
	boton.add_theme_font_size_override("font_size", 24)
	# Sin foco: si no, Enter/Espacio lo activarian ademas de la accion
	# "ui_accept" que ya escuchan los minijuegos.
	boton.focus_mode = Control.FOCUS_NONE
	contenedor_juego.add_child(boton)
	return boton
