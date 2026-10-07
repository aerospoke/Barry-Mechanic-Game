extends Node2D

# Minijuego de cambio de aceite: mismo esqueleto que mini_game_keys.gd y
# mini_game_filter.gd (cinematica -> tutorial -> desafio -> resultado ->
# vuelta a la sala).
#
# El desafio es "atrapar gotas": la botella va y viene sola por arriba (como
# la aguja de la cerradura) y mientras se mantiene pulsado el boton se
# inclina y suelta gotas. Las que caen en el embudo llenan el motor; las que
# no, manchan el piso. Una guia punteada marca donde caerian las gotas y se
# pone verde cuando apunta al embudo. Al pasar la mitad el embudo tambien
# empieza a moverse, y la botella acelera a medida que se llena el motor.
# El puntaje final sale de cuantas manchas quedaron en el piso.

# --- NODOS DE LA CINEMÁTICA ---
@onready var engine_sprite = $MotorCine
@onready var filtro_oscuro = $FiltroOscuro

# --- NODOS DEL MINIJUEGO ---
@onready var contenedor_juego: Node2D = $ContenedorJuego
@onready var botella: Sprite2D = $ContenedorJuego/Botella
@onready var pico: Marker2D = $ContenedorJuego/Botella/Pico
@onready var embudo: Node2D = $ContenedorJuego/Embudo
@onready var guia: Line2D = $ContenedorJuego/Guia
@onready var gotas_nodo: Node2D = $ContenedorJuego/Gotas
@onready var medidor_relleno: ColorRect = $ContenedorJuego/MedidorRelleno
@onready var label_motor: Label = $ContenedorJuego/LabelMotor
@onready var label_manchas: Label = $ContenedorJuego/LabelManchas
@onready var label_instruccion: Label = $ContenedorJuego/LabelInstruccion
@onready var button_action: TouchScreenButton = $ContenedorJuego/buttonAction

const TutorialModal = preload("res://scripts/tutorial_modal.gd")

# Id en el catalogo `tutorials` (ver sql/tutorials_minigame_oil_v2.sql).
# Es uno nuevo, no "minigame_oil": las reglas cambiaron y quien ya vio el
# tutorial viejo tiene que ver este.
const ID_TUTORIAL := "minigame_oil_v2"

const TUTORIAL := [
	{
		"titulo": "Cambio de aceite",
		"texto": "Tu trabajo es llenar el motor de aceite hasta el 100%.\n\nLa botella se mueve sola de un lado al otro por arriba.",
	},
	{
		"titulo": "Verter",
		"texto": "Manten pulsado el boton para inclinar la botella y soltar gotas.\n\nLa linea punteada te muestra donde van a caer: cuando se pone verde, estas apuntando al embudo.",
	},
	{
		"titulo": "No manches el piso",
		"texto": "Cada gota que cae fuera del embudo deja una mancha.\n\nSuelta el boton cuando la botella se aleje del embudo.",
	},
	{
		"titulo": "Se pone dificil",
		"texto": "Mientras mas aceite tiene el motor, mas rapido va la botella.\n\nY a la mitad... el embudo tambien empieza a moverse. ¡Haz combos sin manchar!",
	},
]

# --- TIEMPOS DE LA CINEMÁTICA (segundos), mismos que los otros minijuegos ---
const CINE_FADE_IN: float = 1.2
const CINE_VISIBLE: float = 2.2
const CINE_FADE_OUT: float = 1.0
const CINE_NEGRO: float = 0.6
const CINE_REVELAR: float = 1.0
const CINE_SALIDA: float = 1.4

var engine_textures = [
	preload("res://enginesCars/engine1.png"),
	preload("res://enginesCars/engine2.png"),
	preload("res://enginesCars/engine3.png"),
	preload("res://enginesCars/engine4.png")
]
var escala_original: Vector2

# --- DESAFIO ---
const COLOR_ACEITE := Color(0.85, 0.62, 0.15)
const COLOR_GUIA := Color(1, 1, 1, 0.25)
const COLOR_GUIA_OK := Color(0.4, 1.0, 0.5, 0.8)

# Recorrido horizontal del pico de la botella (no de su centro: el pico
# queda corrido a la izquierda cuando se inclina).
const PICO_X_MIN := 50.0
const PICO_X_MAX := 290.0
const VELOCIDAD_BOTELLA_INICIAL := 110.0
const VELOCIDAD_BOTELLA_FINAL := 210.0

const ANGULO_VERTER := -80.0
# Desde esta inclinacion ya salen gotas (la botella tarda un toque en girar).
const ANGULO_MINIMO_VERTER := -60.0
const GIRO_BOTELLA := 10.0

const GOTAS_POR_SEGUNDO := 14.0
const GRAVEDAD := 1300.0
const RADIO_GOTA := 5.0
const ACEITE_POR_GOTA := 1.5

# Boca del embudo: una gota que cruza esta altura a menos de RADIO_EMBUDO del
# centro entra; si no, sigue hasta el piso y mancha.
const BOCA_EMBUDO_Y := 500.0
const RADIO_EMBUDO := 50.0
const PISO_Y := 705.0

# Desde este nivel el embudo empieza a ir y venir.
const NIVEL_EMBUDO_MOVIL := 50.0
const EMBUDO_X_CENTRO := 170.0
const EMBUDO_AMPLITUD := 60.0
const EMBUDO_VELOCIDAD := 1.6

# Alto del medidor del motor en la escena (ver Medidor/MedidorRelleno).
const MEDIDOR_ABAJO := 640.0
const MEDIDOR_ALTO := 360.0

const TRAMOS_PRECISION := [
	{"max_manchas": 2, "pago": 0.5, "puntos": 3, "titulo": "¡Ni una gota afuera!", "detalle": "Pulso de mecanico profesional."},
	{"max_manchas": 8, "pago": 0.25, "puntos": 2, "titulo": "Muy bien", "detalle": "Apenas unas manchitas."},
	{"max_manchas": 20, "pago": 0.1, "puntos": 1, "titulo": "Aceptable", "detalle": "Hay que pasar el trapo."},
	{"max_manchas": 999999, "pago": 0.0, "puntos": 0, "titulo": "¡Que enchastre!", "detalle": "El taller quedo resbaloso."},
]

var nivel_motor: float = 0.0
var manchas: int = 0
var combo: int = 0

var pico_x: float = PICO_X_MIN
var direccion_botella: float = 1.0
var acumulador_gotas: float = 0.0
var tiempo_embudo: float = 0.0
var embudo_movil: bool = false

# Cada gota en el aire: {"nodo": Polygon2D, "vel": Vector2}.
var gotas: Array = []

var juego_terminado: bool = false
var tutorial_activo: bool = false

func _ready() -> void:
	escala_original = engine_sprite.scale

	contenedor_juego.visible = false
	contenedor_juego.modulate.a = 0.0

	filtro_oscuro.modulate.a = 1.0
	filtro_oscuro.visible = true
	filtro_oscuro.z_index = 100

	engine_sprite.texture = engine_textures.pick_random()

	iniciar_cinematica()

# Cinematica identica a la de los otros minijuegos: mismo paneo, mismos tiempos.
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
	tween_filtro.tween_callback(iniciar_juego_aceite)

func iniciar_juego_aceite() -> void:
	engine_sprite.visible = false

	contenedor_juego.visible = true
	contenedor_juego.modulate.a = 0.0

	_mover_botella(0.0)
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

	_mover_botella(delta)
	_mover_embudo(delta)
	_verter(delta)
	_mover_gotas(delta)

# --- Botella -----------------------------------------------------------------

func _mover_botella(delta: float) -> void:
	var avance := clampf(nivel_motor / 100.0, 0.0, 1.0)
	var velocidad := lerpf(VELOCIDAD_BOTELLA_INICIAL, VELOCIDAD_BOTELLA_FINAL, avance)

	pico_x += velocidad * direccion_botella * delta
	if pico_x >= PICO_X_MAX:
		pico_x = PICO_X_MAX
		direccion_botella = -1.0
	elif pico_x <= PICO_X_MIN:
		pico_x = PICO_X_MIN
		direccion_botella = 1.0

	# Se posiciona la botella para que el pico (inclinado) quede en pico_x:
	# asi la guia y las gotas coinciden con lo que se mueve en pantalla.
	botella.position.x = pico_x - _pico_inclinado().x

	var x_guia := botella.position.x + _pico_inclinado().x
	var apunta := absf(x_guia - embudo.position.x) <= RADIO_EMBUDO
	guia.points = PackedVector2Array([Vector2(x_guia, botella.position.y + _pico_inclinado().y), Vector2(x_guia, BOCA_EMBUDO_Y)])
	guia.default_color = COLOR_GUIA_OK if apunta else COLOR_GUIA

# Desplazamiento del pico respecto del centro de la botella cuando esta
# inclinada del todo, en coordenadas de pantalla.
func _pico_inclinado() -> Vector2:
	return (pico.position * botella.scale).rotated(deg_to_rad(ANGULO_VERTER))

func _verter(delta: float) -> void:
	var pulsado := Input.is_action_pressed("ui_accept") or button_action.is_pressed()
	var objetivo := deg_to_rad(ANGULO_VERTER) if pulsado else 0.0
	botella.rotation = lerp_angle(botella.rotation, objetivo, GIRO_BOTELLA * delta)

	if not pulsado or botella.rotation > deg_to_rad(ANGULO_MINIMO_VERTER):
		acumulador_gotas = 0.0
		return

	acumulador_gotas += GOTAS_POR_SEGUNDO * delta
	while acumulador_gotas >= 1.0:
		acumulador_gotas -= 1.0
		_crear_gota(pico.global_position)

# --- Embudo ------------------------------------------------------------------

func _mover_embudo(delta: float) -> void:
	if not embudo_movil:
		return
	tiempo_embudo += delta
	embudo.position.x = EMBUDO_X_CENTRO + sin(tiempo_embudo * EMBUDO_VELOCIDAD) * EMBUDO_AMPLITUD

# --- Gotas -------------------------------------------------------------------

func _crear_gota(pos: Vector2) -> void:
	var nodo := _circulo(RADIO_GOTA, COLOR_ACEITE)
	nodo.position = pos + Vector2(randf_range(-2.0, 2.0), 0.0)
	gotas_nodo.add_child(nodo)
	gotas.append({"nodo": nodo, "vel": Vector2(0.0, 60.0)})

func _mover_gotas(delta: float) -> void:
	for i in range(gotas.size() - 1, -1, -1):
		var gota: Dictionary = gotas[i]
		var nodo: Polygon2D = gota["nodo"]
		var y_antes := nodo.position.y
		var vel: Vector2 = gota["vel"]
		vel.y += GRAVEDAD * delta
		gota["vel"] = vel
		nodo.position += vel * delta

		# Cruzo la boca del embudo en este frame.
		if y_antes < BOCA_EMBUDO_Y and nodo.position.y >= BOCA_EMBUDO_Y:
			if absf(nodo.position.x - embudo.position.x) <= RADIO_EMBUDO:
				gotas.remove_at(i)
				nodo.queue_free()
				_gota_atrapada()
				if juego_terminado:
					return
				continue

		if nodo.position.y >= PISO_Y:
			gotas.remove_at(i)
			_mancha(nodo)

func _gota_atrapada() -> void:
	nivel_motor = minf(100.0, nivel_motor + ACEITE_POR_GOTA)
	combo += 1

	# Pequeño "glup" del embudo en cada gota.
	var tween := create_tween()
	tween.tween_property(embudo, "scale", Vector2(1.08, 0.92), 0.05)
	tween.tween_property(embudo, "scale", Vector2.ONE, 0.1)

	if combo > 0 and combo % 10 == 0:
		_texto_flotante("¡Combo x%d!" % combo, Vector2(embudo.position.x, BOCA_EMBUDO_Y - 60), Color(1, 0.85, 0.3))

	if not embudo_movil and nivel_motor >= NIVEL_EMBUDO_MOVIL:
		embudo_movil = true
		_texto_flotante("¡El embudo se mueve!", Vector2(210, 330), Color(0.5, 0.85, 1.0))

	_actualizar_ui()

	if nivel_motor >= 100.0:
		_terminar_juego()

# La gota se aplasta en el piso y se desvanece de a poco.
func _mancha(nodo: Polygon2D) -> void:
	manchas += 1
	combo = 0
	nodo.position.y = PISO_Y + randf_range(0.0, 12.0)

	var tween := create_tween()
	tween.tween_property(nodo, "scale", Vector2(2.2, 0.5), 0.08)
	tween.tween_interval(1.2)
	tween.tween_property(nodo, "modulate:a", 0.0, 0.6)
	tween.tween_callback(nodo.queue_free)

	_flash_label(label_manchas, Color(1, 0.4, 0.4))
	_actualizar_ui()

func _circulo(radio: float, color: Color) -> Polygon2D:
	var puntos := PackedVector2Array()
	for i in 12:
		puntos.append(Vector2.from_angle(TAU * i / 12.0) * radio)
	var p := Polygon2D.new()
	p.polygon = puntos
	p.color = color
	return p

# --- UI ----------------------------------------------------------------------

func _actualizar_ui() -> void:
	label_motor.text = "Motor: %d%%" % int(nivel_motor)
	label_manchas.text = "Manchas: %d" % manchas

	var alto := MEDIDOR_ALTO * nivel_motor / 100.0
	medidor_relleno.offset_top = MEDIDOR_ABAJO - alto

func _texto_flotante(texto: String, pos: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	contenedor_juego.add_child(label)
	label.position = pos - label.get_combined_minimum_size() / 2.0
	label.pivot_offset = label.get_combined_minimum_size() / 2.0
	label.scale = Vector2(0.5, 0.5)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.25)
	tween.tween_property(label, "position:y", label.position.y - 40.0, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)

func _flash_label(label: Label, color: Color) -> void:
	label.modulate = color
	var tween := create_tween()
	tween.tween_property(label, "modulate", Color.WHITE, 0.3)

# --- Final -------------------------------------------------------------------

func _terminar_juego() -> void:
	juego_terminado = true
	button_action.visible = false
	guia.visible = false
	label_instruccion.text = "¡Motor lleno!"

	# Las gotas que quedaban en el aire ya no cuentan.
	for gota in gotas:
		gota["nodo"].queue_free()
	gotas.clear()

	var tween := create_tween()
	tween.tween_property(botella, "rotation", 0.0, 0.3)
	tween.parallel().tween_property(medidor_relleno, "color", Color(0.35, 0.85, 0.4), 0.3)
	await tween.finished

	var resultado := _evaluar_precision(manchas)

	var payment = Supabase.active_work_payment
	var points = Supabase.active_work_points
	label_instruccion.text = "Guardando..."

	var ok = await Supabase.complete_active_work(resultado["bono_pago"], resultado["bono_puntos"])
	label_instruccion.text = ""

	var modal = TutorialModal.crear(self, [_pagina_resultado(ok, payment, points, resultado)])
	await modal.terminado

	var tween_salida := create_tween()
	tween_salida.set_trans(Tween.TRANS_SINE)
	tween_salida.set_ease(Tween.EASE_IN)
	tween_salida.tween_property(filtro_oscuro, "modulate:a", 1.0, CINE_SALIDA)
	tween_salida.parallel().tween_property(contenedor_juego, "modulate:a", 0.0, CINE_SALIDA * 0.9)
	tween_salida.tween_interval(CINE_NEGRO)
	tween_salida.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/room.tscn"))

func _evaluar_precision(total_manchas: int) -> Dictionary:
	for tramo in TRAMOS_PRECISION:
		if total_manchas <= tramo["max_manchas"]:
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
			"texto": "Llenaste el motor, pero no se pudo guardar el pago.\n\nRevisa tu conexion e intentalo de nuevo.",
			"boton": "Continuar",
		}

	var bono_pago: int = resultado["bono_pago"]
	var bono_puntos: int = resultado["bono_puntos"]

	var texto := "%s\nManchas en el piso: %d\n\n+ $%d\n+ %d puntos" % [
		resultado["detalle"], manchas, payment, points
	]

	if bono_pago != 0 or bono_puntos != 0:
		texto += "\n\nPrecision: +$%d  |  +%d pts" % [bono_pago, bono_puntos]

	return {
		"titulo": resultado["titulo"],
		"texto": texto,
		"boton": "Continuar",
	}
