extends Node2D

# Sala isométrica estilo Habbo. El escenario (suelo, paredes y el muro de
# colisión del borde) se genera por código a partir del estilo elegido en la
# PC: no hay tilemap ni una escena distinta por cada tipo.
#
# El suelo se pinta en _draw() y no con un nodo por baldosa: una sala de 50x50
# son 2500 rombos, y ese número de nodos hunde el rendimiento en móvil. Aquí
# todo cae en un solo CanvasItem, que además se dibuja una única vez porque la
# sala nunca cambia.
#
# Todo lo demás es igual que en el taller: el jugador es scenes/barry.tscn con
# su movement_script, y el joystick y los botones son scenes/ui.tscn.

const TILE_W := 128.0
const TILE_H := 64.0

# Lo más lejos que se permite poner la cámara: por debajo de esto el personaje
# se ve demasiado pequeño en pantalla de móvil.
const ZOOM_MINIMO := 0.8

@onready var limites: CollisionPolygon2D = $Limites/Contorno
@onready var barry: CharacterBody2D = $Barry
@onready var camara: Camera2D = $Barry/CameraPlayer
@onready var titulo: Label = $CanvasLayer/Titulo
@onready var btn_salir: Button = $CanvasLayer/BtnSalir

var estilo: Dictionary = {}
var ancho: int = 8
var alto: int = 8

func _ready() -> void:
	var sala: Dictionary = Supabase.current_room
	estilo = RoomStyles.get_estilo(str(sala.get("style", "basica")))
	ancho = int(estilo["ancho"])
	alto = int(estilo["alto"])

	titulo.text = str(sala.get("name", estilo["nombre"]))
	btn_salir.pressed.connect(_salir)

	RenderingServer.set_default_clear_color(estilo["fondo"])

	_construir_limites()
	_colocar_jugador()
	queue_redraw()

func _exit_tree() -> void:
	# El taller usa el color de fondo por defecto; si no se restaura, al volver
	# se queda con el cielo de la terraza.
	RenderingServer.set_default_clear_color(Color(0.3, 0.3, 0.3))

# --- Geometría isométrica -------------------------------------------------

# Devuelve el vértice superior de la baldosa (tx, ty). Con tx o ty igual al
# tamaño de la sala devuelve la esquina exacta del suelo.
func tile_a_mundo(tx: int, ty: int) -> Vector2:
	return Vector2((tx - ty) * TILE_W * 0.5, (tx + ty) * TILE_H * 0.5)

func _rombo(tx: int, ty: int) -> PackedVector2Array:
	var o := tile_a_mundo(tx, ty)
	return PackedVector2Array([
		o,
		o + Vector2(TILE_W * 0.5, TILE_H * 0.5),
		o + Vector2(0, TILE_H),
		o + Vector2(-TILE_W * 0.5, TILE_H * 0.5),
	])

# El nodo se dibuja antes que sus hijos, así que Barry queda siempre encima.
func _draw() -> void:
	_dibujar_paredes()
	_dibujar_suelo()

func _dibujar_suelo() -> void:
	var color_a: Color = estilo["suelo_a"]
	var color_b: Color = estilo["suelo_b"]
	var color_borde: Color = estilo["borde"]

	for ty in alto:
		for tx in ancho:
			var puntos := _rombo(tx, ty)
			draw_colored_polygon(puntos, color_a if (tx + ty) % 2 == 0 else color_b)

	# Las líneas van en una segunda pasada para que ninguna quede tapada por la
	# baldosa que se pinta después.
	for ty in alto:
		for tx in ancho:
			var puntos := _rombo(tx, ty)
			draw_polyline(puntos + PackedVector2Array([puntos[0]]), color_borde, 2.0)

func _dibujar_paredes() -> void:
	var h := float(RoomStyles.alto_pared(estilo))
	var esquina := tile_a_mundo(0, 0)
	_dibujar_pared(esquina, tile_a_mundo(ancho, 0), h, estilo["pared_izq"])
	_dibujar_pared(esquina, tile_a_mundo(0, alto), h, estilo["pared_der"])

func _dibujar_pared(base_ini: Vector2, base_fin: Vector2, altura: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		base_ini + Vector2(0, -altura),
		base_fin + Vector2(0, -altura),
		base_fin,
		base_ini,
	]), color)

	# Remate superior: una franja más clara para que se lea el grosor del muro.
	draw_line(base_ini + Vector2(0, -altura), base_fin + Vector2(0, -altura), color.lightened(0.25), 8.0)

# El jugador se mueve libre por el suelo, así que el límite es el contorno del
# rombo completo en modo segmentos: una pared invisible, no un bloque macizo.
func _construir_limites() -> void:
	limites.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	limites.polygon = PackedVector2Array([
		tile_a_mundo(0, 0),
		tile_a_mundo(ancho, 0),
		tile_a_mundo(ancho, alto),
		tile_a_mundo(0, alto),
	])

# --- Jugador y cámara -----------------------------------------------------

func _colocar_jugador() -> void:
	# En medio de la sala, sobre el centro de la baldosa central.
	barry.global_position = tile_a_mundo(ancho / 2, alto / 2) + Vector2(0, TILE_H * 0.5)

	# La cámara viene inclinada del taller (allí el mapa está rotado); aquí la
	# sala ya es isométrica por construcción, así que se endereza.
	camara.rotation = 0.0

	# Se intenta encuadrar la sala entera, pero con un tope: en una sala de 50
	# baldosas alejar la cámara hasta que quepa dejaría a Barry como una
	# hormiga. A partir de ahí la cámara le sigue, igual que en el taller.
	var ancho_px := (ancho + alto) * TILE_W * 0.5
	var alto_px := (ancho + alto) * TILE_H * 0.5 + RoomStyles.alto_pared(estilo)
	var vista := get_viewport_rect().size
	var z: float = maxf(min(vista.x / (ancho_px * 1.1), vista.y / (alto_px * 1.1), 1.0), ZOOM_MINIMO)
	camara.zoom = Vector2(z, z)

func _salir() -> void:
	Supabase.current_room = {}
	get_tree().change_scene_to_file("res://scenes/main.tscn")
