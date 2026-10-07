extends "res://scripts/minijuego_base.gd"

# Minijuego de reparacion electrica (estante de corriente), estilo hackeo de
# GTA V: la corriente avanza sola como un laser por el circuito del carro,
# desde la bateria (A) hasta el faro (B). El jugador no la frena: solo elige
# hacia donde dobla (flechas, botones o deslizando el dedo); nunca dobla
# sola. Donde no puede seguir derecho se frena y espera; si se mete en un
# callejon sin salida hace corto, cuenta como error y vuelve a A.
#
# Son NIVELES circuitos, cada uno mas grande y rapido. Los laberintos se
# generan al azar (siempre tienen camino de A a B).

const NIVELES := [
	{"columnas": 5, "filas": 6, "velocidad": 1.3},
	{"columnas": 6, "filas": 8, "velocidad": 1.7},
]

const AREA := Rect2(30, 150, 360, 470)
const COLOR_PARED := Color(0.25, 0.85, 1.0)
const COLOR_LASER := Color(1.0, 0.25, 0.3)
const COLOR_A := Color(0.4, 1.0, 0.5)
const COLOR_B := Color(1.0, 0.85, 0.3)

const N := Vector2i(0, -1)
const S := Vector2i(0, 1)
const E := Vector2i(1, 0)
const O := Vector2i(-1, 0)
const DIRECCIONES := [N, E, S, O]

# Si se pide doblar un poquito tarde (el laser ya salio del cruce pero no
# paso de esta fraccion del tramo), igual dobla en ese cruce.
const MARGEN_TARDE := 0.45

# Distancia minima del deslizamiento del dedo para contar como direccion.
const SWIPE_MINIMO := 30.0

var nivel: int = 0
var columnas: int = 0
var filas: int = 0
var celda: float = 0.0
var origen: Vector2 = Vector2.ZERO
var velocidad: float = 0.0

# abiertos[Vector2i] = Array de direcciones sin pared desde esa celda.
var abiertos: Dictionary = {}
var inicio: Vector2i
var meta: Vector2i

var celda_actual: Vector2i
var direccion: Vector2i = Vector2i.ZERO
var direccion_pedida: Vector2i = Vector2i.ZERO
# Direccion con la que se entro a celda_actual (no se puede volver por ahi).
var direccion_entrada: Vector2i = Vector2i.ZERO
# Frenado en un cruce sin salida al frente, esperando que el jugador elija.
var esperando: bool = false
var avance: float = 0.0
# Centros de las celdas ya recorridas; el rastro es esto + la cabeza.
var recorrido: PackedVector2Array = PackedVector2Array()
var corriendo: bool = false

var tablero: Node2D
var rastro: Line2D
var rastro_brillo: Line2D
var cabeza: Polygon2D
var _swipe_desde: Vector2
var _swipe_activo: bool = false

func _init() -> void:
	id_tutorial = "minigame_cables"
	instruccion = "Guia la corriente desde la bateria (A) hasta el faro (B)"
	texto_final = "¡Luces encendidas!"
	tutorial = [
		{
			"titulo": "Reparacion electrica",
			"texto": "Las luces del carro no prenden: hay que llevar la corriente desde la bateria (A) hasta el faro (B).",
		},
		{
			"titulo": "La corriente no para",
			"texto": "El laser avanza solo por el circuito. Tu eliges hacia donde dobla con las flechas o deslizando el dedo.\n\nPuedes elegir ANTES de llegar al cruce.",
		},
		{
			"titulo": "Cuidado con los cortos",
			"texto": "Nunca dobla sola: donde no puede seguir derecho, se frena y espera que elijas. Pero si se mete en un callejon sin salida, hace corto: cuenta como error y vuelve a la bateria.\n\nSon %d circuitos, cada uno mas rapido." % NIVELES.size(),
		},
	]

func _construir() -> void:
	tablero = Node2D.new()
	contenedor_juego.add_child(tablero)

	# Flechas en pantalla para tocar (ademas de las del teclado y el swipe).
	var centro := Vector2(210, 700)
	var flechas := {"▲": N, "▼": S, "◀": O, "▶": E}
	var posiciones := {"▲": Vector2(0, -38), "▼": Vector2(0, 38), "◀": Vector2(-80, 0), "▶": Vector2(80, 0)}
	for simbolo in flechas:
		var boton := boton_grande(simbolo, centro + posiciones[simbolo], Vector2(70, 60))
		boton.button_down.connect(_pedir.bind(flechas[simbolo]))

	_armar_nivel()

func _empezar() -> void:
	_arrancar()

# --- Laberinto ---------------------------------------------------------------

func _armar_nivel() -> void:
	for hijo in tablero.get_children():
		hijo.queue_free()

	var datos: Dictionary = NIVELES[nivel]
	columnas = datos["columnas"]
	filas = datos["filas"]
	velocidad = datos["velocidad"]
	celda = minf(AREA.size.x / columnas, AREA.size.y / filas)
	origen = AREA.position + (AREA.size - Vector2(columnas, filas) * celda) / 2.0

	_generar_laberinto()
	inicio = Vector2i(0, filas - 1)
	meta = Vector2i(columnas - 1, 0)

	tablero.add_child(rectangulo(Rect2(origen, Vector2(columnas, filas) * celda), Color(0.05, 0.08, 0.12)))
	_dibujar_paredes()
	_dibujar_punto(inicio, "A", COLOR_A)
	_dibujar_punto(meta, "B", COLOR_B)

	rastro_brillo = Line2D.new()
	rastro_brillo.width = 16.0
	rastro_brillo.default_color = Color(COLOR_LASER, 0.3)
	rastro_brillo.joint_mode = Line2D.LINE_JOINT_ROUND
	rastro_brillo.begin_cap_mode = Line2D.LINE_CAP_ROUND
	tablero.add_child(rastro_brillo)

	rastro = Line2D.new()
	rastro.width = 6.0
	rastro.default_color = COLOR_LASER
	rastro.joint_mode = Line2D.LINE_JOINT_ROUND
	rastro.begin_cap_mode = Line2D.LINE_CAP_ROUND
	tablero.add_child(rastro)

	cabeza = circulo(9, Color.WHITE)
	tablero.add_child(cabeza)
	var pulso := cabeza.create_tween().set_loops()
	pulso.tween_property(cabeza, "scale", Vector2(1.4, 1.4), 0.25)
	pulso.tween_property(cabeza, "scale", Vector2.ONE, 0.25)

	_reiniciar_laser()

# Laberinto perfecto (un solo camino entre dos celdas) con DFS iterativo.
func _generar_laberinto() -> void:
	abiertos.clear()
	for x in columnas:
		for y in filas:
			abiertos[Vector2i(x, y)] = []

	var visitadas := {Vector2i(0, 0): true}
	var pila: Array = [Vector2i(0, 0)]
	while not pila.is_empty():
		var actual: Vector2i = pila.back()
		var vecinos: Array = []
		for d in DIRECCIONES:
			var otra: Vector2i = actual + d
			if abiertos.has(otra) and not visitadas.has(otra):
				vecinos.append(d)
		if vecinos.is_empty():
			pila.pop_back()
			continue
		var elegida: Vector2i = vecinos.pick_random()
		abiertos[actual].append(elegida)
		abiertos[actual + elegida].append(-elegida)
		visitadas[actual + elegida] = true
		pila.append(actual + elegida)

func _dibujar_paredes() -> void:
	for x in columnas:
		for y in filas:
			var c := Vector2i(x, y)
			var esquina := origen + Vector2(x, y) * celda
			# Cada celda dibuja su pared norte y oeste; el borde sur/este del
			# tablero lo dibujan las ultimas filas/columnas.
			if not abiertos[c].has(N):
				_pared(esquina, esquina + Vector2(celda, 0))
			if not abiertos[c].has(O):
				_pared(esquina, esquina + Vector2(0, celda))
			if y == filas - 1:
				_pared(esquina + Vector2(0, celda), esquina + Vector2(celda, celda))
			if x == columnas - 1:
				_pared(esquina + Vector2(celda, 0), esquina + Vector2(celda, celda))

# Pared de neon: un trazo ancho y transparente (brillo) + uno fino.
func _pared(desde: Vector2, hasta: Vector2) -> void:
	for capa in [[10.0, Color(COLOR_PARED, 0.18)], [3.0, COLOR_PARED]]:
		var linea := Line2D.new()
		linea.width = capa[0]
		linea.default_color = capa[1]
		linea.begin_cap_mode = Line2D.LINE_CAP_ROUND
		linea.end_cap_mode = Line2D.LINE_CAP_ROUND
		linea.points = PackedVector2Array([desde, hasta])
		tablero.add_child(linea)

func _dibujar_punto(c: Vector2i, texto: String, color: Color) -> void:
	var punto := circulo(celda * 0.3, Color(color, 0.85))
	punto.position = _centro(c)
	tablero.add_child(punto)
	var pulso := punto.create_tween().set_loops()
	pulso.tween_property(punto, "scale", Vector2(1.15, 1.15), 0.5)
	pulso.tween_property(punto, "scale", Vector2.ONE, 0.5)

	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color.BLACK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(40, 30)
	label.position = _centro(c) - label.size / 2.0
	tablero.add_child(label)

func _centro(c: Vector2i) -> Vector2:
	return origen + (Vector2(c) + Vector2(0.5, 0.5)) * celda

# --- Laser -------------------------------------------------------------------

# Vuelve a A y espera a que el jugador elija por donde salir (ver _process).
func _reiniciar_laser() -> void:
	celda_actual = inicio
	# Arranca quieto en A: la primera direccion siempre la elige el jugador.
	direccion = Vector2i.ZERO
	esperando = true
	direccion_entrada = Vector2i.ZERO
	direccion_pedida = Vector2i.ZERO
	avance = 0.0
	recorrido = PackedVector2Array([_centro(inicio)])
	cabeza.position = _centro(inicio)
	_actualizar_rastro()

func _arrancar() -> void:
	corriendo = true

func _pedir(d: Vector2i) -> void:
	direccion_pedida = d

func _process(delta: float) -> void:
	if not juego_activo or not corriendo:
		return

	if Input.is_action_just_pressed("up"):
		_pedir(N)
	elif Input.is_action_just_pressed("down"):
		_pedir(S)
	elif Input.is_action_just_pressed("left"):
		_pedir(O)
	elif Input.is_action_just_pressed("right"):
		_pedir(E)

	if esperando:
		if _salidas().has(direccion_pedida):
			direccion = direccion_pedida
			direccion_pedida = Vector2i.ZERO
			esperando = false
			label_instruccion.text = instruccion
		return

	# Pedido un poquito tarde: todavia cerca del cruce, dobla igual ahi.
	if direccion_pedida != Vector2i.ZERO and direccion_pedida != direccion \
			and avance < MARGEN_TARDE and _salidas().has(direccion_pedida):
		direccion = direccion_pedida
		direccion_pedida = Vector2i.ZERO
		avance = 0.0

	avance += velocidad * delta
	var desde := _centro(celda_actual)
	var hasta := _centro(celda_actual + direccion)
	cabeza.position = desde.lerp(hasta, minf(avance, 1.0))
	_actualizar_rastro()

	if avance >= 1.0:
		avance = 0.0
		celda_actual += direccion
		direccion_entrada = direccion
		recorrido.append(_centro(celda_actual))
		if celda_actual == meta:
			_nivel_completo()
			return
		_elegir_direccion()

# El rastro es el camino ya recorrido mas la posicion actual de la cabeza.
func _actualizar_rastro() -> void:
	var puntos := recorrido.duplicate()
	puntos.append(cabeza.position)
	rastro.points = puntos
	rastro_brillo.points = puntos

# Caminos posibles desde la celda actual, sin volver por donde se vino.
func _salidas() -> Array:
	var salidas: Array = abiertos[celda_actual].duplicate()
	salidas.erase(-direccion_entrada)
	return salidas

func _elegir_direccion() -> void:
	var salidas := _salidas()

	if direccion_pedida != Vector2i.ZERO and salidas.has(direccion_pedida):
		direccion = direccion_pedida
		direccion_pedida = Vector2i.ZERO
	elif salidas.has(direccion):
		pass
	elif salidas.is_empty():
		# Callejon sin salida: corto.
		_corto()
	else:
		# No puede seguir derecho (curva o cruce): se frena y espera que el
		# jugador elija. Nunca dobla solo.
		esperando = true
		label_instruccion.text = "¡Elige por donde sigue!"

func _corto() -> void:
	corriendo = false
	Efectos.nube(contenedor_juego, cabeza.position, COLOR_CHISPA, 16, 60.0, 0.5)
	error("¡Corto!", cabeza.position + Vector2(0, -40))
	await get_tree().create_timer(0.6).timeout
	_reiniciar_laser()
	corriendo = true

func _nivel_completo() -> void:
	corriendo = false
	Efectos.nube(contenedor_juego, _centro(meta), COLOR_B, 24, 90.0, 0.7)
	acierto("¡Circuito listo!", _centro(meta) + Vector2(-60, 40))
	await get_tree().create_timer(1.0).timeout

	nivel += 1
	if nivel >= NIVELES.size():
		terminar()
		return
	_armar_nivel()
	label_instruccion.text = "Circuito %d de %d" % [nivel + 1, NIVELES.size()]
	await get_tree().create_timer(0.6).timeout
	corriendo = true

# --- Swipe -------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not juego_activo:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and AREA.has_point(event.position):
			_swipe_desde = event.position
			_swipe_activo = true
		else:
			_swipe_activo = false
	elif event is InputEventMouseMotion and _swipe_activo:
		var delta: Vector2 = event.position - _swipe_desde
		if delta.length() >= SWIPE_MINIMO:
			if absf(delta.x) > absf(delta.y):
				_pedir(E if delta.x > 0 else O)
			else:
				_pedir(S if delta.y > 0 else N)
			_swipe_desde = event.position
