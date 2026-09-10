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

# Lo más lejos que se permite poner la cámara: por debajo de esto el personaje
# se ve demasiado pequeño en pantalla de móvil.
const ZOOM_MINIMO := 0.8

const WorldObjectScene = preload("res://scenes/world_object.tscn")

@onready var limites: CollisionPolygon2D = $Limites/Contorno
@onready var barry: CharacterBody2D = $Barry
@onready var camara: Camera2D = $Barry/CameraPlayer
@onready var interaction_zone: Node2D = $InteractionZone
@onready var panel_edicion: Control = $CanvasLayer/PanelEdicion
@onready var btn_listo_edicion: Button = $CanvasLayer/PanelEdicion/BtnListoEdicion

var estilo: Dictionary = {}
var ancho: int = 8
var alto: int = 8

# Caja (en coordenadas de mundo) que envuelve el piso de la sala, calculada
# en _construir_limites(). La usa _posicion_mundo_clampeada para no dejar
# arrastrar un objeto mas alla del mapa.
var _limite_mundo: Rect2 = Rect2()

# Objetos colocados en la sala (ver sql/room_objects.sql), instanciados de
# forma dinamica en _cargar_objetos(). Ninguno viene predefinido en la
# escena: asi un objeto nuevo no necesita tocar room.tscn, solo una entrada
# en RoomObjectCatalog y filas en la tabla.
var _objetos: Array[WorldObject] = []

# Modo edicion: se activa desde el boton "Editar Sala" del panel de perfil
# (ver ui.gd). Mientras esta activo, tocar y arrastrar un objeto lo mueve; al
# soltarlo se ajusta a la baldosa mas cercana y se guarda en la base de datos.
var editando: bool = false
var _arrastrando: WorldObject = null

# Objeto marcado (contorno + rebote, ver WorldObject.set_seleccionado).
# Separado de _arrastrando a proposito: queda marcado despues de soltar el
# toque, no solo mientras se esta arrastrando. Se cambia al tocar otro
# objeto y se limpia al tocar el piso vacio o salir de edicion.
var _seleccionado: WorldObject = null

const DISTANCIA_TOQUE := 90.0

# Capas de colision: bit 1 = limite de la sala (Limites/Contorno), bit 2 =
# muebles (CuerpoSolido de cada WorldObject, ver world_object.tscn). Barry
# normalmente choca con ambos; en modo edicion se le saca el bit 2 para que
# los muebles no lo empujen, pero se queda con el 1 para no poder salirse
# caminando del piso de la sala (y con el la camara, que cuelga de el).
const MASCARA_COLISION_NORMAL := 0b11
const MASCARA_COLISION_LIMITES := 0b01

# Zona segura de pantalla para arrastrar objetos en modo edicion: recorta el
# 20% de arriba (cartel de ayuda/perfil) y el 20% de abajo (joystick y boton
# de accion, ver scenes/ui.tscn), dejando el ancho completo. En coordenadas
# de viewport, no de mundo: se compara contra get_viewport().get_mouse_position().
const ZONA_ENFOQUE := Rect2(
	0.0, 780.0 * 0.2,
	420.0, 780.0 * 0.6
)

func _ready() -> void:
	var sala: Dictionary = Supabase.current_room
	estilo = RoomStyles.get_estilo(str(sala.get("style", "basica")))
	ancho = int(estilo["ancho"])
	alto = int(estilo["alto"])

	RenderingServer.set_default_clear_color(estilo["fondo"])

	btn_listo_edicion.pressed.connect(_salir_edicion)

	_construir_limites()
	_colocar_jugador()
	queue_redraw()
	_cargar_objetos()

func _exit_tree() -> void:
	# El taller usa el color de fondo por defecto; si no se restaura, al volver
	# se queda con el cielo de la terraza.
	RenderingServer.set_default_clear_color(Color(0.3, 0.3, 0.3))

# --- Geometría isométrica -------------------------------------------------

# Devuelve el vértice superior de la baldosa (tx, ty). Con tx o ty igual al
# tamaño de la sala devuelve la esquina exacta del suelo.
func tile_a_mundo(tx: int, ty: int) -> Vector2:
	return Vector2((tx - ty) * RoomStyles.TILE_W * 0.5, (tx + ty) * RoomStyles.TILE_H * 0.5)

func _rombo(tx: int, ty: int) -> PackedVector2Array:
	var o := tile_a_mundo(tx, ty)
	return PackedVector2Array([
		o,
		o + Vector2(RoomStyles.TILE_W * 0.5, RoomStyles.TILE_H * 0.5),
		o + Vector2(0, RoomStyles.TILE_H),
		o + Vector2(-RoomStyles.TILE_W * 0.5, RoomStyles.TILE_H * 0.5),
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
	var esquinas := PackedVector2Array([
		tile_a_mundo(0, 0),
		tile_a_mundo(ancho, 0),
		tile_a_mundo(ancho, alto),
		tile_a_mundo(0, alto),
	])
	limites.polygon = esquinas

	# Caja que envuelve el rombo del piso, para no dejar arrastrar un objeto
	# (ver _posicion_mundo_clampeada) mas alla del mapa. No es pixel-perfect
	# con la forma isometrica exacta (dejaria pasar un poco por las cuatro
	# puntas), pero alcanza para que nunca se vaya a la nada.
	_limite_mundo = Rect2(esquinas[0], Vector2.ZERO)
	for esquina in esquinas:
		_limite_mundo = _limite_mundo.expand(esquina)

# --- Objetos ---------------------------------------------------------------

# Cada sala arranca con estos objetos si todavia no los tiene guardados: la
# PC, el auto (donde se completa un trabajo) y la basura. El offset es en
# baldosas desde el centro, para que no se superpongan entre si; el jugador
# los puede reacomodar despues con el modo de edicion.
const OBJETOS_POR_DEFECTO := {
	"pc": Vector2(1, 0),
	"car": Vector2(-2, 0),
	"trash": Vector2(0, 2),
}

# Carga los objetos guardados de la sala (ver sql/room_objects.sql) y los
# instancia. Es async porque implica una peticion de red: se llama al final
# de _ready() sin esperarla, para no atrasar la entrada a la sala por eso.
func _cargar_objetos() -> void:
	var room_id := str(Supabase.current_room.get("id", ""))
	var filas: Array = await Supabase.load_room_objects(room_id) if room_id != "" else []

	var kinds_presentes := {}
	for fila in filas:
		_instanciar_objeto(fila)
		kinds_presentes[str(fila.get("kind", ""))] = true

	for kind in OBJETOS_POR_DEFECTO:
		if kinds_presentes.has(kind):
			continue
		# Sala vieja o recien creada sin este objeto todavia: se calcula la
		# posicion por defecto y se persiste ya, para no repetir el calculo
		# cada vez que se entre.
		var offset: Vector2 = OBJETOS_POR_DEFECTO[kind]
		var pos := tile_a_mundo(ancho / 2 + int(offset.x), alto / 2 + int(offset.y)) + Vector2(0, RoomStyles.TILE_H * 0.5)
		var fila := {"id": "", "kind": kind, "x": pos.x, "y": pos.y}
		if room_id != "":
			var creada := await Supabase.create_room_object(room_id, kind, pos)
			if not creada.is_empty():
				fila = creada
		_instanciar_objeto(fila)

# Lo llama searchwork_ui.gd (via call()) cuando se compra una decoracion en
# la tienda de la PC. Aparece cerca del centro; el jugador la reacomoda con
# el modo de edicion (que se activa solo al comprar, ver ahi el porque).
func agregar_objeto_comprado(kind: String) -> void:
	var room_id := str(Supabase.current_room.get("id", ""))
	var pos := tile_a_mundo(ancho / 2, alto / 2 - 3) + Vector2(0, RoomStyles.TILE_H * 0.5)
	var fila := {"id": "", "kind": kind, "x": pos.x, "y": pos.y}
	if room_id != "":
		var creada := await Supabase.create_room_object(room_id, kind, pos)
		if not creada.is_empty():
			fila = creada
	_instanciar_objeto(fila)
	activar_edicion()

func _instanciar_objeto(fila: Dictionary) -> void:
	var kind := str(fila.get("kind", ""))
	var objeto: WorldObject = WorldObjectScene.instantiate()
	var nombre := RoomObjectCatalog.nombre_nodo(kind)
	objeto.name = nombre if nombre != "" else "Objeto_%d" % _objetos.size()
	objeto.textura = RoomObjectCatalog.textura(kind)
	objeto.escala_sprite = RoomObjectCatalog.escala(kind)
	objeto.poligono_colision = RoomObjectCatalog.poligono_colision(kind)
	objeto.position = Vector2(float(fila.get("x", 0.0)), float(fila.get("y", 0.0)))
	objeto.set_meta("room_object_id", str(fila.get("id", "")))

	var pieza_gratis := RoomObjectCatalog.pieza_gratis(kind)
	if pieza_gratis != "":
		objeto.set_meta("pieza_gratis", pieza_gratis)

	interaction_zone.add_child(objeto)
	_objetos.append(objeto)

	# Barry decide que conectar segun el nombre reservado (PC, auto) o la meta
	# "pieza_gratis" (estantes); un objeto puramente decorativo no tiene
	# ninguno de los dos y conectar_objeto() no hace nada. call() en vez de
	# llamada directa: movement_script.gd no tiene class_name y "barry" esta
	# tipado como CharacterBody2D (lo necesita para global_position en
	# _colocar_jugador), asi que el chequeo estatico de GDScript rechazaria
	# un metodo que no existe en esa clase base.
	barry.call("conectar_objeto", objeto)

# --- Edicion de sala ---------------------------------------------------------

# Lo llama ui.gd cuando se toca "Editar Sala" en el panel de perfil.
func activar_edicion() -> void:
	editando = true
	panel_edicion.visible = true
	# Barry se hace invisible y deja de chocar con los muebles (bit 2, ver
	# CuerpoSolido en world_object.tscn) mientras se edita: asi un objeto
	# puede pasar tranquilo por donde el estaba parado. Sigue respondiendo al
	# limite de la sala (bit 1) para que la camara, que cuelga de el, no se
	# pueda ir caminando fuera del mapa mientras el panel esta abierto.
	barry.visible = false
	barry.collision_mask = MASCARA_COLISION_LIMITES

func _salir_edicion() -> void:
	editando = false
	_arrastrando = null
	_marcar_seleccionado(null)
	panel_edicion.visible = false
	barry.visible = true
	barry.collision_mask = MASCARA_COLISION_NORMAL

# Cambia cual objeto esta marcado (contorno + rebote), apagando el anterior.
# Pasar null limpia la seleccion sin marcar ninguno nuevo.
func _marcar_seleccionado(objeto: WorldObject) -> void:
	if _seleccionado == objeto:
		return
	if is_instance_valid(_seleccionado):
		_seleccionado.set_seleccionado(false)
	_seleccionado = objeto
	if is_instance_valid(_seleccionado):
		_seleccionado.set_seleccionado(true)

func _unhandled_input(event: InputEvent) -> void:
	if not editando:
		return

	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			var tocado := _objeto_en(get_global_mouse_position())
			# Tocar un objeto lo selecciona y arranca el arrastre en el mismo
			# gesto (como antes); tocar el piso vacio solo limpia la
			# seleccion. La marca (contorno + rebote) ya no se apaga al
			# soltar: queda "preseleccionada" hasta tocar otra cosa.
			_marcar_seleccionado(tocado)
			_arrastrando = tocado
		elif _arrastrando != null:
			_soltar_objeto(_arrastrando)
			_arrastrando = null
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _arrastrando != null:
		_arrastrando.position = _posicion_mundo_clampeada()

# Traduce el toque a mundo pasando primero por la zona segura de pantalla
# (ZONA_ENFOQUE): si el dedo se va debajo del joystick/boton de accion, el
# objeto se queda pegado al borde de la zona en vez de seguir al dedo hasta
# ahi abajo. Despues se clampea otra vez, ya en mundo, contra el piso de la
# sala (_limite_mundo) para que tampoco se pueda arrastrar mas alla del mapa.
func _posicion_mundo_clampeada() -> Vector2:
	var pantalla := get_viewport().get_mouse_position()
	pantalla.x = clampf(pantalla.x, ZONA_ENFOQUE.position.x, ZONA_ENFOQUE.end.x)
	pantalla.y = clampf(pantalla.y, ZONA_ENFOQUE.position.y, ZONA_ENFOQUE.end.y)
	var mundo := get_viewport().canvas_transform.affine_inverse() * pantalla
	mundo.x = clampf(mundo.x, _limite_mundo.position.x, _limite_mundo.end.x)
	mundo.y = clampf(mundo.y, _limite_mundo.position.y, _limite_mundo.end.y)
	return mundo

# Cualquiera de los objetos colocados sirve, no solo la PC: el que este mas
# cerca del toque, dentro de un radio razonable.
func _objeto_en(mundo: Vector2) -> WorldObject:
	for objeto in _objetos:
		if objeto.position.distance_to(mundo) < DISTANCIA_TOQUE:
			return objeto
	return null

# Ajusta el objeto a la baldosa mas cercana (para que quede prolijo con el
# resto del suelo isometrico) y persiste la posicion nueva.
func _soltar_objeto(objeto: WorldObject) -> void:
	var tile := _mundo_a_tile(objeto.position)
	var tx := clampi(int(round(tile.x)), 1, ancho - 1)
	var ty := clampi(int(round(tile.y)), 1, alto - 1)
	objeto.position = tile_a_mundo(tx, ty) + Vector2(0, RoomStyles.TILE_H * 0.5)

	var id := str(objeto.get_meta("room_object_id", ""))
	if id != "":
		Supabase.save_room_object_position(id, objeto.position)

# Inversa de tile_a_mundo(): de una posicion del mundo a coordenadas de
# baldosa (con decimales, sin redondear todavia).
func _mundo_a_tile(pos: Vector2) -> Vector2:
	var a := pos.x / (RoomStyles.TILE_W * 0.5)
	var b := pos.y / (RoomStyles.TILE_H * 0.5)
	return Vector2((a + b) * 0.5, (b - a) * 0.5)

# --- Jugador y cámara -----------------------------------------------------

func _colocar_jugador() -> void:
	# En medio de la sala, sobre el centro de la baldosa central.
	barry.global_position = tile_a_mundo(ancho / 2, alto / 2) + Vector2(0, RoomStyles.TILE_H * 0.5)

	# Se intenta encuadrar la sala entera, pero con un tope: en una sala de 50
	# baldosas alejar la cámara hasta que quepa dejaría a Barry como una
	# hormiga. A partir de ahí la cámara le sigue, igual que en el taller.
	var ancho_px := (ancho + alto) * RoomStyles.TILE_W * 0.5
	var alto_px := (ancho + alto) * RoomStyles.TILE_H * 0.5 + RoomStyles.alto_pared(estilo)
	var vista := get_viewport_rect().size
	var z: float = maxf(min(vista.x / (ancho_px * 1.1), vista.y / (alto_px * 1.1), 1.0), ZOOM_MINIMO)
	camara.zoom = Vector2(z, z)
