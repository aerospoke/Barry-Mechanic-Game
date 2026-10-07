extends Control

const ShopCatalog = preload("res://scripts/shop_catalog.gd")

@onready var btn_iniciar = $BtnIniciar
@onready var btn_crear_sala = $BtnCrearSala
@onready var btn_tienda = $BtnTienda
@onready var btn_volver = $BtnVolver

@onready var room_panel: Control = $RoomCreatePanel
@onready var btn_mis_salas: Button = $RoomCreatePanel/BtnMisSalas
@onready var room_list_scroll: ScrollContainer = $RoomCreatePanel/RoomListScroll
@onready var room_list_container: VBoxContainer = $RoomCreatePanel/RoomListScroll/RoomListContainer
@onready var label_nombre_sala: Label = $RoomCreatePanel/LabelNombre
@onready var room_nombre_edit: LineEdit = $RoomCreatePanel/NombreEdit
@onready var label_estilo_sala: Label = $RoomCreatePanel/LabelEstilo
@onready var room_style_container: VBoxContainer = $RoomCreatePanel/StyleContainer
@onready var room_status: Label = $RoomCreatePanel/StatusRoom
@onready var btn_volver_room: Button = $RoomCreatePanel/BtnVolverRoom

@onready var http_worklist = $HTTPRequestWorkList

@onready var shop_panel: Control = $ShopPanel
@onready var shop_status: Label = $ShopPanel/StatusTienda
@onready var btn_membresia_gold: Button = $ShopPanel/BtnMembresiaGold
@onready var btn_volver_tienda: Button = $ShopPanel/BtnVolverTienda

@onready var gold_panel: Control = $GoldPanel
@onready var status_gold: Label = $GoldPanel/StatusGold
@onready var btn_comprar_gold: Button = $GoldPanel/BtnComprarGold
@onready var btn_volver_gold: Button = $GoldPanel/BtnVolverGold

@onready var work_select_panel = $WorkSelectPanel
@onready var status_label = $WorkSelectPanel/StatusLabel
@onready var work_item_container = $WorkSelectPanel/ScrollContainer/WorkItemContainer
@onready var btn_volver_work = $WorkSelectPanel/BtnVolverWorkSelect
@onready var http_active_work = $HTTPRequestActiveWork
@onready var http_accept_work = $HTTPRequestAcceptWork

var game_controls: Array[CanvasItem] = []
var _pending_work: Dictionary = {}
var _barry: Node = null

# Alto de RoomListScroll (ver searchwork_ui.tscn): al plegar "Mis salas" hay
# que subir todo lo que va debajo esta misma distancia para cerrar el hueco,
# ya que el panel usa posiciones fijas en vez de un contenedor que se
# reacomode solo.
const ALTURA_LISTA_SALAS: float = 135.0
# Arranca plegada (ver searchwork_ui.tscn: RoomListScroll ya nace invisible y
# todo lo de abajo ya nace corrido hacia arriba) para no arrancar mostrando
# una lista larga apenas se abre el panel.
var _lista_salas_colapsada: bool = true

# Cuánto se deja leer el mensaje de confirmación antes de cerrar el menú solo.
const CIERRE_AUTOMATICO: float = 1.2

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	work_select_panel.visible = false
	room_panel.visible = false
	shop_panel.visible = false
	gold_panel.visible = false
	btn_iniciar.pressed.connect(_on_iniciar_pressed)
	btn_crear_sala.pressed.connect(_on_crear_sala_pressed)
	btn_tienda.pressed.connect(_on_tienda_pressed)
	btn_volver.pressed.connect(_on_volver_pressed)
	btn_volver_room.pressed.connect(_on_volver_room_pressed)
	btn_mis_salas.pressed.connect(_on_btn_mis_salas_pressed)
	_construir_opciones_sala()
	btn_volver_work.pressed.connect(_on_volver_work_pressed)
	btn_volver_tienda.pressed.connect(_on_volver_tienda_pressed)
	_construir_carrusel()
	btn_membresia_gold.pressed.connect(_on_membresia_gold_pressed)
	btn_comprar_gold.pressed.connect(_on_comprar_gold_pressed)
	btn_volver_gold.pressed.connect(_on_volver_gold_pressed)
	http_worklist.request_completed.connect(_on_worklist_request_completed)
	http_active_work.request_completed.connect(_on_active_work_completed)
	http_accept_work.request_completed.connect(_on_accept_work_completed)

func _cache_game_controls() -> void:
	if game_controls.size() > 0:
		return
	var ui = get_parent()
	if is_instance_valid(ui):
		if ui.has_node("UI/VirtualJoystickDX"):
			game_controls.append(ui.get_node("UI/VirtualJoystickDX"))
		if ui.has_node("UI/buttonAction"):
			game_controls.append(ui.get_node("UI/buttonAction"))
		if ui.has_node("UI/buttonProfile"):
			game_controls.append(ui.get_node("UI/buttonProfile"))

# Barry no cuelga de CanvasLayer (donde vive este menú) sino de la raíz de
# room.tscn, un nivel más arriba: get_parent() acá ya devuelve CanvasLayer.
func _cache_barry() -> void:
	if is_instance_valid(_barry):
		return
	var raiz = get_parent().get_parent()
	if is_instance_valid(raiz) and raiz.has_node("Barry"):
		_barry = raiz.get_node("Barry")

func open() -> void:
	_cache_game_controls()
	_cache_barry()
	visible = true
	get_tree().paused = true
	for ctrl in game_controls:
		ctrl.visible = false

func close() -> void:
	visible = false
	work_select_panel.visible = false
	room_panel.visible = false
	shop_panel.visible = false
	gold_panel.visible = false
	get_tree().paused = false
	for ctrl in game_controls:
		ctrl.visible = true

func _on_iniciar_pressed() -> void:
	work_select_panel.visible = true
	_check_active_work()

func _on_volver_pressed() -> void:
	close()

func _on_volver_work_pressed() -> void:
	work_select_panel.visible = false

# --- Tienda ------------------------------------------------------------

func _on_tienda_pressed() -> void:
	shop_panel.visible = true
	_fetch_shop_items()

func _on_volver_tienda_pressed() -> void:
	shop_panel.visible = false

func _fetch_shop_items() -> void:
	_articulos.clear()
	_mostrar_articulo(0, 0)

	if not Supabase.is_logged_in():
		shop_status.text = "Inicia sesion para comprar repuestos"
		return

	shop_status.text = "Cargando..."
	var items := await Supabase.load_shop_items()

	# El jugador pudo cerrar el panel mientras iba la peticion.
	if not shop_panel.visible:
		return

	if items.is_empty():
		shop_status.text = "No se pudo cargar la tienda"
		return

	shop_status.text = "Saldo: $%d" % Supabase.profile_balance
	_articulos = items
	_mostrar_articulo(0, 0)

# --- Tienda: carrusel ----------------------------------------------------
# Un articulo a la vez, en grande, con flechas (o deslizando el dedo sobre la
# imagen) para pasar al siguiente. Debajo, nombre, precio, descripcion
# (shop_items.description) y el boton de comprar de ese articulo.

# El articulo ocupa casi todo el ancho y un poco mas que el circulo, asi
# "sale" del fondo. Las flechas quedan encima, a los costados.
const CARRUSEL_IMAGEN := Rect2(15, 98, 390, 350)
const SWIPE_MINIMO_TIENDA := 50.0
const DESCRIPCION_PIEZA := "Repuesto para tus trabajos. Barry lo lleva en la mano hasta el carro."
const DESCRIPCION_DECORACION := "Un estante para tu taller. Tocalo con las manos vacias para sacar repuestos gratis."

# Radio del circulo de fondo, centrado con la imagen del articulo.
const RADIO_FOCO := 165.0

var _articulos: Array = []
# Texturas ya recortadas a su parte visible (ver _recortar_visible).
var _recortes: Dictionary = {}
var _indice_articulo: int = 0
var _carrusel_imagen: TextureRect
var _carrusel_puntos: HBoxContainer
var _carrusel_nombre: Label
var _carrusel_precio: Label
var _carrusel_descripcion: Label
var _btn_comprar_articulo: Button
var _btn_anterior: Button
var _btn_siguiente: Button
var _swipe_tienda_x: float = 0.0
var _tween_carrusel: Tween

func _construir_carrusel() -> void:
	# Foco de luz detras del articulo.
	var foco := Panel.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.2, 0.17, 0.32)
	estilo.set_corner_radius_all(int(RADIO_FOCO))
	foco.add_theme_stylebox_override("panel", estilo)
	foco.position = CARRUSEL_IMAGEN.get_center() - Vector2.ONE * RADIO_FOCO
	foco.size = Vector2.ONE * RADIO_FOCO * 2.0
	foco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_panel.add_child(foco)

	_carrusel_imagen = TextureRect.new()
	_carrusel_imagen.position = CARRUSEL_IMAGEN.position
	_carrusel_imagen.size = CARRUSEL_IMAGEN.size
	_carrusel_imagen.pivot_offset = CARRUSEL_IMAGEN.size / 2.0
	_carrusel_imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_carrusel_imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_carrusel_imagen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_carrusel_imagen.mouse_filter = Control.MOUSE_FILTER_STOP
	_carrusel_imagen.gui_input.connect(_on_carrusel_input)
	shop_panel.add_child(_carrusel_imagen)

	_btn_anterior = _boton_flecha("◀", Vector2(4, 241))
	_btn_anterior.pressed.connect(func(): _mostrar_articulo(_indice_articulo - 1, -1))
	_btn_siguiente = _boton_flecha("▶", Vector2(368, 241))
	_btn_siguiente.pressed.connect(func(): _mostrar_articulo(_indice_articulo + 1, 1))

	_carrusel_puntos = HBoxContainer.new()
	_carrusel_puntos.alignment = BoxContainer.ALIGNMENT_CENTER
	_carrusel_puntos.position = Vector2(20, 454)
	_carrusel_puntos.size = Vector2(380, 14)
	_carrusel_puntos.add_theme_constant_override("separation", 8)
	shop_panel.add_child(_carrusel_puntos)

	_carrusel_nombre = _label_tienda(Vector2(20, 472), Vector2(380, 32), 24, Color.WHITE)
	_carrusel_precio = _label_tienda(Vector2(20, 503), Vector2(380, 28), 21, Color(1.0, 0.82, 0.3))
	_carrusel_descripcion = _label_tienda(Vector2(30, 534), Vector2(360, 66), 15, Color(0.82, 0.82, 0.88))
	_carrusel_descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_carrusel_descripcion.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	_btn_comprar_articulo = Button.new()
	_btn_comprar_articulo.position = Vector2(90, 604)
	_btn_comprar_articulo.size = Vector2(240, 50)
	_btn_comprar_articulo.add_theme_font_size_override("font_size", 20)
	_btn_comprar_articulo.pressed.connect(_on_comprar_articulo_pressed)
	shop_panel.add_child(_btn_comprar_articulo)

func _boton_flecha(texto: String, pos: Vector2) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.position = pos
	boton.size = Vector2(48, 64)
	boton.add_theme_font_size_override("font_size", 24)
	shop_panel.add_child(boton)
	return boton

func _label_tienda(pos: Vector2, tam: Vector2, fuente: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = tam
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", fuente)
	label.add_theme_color_override("font_color", color)
	shop_panel.add_child(label)
	return label

# Muestra el articulo `indice` (da la vuelta en los extremos). `direccion`
# (-1/1) es hacia donde se desliza la imagen; 0 = sin animacion.
func _mostrar_articulo(indice: int, direccion: int) -> void:
	var hay := not _articulos.is_empty()
	_btn_anterior.visible = _articulos.size() > 1
	_btn_siguiente.visible = _articulos.size() > 1
	_btn_comprar_articulo.visible = hay
	if not hay:
		_carrusel_imagen.texture = null
		_carrusel_nombre.text = ""
		_carrusel_precio.text = ""
		_carrusel_descripcion.text = ""
		_actualizar_puntos_carrusel()
		return

	_indice_articulo = posmod(indice, _articulos.size())
	var item: Dictionary = _articulos[_indice_articulo]
	var key := str(item.get("key", ""))
	var precio := int(item.get("price", 0))
	var es_decoracion := str(item.get("tipo", "pieza")) == "decoracion"

	# Las piezas de trabajo tienen su icono en ShopCatalog (van a la mano de
	# Barry); las decoraciones usan el catalogo que las instancia en la sala.
	var textura: Texture2D = RoomObjectCatalog.textura(key) if es_decoracion else ShopCatalog.icono_tienda(key)

	var descripcion := str(item.get("description", ""))
	if descripcion == "" or descripcion == "<null>":
		descripcion = DESCRIPCION_DECORACION if es_decoracion else DESCRIPCION_PIEZA

	_carrusel_nombre.text = str(item.get("name", key))
	_carrusel_precio.text = "$%d" % precio
	_carrusel_descripcion.text = descripcion
	_actualizar_puntos_carrusel()

	# Una decoracion no ocupa la mano de Barry, asi que esa restriccion solo
	# aplica a las piezas de trabajo.
	var ya_tiene_item: bool = not es_decoracion and is_instance_valid(_barry) and bool(_barry.tiene_item)
	if ya_tiene_item:
		_btn_comprar_articulo.text = "Manos ocupadas"
	elif precio > Supabase.profile_balance:
		_btn_comprar_articulo.text = "Saldo insuficiente"
	else:
		_btn_comprar_articulo.text = "Comprar $%d" % precio
	_btn_comprar_articulo.disabled = ya_tiene_item or precio > Supabase.profile_balance

	_animar_carrusel(_recortar_visible(textura), direccion)

# Las imagenes de los estantes traen mucho margen transparente (el mueble
# queda abajo y corrido), asi que se recortan a la parte con pixeles: el
# dibujo queda centrado de verdad dentro del circulo.
func _recortar_visible(textura: Texture2D) -> Texture2D:
	if textura == null:
		return null
	if _recortes.has(textura):
		return _recortes[textura]

	var recorte: Texture2D = textura
	var imagen := textura.get_image()
	if imagen != null:
		if imagen.is_compressed():
			imagen.decompress()
		var usado := imagen.get_used_rect()
		if usado.size.x > 0 and usado.size.y > 0:
			var atlas := AtlasTexture.new()
			atlas.atlas = textura
			atlas.region = Rect2(usado)
			recorte = atlas
	_recortes[textura] = recorte
	return recorte

# La imagen vieja sale hacia un lado y la nueva entra del otro con un rebote.
func _animar_carrusel(textura: Texture2D, direccion: int) -> void:
	if _tween_carrusel:
		_tween_carrusel.kill()
	var base := CARRUSEL_IMAGEN.position

	if direccion == 0:
		_carrusel_imagen.texture = textura
		_carrusel_imagen.position = base
		_carrusel_imagen.modulate.a = 1.0
		_carrusel_imagen.scale = Vector2.ONE
		return

	_tween_carrusel = create_tween()
	_tween_carrusel.tween_property(_carrusel_imagen, "position:x", base.x - direccion * 90.0, 0.1)
	_tween_carrusel.parallel().tween_property(_carrusel_imagen, "modulate:a", 0.0, 0.1)
	_tween_carrusel.tween_callback(func():
		_carrusel_imagen.texture = textura
		_carrusel_imagen.position.x = base.x + direccion * 90.0
		_carrusel_imagen.scale = Vector2(0.85, 0.85)
	)
	_tween_carrusel.set_trans(Tween.TRANS_BACK)
	_tween_carrusel.set_ease(Tween.EASE_OUT)
	_tween_carrusel.tween_property(_carrusel_imagen, "position:x", base.x, 0.25)
	_tween_carrusel.parallel().tween_property(_carrusel_imagen, "modulate:a", 1.0, 0.15)
	_tween_carrusel.parallel().tween_property(_carrusel_imagen, "scale", Vector2.ONE, 0.25)

func _actualizar_puntos_carrusel() -> void:
	for punto in _carrusel_puntos.get_children():
		punto.queue_free()
	for i in _articulos.size():
		var punto := ColorRect.new()
		punto.custom_minimum_size = Vector2(10, 10)
		punto.color = Color(1.0, 0.82, 0.3) if i == _indice_articulo else Color(0.4, 0.38, 0.5)
		_carrusel_puntos.add_child(punto)

# Deslizar el dedo sobre la imagen pasa de articulo.
func _on_carrusel_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		_swipe_tienda_x = event.position.x
		return
	var delta: float = event.position.x - _swipe_tienda_x
	if absf(delta) >= SWIPE_MINIMO_TIENDA:
		var direccion := -1 if delta > 0 else 1
		_mostrar_articulo(_indice_articulo + direccion, direccion)

func _on_comprar_articulo_pressed() -> void:
	if _articulos.is_empty():
		return
	var item: Dictionary = _articulos[_indice_articulo]
	_on_comprar_pressed(str(item.get("key", "")), int(item.get("price", 0)), str(item.get("tipo", "pieza")), _btn_comprar_articulo)

func _on_comprar_pressed(key: String, precio: int, tipo: String, btn: Button) -> void:
	btn.disabled = true
	shop_status.text = "Comprando..."

	var ok: bool = await Supabase.buy_item(precio)
	if not ok:
		shop_status.text = "No se pudo completar la compra"
		btn.disabled = false
		return

	if tipo == "decoracion":
		# La sala instancia el objeto y ya te deja en modo edicion para que lo
		# ubiques donde quieras: es literalmente para lo que se compró.
		var sala = get_parent().get_parent()
		if is_instance_valid(sala):
			sala.call("agregar_objeto_comprado", key)
	elif is_instance_valid(_barry):
		_barry.recibir_item_comprado(key)

	shop_status.text = "Compraste %s. Saldo: %d" % [key, Supabase.profile_balance]
	close()

# --- Membresia Gold ---------------------------------------------------------

func _on_membresia_gold_pressed() -> void:
	shop_panel.visible = false
	gold_panel.visible = true
	_actualizar_estado_gold()

func _on_volver_gold_pressed() -> void:
	gold_panel.visible = false
	shop_panel.visible = true

# Refleja si ya es Gold (bloquea el boton) o si le falta saldo, igual que las
# filas de la tienda con "ya_tiene_item"/precio > saldo.
func _actualizar_estado_gold() -> void:
	if Supabase.profile_is_gold:
		status_gold.text = "Ya sos miembro Gold. ¡Gracias!"
		btn_comprar_gold.disabled = true
		return

	btn_comprar_gold.disabled = Supabase.PRECIO_MEMBRESIA_GOLD > Supabase.profile_balance
	status_gold.text = "Saldo: %d" % Supabase.profile_balance

func _on_comprar_gold_pressed() -> void:
	btn_comprar_gold.disabled = true
	status_gold.text = "Comprando..."

	var ok: bool = await Supabase.buy_gold_membership()
	if not ok:
		status_gold.text = "No se pudo completar la compra"
		_actualizar_estado_gold()
		return

	status_gold.text = "¡Listo! Ya sos miembro Gold. Saldo: %d" % Supabase.profile_balance

	# Saca el banner de la pared ya, sin esperar a salir y volver a entrar.
	var sala = get_parent().get_parent()
	if is_instance_valid(sala) and sala.has_method("actualizar_banner_gold"):
		sala.actualizar_banner_gold()

	close()

# --- Salas -----------------------------------------------------------------

func _on_crear_sala_pressed() -> void:
	room_status.text = ""
	room_nombre_edit.text = ""
	room_panel.visible = true
	if not _lista_salas_colapsada:
		_on_btn_mis_salas_pressed()
	_refrescar_mis_salas()

# Pliega/despliega la lista de salas ya creadas. El panel usa posiciones
# fijas (no un contenedor que se reacomode solo), asi que hay que correr a
# mano todo lo que va debajo para que no quede un hueco vacio.
func _on_btn_mis_salas_pressed() -> void:
	_lista_salas_colapsada = not _lista_salas_colapsada
	room_list_scroll.visible = not _lista_salas_colapsada
	btn_mis_salas.text = ("▸ " if _lista_salas_colapsada else "▾ ") + "Mis salas"

	var delta := -ALTURA_LISTA_SALAS if _lista_salas_colapsada else ALTURA_LISTA_SALAS
	for nodo: Control in [label_nombre_sala, room_nombre_edit, label_estilo_sala, room_style_container, room_status]:
		nodo.position.y += delta

# Las salas ya creadas se listan encima de los estilos para poder volver a
# entrar sin crear una nueva cada vez.
func _refrescar_mis_salas() -> void:
	for child in room_list_container.get_children():
		child.queue_free()

	if not Supabase.is_logged_in():
		return

	await Supabase.load_rooms()

	# El jugador pudo cerrar el panel mientras iba la petición.
	if not room_panel.visible:
		return

	for sala in Supabase.rooms:
		var btn := Button.new()
		btn.custom_minimum_size.y = 45
		var estilo: Dictionary = RoomStyles.get_estilo(str(sala.get("style", "")))
		btn.text = "%s  (%s)" % [str(sala.get("name", "")), estilo["nombre"]]
		btn.pressed.connect(_on_sala_existente.bind(sala))
		room_list_container.add_child(btn)

func _on_sala_existente(sala: Dictionary) -> void:
	Supabase.current_room = sala
	_entrar_a_sala()

func _on_volver_room_pressed() -> void:
	room_panel.visible = false

# Una tarjeta por estilo, con nombre y descripción, como el selector de Habbo.
func _construir_opciones_sala() -> void:
	for id in RoomStyles.ORDEN:
		var estilo: Dictionary = RoomStyles.ESTILOS[id]

		var btn := Button.new()
		btn.custom_minimum_size.y = 80
		btn.text = "%s\n%s" % [estilo["nombre"], estilo["descripcion"]]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_color_override("font_color", estilo["suelo_a"])
		btn.pressed.connect(_on_estilo_elegido.bind(id))
		room_style_container.add_child(btn)

func _on_estilo_elegido(id: String) -> void:
	var estilo: Dictionary = RoomStyles.ESTILOS[id]
	var nombre := room_nombre_edit.text.strip_edges()
	if nombre == "":
		nombre = str(estilo["nombre"])

	room_status.text = "Creando \"%s\"..." % nombre
	_bloquear_estilos(true)

	var sala := await Supabase.create_room(nombre, id)
	if sala.is_empty():
		# Sin sesión o sin tabla `rooms`: se entra igual con una sala suelta,
		# pero no quedará guardada al cerrar el juego.
		room_status.text = "No se pudo guardar la sala; entras sin guardarla"
		sala = {"id": "", "name": nombre, "style": id, "owner": Supabase.user_id}

	_bloquear_estilos(false)

	Supabase.current_room = sala
	_entrar_a_sala()

func _bloquear_estilos(bloqueado: bool) -> void:
	for child in room_style_container.get_children():
		if child is Button:
			child.disabled = bloqueado

func _entrar_a_sala() -> void:
	# El menú deja el árbol pausado: hay que soltarlo antes de cambiar de
	# escena o la sala arranca congelada.
	visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/room.tscn")

func _check_active_work() -> void:
	for child in work_item_container.get_children():
		child.queue_free()
	status_label.text = "Cargando..."

	if not Supabase.is_logged_in():
		status_label.text = "Inicia sesion para buscar trabajo"
		return

	var endpoint = "/rest/v1/usersWorks?select=id,work,state&userId=eq." + Supabase.user_id + "&state=eq.active"
	Supabase.make_auth_request(http_active_work, endpoint, HTTPClient.METHOD_GET)

func _on_active_work_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		status_label.text = "Error al verificar trabajo activo"
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		status_label.text = "Error al leer datos"
		return

	var data = json.get_data()
	if data is Array and data.size() > 0:
		status_label.text = "Ya tienes un trabajo activo"
		return

	status_label.text = "Selecciona un trabajo:"
	_fetch_work_list_for_select()

func _fetch_work_list_for_select() -> void:
	for child in work_item_container.get_children():
		child.queue_free()

	var endpoint = "/rest/v1/WorkList?select=id,name,price,payment,points,key"
	Supabase.make_auth_request(http_worklist, endpoint, HTTPClient.METHOD_GET)

func _on_worklist_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		status_label.text = "Error al cargar trabajos"
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		status_label.text = "Error al leer datos"
		return

	var data = json.get_data()
	if not data is Array or data.size() == 0:
		status_label.text = "Sin trabajos disponibles"
		return

	for item in data:
		_add_selectable_work_row(
			str(item.get("id", "")),
			str(item.get("name", "")),
			str(item.get("payment", "")),
			str(item.get("points", "")),
			str(item.get("key", ""))
		)

func _add_selectable_work_row(work_id: String, name: String, payment: String, points: String, key: String) -> void:
	var btn = Button.new()
	btn.text = "%s  |  $%s  |  %s pts" % [name, payment, points]
	btn.custom_minimum_size.y = 50
	btn.set_meta("work_id", work_id)
	btn.set_meta("work_name", name)
	btn.set_meta("work_payment", int(payment))
	btn.set_meta("work_points", int(points))
	btn.set_meta("work_key", key)
	btn.pressed.connect(_on_work_selected.bind(btn))
	work_item_container.add_child(btn)
	print("DEBUG work_id raw: '%s' | int: %d" % [work_id, int(work_id)])

func _on_work_selected(btn: Button) -> void:
	_pending_work = {
		"work_id": btn.get_meta("work_id"),
		"work_name": btn.get_meta("work_name"),
		"work_payment": btn.get_meta("work_payment"),
		"work_points": btn.get_meta("work_points"),
		"work_key": btn.get_meta("work_key"),
	}

	status_label.text = "Aceptando trabajo..."

	# Evita que un segundo toque cree otro trabajo mientras va la petición.
	_bloquear_seleccion(true)

	Supabase.make_auth_request(http_accept_work, "/rest/v1/usersWorks", HTTPClient.METHOD_POST, {
		"userId": Supabase.user_id,
		"work": int(_pending_work["work_id"]),
		"state": "active"
	})

func _on_accept_work_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if response_code == 201 or response_code == 200:
		Supabase.active_work_id = str(_pending_work["work_id"])
		Supabase.active_work_name = str(_pending_work["work_name"])
		Supabase.active_work_key = str(_pending_work["work_key"])
		Supabase.active_work_payment = int(_pending_work["work_payment"])
		Supabase.active_work_points = int(_pending_work["work_points"])

		status_label.text = "Trabajo asignado!"
		print("Trabajo activo: %s ($%d, %d pts)" % [Supabase.active_work_name, Supabase.active_work_payment, Supabase.active_work_points])
		_cerrar_con_retardo()
	else:
		status_label.text = "Error al aceptar trabajo (%d)" % response_code
		print("Error al aceptar trabajo: %d" % response_code)
		# Falló: se devuelve el control para poder reintentar.
		_bloquear_seleccion(false)

func _bloquear_seleccion(bloqueado: bool) -> void:
	for child in work_item_container.get_children():
		if child is Button:
			child.disabled = bloqueado

func _cerrar_con_retardo() -> void:
	# El árbol está pausado con el menú abierto, así que el timer debe correr
	# igualmente (process_always = true, que es el valor por defecto).
	await get_tree().create_timer(CIERRE_AUTOMATICO).timeout

	# Si el jugador ya cerró el menú a mano no hay nada que hacer.
	if visible:
		close()
