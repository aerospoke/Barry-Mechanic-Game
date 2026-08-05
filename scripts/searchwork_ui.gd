extends Control

@onready var btn_iniciar = $BtnIniciar
@onready var btn_precios = $BtnPrecios
@onready var btn_volver = $BtnVolver

@onready var price_list_panel = $PriceListPanel
@onready var item_container = $PriceListPanel/ScrollContainer/ItemContainer
@onready var btn_volver_precios = $PriceListPanel/BtnVolverPrecios
@onready var http_worklist = $HTTPRequestWorkList

@onready var work_select_panel = $WorkSelectPanel
@onready var status_label = $WorkSelectPanel/StatusLabel
@onready var work_item_container = $WorkSelectPanel/ScrollContainer/WorkItemContainer
@onready var btn_volver_work = $WorkSelectPanel/BtnVolverWorkSelect
@onready var http_active_work = $HTTPRequestActiveWork
@onready var http_accept_work = $HTTPRequestAcceptWork

var game_controls: Array[CanvasItem] = []
var _pending_work: Dictionary = {}

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	price_list_panel.visible = false
	work_select_panel.visible = false
	btn_iniciar.pressed.connect(_on_iniciar_pressed)
	btn_precios.pressed.connect(_on_precios_pressed)
	btn_volver.pressed.connect(_on_volver_pressed)
	btn_volver_precios.pressed.connect(_on_volver_precios_pressed)
	btn_volver_work.pressed.connect(_on_volver_work_pressed)
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

func open() -> void:
	_cache_game_controls()
	visible = true
	get_tree().paused = true
	for ctrl in game_controls:
		ctrl.visible = false

func close() -> void:
	visible = false
	price_list_panel.visible = false
	work_select_panel.visible = false
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

func _on_volver_precios_pressed() -> void:
	price_list_panel.visible = false

func _on_volver_work_pressed() -> void:
	work_select_panel.visible = false

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
	else:
		status_label.text = "Error al aceptar trabajo (%d)" % response_code
		print("Error al aceptar trabajo: %d" % response_code)

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
