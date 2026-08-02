extends Control

# 1. Cambiamos el nombre de la variable y el nodo para que tenga sentido
@onready var username_input = $UsernameInput 
@onready var password_input = $PasswordInput
@onready var btn_login = $BtnLogin

@onready var http_request = $HTTPRequest
@onready var http_get_email = $HTTPRequest_GetEmail 
@onready var http_profile = $HTTPRequest_Profile

func _ready() -> void:
	btn_login.pressed.connect(_on_btn_login_pressed)
	http_request.request_completed.connect(_on_request_completed)
	http_get_email.request_completed.connect(_on_get_email_completed)
	http_profile.request_completed.connect(_on_profile_completed)

func _on_btn_redirect_register_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/registro_ui.tscn")

func _on_btn_login_pressed() -> void:
	var username = username_input.text
	var password = password_input.text

	if username == "" or password == "":
		print("Por favor, llena todos los campos.")
		return

	# Desactivamos el botón temporalmente para que el jugador no haga doble clic
	btn_login.disabled = true 

	# 4. NUEVO PASO: En lugar de iniciar sesión, buscamos el correo del Nick
	var error = Supabase.make_request(http_get_email, "/rest/v1/rpc/get_email_by_username", {
		"p_username": username
	})

	if error != OK:
		print("Error al intentar conectar con la base de datos.")
		btn_login.disabled = false

# 5. NUEVA FUNCIÓN: Recibe el correo oculto desde Supabase
func _on_get_email_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var body_string = body.get_string_from_utf8()
		var email = body_string.replace('"', "").strip_edges()
		
		# Si encontramos un correo válido, llamamos a tu función original
		if email != "" and email != "null":
			iniciar_sesion(email, password_input.text)
		else:
			print("Error: El nombre de usuario no existe.")
			btn_login.disabled = false
	else:
		print("Error en el servidor al buscar el usuario.")
		btn_login.disabled = false

# 6. Tu función original se queda casi intacta
func iniciar_sesion(email: String, password: String) -> void:
	var error = Supabase.make_request(http_request, "/auth/v1/token?grant_type=password", {
		"email": email,
		"password": password
	})

	if error != OK:
		print("Error al intentar conectar con Supabase: ", error)
		btn_login.disabled = false

# Las respuestas finales se quedan exactamente igual que en tu código
func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	Supabase.handle_response(
		response_code,
		body,
		Callable(self, "_on_login_success"),
		Callable(self, "_on_login_error")
	)

func _on_login_success(data) -> void:
	btn_login.disabled = false
	Supabase.set_session(data)
	_fetch_profile_on_login()

func _fetch_profile_on_login() -> void:
	var endpoint = "/rest/v1/profiles?id=eq." + Supabase.user_id + "&select=name,balance,points"
	Supabase.make_auth_request(http_profile, endpoint, HTTPClient.METHOD_GET)

func _on_profile_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var json = JSON.new()
		json.parse(body.get_string_from_utf8())
		var data = json.get_data()
		if data is Array and data.size() > 0:
			var profile = data[0]
			Supabase.profile_name = str(profile.get("name", ""))
			Supabase.profile_balance = int(profile.get("balance", 0))
			Supabase.profile_points = int(profile.get("points", 0))
			Supabase.profile_loaded = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_login_error(msg: String) -> void:
	btn_login.disabled = false
	print(msg)
