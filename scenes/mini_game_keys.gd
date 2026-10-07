extends Node2D

# Minijuego de cerrajeria: forzar una cerradura pin por pin. Mismo esqueleto
# que mini_game_oil.gd (cinematica -> tutorial -> desafio -> resultado ->
# vuelta a la sala) pero con un desafio mas simple: una aguja rebota entre
# 0 y 100 y hay que pulsar el boton cuando esta dentro de la zona marcada.
# Cada pin acertado achica la zona y acelera la aguja; el puntaje final sale
# de cuantos fallos tuviste en total.

# --- NODOS DE LA CINEMÁTICA ---
@onready var engine_sprite = $MotorCine
@onready var filtro_oscuro = $FiltroOscuro

# --- NODOS DEL MINIJUEGO ---
@onready var contenedor_juego = $ContenedorJuego
@onready var candado: Node2D = $ContenedorJuego/Candado  # chapa del minijuego
@onready var label_pin = $ContenedorJuego/LabelPin
@onready var label_fallos = $ContenedorJuego/LabelFallos
@onready var zona_objetivo = $ContenedorJuego/ZonaObjetivo
@onready var aguja = $ContenedorJuego/Aguja
@onready var button_action = $ContenedorJuego/buttonAction

var engine_textures = [
	preload("res://enginesCars/engine1.png"),
	preload("res://enginesCars/engine2.png"),
	preload("res://enginesCars/engine3.png"),
	preload("res://enginesCars/engine4.png")
]
var escala_original: Vector2

const TutorialModal = preload("res://scripts/tutorial_modal.gd")
const Efectos = preload("res://scripts/efectos.gd")

const COLOR_OK := Color(0.45, 1.0, 0.55)
const COLOR_ERROR := Color(1.0, 0.4, 0.35)
const COLOR_CHISPA := Color(1.0, 0.9, 0.45)
const COLOR_METAL := Color(0.8, 0.82, 0.86)

# Si la aguja queda a menos de esta fraccion del ancho de la zona respecto de
# su centro, el pin cuenta como "¡Perfecto!" (solo festejo, no cambia el pago).
const MARGEN_PERFECTO := 0.2
# Pines seguidos sin fallar; desde RACHA_MINIMA se muestra en pantalla.
const RACHA_MINIMA := 2

const COLOR_CROMO := Color(0.74, 0.76, 0.8)
const COLOR_CILINDRO := Color(0.1, 0.1, 0.12)
const COLOR_CILINDRO_ABIERTO := Color(0.2, 0.55, 0.3)

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

# Cuanto se hunde la ganzua en el ojo de la cerradura al abrir todos los
# pines (en pixeles de la puerta). La parte que entra se recorta.
const GANZUA_PROFUNDIDAD := 60.0
# Giro del cilindro por pin acertado, como la tension de la llave de torsion.
const CILINDRO_GIRO_PIN := 4.0
# Angulos entre los que oscila la segunda ganzua, siguiendo a la aguja del riel.
const GANZUA2_ANGULO_MIN := -5.0
const GANZUA2_ANGULO_MAX := 35.0

const TRAMOS_PRECISION := [
	{"max_fallos": 0, "pago": 0.5, "puntos": 3, "titulo": "¡Ni un fallo!", "detalle": "Cerrajero de primera."},
	{"max_fallos": 2, "pago": 0.25, "puntos": 2, "titulo": "Muy bien", "detalle": "Pocos fallos."},
	{"max_fallos": 5, "pago": 0.1, "puntos": 1, "titulo": "Aceptable", "detalle": "Se te resistio un poco."},
	{"max_fallos": 999999, "pago": 0.0, "puntos": 0, "titulo": "Costo, pero abrio", "detalle": "La forzaste igual."},
]

var pin_actual: int = 0
var fallos: int = 0
var racha: int = 0

var aguja_pos: float = 0.0
var aguja_dir: float = 1.0
var velocidad_aguja: float = VELOCIDAD_INICIAL

var zona_inicio: float = 0.0
var ancho_zona: float = ANCHO_ZONA_INICIAL

var juego_terminado: bool = false
var tutorial_activo: bool = false

# Ganzua dibujada por codigo (no hay sprite): su punta entra al ojo de la
# cerradura a medida que se acierta cada pin.
var ganzua: Node2D
var cilindro: Node2D  # parte giratoria de la cerradura del minijuego
var disco_cilindro: Polygon2D
var ganzua2: Node2D  # oscila en el ojo al ritmo de la aguja
var tween_ganzua: Tween

func _ready() -> void:
	contenedor_juego.visible = false
	contenedor_juego.modulate.a = 0.0

	filtro_oscuro.modulate.a = 1.0
	filtro_oscuro.visible = true
	filtro_oscuro.z_index = 100

	escala_original = engine_sprite.scale
	engine_sprite.texture = engine_textures.pick_random()

	_crear_puerta(candado)

	_crear_ganzua()

	iniciar_cinematica()

# Dibuja la chapa de la puerta del carro alrededor del origen del nodo: el
# ojo de la cerradura queda en (0, 0).
func _crear_puerta(padre: Node2D) -> void:
	# Cerradura: placa, aro cromado y cilindro con el ojo.
	_rect(padre, Rect2(-34, -30, 68, 60), COLOR_CROMO.darkened(0.45))
	_disco(padre, 24.0, COLOR_CROMO)

	cilindro = Node2D.new()
	padre.add_child(cilindro)
	disco_cilindro = _disco(cilindro, 18.0, COLOR_CILINDRO)
	_disco(cilindro, 4.5, Color.BLACK).position = Vector2(0, -3)
	_rect(cilindro, Rect2(-2.5, -3, 5, 14), Color.BLACK)

func _rect(padre: Node2D, rect: Rect2, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)
	])
	p.color = color
	padre.add_child(p)
	return p

func _disco(padre: Node2D, radio: float, color: Color) -> Polygon2D:
	var puntos := PackedVector2Array()
	for i in 28:
		puntos.append(Vector2.from_angle(TAU * i / 28.0) * radio)
	var p := Polygon2D.new()
	p.polygon = puntos
	p.color = color
	padre.add_child(p)
	return p

# Al abrir, el cilindro gira y se tiñe de verde.
func _abrir_cerradura() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(cilindro, "rotation_degrees", 90.0, 0.4)
	tween.parallel().tween_property(disco_cilindro, "color", COLOR_CILINDRO_ABIERTO, 0.4)

# La ganzua vive dentro de la puerta: su punta arranca en el ojo (0, 0) y
# un recorte justo en el ojo oculta la parte que va entrando.
func _crear_ganzua() -> void:
	var recorte := Control.new()
	recorte.position = Vector2(-300, -20)
	recorte.size = Vector2(300, 40)
	recorte.clip_contents = true
	recorte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	candado.add_child(recorte)

	ganzua = Node2D.new()
	ganzua.position = Vector2(300, 20)

	# Origen local = punta. Varilla de metal y mango.
	var varilla := Line2D.new()
	varilla.points = PackedVector2Array([Vector2(-90, 0), Vector2(4, 0)])
	varilla.width = 3.0
	varilla.default_color = Color(0.78, 0.8, 0.85)
	ganzua.add_child(varilla)

	var mango := Line2D.new()
	mango.points = PackedVector2Array([Vector2(-130, 0), Vector2(-90, 0)])
	mango.width = 9.0
	mango.default_color = Color(0.45, 0.28, 0.16)
	mango.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ganzua.add_child(mango)

	recorte.add_child(ganzua)

	# Segunda ganzua: pivota en el ojo y sale hacia la derecha. Va dentro del
	# cilindro para girar con el cuando se abre la cerradura.
	ganzua2 = Node2D.new()
	var varilla2 := Line2D.new()
	varilla2.points = PackedVector2Array([Vector2(0, 0), Vector2(45, 0)])
	varilla2.width = 3.0
	varilla2.default_color = Color(0.78, 0.8, 0.85)
	ganzua2.add_child(varilla2)

	var mango2 := Line2D.new()
	mango2.points = PackedVector2Array([Vector2(45, 0), Vector2(85, 0)])
	mango2.width = 8.0
	mango2.default_color = Color(0.3, 0.3, 0.34)
	mango2.end_cap_mode = Line2D.LINE_CAP_ROUND
	ganzua2.add_child(mango2)

	cilindro.add_child(ganzua2)
	_mover_ganzua2()

func _mover_ganzua2() -> void:
	ganzua2.rotation_degrees = lerpf(GANZUA2_ANGULO_MIN, GANZUA2_ANGULO_MAX, aguja_pos / 100.0)

# Hunde la ganzua en el ojo segun los pines abiertos y gira un poco el cilindro.
func _avanzar_ganzua(pines_abiertos: int) -> void:
	var x := 300.0 + GANZUA_PROFUNDIDAD * float(pines_abiertos) / TOTAL_PINES
	if tween_ganzua:
		tween_ganzua.kill()
	ganzua.position.y = 20.0
	tween_ganzua = create_tween()
	tween_ganzua.set_trans(Tween.TRANS_BACK)
	tween_ganzua.set_ease(Tween.EASE_OUT)
	tween_ganzua.tween_property(ganzua, "position:x", x, 0.35)
	# En el ultimo pin el giro completo lo hace _abrir_cerradura.
	if pines_abiertos < TOTAL_PINES:
		tween_ganzua.parallel().tween_property(cilindro, "rotation_degrees", CILINDRO_GIRO_PIN * pines_abiertos, 0.35)

# Pequeña sacudida vertical al fallar, como si la ganzua se trabara.
func _sacudir_ganzua() -> void:
	if tween_ganzua and tween_ganzua.is_running():
		return
	var base := ganzua.position
	tween_ganzua = create_tween()
	tween_ganzua.tween_property(ganzua, "position:y", base.y - 4.0, 0.04)
	tween_ganzua.tween_property(ganzua, "position:y", base.y + 4.0, 0.06)
	tween_ganzua.tween_property(ganzua, "position:y", base.y, 0.04)

# Cinematica identica a la de mini_game_oil.gd: mismo paneo, mismos tiempos.
func iniciar_cinematica() -> void:
	var centro_pantalla = get_viewport_rect().size / 2
	var direccion_aleatoria = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()

	var duracion_paneo = CINE_FADE_IN + CINE_VISIBLE + CINE_FADE_OUT
	var distancia_paneo = 120.0

	var punto_inicio = centro_pantalla + (direccion_aleatoria * distancia_paneo)
	var punto_fin = centro_pantalla - (direccion_aleatoria * distancia_paneo)

	engine_sprite.scale = escala_original * 1.15
	engine_sprite.position = punto_inicio

	var tween_motor = create_tween()
	tween_motor.set_trans(Tween.TRANS_SINE)
	tween_motor.set_ease(Tween.EASE_IN_OUT)
	tween_motor.tween_property(engine_sprite, "position", punto_fin, duracion_paneo)
	tween_motor.parallel().tween_property(engine_sprite, "scale", escala_original, duracion_paneo)

	var tween_filtro := create_tween()
	tween_filtro.set_trans(Tween.TRANS_SINE)
	tween_filtro.tween_property(filtro_oscuro, "modulate:a", 0.0, CINE_FADE_IN).set_ease(Tween.EASE_OUT)
	tween_filtro.tween_interval(CINE_VISIBLE)
	tween_filtro.tween_property(filtro_oscuro, "modulate:a", 1.0, CINE_FADE_OUT).set_ease(Tween.EASE_IN)
	tween_filtro.tween_interval(CINE_NEGRO)
	tween_filtro.tween_callback(iniciar_juego_llaves)

func iniciar_juego_llaves() -> void:
	engine_sprite.visible = false

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
	_mover_ganzua2()

	if Input.is_action_just_pressed("ui_accept"):
		_intentar_pin()

func _intentar_pin() -> void:
	if aguja_pos >= zona_inicio and aguja_pos <= zona_inicio + ancho_zona:
		pin_actual += 1
		_avanzar_ganzua(pin_actual)
		_flash(zona_objetivo, Color(0.4, 0.9, 0.45, 0.85))
		_festejar_pin()
		if pin_actual >= TOTAL_PINES:
			_terminar_juego()
		else:
			_preparar_pin(pin_actual)
	else:
		fallos += 1
		racha = 0
		_sacudir_ganzua()
		_flash(zona_objetivo, Color(0.9, 0.35, 0.35, 0.85))
		label_fallos.text = "Fallos: %d" % fallos
		Efectos.texto_flotante(contenedor_juego, "¡Uy!", candado.position + Vector2(0, -70), COLOR_ERROR, 26)
		Efectos.sacudir(candado, 5.0, 0.2)

# Chispas en el ojo de la cerradura, texto segun que tan centrado fue el
# acierto y la racha de pines seguidos sin fallar.
func _festejar_pin() -> void:
	racha += 1
	var centro_zona := zona_inicio + ancho_zona / 2.0
	var perfecto := absf(aguja_pos - centro_zona) <= ancho_zona * MARGEN_PERFECTO

	var pos := candado.position + Vector2(0, -70)
	if perfecto:
		Efectos.texto_flotante(contenedor_juego, "¡Perfecto!", pos, COLOR_CHISPA, 28)
		Efectos.nube(contenedor_juego, candado.position, COLOR_CHISPA, 14, 70.0, 0.5)
	else:
		Efectos.texto_flotante(contenedor_juego, "¡Click!", pos, COLOR_OK)
		Efectos.nube(contenedor_juego, candado.position, COLOR_METAL, 8, 45.0, 0.4)

	Efectos.rebote(candado, candado.scale, Vector2(1.08, 0.94))

	if racha >= RACHA_MINIMA:
		Efectos.texto_flotante(contenedor_juego, "¡Racha x%d!" % racha, pos + Vector2(0, 32), COLOR_CHISPA, 18)

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
	_abrir_cerradura()
	label_pin.text = "¡Cerradura abierta!"

	# Festejo: espera a que gire el cilindro y tira confeti.
	await get_tree().create_timer(0.45).timeout
	Efectos.sacudir(candado, 6.0)
	Efectos.confeti(contenedor_juego, candado.position, 40)
	Efectos.texto_flotante(contenedor_juego, "¡Abierta!", candado.position + Vector2(0, 110), COLOR_CHISPA, 32)
	await get_tree().create_timer(1.2).timeout

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
