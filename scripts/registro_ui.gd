extends Control

@onready var email_input = $EmailInput
@onready var password_input = $PasswordInput
@onready var btn_registrar = $BtnRegistrar
@onready var http_request = $HTTPRequest
@onready var username_input = $userNameInput

const StatusLabel = preload("res://scripts/status_label.gd")

var status: Label

func _ready() -> void:
	# Debajo del campo de contraseña (y=598) y encima de los botones (y=670).
	status = StatusLabel.crear(self, Vector2(40.0, 606.0), 340.0)

	btn_registrar.pressed.connect(_on_btn_registrar_pressed)
	http_request.request_completed.connect(_on_request_completed)

	for campo in [email_input, password_input, username_input]:
		campo.text_changed.connect(func(_t): status.limpiar())

func _on_btn_registrar_pressed() -> void:
	var email = email_input.text
	var password = password_input.text
	var userName = username_input.text

	# Se actualizó la validación para asegurar que el userName tampoco esté vacío
	if email == "" or password == "" or userName == "":
		status.mostrar_error("Por favor, llena todos los campos.")
		return

	# Supabase rechaza contraseñas cortas con un 422; avisar antes evita el
	# viaje al servidor y da un mensaje más claro.
	if password.length() < 6:
		status.mostrar_error("La contrasena debe tener al menos 6 caracteres.")
		return

	if not email.contains("@") or not email.contains("."):
		status.mostrar_error("El correo no parece valido.")
		return

	btn_registrar.disabled = true
	status.mostrar_info("Creando cuenta...")

	# Se pasa el userName a la función de registro
	registrar_usuario(email, password, userName)

func registrar_usuario(email: String, password: String, userName: String) -> void:
	# Se agregó el campo "data" con el "name" para los metadatos de Supabase
	var error = Supabase.make_request(http_request, "/auth/v1/signup", {
		"email": email,
		"password": password,
		"data": {
			"name": userName
		}
	})

	if error != OK:
		status.mostrar_error("No se pudo conectar con el servidor. (error %d)" % error)
		btn_registrar.disabled = false

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	Supabase.handle_response(
		response_code,
		body,
		Callable(self, "_on_register_success"),
		Callable(self, "_on_register_error")
	)

func _on_register_success(_data) -> void:
	status.mostrar_ok("Registro exitoso! Redirigiendo...")
	await get_tree().create_timer(1.2).timeout
	get_tree().change_scene_to_file("res://scenes/login_ui.tscn")

func _on_register_error(msg: String) -> void:
	btn_registrar.disabled = false
	status.mostrar_error(msg)

func _on_btn_redirect_login_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/login_ui.tscn")
