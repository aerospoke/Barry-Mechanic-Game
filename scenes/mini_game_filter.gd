extends Node2D

# Minijuego de cambio de filtro de aire: mismo esqueleto que mini_game_oil.gd
# y mini_game_keys.gd (cinematica -> tutorial -> desafio -> resultado ->
# vuelta a la sala). La cinematica es la misma que la de mini_game_oil.gd
# (imagen de motor al azar + paneo + fundido a negro), para que las tres
# pantallas de carga se vean identicas.
#
# El desafio es un cambio de filtro real:
#   1) Arrastrar el destornillador a cada tornillo de la tapa para aflojarlos.
#   2) Arrastrar la tapa para destapar la carcasa.
#   3) Arrastrar el filtro viejo a la papelera.
#   4) Arrastrar el filtro nuevo (desde su caja) a la carcasa.
#   5) Automatico: a los 2s la tapa vuelve sola y los tornillos se acomodan
#      uno por uno (el filtro nuevo queda tapado, ya no se ve).
#   6) Arrastrar el destornillador de nuevo a cada tornillo para apretarlos.
#
# Cada arrastre que se suelta fuera de su destino cuenta como error (ver
# scripts/draggable_2d.gd).

# --- NODOS DE LA CINEMÁTICA (identica a mini_game_oil.gd) ---
@onready var engine_sprite = $FiltroCine
@onready var filtro_oscuro = $FiltroOscuro

# --- NODOS DEL MINIJUEGO ---
@onready var contenedor_juego = $ContenedorJuego
@onready var label_instruccion = $ContenedorJuego/LabelInstruccion
@onready var tapa = $ContenedorJuego/Tapa
@onready var filtro_viejo = $ContenedorJuego/FiltroViejo
@onready var filtro_nuevo = $ContenedorJuego/FiltroNuevo
@onready var destornillador = $ContenedorJuego/Destornillador
@onready var tornillo_izquierdo = $ContenedorJuego/TornilloIzquierdo
@onready var tornillo_derecho = $ContenedorJuego/TornilloDerecho
@onready var marca_ranura = $ContenedorJuego/MarcaRanura
@onready var marca_abierta = $ContenedorJuego/MarcaAbierta
@onready var marca_papelera = $ContenedorJuego/MarcaPapelera
@onready var marca_tornillo_izq = $ContenedorJuego/MarcaTornilloIzq
@onready var marca_tornillo_der = $ContenedorJuego/MarcaTornilloDer

const TutorialModal = preload("res://scripts/tutorial_modal.gd")

# Id en el catalogo `tutorials` (ver sql/tutorials_minigame_filter.sql).
const ID_TUTORIAL := "minigame_filter"

const TUTORIAL := [
	{
		"titulo": "Cambio de filtro de aire",
		"texto": "Tu trabajo es cambiar el filtro completo: aflojar los tornillos de la tapa, sacar el filtro viejo y poner uno nuevo.",
	},
	{
		"titulo": "El destornillador",
		"texto": "La tapa tiene dos tornillos. Arrastra el destornillador hasta cada uno para aflojarlos.\n\nAl final los volves a apretar de la misma forma.",
	},
	{
		"titulo": "Arrastrar las piezas",
		"texto": "Con los tornillos flojos, arrastra la tapa para destapar la carcasa.\n\nDespues arrastra el filtro viejo hasta la papelera, y el nuevo desde su caja hasta la carcasa.",
	},
	{
		"titulo": "Cuidado al soltar",
		"texto": "Si soltas una pieza lejos de donde va, vuelve sola a su lugar y cuenta como error.\n\nMientras menos errores, mejor pago.",
	},
]

# --- TIEMPOS DE LA CINEMÁTICA (segundos), identicos a mini_game_oil.gd ---
const CINE_FADE_IN: float = 1.2
const CINE_VISIBLE: float = 2.2
const CINE_FADE_OUT: float = 1.0
const CINE_NEGRO: float = 0.6
const CINE_REVELAR: float = 1.0
const CINE_SALIDA: float = 1.4

# Espera entre poner el filtro nuevo y que arranque la animacion de cierre.
const ESPERA_CIERRE_AUTOMATICO: float = 2.0

var escala_original: Vector2

var engine_textures = [
	preload("res://enginesCars/engine1.png"),
	preload("res://enginesCars/engine2.png"),
	preload("res://enginesCars/engine3.png"),
	preload("res://enginesCars/engine4.png")
]

# --- PASOS DEL DESAFIO ---
enum Paso { ABRIR_TORNILLOS, LEVANTAR_TAPA, SACAR_VIEJO, PONER_NUEVO, CERRAR_TORNILLOS, TERMINADO }
var paso_actual: Paso = Paso.ABRIR_TORNILLOS

# Cola de tornillos que faltan para el paso actual (aflojar o apretar).
var tornillos_pendientes: Array = []

# Posiciones "puestas" (en la carcasa) y "afuera" (sacadas, a un costado) de
# cada tornillo, calculadas en _ready() a partir de su posicion inicial.
var _tornillo_izq_puesto: Vector2
var _tornillo_izq_afuera: Vector2
var _tornillo_der_puesto: Vector2
var _tornillo_der_afuera: Vector2

var errores: int = 0
var juego_terminado: bool = false
var tutorial_activo: bool = false

const TRAMOS_PRECISION := [
	{"max_errores": 0, "pago": 0.5, "puntos": 3, "titulo": "¡Perfecto!", "detalle": "Ningun error."},
	{"max_errores": 1, "pago": 0.25, "puntos": 2, "titulo": "Muy bien", "detalle": "Casi sin errores."},
	{"max_errores": 3, "pago": 0.1, "puntos": 1, "titulo": "Aceptable", "detalle": "Te costo un poco."},
	{"max_errores": 999999, "pago": 0.0, "puntos": 0, "titulo": "Costo, pero quedo cambiado", "detalle": "Tuviste bastantes errores, pero terminaste."},
]

func _ready() -> void:
	escala_original = engine_sprite.scale

	contenedor_juego.visible = false
	contenedor_juego.modulate.a = 0.0

	filtro_oscuro.modulate.a = 1.0
	filtro_oscuro.visible = true
	filtro_oscuro.z_index = 100

	engine_sprite.texture = engine_textures.pick_random()

	_tornillo_izq_puesto = tornillo_izquierdo.position
	_tornillo_izq_afuera = _tornillo_izq_puesto + Vector2(-70.0, -55.0)
	_tornillo_der_puesto = tornillo_derecho.position
	_tornillo_der_afuera = _tornillo_der_puesto + Vector2(70.0, -55.0)

	_configurar_estado_inicial()

	tapa.soltado_en_destino.connect(_on_tapa_ok)
	tapa.soltado_fuera.connect(_on_error)
	filtro_viejo.soltado_en_destino.connect(_on_filtro_viejo_ok)
	filtro_viejo.soltado_fuera.connect(_on_error)
	filtro_nuevo.soltado_en_destino.connect(_on_filtro_nuevo_ok)
	filtro_nuevo.soltado_fuera.connect(_on_error)
	destornillador.soltado_en_destino.connect(_on_destornillador_ok)
	destornillador.soltado_fuera.connect(_on_error)

	iniciar_cinematica()

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

	var tween_filtro = create_tween()
	tween_filtro.set_trans(Tween.TRANS_SINE)
	tween_filtro.tween_property(filtro_oscuro, "modulate:a", 0.0, CINE_FADE_IN).set_ease(Tween.EASE_OUT)
	tween_filtro.tween_interval(CINE_VISIBLE)
	tween_filtro.tween_property(filtro_oscuro, "modulate:a", 1.0, CINE_FADE_OUT).set_ease(Tween.EASE_IN)
	tween_filtro.tween_interval(CINE_NEGRO)
	tween_filtro.tween_callback(iniciar_juego_filtro)

func iniciar_juego_filtro() -> void:
	engine_sprite.visible = false

	contenedor_juego.visible = true
	contenedor_juego.modulate.a = 0.0

	var tween_revelar = create_tween()
	tween_revelar.set_trans(Tween.TRANS_SINE)
	tween_revelar.set_ease(Tween.EASE_OUT)
	tween_revelar.tween_property(filtro_oscuro, "modulate:a", 0.0, CINE_REVELAR)
	tween_revelar.parallel().tween_property(contenedor_juego, "modulate:a", 1.0, CINE_REVELAR * 0.8)
	tween_revelar.tween_callback(mostrar_tutorial)

func mostrar_tutorial() -> void:
	if await Supabase.tutorial_fue_visto(ID_TUTORIAL):
		_iniciar_paso(Paso.ABRIR_TORNILLOS)
		return
	Supabase.marcar_tutorial_visto(ID_TUTORIAL)

	tutorial_activo = true
	var modal = TutorialModal.crear(self, TUTORIAL)
	await modal.terminado
	tutorial_activo = false

	_iniciar_paso(Paso.ABRIR_TORNILLOS)

# Todo bloqueado hasta que arranca el desafio (cinematica y/o tutorial de por
# medio): evita que se pueda arrastrar algo detras del modal.
func _configurar_estado_inicial() -> void:
	label_instruccion.text = ""

	destornillador.habilitado = false

	tapa.habilitado = false
	tapa.destino = marca_abierta

	filtro_viejo.visible = false
	filtro_viejo.habilitado = false
	filtro_viejo.destino = marca_papelera

	filtro_nuevo.habilitado = false
	filtro_nuevo.destino = marca_ranura

func _iniciar_paso(paso: Paso) -> void:
	paso_actual = paso

	match paso:
		Paso.ABRIR_TORNILLOS:
			label_instruccion.text = "Lleva el destornillador a cada tornillo para aflojarlo."
			tornillos_pendientes = [marca_tornillo_izq, marca_tornillo_der]
			destornillador.destino = tornillos_pendientes[0]
			destornillador.habilitado = true
		Paso.LEVANTAR_TAPA:
			label_instruccion.text = "Arrastra la tapa hacia abajo para destaparla."
			tapa.destino = marca_abierta
			tapa.habilitado = true
		Paso.SACAR_VIEJO:
			label_instruccion.text = "Arrastra el filtro viejo hasta la papelera."
			filtro_viejo.visible = true
			filtro_viejo.habilitado = true
		Paso.PONER_NUEVO:
			label_instruccion.text = "Arrastra el filtro nuevo hasta la carcasa."
			filtro_nuevo.habilitado = true
		Paso.CERRAR_TORNILLOS:
			label_instruccion.text = "Toma el destornillador para apretar los tornillos."
			tornillos_pendientes = [marca_tornillo_izq, marca_tornillo_der]
			destornillador.destino = tornillos_pendientes[0]
			destornillador.habilitado = true
		Paso.TERMINADO:
			_terminar_juego()

func _on_tapa_ok() -> void:
	tapa.habilitado = false
	_iniciar_paso(Paso.SACAR_VIEJO)

func _on_filtro_viejo_ok() -> void:
	filtro_viejo.habilitado = false
	filtro_viejo.visible = false
	_iniciar_paso(Paso.PONER_NUEVO)

func _on_filtro_nuevo_ok() -> void:
	filtro_nuevo.habilitado = false
	label_instruccion.text = "Ajustando la tapa..."

	await get_tree().create_timer(ESPERA_CIERRE_AUTOMATICO).timeout
	await _animacion_cierre_automatico()

	_iniciar_paso(Paso.CERRAR_TORNILLOS)

# Cierre automatico: la tapa vuelve sola a su lugar (tapando el filtro nuevo,
# que deja de verse) y los tornillos se acomodan uno por uno antes de pedirle
# al jugador que los apriete.
func _animacion_cierre_automatico() -> void:
	# La tapa esta despues del filtro en el arbol (se dibuja detras): mientras
	# viaja de vuelta hay que subirla al frente para que tape el filtro en
	# vez de pasar por encima de ella.
	tapa.z_index = 10

	var tween_tapa := create_tween()
	tween_tapa.set_trans(Tween.TRANS_SINE)
	tween_tapa.set_ease(Tween.EASE_OUT)
	tween_tapa.tween_property(tapa, "global_position", marca_ranura.global_position, 0.6)
	await tween_tapa.finished

	# El filtro quedo debajo de la tapa: ya no debe verse.
	filtro_nuevo.visible = false
	tapa.z_index = 0

	await _mover_tornillo(tornillo_izquierdo, _tornillo_izq_puesto)
	await get_tree().create_timer(0.2).timeout
	await _mover_tornillo(tornillo_derecho, _tornillo_der_puesto)

func _mover_tornillo(tornillo: Label, destino_pos: Vector2) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(tornillo, "position", destino_pos, 0.35)
	await tween.finished

# Gira el tornillo un par de vueltas: -1 para aflojar (sentido antihorario),
# 1 para apretar (sentido horario). Es solo cosmetico, no bloquea nada.
func _girar_tornillo(tornillo: Label, sentido: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(tornillo, "rotation", tornillo.rotation + sentido * TAU * 2.0, 0.4)

func _on_destornillador_ok() -> void:
	var objetivo = destornillador.destino
	var es_izquierdo: bool = objetivo == marca_tornillo_izq
	var tornillo: Label = tornillo_izquierdo if es_izquierdo else tornillo_derecho

	if paso_actual == Paso.ABRIR_TORNILLOS:
		_girar_tornillo(tornillo, -1.0)
		_mover_tornillo(tornillo, _tornillo_izq_afuera if es_izquierdo else _tornillo_der_afuera)
	elif paso_actual == Paso.CERRAR_TORNILLOS:
		_girar_tornillo(tornillo, 1.0)

	tornillos_pendientes.erase(objetivo)

	if tornillos_pendientes.is_empty():
		destornillador.habilitado = false
		if paso_actual == Paso.ABRIR_TORNILLOS:
			_iniciar_paso(Paso.LEVANTAR_TAPA)
		elif paso_actual == Paso.CERRAR_TORNILLOS:
			_iniciar_paso(Paso.TERMINADO)
	else:
		destornillador.destino = tornillos_pendientes[0]

# Cualquier pieza que se suelta lejos de su destino cuenta como error, sin
# importar cual sea: es siempre "intentaste mal ese paso".
func _on_error() -> void:
	if juego_terminado:
		return
	errores += 1
	_flash(label_instruccion, Color(1.0, 0.3, 0.2))

# Pulso corto de color para marcar el error, sin depender de sprites nuevos.
func _flash(nodo: Label, color: Color) -> void:
	var original := nodo.modulate
	var tween := create_tween()
	tween.tween_property(nodo, "modulate", color, 0.08)
	tween.tween_property(nodo, "modulate", original, 0.3)

func _terminar_juego() -> void:
	juego_terminado = true
	label_instruccion.text = "¡Listo!"

	var resultado := _evaluar_precision(errores)

	var payment = Supabase.active_work_payment
	var points = Supabase.active_work_points

	var ok = await Supabase.complete_active_work(resultado["bono_pago"], resultado["bono_puntos"])

	var modal = TutorialModal.crear(self, [_pagina_resultado(ok, payment, points, resultado)])
	await modal.terminado

	var tween_salida := create_tween()
	tween_salida.set_trans(Tween.TRANS_SINE)
	tween_salida.set_ease(Tween.EASE_IN)
	tween_salida.tween_property(filtro_oscuro, "modulate:a", 1.0, CINE_SALIDA)
	tween_salida.parallel().tween_property(contenedor_juego, "modulate:a", 0.0, CINE_SALIDA * 0.9)
	tween_salida.tween_interval(CINE_NEGRO)
	tween_salida.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/room.tscn"))

func _evaluar_precision(total_errores: int) -> Dictionary:
	for tramo in TRAMOS_PRECISION:
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
			"texto": "Cambiaste el filtro, pero no se pudo guardar el pago.\n\nRevisa tu conexion e intentalo de nuevo.",
			"boton": "Continuar",
		}

	var bono_pago: int = resultado["bono_pago"]
	var bono_puntos: int = resultado["bono_puntos"]

	var texto := "%s\nErrores: %d\n\n+ $%d\n+ %d puntos" % [
		resultado["detalle"], errores, payment, points
	]

	if bono_pago != 0 or bono_puntos != 0:
		texto += "\n\nPrecision: +$%d  |  +%d pts" % [bono_pago, bono_puntos]

	return {
		"titulo": resultado["titulo"],
		"texto": texto,
		"boton": "Continuar",
	}
