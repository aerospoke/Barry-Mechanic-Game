extends Control

@onready var button_profile = $buttonProfile
@onready var fondo_oscuro = $fondoOscuro

@onready var label_nick = $fondoOscuro/PanelProfile/LabelNick
@onready var label_money = $fondoOscuro/PanelMoney/LabelNick
@onready var label_points = $fondoOscuro/PanelPoints/LabelNick
@onready var label_work = $fondoOscuro/PanelWork/LabelWork

@onready var http_profile = $HTTPRequestProfile
@onready var http_active_work = $HTTPRequestActiveWork

var _fetching_work_details: bool = false

func _ready() -> void:
	fondo_oscuro.visible = false
	button_profile.pressed.connect(_on_button_profile_pressed)
	http_profile.request_completed.connect(_on_profile_request_completed)
	http_active_work.request_completed.connect(_on_active_work_request_completed)

func _on_button_profile_pressed() -> void:
	if fondo_oscuro.visible == true:
		fondo_oscuro.visible = false
		get_tree().paused = false
	else:
		fondo_oscuro.visible = true
		get_tree().paused = true
		if Supabase.profile_loaded:
			_show_cached_profile()
		else:
			_fetch_profile()
		_fetch_active_work()

func _show_cached_profile() -> void:
	label_nick.text = str(Supabase.profile_name)
	label_money.text = str(Supabase.profile_balance)
	label_points.text = str(Supabase.profile_points)
	_show_active_work()

func _show_active_work() -> void:
	if Supabase.active_work_name != "":
		label_work.text = Supabase.active_work_name
	else:
		label_work.text = "Sin trabajo activo"

func _fetch_profile() -> void:
	if not Supabase.is_logged_in():
		label_nick.text = "userName: --"
		label_money.text = "Creditos: --"
		label_points.text = "Puntos: --"
		label_work.text = "Sin trabajo activo"
		return

	label_nick.text = "Cargando..."
	label_money.text = "Cargando..."
	label_points.text = "Cargando..."

	var endpoint = "/rest/v1/profiles?id=eq." + Supabase.user_id + "&select=name,balance,points"
	var error = Supabase.make_auth_request(http_profile, endpoint, HTTPClient.METHOD_GET)

	if error != OK:
		label_nick.text = "userName: Error"
		label_money.text = "Creditos: Error"
		label_points.text = "Puntos: Error"

func _on_profile_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var json = JSON.new()
		var parse_error = json.parse(body.get_string_from_utf8())
		if parse_error != OK:
			label_nick.text = "userName: Error"
			label_money.text = "Creditos: Error"
			label_points.text = "Puntos: Error"
			return

		var data = json.get_data()
		if data is Array and data.size() > 0:
			var profile = data[0]
			Supabase.profile_name = str(profile.get("name", ""))
			Supabase.profile_balance = int(profile.get("balance", 0))
			Supabase.profile_points = int(profile.get("points", 0))
			Supabase.profile_loaded = true
			_show_cached_profile()
		else:
			label_nick.text = "username: Sin datos"
			label_money.text = "Creditos: Sin datos"
			label_points.text = "Puntos: Sin datos"
	else:
		label_nick.text = "Nickname: Error al cargar"
		label_money.text = "Creditos: Error al cargar"
		label_points.text = "Puntos: Error al cargar"

func _fetch_active_work() -> void:
	if not Supabase.is_logged_in():
		label_work.text = "Sin trabajo activo"
		return

	label_work.text = "Cargando..."
	_fetching_work_details = false
	var endpoint = "/rest/v1/usersWorks?select=work,state&userId=eq." + Supabase.user_id + "&state=eq.active"
	Supabase.make_auth_request(http_active_work, endpoint, HTTPClient.METHOD_GET)

func _on_active_work_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		label_work.text = "Error al cargar trabajo (%d)" % response_code
		_fetching_work_details = false
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		label_work.text = "Sin trabajo activo"
		return

	var data = json.get_data()
	if not data is Array or data.size() == 0:
		if not _fetching_work_details:
			Supabase.active_work_id = ""
			Supabase.active_work_name = ""
			Supabase.active_work_payment = 0
			Supabase.active_work_points = 0
			label_work.text = "Sin trabajo activo"
		return

	if _fetching_work_details:
		var work = data[0]
		Supabase.active_work_name = str(work.get("name", ""))
		Supabase.active_work_payment = int(work.get("payment", 0))
		Supabase.active_work_points = int(work.get("points", 0))
		_show_active_work()
	else:
		var work_id = int(data[0].get("work", 0))
		if work_id == 0:
			label_work.text = "Sin trabajo activo"
			return
		Supabase.active_work_id = str(work_id)
		_fetching_work_details = true
		var endpoint = "/rest/v1/WorkList?id=eq." + str(work_id) + "&select=name,payment,points"
		Supabase.make_auth_request(http_active_work, endpoint, HTTPClient.METHOD_GET)
