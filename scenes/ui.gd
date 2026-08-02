extends Control

@onready var button_profile = $buttonProfile
@onready var fondo_oscuro = $fondoOscuro

@onready var label_nick = $fondoOscuro/PanelProfile/LabelNick
@onready var label_money = $fondoOscuro/PanelMoney/LabelNick
@onready var label_points = $fondoOscuro/PanelPoints/LabelNick

@onready var http_profile = $HTTPRequestProfile

func _ready() -> void:
	fondo_oscuro.visible = false
	button_profile.pressed.connect(_on_button_profile_pressed)
	http_profile.request_completed.connect(_on_profile_request_completed)

func _on_button_profile_pressed() -> void:
	if fondo_oscuro.visible == true:
		fondo_oscuro.visible = false
		get_tree().paused = false
	else:
		fondo_oscuro.visible = true
		get_tree().paused = true
		_fetch_profile()

func _fetch_profile() -> void:
	if not Supabase.is_logged_in():
		label_nick.text = "userName: --"
		label_money.text = "Creditos: --"
		label_points.text = "Puntos: --"
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
			label_nick.text = str(profile.get("name", ""))
			label_money.text = str(profile.get("balance", 0))
			label_points.text = str(profile.get("points", 0))
		else:
			label_nick.text = "username: Sin datos"
			label_money.text = "Creditos: Sin datos"
			label_points.text = "Puntos: Sin datos"
	else:
		label_nick.text = "Nickname: Error al cargar"
		label_money.text = "Creditos: Error al cargar"
		label_points.text = "Puntos: Error al cargar"
