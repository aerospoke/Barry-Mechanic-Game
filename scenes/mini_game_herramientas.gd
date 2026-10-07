extends "res://scripts/minijuego_base.gd"

# Minijuego del banco de herramientas: el tablero de la pared tiene dibujada
# la silueta de cada herramienta y las herramientas quedaron tiradas en la
# mesa. Hay que arrastrar cada una a su silueta, como un rompecabezas. Cada
# partida usa HERRAMIENTAS_POR_PARTIDA herramientas al azar de la lista, asi
# que nunca es igual. Soltarla sobre la silueta de OTRA herramienta es error.

const Draggable = preload("res://scripts/draggable_2d.gd")

# Para sumar una herramienta nueva alcanza con agregar su imagen aca.
const HERRAMIENTAS := [
	preload("res://objetos/herramientas/alemana.png"),
	preload("res://objetos/herramientas/bisturi.png"),
	preload("res://objetos/herramientas/cerrucho.png"),
	preload("res://objetos/herramientas/cizalla.png"),
	preload("res://objetos/herramientas/destornillador.png"),
	preload("res://objetos/herramientas/lima.png"),
	preload("res://objetos/herramientas/martillo.png"),
	preload("res://objetos/herramientas/maseta.png"),
	preload("res://objetos/herramientas/metro.png"),
	preload("res://objetos/herramientas/multimetro.png"),
	preload("res://objetos/herramientas/nivel.png"),
	preload("res://objetos/herramientas/palanca.png"),
	preload("res://objetos/herramientas/piederey.png"),
	preload("res://objetos/herramientas/pinzas.png"),
	preload("res://objetos/herramientas/pinzas2.png"),
	preload("res://objetos/herramientas/taladro.png"),
	preload("res://objetos/herramientas/aceite2.png"),
]
const HERRAMIENTAS_POR_PARTIDA := 8
const COLUMNAS := 4

# Tablero de la pared (siluetas) y mesa (herramientas sueltas).
const TABLERO := Rect2(20, 140, 380, 360)
const MESA := Rect2(20, 525, 380, 235)
const TAMANO_MAXIMO := Vector2(78, 150)
const COLOR_SILUETA := Color(0.05, 0.05, 0.08, 0.75)

# Cada pieza: {"herramienta": Draggable, "silueta": Node2D, "lista": bool}
var piezas: Array = []

func _init() -> void:
	id_tutorial = "minigame_herramientas"
	instruccion = "Cuelga cada herramienta en su silueta"
	texto_final = "¡Banco ordenado!"
	tutorial = [
		{
			"titulo": "Banco de herramientas",
			"texto": "¡Que desorden! Las herramientas quedaron tiradas en la mesa.",
		},
		{
			"titulo": "Como un rompecabezas",
			"texto": "En la pared esta dibujada la silueta de cada herramienta.\n\nArrastra cada una hasta la silueta que tiene su misma forma.",
		},
		{
			"titulo": "Mira bien",
			"texto": "Hay herramientas parecidas. Si la cuelgas en la silueta equivocada cuenta como error.",
		},
	]

func _construir() -> void:
	_dibujar_tablero()
	_dibujar_mesa()

	var elegidas: Array = HERRAMIENTAS.duplicate()
	elegidas.shuffle()
	elegidas.resize(HERRAMIENTAS_POR_PARTIDA)

	var filas := ceili(float(HERRAMIENTAS_POR_PARTIDA) / COLUMNAS)
	var celda_tablero := Vector2(TABLERO.size.x / COLUMNAS, TABLERO.size.y / filas)
	var celda_mesa := Vector2(MESA.size.x / COLUMNAS, MESA.size.y / filas)

	# La mesa usa otro orden que la pared, para que no sea copiar posiciones.
	var lugares_mesa := range(HERRAMIENTAS_POR_PARTIDA)
	lugares_mesa.shuffle()

	for i in HERRAMIENTAS_POR_PARTIDA:
		var textura: Texture2D = elegidas[i]
		var escala := _escala_para(textura)

		var silueta := Sprite2D.new()
		silueta.texture = textura
		silueta.scale = Vector2.ONE * escala
		silueta.modulate = COLOR_SILUETA
		silueta.position = TABLERO.position + celda_tablero * Vector2(i % COLUMNAS + 0.5, i / COLUMNAS + 0.5)
		contenedor_juego.add_child(silueta)

		var lugar: int = lugares_mesa[i]
		var herramienta: Draggable = Draggable.new()
		herramienta.position = MESA.position + celda_mesa * Vector2(lugar % COLUMNAS + 0.5, lugar / COLUMNAS + 0.5) \
			+ Vector2(randf_range(-8, 8), randf_range(-6, 6))
		herramienta.destino = silueta
		herramienta.radio_destino = 45.0
		herramienta.radio_agarre = 50.0
		herramienta.habilitado = false
		var sprite := Sprite2D.new()
		sprite.texture = textura
		# La herramienta en la mesa se ve un poco mas chica que su silueta.
		sprite.scale = Vector2.ONE * escala * 0.85
		herramienta.add_child(sprite)
		contenedor_juego.add_child(herramienta)

		var pieza := {"herramienta": herramienta, "silueta": silueta, "lista": false, "escala": escala}
		piezas.append(pieza)
		herramienta.soltado_en_destino.connect(_on_colgada.bind(pieza))
		herramienta.soltado_fuera.connect(_on_suelta.bind(pieza))

func _empezar() -> void:
	for pieza in piezas:
		pieza["herramienta"].habilitado = true

func _escala_para(textura: Texture2D) -> float:
	var tam := Vector2(textura.get_size())
	return minf(TAMANO_MAXIMO.x / tam.x, TAMANO_MAXIMO.y / tam.y)

# Tablero perforado de la pared.
func _dibujar_tablero() -> void:
	contenedor_juego.add_child(rectangulo(TABLERO.grow(6), Color(0.35, 0.22, 0.12)))
	contenedor_juego.add_child(rectangulo(TABLERO, Color(0.62, 0.48, 0.32)))
	var paso := 24.0
	var y := TABLERO.position.y + paso / 2.0
	while y < TABLERO.end.y:
		var x := TABLERO.position.x + paso / 2.0
		while x < TABLERO.end.x:
			var agujero := circulo(2.5, Color(0.4, 0.29, 0.18), 6)
			agujero.position = Vector2(x, y)
			contenedor_juego.add_child(agujero)
			x += paso
		y += paso

func _dibujar_mesa() -> void:
	contenedor_juego.add_child(rectangulo(MESA, Color(0.42, 0.28, 0.17)))
	contenedor_juego.add_child(rectangulo(Rect2(MESA.position, Vector2(MESA.size.x, 8)), Color(0.55, 0.38, 0.24)))

func _on_colgada(pieza: Dictionary) -> void:
	var herramienta: Draggable = pieza["herramienta"]
	var silueta: Sprite2D = pieza["silueta"]
	herramienta.habilitado = false
	pieza["lista"] = true

	# Encaja: crece al tamaño de la silueta y la silueta desaparece.
	var sprite: Sprite2D = herramienta.get_child(0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2.ONE * pieza["escala"], 0.2)
	silueta.visible = false

	Efectos.nube(contenedor_juego, silueta.position, COLOR_CHISPA, 10, 55.0, 0.4)
	acierto(["¡Encaja!", "¡Justo ahi!", "¡Bien!", "¡Perfecto!"].pick_random(), silueta.position + Vector2(0, -60))

	for p in piezas:
		if not p["lista"]:
			return
	terminar()

# Soltada fuera de su silueta: si cayo sobre otra silueta libre es error.
func _on_suelta(pieza: Dictionary) -> void:
	var punto := get_viewport().get_mouse_position()
	for otra in piezas:
		if otra == pieza or otra["lista"]:
			continue
		var silueta: Sprite2D = otra["silueta"]
		if silueta.position.distance_to(punto) <= 45.0:
			Efectos.sacudir(silueta, 4.0, 0.2)
			error("¡Esa no va ahi!", silueta.position + Vector2(0, -60))
			return
