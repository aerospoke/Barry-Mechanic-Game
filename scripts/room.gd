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
const ConfirmModal = preload("res://scripts/confirm_modal.gd")
# Solo por su const MINIGAMES (pieza -> trabajo), para saber que estante
# resaltar segun el trabajo activo.
const BarryScript = preload("res://scripts/movement_script.gd")
const PetPicker = preload("res://scripts/pet_picker.gd")
const VentanaPared = preload("res://scripts/ventana_pared.gd")
const RadioEquipo = preload("res://scripts/radio_equipo.gd")
const RadioPanel = preload("res://scripts/radio_panel.gd")
const Balanceo = preload("res://scripts/balanceo.gd")
const SelectorVariante = preload("res://scripts/selector_variante.gd")

# Objetos que se tocan con el boton de accion (ver interactuar_objeto):
# "luz" se prende/apaga, "variante" abre el selector (ej. la bandera).
const ACCION_LUZ := "luz"
const ACCION_VARIANTE := "variante"
const Efectos = preload("res://scripts/efectos.gd")

# Capa de fisica de las mascotas: chocan con los limites (1) y los muebles
# (2), pero Barry (que no tiene la capa 3 en su mascara) les pasa por encima
# en vez de quedar trabado.
const CAPA_MASCOTA := 0b100
const MASCARA_MASCOTA := 0b11

# "Premio" que muestra la TV de hazte-Gold (ver _crear_banner_gold): uno al
# azar por sala, elegido entre objetos sueltos de res://objetos (nada de
# spritesheets ni el propio sprite de Barry).
const OBJETOS_BANNER_GOLD := [
	preload("res://objetos/coin.png"),
	preload("res://objetos/trophiev2.png"),
	preload("res://objetos/a3.png"),
	preload("res://objetos/llantasIluminado.png"),
	preload("res://objetos/light1.png"),
	preload("res://objetos/oil2.png"),
	preload("res://objetos/boxKeys.png"),
	preload("res://objetos/boxFilters.png"),
	preload("res://objetos/boxLights.png"),
	preload("res://objetos/trash2.png"),
]

@onready var limites: CollisionPolygon2D = $Limites/Contorno
@onready var barry: CharacterBody2D = $Barry
@onready var camara: Camera2D = $Barry/CameraPlayer
@onready var interaction_zone: Node2D = $InteractionZone
@onready var panel_edicion: Control = $CanvasLayer/PanelEdicion
@onready var btn_listo_edicion: Button = $CanvasLayer/PanelEdicion/BtnListoEdicion
@onready var btn_borrar_objeto: Button = $CanvasLayer/PanelEdicion/BtnBorrarObjeto
@onready var btn_girar_objeto: Button = $CanvasLayer/PanelEdicion/BtnGirarObjeto

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

# Banner publicitario en la pared, ver _crear_banner_gold() /
# actualizar_banner_gold(). Se oculta si Supabase.current_room["owner_gold"]
# es true (ver sql/rooms_gold.sql).
var _banner_gold: Node2D = null
var _banner_gold_tam: Vector2 = Vector2.ZERO

# Igual que _seleccionado pero para el banner: no es un WorldObject (no tiene
# fila propia en room_objects, no se puede borrar), asi que se marca aparte
# con solo el pulso, sin contorno ni boton de eliminar. Si se puede arrastrar,
# pero solo a lo largo de la pared (ver _banner_gold_t/_mover_banner_gold),
# no libremente como los objetos del piso.
var _banner_gold_seleccionado: bool = false
var _tween_banner_gold: Tween
var _banner_gold_arrastrando: bool = false
# Posicion a lo largo de la pared, 0.0-1.0 (ver sql/rooms_gold_banner_pos.sql).
var _banner_gold_t: float = 0.5

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

# Guacal recien comprado que todavia no eligio mascota (ver _salir_edicion).
var _guacal_pendiente: WorldObject = null
# Objeto con variantes recien comprado: se elige cual al terminar de ubicarlo.
var _variante_pendiente: WorldObject = null

# Objetos de pared (ventanas). Van aparte de _objetos: no son WorldObject,
# se arrastran a lo largo de las paredes y no se giran.
var _ventanas: Array = []
var _ventana_seleccionada: VentanaPared = null
var _ventana_arrastrando: VentanaPared = null
var _tween_ventana: Tween

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
	btn_borrar_objeto.pressed.connect(_on_btn_borrar_objeto_pressed)
	btn_girar_objeto.pressed.connect(_on_btn_girar_objeto_pressed)

	_construir_limites()
	_colocar_jugador()
	queue_redraw()
	Supabase.active_work_changed.connect(_actualizar_resaltados)
	barry.connect("item_en_mano_cambiado", _actualizar_resaltados)
	_cargar_objetos()
	_crear_banner_gold()
	actualizar_banner_gold()

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

# "TV" de "hazte Gold" colgada en la pared izquierda (de (0,0) a (ancho,0)):
# marco oscuro + pantalla. Puramente cosmetico/de venta: no existe otro
# efecto de juego, se oculta o muestra segun actualizar_banner_gold().
func _crear_banner_gold() -> void:
	_banner_gold_t = clampf(float(Supabase.current_room.get("gold_banner_t", 0.5)), 0.0, 1.0)

	var h := float(RoomStyles.alto_pared(estilo))

	# Proporcional al alto del muro: una sala de paredes bajas (terraza) tiene
	# una TV chica, una de paredes altas (loft) la tiene grande, pero en
	# ambas ocupa la misma fraccion de la pared y deja margen arriba/abajo.
	var alto_tv := h * 0.85
	var ancho_tv := alto_tv * 1.5
	_banner_gold_tam = Vector2(ancho_tv, alto_tv)
	const GROSOR_MARCO := 10.0

	_banner_gold = Node2D.new()
	add_child(_banner_gold)
	# Mismo z_index que Barry y los objetos (0, todos quedan encima del muro
	# por como se dibuja), pero primero en la lista de hijos: a igualdad de
	# z_index, Godot pinta a los hermanos en orden, asi que esto la deja
	# siempre detras de Barry y de cualquier mueble en vez de tapar al
	# personaje cuando pasa justo enfrente.
	move_child(_banner_gold, 0)
	_actualizar_transform_banner_gold()

	var marco := ColorRect.new()
	marco.color = Color(0.05, 0.05, 0.06)
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marco.offset_left = -ancho_tv * 0.5
	marco.offset_top = -alto_tv * 0.5
	marco.offset_right = ancho_tv * 0.5
	marco.offset_bottom = alto_tv * 0.5
	_banner_gold.add_child(marco)

	var pantalla := ColorRect.new()
	pantalla.color = Color(0.95, 0.76, 0.15)
	pantalla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pantalla.offset_left = marco.offset_left + GROSOR_MARCO
	pantalla.offset_top = marco.offset_top + GROSOR_MARCO
	pantalla.offset_right = marco.offset_right - GROSOR_MARCO
	pantalla.offset_bottom = marco.offset_bottom - GROSOR_MARCO
	_banner_gold.add_child(pantalla)

	# "Premio" al azar arriba, texto de venta abajo: el mismo objeto se ve
	# distinto en cada sala/refresco, como un anuncio de verdad.
	var divisoria := pantalla.offset_top + (pantalla.offset_bottom - pantalla.offset_top) * 0.6

	var premio := TextureRect.new()
	premio.texture = OBJETOS_BANNER_GOLD.pick_random()
	premio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	premio.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	premio.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	premio.offset_left = pantalla.offset_left + 6.0
	premio.offset_top = pantalla.offset_top + 4.0
	premio.offset_right = pantalla.offset_right - 6.0
	premio.offset_bottom = divisoria
	_banner_gold.add_child(premio)

	var texto := Label.new()
	texto.text = "¡DINERO GRATIS!"
	texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texto.offset_left = pantalla.offset_left
	texto.offset_top = divisoria
	texto.offset_right = pantalla.offset_right
	texto.offset_bottom = pantalla.offset_bottom
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.add_theme_color_override("font_color", Color(0.15, 0.85, 0.25))
	texto.add_theme_font_size_override("font_size", int(alto_tv * 0.11))
	_banner_gold.add_child(texto)

# Extremos de la pared donde cuelga la TV (de (0,0) a (ancho,0)).
func _banner_gold_pared() -> Array:
	return [tile_a_mundo(0, 0), tile_a_mundo(ancho, 0)]

# Reconstruye el transform de la TV a partir de _banner_gold_t. Se llama al
# crearla y en cada frame de arrastre (ver _mover_banner_gold).
func _actualizar_transform_banner_gold() -> void:
	var pared := _banner_gold_pared()
	var base_ini: Vector2 = pared[0]
	var base_fin: Vector2 = pared[1]
	var h := float(RoomStyles.alto_pared(estilo))
	var centro := base_ini.lerp(base_fin, _banner_gold_t) + Vector2(0, -h * 0.5)
	# Transform a mano, no rotation: el muro (ver _dibujar_pared) no esta
	# rotado, esta "estirado" — el borde horizontal sigue la baldosa pero el
	# vertical es recto (Vector2(0, -altura), sin componente en x). Una
	# rotacion gira los dos ejes por igual y flota "de perfil" en vez de
	# quedar pegada a la pared. El eje Y tiene que apuntar para abajo (no
	# Vector2.UP): es hacia donde crecen los offset_top/bottom, y con UP el
	# contenido queda espejado.
	var direccion_pared := (base_fin - base_ini).normalized()
	_banner_gold.transform = Transform2D(direccion_pared, Vector2.DOWN, centro)

# Arrastra la TV a lo largo de la pared: proyecta el toque sobre la linea de
# la pared y lo pasa a "t" (0.0-1.0), recortado para que la TV nunca
# sobresalga de ninguna punta.
func _mover_banner_gold(mundo: Vector2) -> void:
	var pared := _banner_gold_pared()
	var base_ini: Vector2 = pared[0]
	var base_fin: Vector2 = pared[1]
	var largo := base_ini.distance_to(base_fin)
	if largo <= 0.0:
		return

	var direccion := (base_fin - base_ini) / largo
	var t := (mundo - base_ini).dot(direccion) / largo

	var margen := (_banner_gold_tam.x * 0.5) / largo
	_banner_gold_t = clampf(t, margen, 1.0 - margen) if margen < 0.5 else 0.5
	_actualizar_transform_banner_gold()

# Persiste donde quedo la TV al soltarla (ver _unhandled_input).
func _guardar_pos_banner_gold() -> void:
	var room_id := str(Supabase.current_room.get("id", ""))
	if room_id == "":
		return
	Supabase.current_room["gold_banner_t"] = _banner_gold_t
	await Supabase.save_gold_banner_pos(room_id, _banner_gold_t)

# Lo llama searchwork_ui.gd (via call()) justo despues de comprar la
# membresia, para que el banner desaparezca sin tener que salir y volver a
# entrar a la sala. _ready() tambien lo llama para el estado inicial.
func actualizar_banner_gold() -> void:
	if not is_instance_valid(_banner_gold):
		return
	_banner_gold.visible = not bool(Supabase.current_room.get("owner_gold", false))

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

	await _dejar_un_solo_equipo()

	# El nivel de la caneca viene del perfil; normalmente ya esta cargado
	# (load_profile no repite la peticion), pero al entrar directo a la sala
	# puede no estarlo todavia.
	await Supabase.load_profile()
	_actualizar_canecas()

# Lo llama searchwork_ui.gd (via call()) cuando se compra una decoracion en
# la tienda de la PC. Aparece cerca del centro; el jugador la reacomoda con
# el modo de edicion (que se activa solo al comprar, ver ahi el porque).
func agregar_objeto_comprado(kind: String) -> void:
	var room_id := str(Supabase.current_room.get("id", ""))
	var pos := _posicion_a_la_vista()
	if RoomObjectCatalog.es_de_pared(kind):
		# Al medio de la primera pared (x = t, y = pared).
		pos = Vector2(0.5, 0)

	# El equipo PRO reemplaza al comun: nunca hay dos. Aparece en el mismo
	# lugar donde estaba el viejo, que se borra.
	var reemplazado: WorldObject = null
	if RoomObjectCatalog.es_radio_pro(kind):
		reemplazado = _objeto_de_tipo("radio")
		if reemplazado != null:
			pos = reemplazado.position

	var fila := {"id": "", "kind": kind, "x": pos.x, "y": pos.y}
	if room_id != "":
		var creada := await Supabase.create_room_object(room_id, kind, pos)
		if not creada.is_empty():
			fila = creada
	_instanciar_objeto(fila)
	if reemplazado != null:
		await _quitar_objeto(reemplazado)
	_actualizar_canecas()
	# Un guacal recien comprado pide elegir mascota apenas se termina de
	# ubicarlo (ver _salir_edicion).
	if RoomObjectCatalog.es_mascota(kind):
		_guacal_pendiente = _objetos.back()
	if not RoomObjectCatalog.variantes(kind).is_empty():
		_variante_pendiente = _objetos.back()
	activar_edicion()
	if RoomObjectCatalog.es_de_pared(kind) and not _ventanas.is_empty():
		_marcar_ventana(_ventanas.back())
	elif not _objetos.is_empty():
		# Ya marcado: encima de todo, con contorno y rebote, listo para
		# arrastrarlo a donde se quiera.
		_marcar_seleccionado(_objetos.back())

# Donde aparece algo recien comprado: en el centro de lo que se ve en
# pantalla (un poco arriba, para no caerle encima a Barry), ajustado a la
# baldosa mas cercana y sin salirse del piso. Antes aparecia siempre en el
# centro de la sala y en salas grandes habia que ir a buscarlo.
const ALTURA_SOBRE_BARRY := 110.0

func _posicion_a_la_vista() -> Vector2:
	var pantalla := get_viewport_rect().size / 2.0 - Vector2(0, ALTURA_SOBRE_BARRY)
	var mundo := get_viewport().canvas_transform.affine_inverse() * pantalla
	var tile := _mundo_a_tile(mundo)
	var tx := clampi(int(round(tile.x)), 1, ancho - 1)
	var ty := clampi(int(round(tile.y)), 1, alto - 1)
	return tile_a_mundo(tx, ty) + Vector2(0, RoomStyles.TILE_H * 0.5)

func _instanciar_objeto(fila: Dictionary) -> void:
	var kind := str(fila.get("kind", ""))
	if RoomObjectCatalog.es_de_pared(kind):
		_instanciar_ventana(fila)
		return
	var objeto: WorldObject = WorldObjectScene.instantiate()
	var nombre := RoomObjectCatalog.nombre_nodo(kind)
	objeto.name = nombre if nombre != "" else "Objeto_%d" % _objetos.size()
	objeto.textura = RoomObjectCatalog.textura(kind)
	objeto.escala_sprite = RoomObjectCatalog.escala(kind)
	objeto.poligono_colision = RoomObjectCatalog.poligono_colision(kind)
	objeto.position = Vector2(float(fila.get("x", 0.0)), float(fila.get("y", 0.0)))
	objeto.posicion_sprite = RoomObjectCatalog.posicion_sprite(kind)
	# null (columna sin correr su SQL) cuenta como no girado.
	objeto.volteado = fila.get("volteado") == true
	objeto.set_meta("room_object_id", str(fila.get("id", "")))
	objeto.set_meta("kind", kind)
	# Variante guardada (null si la columna esta vacia): que bandera es, si
	# la luz quedo prendida...
	var variante_guardada = fila.get("variant")
	var variante_txt := str(variante_guardada) if variante_guardada != null else ""

	# Decoracion de piso: debajo de todo y sin choque (Barry la pisa).
	if RoomObjectCatalog.es_de_piso(kind):
		objeto.en_piso = true
		objeto.get_node("CuerpoSolido").collision_layer = 0

	# Luces: la variante guarda si quedo prendida ("on").
	if RoomObjectCatalog.textura_encendida(kind) != null:
		objeto.set_meta("accion", ACCION_LUZ)
		if variante_txt == "on":
			objeto.textura = RoomObjectCatalog.textura_encendida(kind)
		objeto.set_meta("encendida", variante_txt == "on")

	# Objetos con varias versiones (banderas): la variante es cual se eligio.
	var variantes := RoomObjectCatalog.variantes(kind)
	if not variantes.is_empty():
		objeto.set_meta("accion", ACCION_VARIANTE)
		if variantes.has(variante_txt):
			objeto.textura = variantes[variante_txt]["textura"]
			objeto.set_meta("variante", variante_txt)

	var pieza_gratis := RoomObjectCatalog.pieza_gratis(kind)
	if pieza_gratis != "":
		objeto.set_meta("pieza_gratis", pieza_gratis)
	if RoomObjectCatalog.es_mascota(kind):
		objeto.set_meta("guacal", true)
	if RoomObjectCatalog.es_radio(kind):
		objeto.set_meta("radio", true)
		if RoomObjectCatalog.es_radio_pro(kind):
			objeto.set_meta("radio_pro", true)
	if RoomObjectCatalog.es_reciclaje(kind):
		objeto.set_meta("reciclaje", RoomObjectCatalog.posicion_medidor(kind))

	interaction_zone.add_child(objeto)
	_objetos.append(objeto)

	if RoomObjectCatalog.se_balancea(kind):
		objeto.add_child(Balanceo.new())

	if objeto.has_meta("radio"):
		var equipo := RadioEquipo.new()
		equipo.es_pro = objeto.has_meta("radio_pro")
		objeto.add_child(equipo)
		_elegir_radio_activa()

	# Barry decide que conectar segun el nombre reservado (PC, auto) o la meta
	# "pieza_gratis" (estantes); un objeto puramente decorativo no tiene
	# ninguno de los dos y conectar_objeto() no hace nada. call() en vez de
	# llamada directa: movement_script.gd no tiene class_name y "barry" esta
	# tipado como CharacterBody2D (lo necesita para global_position en
	# _colocar_jugador), asi que el chequeo estatico de GDScript rechazaria
	# un metodo que no existe en esa clase base.
	barry.call("conectar_objeto", objeto)

	var variante := str(fila.get("variant", ""))
	if objeto.has_meta("guacal") and PetCatalog.existe(variante):
		_soltar_mascota(objeto, variante, false)

# --- Ventanas (objetos de pared) -------------------------------------------

# Las dos paredes de la sala, como pares [inicio, fin] de su base. La 0 es
# la misma donde cuelga la TV Gold.
func _paredes() -> Array:
	return [
		[tile_a_mundo(0, 0), tile_a_mundo(ancho, 0)],
		[tile_a_mundo(0, 0), tile_a_mundo(0, alto)],
	]

func _instanciar_ventana(fila: Dictionary) -> void:
	var h := float(RoomStyles.alto_pared(estilo))
	var ventana := VentanaPared.new()
	# Proporcional al alto del muro, como la TV.
	ventana.configurar(Vector2(h * 0.55, h * 0.5))
	ventana.t = clampf(float(fila.get("x", 0.5)), 0.0, 1.0)
	ventana.pared = clampi(int(fila.get("y", 0)), 0, 1)
	ventana.set_meta("room_object_id", str(fila.get("id", "")))
	add_child(ventana)
	_colocar_ventana(ventana)
	_ventanas.append(ventana)

# Mismo transform "pegado a la pared" que la TV (ver
# _actualizar_transform_banner_gold): eje x a lo largo de la pared, eje y
# recto hacia abajo.
func _colocar_ventana(ventana: VentanaPared) -> void:
	var pared: Array = _paredes()[ventana.pared]
	var h := float(RoomStyles.alto_pared(estilo))
	var centro: Vector2 = pared[0].lerp(pared[1], ventana.t) + Vector2(0, -h * 0.55)
	var direccion: Vector2 = (pared[1] - pared[0]).normalized()
	ventana.transform = Transform2D(direccion, Vector2.DOWN, centro)

# Arrastre: la ventana va a la pared mas cercana al dedo y se desliza a lo
# largo de ella, sin sobresalir de las puntas.
func _mover_ventana(ventana: VentanaPared, mundo: Vector2) -> void:
	var h := float(RoomStyles.alto_pared(estilo))
	var mejor_dist := INF
	var paredes := _paredes()
	for i in paredes.size():
		var ini: Vector2 = paredes[i][0]
		var fin: Vector2 = paredes[i][1]
		var largo := ini.distance_to(fin)
		if largo <= 0.0:
			continue
		var margen: float = (ventana.tam.x * 0.5) / largo
		var t := clampf((mundo - ini).dot((fin - ini) / largo) / largo, margen, 1.0 - margen)
		var punto := ini.lerp(fin, t) + Vector2(0, -h * 0.55)
		var dist := punto.distance_to(mundo)
		if dist < mejor_dist:
			mejor_dist = dist
			ventana.pared = i
			ventana.t = t
	_colocar_ventana(ventana)

func _ventana_en(mundo: Vector2) -> VentanaPared:
	for ventana in _ventanas:
		if ventana.contiene(mundo):
			return ventana
	return null

# Marca (brillo pulsante) la ventana elegida en modo edicion. Elegir una
# ventana desmarca muebles y TV, y viceversa (ver _marcar_seleccionado).
func _marcar_ventana(ventana: VentanaPared) -> void:
	if ventana != null:
		_marcar_seleccionado(null)
		_marcar_banner_gold_seleccionado(false)
	if ventana == _ventana_seleccionada:
		return

	if is_instance_valid(_tween_ventana):
		_tween_ventana.kill()
	if is_instance_valid(_ventana_seleccionada):
		_ventana_seleccionada.modulate = Color.WHITE
	_ventana_seleccionada = ventana

	if ventana != null:
		_tween_ventana = create_tween().set_loops()
		_tween_ventana.tween_property(ventana, "modulate", Color(1.35, 1.35, 1.35), 0.6)
		_tween_ventana.tween_property(ventana, "modulate", Color.WHITE, 0.6)
		btn_borrar_objeto.disabled = false
		btn_girar_objeto.disabled = true

func _guardar_ventana(ventana: VentanaPared) -> void:
	var id := str(ventana.get_meta("room_object_id", ""))
	if id != "":
		Supabase.save_room_object_position(id, Vector2(ventana.t, ventana.pared))

# --- Equipo de sonido -------------------------------------------------------

# Solo suena un equipo por sala: el profesional si hay, si no el primero.
func _elegir_radio_activa() -> void:
	var equipos: Array = []
	for objeto in _objetos:
		if not is_instance_valid(objeto) or objeto.is_queued_for_deletion():
			continue
		for hijo in objeto.get_children():
			if hijo is RadioEquipo:
				equipos.append(hijo)
	var elegido: RadioEquipo = null
	for equipo in equipos:
		if equipo.es_pro:
			elegido = equipo
			break
	if elegido == null and not equipos.is_empty():
		elegido = equipos[0]
	for equipo in equipos:
		equipo.activo = equipo == elegido

# Primer objeto de la sala con esa meta (ej. "radio", "radio_pro"), o null.
# Para "radio" no cuenta el PRO: es el equipo comun.
func _objeto_de_tipo(meta: String) -> WorldObject:
	for objeto in _objetos:
		if not is_instance_valid(objeto) or not objeto.has_meta(meta):
			continue
		if meta == "radio" and objeto.has_meta("radio_pro"):
			continue
		return objeto
	return null

# La tienda pregunta (via call()) si ya hay un equipo de sonido, para no
# vender uno de mas: "radio" = cualquiera de los dos, "radio_pro" = el PRO.
func tiene_equipo(kind: String) -> bool:
	if kind == "radio_pro":
		return _objeto_de_tipo("radio_pro") != null
	return _objeto_de_tipo("radio") != null or _objeto_de_tipo("radio_pro") != null

# Una sala tiene un solo equipo de sonido. Salas que quedaron con mas de uno
# (de antes de esta regla) se arreglan al cargar: se queda el PRO si hay, si
# no el primero, y los demas se borran de la sala y de la base.
func _dejar_un_solo_equipo() -> void:
	var equipos: Array = []
	for objeto in _objetos:
		if is_instance_valid(objeto) and objeto.has_meta("radio"):
			equipos.append(objeto)
	if equipos.size() <= 1:
		return
	var queda: WorldObject = equipos[0]
	for equipo in equipos:
		if equipo.has_meta("radio_pro"):
			queda = equipo
			break
	for equipo in equipos:
		if equipo != queda:
			await _quitar_objeto(equipo)

# Borra un objeto de la sala y de la base sin preguntar (reemplazos).
func _quitar_objeto(objeto: WorldObject) -> void:
	var id := str(objeto.get_meta("room_object_id", ""))
	if id != "":
		await Supabase.delete_room_object(id)
	_quitar_mascota(objeto)
	_objetos.erase(objeto)
	objeto.queue_free()
	_elegir_radio_activa()

# Lo llama Barry al tocar el equipo de sonido.
func abrir_radio() -> void:
	RadioPanel.crear(self, _objeto_de_tipo("radio_pro") != null)

# --- Objetos que se tocan (luces, banderas) ---------------------------------

# Lo llama Barry al tocar un objeto con meta "accion".
func interactuar_objeto(objeto: WorldObject) -> void:
	if not is_instance_valid(objeto):
		return
	var kind := str(objeto.get_meta("kind", ""))
	match objeto.get_meta("accion", ""):
		ACCION_LUZ:
			var encendida: bool = not objeto.get_meta("encendida", false)
			objeto.set_meta("encendida", encendida)
			objeto.textura = RoomObjectCatalog.textura_encendida(kind) if encendida else RoomObjectCatalog.textura(kind)
			Sonido.efecto("click", 1.2 if encendida else 0.85)
			_guardar_variante(objeto, "on" if encendida else "off")
		ACCION_VARIANTE:
			var variantes := RoomObjectCatalog.variantes(kind)
			var menu = SelectorVariante.crear(self, "Elige cual mostrar", variantes, str(objeto.get_meta("variante", "")))
			var elegida: String = await menu.elegido
			if elegida == "" or not variantes.has(elegida) or not is_instance_valid(objeto):
				return
			objeto.set_meta("variante", elegida)
			objeto.textura = variantes[elegida]["textura"]
			Efectos.rebote(objeto, Vector2.ONE)
			Sonido.efecto("acierto")
			_guardar_variante(objeto, elegida)

func _guardar_variante(objeto: WorldObject, variante: String) -> void:
	var id := str(objeto.get_meta("room_object_id", ""))
	if id != "":
		Supabase.save_room_object_variant(id, variante)

# --- Mascotas ---------------------------------------------------------------

# Abre "Elige la mascota del taller" para un guacal. Lo llama Barry al tocar
# el guacal y la sala al terminar de ubicar uno recien comprado.
func abrir_selector_mascota(guacal: WorldObject) -> void:
	var actual := str(guacal.get_meta("mascota_id", ""))
	var menu = PetPicker.crear(self, actual)
	var elegida: String = await menu.elegido
	if elegida == "" or elegida == actual or not is_instance_valid(guacal):
		return

	var id := str(guacal.get_meta("room_object_id", ""))
	if id != "" and not await Supabase.save_room_object_variant(id, elegida):
		return
	_soltar_mascota(guacal, elegida, true)

# La mascota sale del guacal (reemplaza a la anterior si habia una) y se
# queda paseando por la sala.
func _soltar_mascota(guacal: WorldObject, id: String, festejar: bool) -> void:
	_quitar_mascota(guacal)

	var mascota: CharacterBody2D = PetCatalog.escena(id).instantiate()
	mascota.collision_layer = CAPA_MASCOTA
	mascota.collision_mask = MASCARA_MASCOTA
	# Los sprites de la mascota son chicos: se agranda todo menos el cuerpo
	# fisico, y el dibujo se sube para que el origen quede en sus patas (la
	# sala ordena por profundidad con ese punto).
	var escala := PetCatalog.escala(id)
	for hijo in mascota.get_children():
		if hijo is Node2D:
			hijo.scale *= escala
		if hijo is AnimatedSprite2D:
			hijo.position.y -= 14.0 * escala
	# Delante del guacal, fuera de su base solida.
	mascota.position = guacal.position + Vector2(0, 150)
	interaction_zone.add_child(mascota)
	guacal.set_meta("mascota_id", id)
	guacal.set_meta("mascota_nodo", mascota)

	if festejar:
		mascota.scale = Vector2(0.2, 0.2)
		var tween := mascota.create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(mascota, "scale", Vector2.ONE, 0.4)
		Efectos.nube(interaction_zone, mascota.position, Color(1.0, 0.9, 0.45), 14, 70.0, 0.6)
		Sonido.efecto("miau")
		Efectos.texto_flotante(interaction_zone, "¡Hola, %s!" % PetCatalog.nombre(id), mascota.position + Vector2(0, -90), Color(1.0, 0.85, 0.3), 26)

func _quitar_mascota(guacal: WorldObject) -> void:
	var anterior = guacal.get_meta("mascota_nodo", null)
	if is_instance_valid(anterior):
		anterior.queue_free()
	guacal.remove_meta("mascota_nodo")

# Medidor de las canecas con el nivel de basura del jugador (ver
# Supabase.profile_trash). Llena, ademas se resalta (ver _actualizar_resaltados).
func _actualizar_canecas() -> void:
	var nivel: int = Supabase.profile_trash
	var capacidad: int = Supabase.CAPACIDAD_BASURA
	for objeto in _objetos:
		if objeto.has_meta("reciclaje"):
			var texto := "¡Llena!" if nivel >= capacidad else "%d/%d" % [nivel, capacidad]
			objeto.set_medidor(float(nivel) / capacidad, texto, objeto.get_meta("reciclaje"))
	_actualizar_resaltados()

# Marca los estantes que dan la pieza que pide el trabajo activo (puede
# haber mas de uno del mismo tipo) y las canecas llenas; apaga el resto. Sin
# trabajo activo, o con la pieza ya en la mano de Barry, no queda ningun
# estante marcado.
func _actualizar_resaltados() -> void:
	var pieza := ""
	for item in BarryScript.MINIGAMES:
		if BarryScript.MINIGAMES[item]["clave"] == Supabase.active_work_key:
			pieza = item
			break

	if barry.get("item_en_mano") == pieza:
		pieza = ""

	var caneca_llena := Supabase.basura_llena()
	for objeto in _objetos:
		var es_estante: bool = pieza != "" and objeto.get_meta("pieza_gratis", "") == pieza
		var es_caneca: bool = caneca_llena and objeto.has_meta("reciclaje")
		objeto.set_resaltado(es_estante or es_caneca)

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
	_ventana_arrastrando = null
	_banner_gold_arrastrando = false
	_marcar_seleccionado(null)
	_marcar_banner_gold_seleccionado(false)
	panel_edicion.visible = false
	barry.visible = true
	barry.collision_mask = MASCARA_COLISION_NORMAL

	if is_instance_valid(_guacal_pendiente):
		var guacal := _guacal_pendiente
		_guacal_pendiente = null
		abrir_selector_mascota(guacal)
	elif is_instance_valid(_variante_pendiente):
		var objeto := _variante_pendiente
		_variante_pendiente = null
		interactuar_objeto(objeto)

# Cambia cual objeto esta marcado (contorno + rebote), apagando el anterior.
# Pasar null limpia la seleccion sin marcar ninguno nuevo.
func _marcar_seleccionado(objeto: WorldObject) -> void:
	_marcar_ventana(null)
	# Solo una cosa marcada a la vez: elegir un objeto real (o limpiar tocando
	# el piso vacio) apaga el banner tambien.
	_marcar_banner_gold_seleccionado(false)

	if _seleccionado == objeto:
		return
	if is_instance_valid(_seleccionado):
		_seleccionado.set_seleccionado(false)
	_seleccionado = objeto
	if is_instance_valid(_seleccionado):
		_seleccionado.set_seleccionado(true)
	btn_borrar_objeto.disabled = _seleccionado == null
	btn_girar_objeto.disabled = _seleccionado == null

# El banner no es un WorldObject (no tiene fila en room_objects: no se puede
# arrastrar ni borrar), asi que solo se marca con el mismo pulso que usan los
# objetos reales, sin contorno ni boton de eliminar.
func _marcar_banner_gold_seleccionado(activo: bool) -> void:
	if activo:
		_marcar_seleccionado(null)

	if _banner_gold_seleccionado == activo or not is_instance_valid(_banner_gold):
		return
	_banner_gold_seleccionado = activo

	if is_instance_valid(_tween_banner_gold):
		_tween_banner_gold.kill()

	if activo:
		_tween_banner_gold = create_tween()
		_tween_banner_gold.set_trans(Tween.TRANS_SINE)
		_tween_banner_gold.set_ease(Tween.EASE_IN_OUT)
		_tween_banner_gold.set_loops()
		_tween_banner_gold.tween_property(_banner_gold, "scale", Vector2(1.05, 1.05), 1.0)
		_tween_banner_gold.tween_property(_banner_gold, "scale", Vector2.ONE, 1.0)
	else:
		_banner_gold.scale = Vector2.ONE

# Test de punto dentro del rectangulo de la TV, pasando el toque a su espacio
# local (deshace el transform con inclinacion de _crear_banner_gold). Un
# simple radio no alcanza: la TV puede ser bastante mas grande que
# DISTANCIA_TOQUE en salas de paredes altas.
func _banner_gold_en(mundo: Vector2) -> bool:
	if not is_instance_valid(_banner_gold) or not _banner_gold.visible:
		return false
	var local := _banner_gold.transform.affine_inverse() * mundo
	return absf(local.x) <= _banner_gold_tam.x * 0.5 and absf(local.y) <= _banner_gold_tam.y * 0.5

# Gira (espeja) el mueble marcado con un pequeño "giro" de animacion y lo
# guarda. Ver WorldObject.volteado.
func _on_btn_girar_objeto_pressed() -> void:
	if not is_instance_valid(_seleccionado):
		return
	var objeto := _seleccionado

	# Se aplasta de costado, se espeja en el medio y vuelve: parece que gira.
	var tween := create_tween()
	tween.tween_property(objeto, "scale", Vector2(0.05, 1.0), 0.1)
	tween.tween_callback(func():
		objeto.volteado = not objeto.volteado
		# El rebote de seleccion usa la escala con el signo del volteo.
		objeto.set_seleccionado(true)
	)
	tween.tween_property(objeto, "scale", Vector2.ONE, 0.12)

	var id := str(objeto.get_meta("room_object_id", ""))
	if id != "":
		Supabase.update_room_object(id, {"volteado": not objeto.volteado})

# Confirma (sin reembolso, se lo avisa en el modal) y borra el objeto
# marcado: primero en la base, y solo si eso sale bien lo saca de la sala.
func _on_btn_borrar_objeto_pressed() -> void:
	if is_instance_valid(_ventana_seleccionada):
		_borrar_ventana(_ventana_seleccionada)
		return
	if not is_instance_valid(_seleccionado):
		return

	var objeto := _seleccionado
	btn_borrar_objeto.disabled = true

	var modal := ConfirmModal.crear(
		self,
		"Eliminar objeto",
		"Esto lo saca de la sala para siempre. No se te devuelve nada de lo que pagaste en la tienda.",
		"Si, eliminar"
	)
	var confirmado: bool = await modal.resuelto

	if not confirmado:
		btn_borrar_objeto.disabled = not is_instance_valid(_seleccionado)
		return

	var id := str(objeto.get_meta("room_object_id", ""))
	if id != "":
		var ok := await Supabase.delete_room_object(id)
		if not ok:
			# Se deja seleccionado para poder reintentar en vez de perderlo
			# de la sala sin haberse borrado realmente de la base.
			btn_borrar_objeto.disabled = false
			return

	_quitar_mascota(objeto)
	_objetos.erase(objeto)
	if _seleccionado == objeto:
		_seleccionado = null
	objeto.queue_free()
	# Si se borro el equipo que sonaba, toma la posta otro (si hay).
	_elegir_radio_activa()
	btn_borrar_objeto.disabled = true

func _borrar_ventana(ventana: VentanaPared) -> void:
	btn_borrar_objeto.disabled = true
	var modal := ConfirmModal.crear(
		self,
		"Eliminar ventana",
		"Esto la saca de la sala para siempre. No se te devuelve nada de lo que pagaste en la tienda.",
		"Si, eliminar"
	)
	var confirmado: bool = await modal.resuelto
	if not confirmado:
		btn_borrar_objeto.disabled = false
		return

	var id := str(ventana.get_meta("room_object_id", ""))
	if id != "" and not await Supabase.delete_room_object(id):
		btn_borrar_objeto.disabled = false
		return

	_marcar_ventana(null)
	_ventanas.erase(ventana)
	ventana.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if not editando:
		return

	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			var mundo := get_global_mouse_position()

			# La TV se arrastra distinto a un objeto de piso: solo a lo largo
			# de la pared (ver _mover_banner_gold), no libremente.
			if _banner_gold_en(mundo):
				_marcar_banner_gold_seleccionado(true)
				_banner_gold_arrastrando = true
				_arrastrando = null
				return

			_banner_gold_arrastrando = false

			# Las ventanas tambien van por la pared, como la TV.
			var ventana := _ventana_en(mundo)
			if ventana != null:
				_marcar_ventana(ventana)
				_ventana_arrastrando = ventana
				_arrastrando = null
				return

			var tocado := _objeto_en(mundo)
			# Tocar un objeto lo selecciona y arranca el arrastre en el mismo
			# gesto (como antes); tocar el piso vacio solo limpia la
			# seleccion. La marca (contorno + rebote) ya no se apaga al
			# soltar: queda "preseleccionada" hasta tocar otra cosa.
			_marcar_seleccionado(tocado)
			_arrastrando = tocado
		elif _banner_gold_arrastrando:
			_banner_gold_arrastrando = false
			_guardar_pos_banner_gold()
		elif _ventana_arrastrando != null:
			_guardar_ventana(_ventana_arrastrando)
			_ventana_arrastrando = null
		elif _arrastrando != null:
			_soltar_objeto(_arrastrando)
			_arrastrando = null
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if _banner_gold_arrastrando:
			_mover_banner_gold(get_global_mouse_position())
		elif _ventana_arrastrando != null:
			_mover_ventana(_ventana_arrastrando, get_global_mouse_position())
		elif _arrastrando != null:
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
