extends "res://scripts/minijuego_base.gd"

# Minijuego del estante de pinturas: retocar la puerta rayada de un carro.
#   1) Elegir, entre 3 latas, la del MISMO color que el carro (equivocarse
#      es error).
#   2) Pintar con el dedo encima de cada rayon hasta taparlo. Pintar sobre
#      el vidrio de la ventana es error (uno por trazo).
# Al tapar todos, la puerta brilla como nueva.

enum Fase { ELEGIR, PINTAR, FIN }

const COLORES_CARRO := [
	Color(0.85, 0.2, 0.2),
	Color(0.2, 0.45, 0.9),
	Color(0.2, 0.7, 0.35),
	Color(0.95, 0.75, 0.15),
	Color(0.6, 0.3, 0.8),
]
const RAYONES := 6
const RADIO_BROCHA := 18.0
# Distancia minima entre manchas de pintura de un mismo trazo.
const PASO_BROCHA := 7.0

const PUERTA := Rect2(45, 160, 330, 380)
const VIDRIO := Rect2(75, 180, 270, 120)
const ZONA_RAYONES := Rect2(85, 335, 250, 175)
const Y_LATAS := 655.0

var fase: Fase = Fase.ELEGIR
var color_carro: Color
var latas: Array = []

# Cada rayon: {"linea": Line2D, "puntos": PackedVector2Array, "tapados": Array[bool], "listo": bool}
var rayones: Array = []
var pintura: Node2D
var label_rayones: Label

var pintando: bool = false
var error_en_trazo: bool = false
var ultima_mancha: Vector2 = Vector2.INF

func _init() -> void:
	id_tutorial = "minigame_pintura"
	instruccion = "Elige la pintura del mismo color que el carro"
	texto_final = "¡Como nueva!"
	tutorial = [
		{
			"titulo": "Retocar la pintura",
			"texto": "Este carro tiene la puerta llena de rayones. ¡Hay que dejarla como nueva!",
		},
		{
			"titulo": "El color",
			"texto": "Primero toca la lata de pintura del MISMO color que el carro.",
		},
		{
			"titulo": "Pintar",
			"texto": "Despues pasa el dedo por encima de cada rayon hasta taparlo.\n\nCuidado: ¡pintar el vidrio de la ventana cuenta como error!",
		},
	]

func _construir() -> void:
	color_carro = COLORES_CARRO.pick_random()
	_dibujar_puerta()

	pintura = Node2D.new()
	contenedor_juego.add_child(pintura)
	_crear_rayones()

	label_rayones = _label(Vector2(20, 118), Vector2(380, 24), 15, HORIZONTAL_ALIGNMENT_CENTER)
	_crear_latas()
	_actualizar_rayones()

func _dibujar_puerta() -> void:
	contenedor_juego.add_child(rectangulo(PUERTA.grow(4), color_carro.darkened(0.45)))
	contenedor_juego.add_child(rectangulo(PUERTA, color_carro))
	contenedor_juego.add_child(rectangulo(VIDRIO.grow(5), Color(0.15, 0.15, 0.18)))
	contenedor_juego.add_child(rectangulo(VIDRIO, Color(0.6, 0.8, 0.95)))
	# Reflejo del vidrio.
	var reflejo := Polygon2D.new()
	reflejo.polygon = PackedVector2Array([
		VIDRIO.position + Vector2(30, 0), VIDRIO.position + Vector2(70, 0),
		VIDRIO.position + Vector2(20, VIDRIO.size.y), VIDRIO.position + Vector2(-0, VIDRIO.size.y),
	])
	reflejo.color = Color(1, 1, 1, 0.35)
	contenedor_juego.add_child(reflejo)
	# Manija.
	contenedor_juego.add_child(rectangulo(Rect2(270, 318, 70, 14), Color(0.8, 0.82, 0.86)))

func _crear_rayones() -> void:
	for i in RAYONES:
		var inicio := Vector2(
			randf_range(ZONA_RAYONES.position.x, ZONA_RAYONES.end.x - 70),
			ZONA_RAYONES.position.y + (i + 0.5) * ZONA_RAYONES.size.y / RAYONES
		)
		var largo := randf_range(55, 95)
		var angulo := randf_range(-0.35, 0.35)
		var puntos := PackedVector2Array()
		for t in 7:
			var base := inicio + Vector2.from_angle(angulo) * largo * t / 6.0
			puntos.append(base + Vector2(0, randf_range(-4, 4)))

		var linea := Line2D.new()
		linea.points = puntos
		linea.width = 4.0
		linea.default_color = Color(0.85, 0.85, 0.88)
		contenedor_juego.add_child(linea)

		var tapados: Array = []
		tapados.resize(puntos.size())
		tapados.fill(false)
		rayones.append({"linea": linea, "puntos": puntos, "tapados": tapados, "listo": false})

func _crear_latas() -> void:
	# Una lata del color correcto y dos parecidas pero distintas.
	var colores: Array = [color_carro]
	var otros: Array = COLORES_CARRO.duplicate()
	otros.erase(color_carro)
	otros.shuffle()
	colores.append(otros[0])
	colores.append(otros[1])
	colores.shuffle()

	for i in colores.size():
		var lata := Node2D.new()
		lata.position = Vector2(105 + i * 105, Y_LATAS)
		lata.add_child(rectangulo(Rect2(-30, -40, 60, 75), Color(0.75, 0.77, 0.8)))
		lata.add_child(rectangulo(Rect2(-30, -18, 60, 34), colores[i]))
		var tapa := circulo(30, colores[i].lightened(0.15))
		tapa.scale = Vector2(1, 0.3)
		tapa.position = Vector2(0, -40)
		lata.add_child(tapa)
		contenedor_juego.add_child(lata)
		latas.append({"nodo": lata, "color": colores[i]})

func _actualizar_rayones() -> void:
	var listos := 0
	for rayon in rayones:
		if rayon["listo"]:
			listos += 1
	label_rayones.text = "Rayones tapados: %d/%d" % [listos, RAYONES]

# --- Entrada -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not juego_activo:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			pintando = false
			return
		if fase == Fase.ELEGIR:
			_tocar_lata(event.position)
		elif fase == Fase.PINTAR:
			pintando = true
			error_en_trazo = false
			ultima_mancha = Vector2.INF
			_rociar(event.position)
	elif event is InputEventMouseMotion and pintando:
		_rociar(event.position)

func _tocar_lata(punto: Vector2) -> void:
	for lata in latas:
		var nodo: Node2D = lata["nodo"]
		if nodo.position.distance_to(punto) > 45.0:
			continue
		if lata["color"] == color_carro:
			Efectos.rebote(nodo, Vector2.ONE)
			acierto("¡Ese es!", nodo.position + Vector2(0, -70))
			_empezar_a_pintar(nodo)
		else:
			Efectos.sacudir(nodo, 5.0, 0.2)
			error("¡Ese color no es!", nodo.position + Vector2(0, -70))
		return

func _empezar_a_pintar(lata_elegida: Node2D) -> void:
	fase = Fase.PINTAR
	label_instruccion.text = "¡Pasa el dedo por los rayones!"
	for lata in latas:
		var nodo: Node2D = lata["nodo"]
		if nodo != lata_elegida:
			create_tween().tween_property(nodo, "modulate:a", 0.25, 0.3)

# --- Pintar ------------------------------------------------------------------

func _rociar(punto: Vector2) -> void:
	if not PUERTA.has_point(punto):
		return
	if ultima_mancha != Vector2.INF and ultima_mancha.distance_to(punto) < PASO_BROCHA:
		return
	ultima_mancha = punto

	var mancha := circulo(RADIO_BROCHA * randf_range(0.8, 1.0), color_carro, 12)
	mancha.position = punto
	pintura.add_child(mancha)
	# Nube de spray alrededor.
	if randf() < 0.4:
		Efectos.nube(contenedor_juego, punto, Color(color_carro.lightened(0.3), 0.6), 2, 22.0, 0.3)

	if VIDRIO.has_point(punto):
		if not error_en_trazo:
			error_en_trazo = true
			error("¡En el vidrio no!", punto + Vector2(0, -40))
		return

	_tapar_rayones(punto)

func _tapar_rayones(punto: Vector2) -> void:
	for rayon in rayones:
		if rayon["listo"]:
			continue
		var puntos: PackedVector2Array = rayon["puntos"]
		var tapados: Array = rayon["tapados"]
		var cambio := false
		for i in puntos.size():
			if not tapados[i] and puntos[i].distance_to(punto) <= RADIO_BROCHA:
				tapados[i] = true
				cambio = true
		if not cambio:
			continue

		var cuantos := tapados.count(true)
		var linea: Line2D = rayon["linea"]
		linea.modulate.a = 1.0 - float(cuantos) / puntos.size()
		if cuantos == puntos.size():
			rayon["listo"] = true
			linea.visible = false
			var centro := (puntos[0] + puntos[puntos.size() - 1]) / 2.0
			Efectos.nube(contenedor_juego, centro, COLOR_CHISPA, 10, 50.0, 0.4)
			acierto(["¡Tapado!", "¡Brilla!", "¡Bien!"].pick_random(), centro + Vector2(0, -35))
			_actualizar_rayones()
			_revisar_fin()

func _revisar_fin() -> void:
	for rayon in rayones:
		if not rayon["listo"]:
			return
	fase = Fase.FIN
	pintando = false

	# Destello que cruza la puerta de punta a punta.
	var destello := Polygon2D.new()
	destello.polygon = PackedVector2Array([Vector2(0, 0), Vector2(30, 0), Vector2(-10, PUERTA.size.y), Vector2(-40, PUERTA.size.y)])
	destello.color = Color(1, 1, 1, 0.55)
	destello.position = Vector2(PUERTA.position.x - 40, PUERTA.position.y)
	contenedor_juego.add_child(destello)
	var tween := create_tween()
	tween.tween_property(destello, "position:x", PUERTA.end.x + 40, 0.6)
	tween.tween_callback(destello.queue_free)
	await tween.finished
	terminar()
