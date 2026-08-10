extends Control

const ShopCatalog = preload("res://scripts/shop_catalog.gd")

@onready var btn_iniciar = $BtnIniciar
@onready var btn_precios = $BtnPrecios
@onready var btn_crear_sala = $BtnCrearSala
@onready var btn_tienda = $BtnTienda
@onready var btn_taller = $BtnTaller
@onready var btn_volver = $BtnVolver

@onready var room_panel: Control = $RoomCreatePanel
@onready var room_nombre_edit: LineEdit = $RoomCreatePanel/NombreEdit
@onready var room_style_container: VBoxContainer = $RoomCreatePanel/StyleContainer
@onready var room_list_container: VBoxContainer = $RoomCreatePanel/RoomListScroll/RoomListContainer
@onready var room_status: Label = $RoomCreatePanel/StatusRoom
@onready var btn_volver_room: Button = $RoomCreatePanel/BtnVolverRoom

@onready var price_list_panel = $PriceListPanel
@onready var item_container = $PriceListPanel/ScrollContainer/ItemContainer
@onready var btn_volver_precios = $PriceListPanel/BtnVolverPrecios
@onready var http_worklist = $HTTPRequestWorkList

@onready var shop_panel: Control = $ShopPanel
@onready var shop_status: Label = $ShopPanel/StatusTienda
@onready var shop_item_container: VBoxContainer = $ShopPanel/ScrollContainer/ItemContainer
@onready var btn_volver_tienda: Button = $ShopPanel/BtnVolverTienda

@onready var work_select_panel = $WorkSelectPanel
@onready var status_label = $WorkSelectPanel/StatusLabel
@onready var work_item_container = $WorkSelectPanel/ScrollContainer/WorkItemContainer
@onready var btn_volver_work = $WorkSelectPanel/BtnVolverWorkSelect
@onready var http_active_work = $HTTPRequestActiveWork
@onready var http_accept_work = $HTTPRequestAcceptWork

var game_controls: Array[CanvasItem] = []
var _pending_work: Dictionary = {}
var _barry: Node = null

# Cuánto se deja leer el mensaje de confirmación antes de cerrar el menú solo.
const CIERRE_AUTOMATICO: float = 1.2

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	price_list_panel.visible = false
	work_select_panel.visible = false
	room_panel.visible = false
	shop_panel.visible = false
	btn_iniciar.pressed.connect(_on_iniciar_pressed)
	btn_precios.pressed.connect(_on_precios_pressed)
	btn_crear_sala.pressed.connect(_on_crear_sala_pressed)
	btn_tienda.pressed.connect(_on_tienda_pressed)
	btn_taller.pressed.connect(_on_taller_pressed)
	# En el taller ya estamos ahi: el boton solo tiene sentido dentro de una sala.
	btn_taller.visible = not get_parent().get_parent().has_node("Taller")
	btn_volver.pressed.connect(_on_volver_pressed)
	btn_volver_room.pressed.connect(_on_volver_room_pressed)
	_construir_opciones_sala()
	btn_volver_precios.pressed.connect(_on_volver_precios_pressed)
	btn_volver_work.pressed.connect(_on_volver_work_pressed)
	btn_volver_tienda.pressed.connect(_on_volver_tienda_pressed)
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
# main.tscn, un nivel más arriba: get_parent() acá ya devuelve CanvasLayer.
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
	price_list_panel.visible = false
	work_select_panel.visible = false
	room_panel.visible = false
	shop_panel.visible = false
	get_tree().paused = false
	for ctrl in game_controls:
		ctrl.visible = true

func _on_iniciar_pressed() -> void:
	work_select_panel.visible = true
	_check_active_work()

func _on_precios_pressed() -> void:
	price_list_panel.visible = true
	_fetch_work_list()

func _on_volver_pressed() -> void:
	close()

# Unica forma de salir de una sala: no hay boton de "Salir" en la escena, se
# navega siempre desde la PC.
func _on_taller_pressed() -> void:
	visible = false
	get_tree().paused = false
	Supabase.current_room = {}
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_volver_precios_pressed() -> void:
	price_list_panel.visible = false

func _on_volver_work_pressed() -> void:
	work_select_panel.visible = false

# --- Tienda ------------------------------------------------------------

func _on_tienda_pressed() -> void:
	shop_panel.visible = true
	_fetch_shop_items()

func _on_volver_tienda_pressed() -> void:
	shop_panel.visible = false

func _fetch_shop_items() -> void:
	for child in shop_item_container.get_children():
		child.queue_free()

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

	shop_status.text = "Saldo: %d" % Supabase.profile_balance
	for item in items:
		_add_shop_row(item)

func _add_shop_row(item: Dictionary) -> void:
	var key := str(item.get("key", ""))
	var precio := int(item.get("price", 0))

	var fila := HBoxContainer.new()
	fila.custom_minimum_size.y = 60

	var icono := TextureRect.new()
	icono.texture = ShopCatalog.icono_tienda(key)
	icono.custom_minimum_size = Vector2(48, 48)
	icono.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fila.add_child(icono)

	var lbl_nombre := Label.new()
	lbl_nombre.text = str(item.get("name", key))
	lbl_nombre.custom_minimum_size.x = 150
	fila.add_child(lbl_nombre)

	var lbl_precio := Label.new()
	lbl_precio.text = "$%d" % precio
	lbl_precio.custom_minimum_size.x = 60
	fila.add_child(lbl_precio)

	var btn := Button.new()
	btn.text = "Comprar"
	var ya_tiene_item: bool = is_instance_valid(_barry) and bool(_barry.tiene_item)
	btn.disabled = ya_tiene_item or precio > Supabase.profile_balance
	btn.pressed.connect(_on_comprar_pressed.bind(key, precio, btn))
	fila.add_child(btn)

	shop_item_container.add_child(fila)

func _on_comprar_pressed(key: String, precio: int, btn: Button) -> void:
	btn.disabled = true
	shop_status.text = "Comprando..."

	var ok: bool = await Supabase.buy_item(precio)
	if not ok:
		shop_status.text = "No se pudo completar la compra"
		btn.disabled = false
		return

	if is_instance_valid(_barry):
		_barry.recibir_item_comprado(key)

	shop_status.text = "Compraste %s. Saldo: %d" % [key, Supabase.profile_balance]
	close()

# --- Salas -----------------------------------------------------------------

func _on_crear_sala_pressed() -> void:
	room_status.text = ""
	room_nombre_edit.text = ""
	room_panel.visible = true
	_refrescar_mis_salas()

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

	var endpoint = "/rest/v1/WorkList?select=id,name,price,payment,points"
	Supabase.make_auth_request(http_worklist, endpoint, HTTPClient.METHOD_GET)

func _on_worklist_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_add_error_row("Error al cargar: %d" % response_code)
		status_label.text = "Error al cargar trabajos"
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_add_error_row("Error al leer datos")
		status_label.text = "Error al leer datos"
		return

	var data = json.get_data()
	if not data is Array or data.size() == 0:
		_add_error_row("Sin trabajos disponibles")
		status_label.text = "Sin trabajos disponibles"
		return

	if work_select_panel.visible:
		for item in data:
			_add_selectable_work_row(
				str(item.get("id", "")),
				str(item.get("name", "")),
				str(item.get("payment", "")),
				str(item.get("points", ""))
			)
	else:
		for item in data:
			_add_work_row(
				str(item.get("name", "")),
				str(item.get("price", "")),
				str(item.get("payment", "")),
				str(item.get("points", ""))
			)

func _add_selectable_work_row(work_id: String, name: String, payment: String, points: String) -> void:
	var btn = Button.new()
	btn.text = "%s  |  $%s  |  %s pts" % [name, payment, points]
	btn.custom_minimum_size.y = 50
	btn.set_meta("work_id", work_id)
	btn.set_meta("work_name", name)
	btn.set_meta("work_payment", int(payment))
	btn.set_meta("work_points", int(points))
	btn.pressed.connect(_on_work_selected.bind(btn))
	work_item_container.add_child(btn)
	print("DEBUG work_id raw: '%s' | int: %d" % [work_id, int(work_id)])

func _on_work_selected(btn: Button) -> void:
	_pending_work = {
		"work_id": btn.get_meta("work_id"),
		"work_name": btn.get_meta("work_name"),
		"work_payment": btn.get_meta("work_payment"),
		"work_points": btn.get_meta("work_points"),
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

func _fetch_work_list() -> void:
	for child in item_container.get_children():
		child.queue_free()

	if not Supabase.is_logged_in():
		_add_error_row("Inicia sesion para ver precios")
		return

	Supabase.make_auth_request(http_worklist, "/rest/v1/WorkList?select=name,price,payment,points", HTTPClient.METHOD_GET)

func _add_work_row(name: String, price: String, payment: String, points: String) -> void:
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size.y = 40

	var lbl_name = Label.new()
	lbl_name.text = name
	lbl_name.custom_minimum_size.x = 120
	hbox.add_child(lbl_name)

	var lbl_price = Label.new()
	lbl_price.text = "$" + price
	lbl_price.custom_minimum_size.x = 70
	hbox.add_child(lbl_price)

	var lbl_payment = Label.new()
	lbl_payment.text = "$" + payment
	lbl_payment.custom_minimum_size.x = 70
	hbox.add_child(lbl_payment)

	var lbl_points = Label.new()
	lbl_points.text = points + " pts"
	lbl_points.custom_minimum_size.x = 70
	hbox.add_child(lbl_points)

	item_container.add_child(hbox)

func _add_error_row(msg: String) -> void:
	var lbl = Label.new()
	lbl.text = msg
	item_container.add_child(lbl)
