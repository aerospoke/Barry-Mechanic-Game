extends Control

# 1. Cambiamos el nombre de la variable y el nodo para que tenga sentido
@onready var username_input = $UsernameInput 
@onready var password_input = $PasswordInput
@onready var btn_login = $BtnLogin

@onready var http_request = $HTTPRequest
@onready var http_get_email = $HTTPRequest_GetEmail

const EyeToggle = preload("res://scripts/eye_toggle.gd")

const StatusLabel = preload("res://scripts/status_label.gd")

var status_label: Label

func _ready() -> void:
	# Entre el campo de contraseña (y=490) y el botón de entrar (y=574).
	status_label = StatusLabel.crear(self, Vector2(40.0, 500.0), 340.0)
	_agregar_ojo(password_input)
	btn_login.pressed.connect(_on_btn_login_pressed)
	# Al corregir los datos se borra el error anterior, que ya no aplica.
	username_input.text_changed.connect(func(_t): status_label.limpiar())
	password_input.text_changed.connect(func(_t): status_label.limpiar())
	http_request.request_completed.connect(_on_request_completed)
	http_get_email.request_completed.connect(_on_get_email_completed)

# Coloca el botón de ojo dentro del campo, pegado al borde derecho. Se ancla
# en vez de posicionarse a mano para que siga al campo si cambia de tamaño.
func _agregar_ojo(campo: LineEdit) -> void:
	var ojo := EyeToggle.new()
	ojo.name = "EyeToggle"
	campo.add_child(ojo)

	var lado := campo.size.y * 0.8
	ojo.custom_minimum_size = Vector2(lado, lado)
	ojo.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	ojo.size = Vector2(lado, lado)
	ojo.position = Vector2(campo.size.x - lado - 6.0, (campo.size.y - lado) / 2.0)

	# Deja hueco a la derecha para que el texto no pase por debajo del ojo.
	campo.add_theme_constant_override("minimum_character_width", 0)
	var estilo := campo.get_theme_stylebox("normal").duplicate()
	if estilo is StyleBox:
		estilo.content_margin_right = lado + 10.0
		campo.add_theme_stylebox_override("normal", estilo)
		campo.add_theme_stylebox_override("focus", estilo)

func _on_btn_redirect_register_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/registro_ui.tscn")

func _on_btn_login_pressed() -> void:
	var username = username_input.text
	var password = password_input.text

	if username == "" or password == "":
		status_label.mostrar_error("Por favor, llena todos los campos.")
		return

	# Desactivamos el botón temporalmente para que el jugador no haga doble clic
	btn_login.disabled = true
	status_label.mostrar_info("Conectando...")

	# 4. NUEVO PASO: En lugar de iniciar sesión, buscamos el correo del Nick
	var error = Supabase.make_request(http_get_email, "/rest/v1/rpc/get_email_by_username", {
		"p_username": username
	})

	if error != OK:
		status_label.mostrar_error("No hay conexion. Revisa tu internet. (error %d)" % error)
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
			status_label.mostrar_error("El nombre de usuario no existe.")
			btn_login.disabled = false
	else:
		# Se muestra el cuerpo de la respuesta: ahi viene el motivo real que
		# manda Supabase (RLS, funcion inexistente, apikey invalida...).
		status_label.mostrar_error("Error %d al buscar el usuario.\n%s" % [
			response_code, body.get_string_from_utf8().strip_edges()
		])
		btn_login.disabled = false

# 6. Tu función original se queda casi intacta
func iniciar_sesion(email: String, password: String) -> void:
	var error = Supabase.make_request(http_request, "/auth/v1/token?grant_type=password", {
		"email": email,
		"password": password
	})

	if error != OK:
		status_label.mostrar_error("No se pudo conectar con el servidor. (error %d)" % error)
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
	status_label.mostrar_info("Sesion iniciada, cargando perfil...")

	# Se usa load_profile() del autoload en vez de una peticion propia: aquella
	# no traia pos_x/pos_y pero marcaba el perfil como cargado, asi que despues
	# el jugador nunca recuperaba su ultima posicion.
	if not await Supabase.load_profile():
		status_label.mostrar_error("No se pudo cargar tu perfil. Revisa las politicas RLS de SELECT en profiles.")
		return

	await Supabase.redirigir_tras_login()

func _on_login_error(msg: String) -> void:
	btn_login.disabled = false
	status_label.mostrar_error(msg)
