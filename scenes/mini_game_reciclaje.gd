extends Node2D

# Minijuego de reciclaje del taller: se abre al interactuar con la caneca
# llena (ver Supabase.basura_llena() y movement_script.gd). Mismo esqueleto
# que los otros minijuegos (cinematica -> tutorial -> desafio -> resultado ->
# vuelta a la sala), pero no cierra un trabajo: vacia la caneca y paga una
# recompensa propia (Supabase.completar_reciclaje).
#
# El desafio: los residuos del taller pasan por una cinta transportadora y
# hay que arrastrar cada uno a su contenedor (plastico, carton, vidrio o
# llantas) antes de que se caiga por el otro lado. La cinta acelera a medida
# que avanza. Contenedor equivocado o residuo que se escapa = error.
#
# Los residuos y contenedores son datos (RESIDUOS / CONTENEDORES): sumar uno
# nuevo es agregar una linea, sin tocar la logica.

# --- NODOS DE LA CINEMÁTICA ---
@onready var engine_sprite: Sprite2D = $MotorCine
@onready var filtro_oscuro: ColorRect = $FiltroOscuro

# --- NODOS DEL MINIJUEGO ---
@onready var contenedor_juego: Node2D = $ContenedorJuego
@onready var label_instruccion: Label = $ContenedorJuego/LabelInstruccion
@onready var label_progreso: Label = $ContenedorJuego/LabelProgreso
@onready var label_errores: Label = $ContenedorJuego/LabelErrores

const TutorialModal = preload("res://scripts/tutorial_modal.gd")
const Efectos = preload("res://scripts/efectos.gd")
const Draggable = preload("res://scripts/draggable_2d.gd")

# Id en el catalogo `tutorials` (ver sql/tutorials_minigame_reciclaje.sql).
const ID_TUTORIAL := "minigame_reciclaje"

const TUTORIAL := [
	{
		"titulo": "¡La caneca esta llena!",
		"texto": "Despues de tantos trabajos el taller junto mucha basura de carros.\n\nHay que separarla para reciclarla.",
	},
	{
		"titulo": "La cinta",
		"texto": "Los residuos pasan por la cinta de arriba.\n\nArrastra cada uno hasta su contenedor antes de que se caiga por el otro lado.",
	},
	{
		"titulo": "Los contenedores",
		"texto": "PLASTICO: botellas de aceite.\nCARTON: cajas de repuestos.\nVIDRIO: bombillos.\nLLANTAS: llantas viejas.",
	},
	{
		"titulo": "Cuidado",
		"texto": "Ponerlo en el contenedor equivocado o dejarlo escapar es un error.\n\nLa cinta va cada vez mas rapido. ¡Mientras menos errores, mejor recompensa!",
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

# --- CATALOGOS ---
const CONTENEDORES := {
	"plastico": {"nombre": "PLASTICO", "color": Color(0.95, 0.78, 0.2)},
	"carton": {"nombre": "CARTON", "color": Color(0.3, 0.55, 0.95)},
	"vidrio": {"nombre": "VIDRIO", "color": Color(0.3, 0.75, 0.4)},
	"llantas": {"nombre": "LLANTAS", "color": Color(0.38, 0.38, 0.42)},
}
# Orden de izquierda a derecha en pantalla.
const ORDEN_CONTENEDORES := ["plastico", "carton", "vidrio", "llantas"]

const RESIDUOS := [
	{"textura": preload("res://objetos/work1.png"), "contenedor": "plastico"},
	{"textura": preload("res://objetos/oil2.png"), "contenedor": "plastico"},
	{"textura": preload("res://objetos/boxFilters.png"), "contenedor": "carton"},
	{"textura": preload("res://objetos/boxKeys.png"), "contenedor": "carton"},
	{"textura": preload("res://objetos/boxLights.png"), "contenedor": "carton"},
	{"textura": preload("res://objetos/light1.png"), "contenedor": "vidrio"},
	{"textura": preload("res://objetos/light5.png"), "contenedor": "vidrio"},
	{"textura": preload("res://objetos/work3.png"), "contenedor": "vidrio"},
	{"textura": preload("res://objetos/work0.png"), "contenedor": "llantas"},
]

# --- DESAFIO ---
const RESIDUOS_POR_CONTENEDOR := 3
const TAMANO_RESIDUO := 64.0

const CINTA_Y := 255.0
const CINTA_ALTO := 80.0
const CINTA_X_SALIDA := 470.0
const VELOCIDAD_INICIAL := 55.0
const VELOCIDAD_FINAL := 115.0
const INTERVALO_INICIAL := 2.6
const INTERVALO_FINAL := 1.4

const CONTENEDOR_Y := 570.0
const CONTENEDOR_ANCHO := 88.0
const CONTENEDOR_ALTO := 130.0
const RADIO_CONTENEDOR := 65.0

const COLOR_OK := Color(0.45, 1.0, 0.55)
const COLOR_ERROR := Color(1.0, 0.4, 0.35)
const COLOR_CHISPA := Color(1.0, 0.9, 0.45)

const RACHA_MINIMA := 3

# Recompensa por vaciar la caneca, mas un bono segun los errores.
const PAGO_BASE := 15
const PUNTOS_BASE := 2
const TRAMOS_PRECISION := [
	{"max_errores": 0, "pago": 1.0, "puntos": 3, "titulo": "¡Taller impecable!", "detalle": "Todo en su lugar."},
	{"max_errores": 2, "pago": 0.5, "puntos": 2, "titulo": "Muy bien", "detalle": "Casi todo bien separado."},
	{"max_errores": 5, "pago": 0.2, "puntos": 1, "titulo": "Aceptable", "detalle": "Algo se mezclo."},
	{"max_errores": 999999, "pago": 0.0, "puntos": 0, "titulo": "Hay que repasar", "detalle": "Quedo bastante mezclado."},
]

# id del contenedor -> {"cuerpo": Node2D, "destino": Node2D}
var contenedores: Dictionary = {}
# Residuos que faltan salir a la cinta (indices de RESIDUOS).
var cola: Array = []
var total_residuos: int = 0
# Residuos en la cinta ahora mismo (nodos con draggable_2d.gd).
var en_cinta: Array = []
var procesados: int = 0
var errores: int = 0
var racha: int = 0

var tiempo_proximo: float = 0.0
var franjas: Array = []
var juego_activo: bool = false
var juego_terminado: bool = false

func _ready() -> void:
	escala_original = engine_sprite.scale

	contenedor_juego.visible = false
	contenedor_juego.modulate.a = 0.0

	filtro_oscuro.modulate.a = 1.0
	filtro_oscuro.visible = true
	filtro_oscuro.z_index = 100

	engine_sprite.texture = engine_textures.pick_random()

	_armar_cola()
	_crear_cinta()
	_crear_contenedores()
	_actualizar_ui()

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
	tween_filtro.tween_callback(iniciar_juego)

func iniciar_juego() -> void:
	engine_sprite.visible = false

	contenedor_juego.visible = true
	contenedor_juego.modulate.a = 0.0

	var tween_revelar := create_tween()
	tween_revelar.set_trans(Tween.TRANS_SINE)
	tween_revelar.set_ease(Tween.EASE_OUT)
	tween_revelar.tween_property(filtro_oscuro, "modulate:a", 0.0, CINE_REVELAR)
	tween_revelar.parallel().tween_property(contenedor_juego, "modulate:a", 1.0, CINE_REVELAR * 0.8)
	tween_revelar.tween_callback(mostrar_tutorial)

func mostrar_tutorial() -> void:
	if not await Supabase.tutorial_fue_visto(ID_TUTORIAL):
		Supabase.marcar_tutorial_visto(ID_TUTORIAL)
		var modal = TutorialModal.crear(self, TUTORIAL)
		await modal.terminado

	juego_activo = true
	tiempo_proximo = 0.5

# --- Armado -----------------------------------------------------------------

# Igual cantidad de residuos por contenedor, en orden aleatorio.
func _armar_cola() -> void:
	for id in ORDEN_CONTENEDORES:
		var del_tipo: Array = []
		for i in RESIDUOS.size():
			if RESIDUOS[i]["contenedor"] == id:
				del_tipo.append(i)
		for n in RESIDUOS_POR_CONTENEDOR:
			cola.append(del_tipo.pick_random())
	cola.shuffle()
	total_residuos = cola.size()

func _crear_cinta() -> void:
	var cinta := ColorRect.new()
	cinta.color = Color(0.14, 0.14, 0.16)
	cinta.position = Vector2(0, CINTA_Y - CINTA_ALTO / 2.0)
	cinta.size = Vector2(420, CINTA_ALTO)
	cinta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenedor_juego.add_child(cinta)

	# Franjas que avanzan con la cinta para que se note que se mueve.
	for i in 12:
		var franja := ColorRect.new()
		franja.color = Color(0.2, 0.2, 0.23)
		franja.position = Vector2(i * 40.0, CINTA_Y - CINTA_ALTO / 2.0)
		franja.size = Vector2(8, CINTA_ALTO)
		franja.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contenedor_juego.add_child(franja)
		franjas.append(franja)

	for borde_y in [CINTA_Y - CINTA_ALTO / 2.0 - 6.0, CINTA_Y + CINTA_ALTO / 2.0]:
		var riel := ColorRect.new()
		riel.color = Color(0.55, 0.56, 0.6)
		riel.position = Vector2(0, borde_y)
		riel.size = Vector2(420, 6)
		riel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contenedor_juego.add_child(riel)

func _crear_contenedores() -> void:
	var paso := 420.0 / ORDEN_CONTENEDORES.size()
	for i in ORDEN_CONTENEDORES.size():
		var id: String = ORDEN_CONTENEDORES[i]
		var datos: Dictionary = CONTENEDORES[id]
		var color: Color = datos["color"]

		var cuerpo := Node2D.new()
		cuerpo.position = Vector2(paso * (i + 0.5), CONTENEDOR_Y)
		contenedor_juego.add_child(cuerpo)

		var medio := CONTENEDOR_ANCHO / 2.0
		var balde := Polygon2D.new()
		balde.polygon = PackedVector2Array([
			Vector2(-medio, 0), Vector2(medio, 0),
			Vector2(medio - 8, CONTENEDOR_ALTO), Vector2(-medio + 8, CONTENEDOR_ALTO),
		])
		balde.color = color
		cuerpo.add_child(balde)

		var tapa := Polygon2D.new()
		tapa.polygon = PackedVector2Array([
			Vector2(-medio - 5, -12), Vector2(medio + 5, -12), Vector2(medio + 5, 2), Vector2(-medio - 5, 2),
		])
		tapa.color = color.darkened(0.35)
		cuerpo.add_child(tapa)

		var nombre := Label.new()
		nombre.text = datos["nombre"]
		nombre.add_theme_font_size_override("font_size", 12)
		nombre.add_theme_color_override("font_outline_color", Color.BLACK)
		nombre.add_theme_constant_override("outline_size", 4)
		nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nombre.position = Vector2(-medio, 10)
		nombre.size = Vector2(CONTENEDOR_ANCHO, 18)
		cuerpo.add_child(nombre)

		# Muestra de lo que va adentro, para que los chicos no tengan que leer.
		var muestra := Sprite2D.new()
		muestra.texture = _ejemplo_de(id)
		muestra.scale = Vector2.ONE * (44.0 / maxf(muestra.texture.get_width(), muestra.texture.get_height()))
		muestra.position = Vector2(0, 70)
		muestra.modulate.a = 0.9
		cuerpo.add_child(muestra)

		var destino := Node2D.new()
		destino.position = cuerpo.position + Vector2(0, CONTENEDOR_ALTO * 0.4)
		contenedor_juego.add_child(destino)

		contenedores[id] = {"cuerpo": cuerpo, "destino": destino}

func _ejemplo_de(id: String) -> Texture2D:
	for residuo in RESIDUOS:
		if residuo["contenedor"] == id:
			return residuo["textura"]
	return null

# --- Juego -------------------------------------------------------------------

func _process(delta: float) -> void:
	if not juego_activo or juego_terminado:
		return

	var avance := float(total_residuos - cola.size()) / maxf(total_residuos, 1)
	var velocidad := lerpf(VELOCIDAD_INICIAL, VELOCIDAD_FINAL, avance)

	for franja in franjas:
		franja.position.x = fposmod(franja.position.x + velocidad * delta, 480.0) - 40.0

	tiempo_proximo -= delta
	if tiempo_proximo <= 0.0 and not cola.is_empty():
		_soltar_residuo(cola.pop_back())
		tiempo_proximo = lerpf(INTERVALO_INICIAL, INTERVALO_FINAL, avance)

	for i in range(en_cinta.size() - 1, -1, -1):
		var residuo: Draggable = en_cinta[i]
		if not residuo.libre():
			continue
		residuo.position.x += velocidad * delta
		residuo.fijar_base(residuo.global_position)
		if residuo.position.x >= CINTA_X_SALIDA:
			en_cinta.remove_at(i)
			_escapo(residuo)

func _soltar_residuo(indice: int) -> void:
	var datos: Dictionary = RESIDUOS[indice]
	var id: String = datos["contenedor"]

	var residuo: Draggable = Draggable.new()
	residuo.position = Vector2(-40, CINTA_Y)
	residuo.destino = contenedores[id]["destino"]
	residuo.radio_destino = RADIO_CONTENEDOR
	residuo.radio_agarre = 45.0
	residuo.set_meta("contenedor", id)

	var sprite := Sprite2D.new()
	sprite.texture = datos["textura"]
	sprite.scale = Vector2.ONE * (TAMANO_RESIDUO / maxf(sprite.texture.get_width(), sprite.texture.get_height()))
	residuo.add_child(sprite)

	contenedor_juego.add_child(residuo)
	en_cinta.append(residuo)

	residuo.soltado_en_destino.connect(_on_residuo_ok.bind(residuo))
	residuo.soltado_fuera.connect(_on_residuo_fuera.bind(residuo))

func _on_residuo_ok(residuo: Draggable) -> void:
	en_cinta.erase(residuo)
	residuo.habilitado = false
	var id: String = residuo.get_meta("contenedor")
	var cuerpo: Node2D = contenedores[id]["cuerpo"]

	# Cae adentro del contenedor achicandose.
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(residuo, "global_position", cuerpo.global_position + Vector2(0, 10), 0.2)
	tween.parallel().tween_property(residuo, "scale", Vector2(0.2, 0.2), 0.2)
	tween.tween_callback(residuo.queue_free)

	Efectos.rebote(cuerpo, Vector2.ONE, Vector2(1.15, 0.85))
	Efectos.nube(contenedor_juego, cuerpo.global_position, CONTENEDORES[id]["color"].lightened(0.3), 10, 50.0, 0.5)

	racha += 1
	Efectos.texto_flotante(contenedor_juego, "¡Bien!", cuerpo.global_position + Vector2(0, -50), COLOR_OK)
	if racha >= RACHA_MINIMA:
		Efectos.texto_flotante(contenedor_juego, "¡Racha x%d!" % racha, cuerpo.global_position + Vector2(0, -80), COLOR_CHISPA, 18)

	_residuo_procesado()

# Soltado fuera de su contenedor: si cayo sobre OTRO contenedor es un error;
# si se solto en cualquier otro lado vuelve a la cinta sin castigo.
func _on_residuo_fuera(residuo: Node2D) -> void:
	var punto := get_viewport().get_mouse_position()
	for id in contenedores:
		if id == residuo.get_meta("contenedor"):
			continue
		var destino: Node2D = contenedores[id]["destino"]
		if destino.global_position.distance_to(punto) <= RADIO_CONTENEDOR:
			var cuerpo: Node2D = contenedores[id]["cuerpo"]
			Efectos.sacudir(cuerpo, 5.0, 0.2)
			_error("¡Ese no es!", cuerpo.global_position + Vector2(0, -50))
			return

func _escapo(residuo: Node2D) -> void:
	_error("¡Se escapo!", Vector2(360, CINTA_Y - 70))
	var tween := create_tween()
	tween.tween_property(residuo, "position", residuo.position + Vector2(40, 120), 0.4)
	tween.parallel().tween_property(residuo, "modulate:a", 0.0, 0.4)
	tween.tween_callback(residuo.queue_free)
	_residuo_procesado()

func _error(texto: String, pos: Vector2) -> void:
	errores += 1
	racha = 0
	Efectos.texto_flotante(contenedor_juego, texto, pos, COLOR_ERROR, 24)
	Efectos.sacudir(contenedor_juego, 4.0, 0.2)
	label_errores.modulate = COLOR_ERROR
	create_tween().tween_property(label_errores, "modulate", Color.WHITE, 0.3)
	_actualizar_ui()

func _residuo_procesado() -> void:
	procesados += 1
	_actualizar_ui()
	if procesados >= total_residuos:
		_terminar_juego()

func _actualizar_ui() -> void:
	label_progreso.text = "Residuos: %d/%d" % [procesados, total_residuos]
	label_errores.text = "Errores: %d" % errores

# --- Final -------------------------------------------------------------------

func _terminar_juego() -> void:
	juego_terminado = true
	label_instruccion.text = "¡Taller limpio!"

	Efectos.confeti(contenedor_juego, Vector2(210, 400), 40)
	Efectos.texto_flotante(contenedor_juego, "¡Todo reciclado!", Vector2(210, 420), COLOR_CHISPA, 30)
	await get_tree().create_timer(1.2).timeout

	var resultado := _evaluar_precision(errores)
	label_instruccion.text = "Guardando..."
	var ok: bool = await Supabase.completar_reciclaje(resultado["pago"], resultado["puntos"])
	label_instruccion.text = ""

	var modal = TutorialModal.crear(self, [_pagina_resultado(ok, resultado)])
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
				"pago": PAGO_BASE + int(ceil(PAGO_BASE * tramo["pago"])),
				"puntos": PUNTOS_BASE + int(tramo["puntos"]),
			}
	return {"titulo": "Terminado", "detalle": "", "pago": PAGO_BASE, "puntos": PUNTOS_BASE}

func _pagina_resultado(ok: bool, resultado: Dictionary) -> Dictionary:
	if not ok:
		return {
			"titulo": "Caneca vaciada",
			"texto": "Separaste todo, pero no se pudo guardar.\n\nRevisa tu conexion e intentalo de nuevo.",
			"boton": "Continuar",
		}

	return {
		"titulo": resultado["titulo"],
		"texto": "%s\nErrores: %d\n\n+ $%d\n+ %d puntos" % [
			resultado["detalle"], errores, resultado["pago"], resultado["puntos"]
		],
		"boton": "Continuar",
	}
