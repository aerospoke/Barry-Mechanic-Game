extends Control

@onready var email_input = $EmailInput
@onready var password_input = $PasswordInput
@onready var btn_registrar = $BtnRegistrar
@onready var http_request = $HTTPRequest

func _ready() -> void:
	btn_registrar.pressed.connect(_on_btn_registrar_pressed)
	http_request.request_completed.connect(_on_request_completed)

func _on_btn_registrar_pressed() -> void:
	var email = email_input.text
	var password = password_input.text

	if email == "" or password == "":
		print("Por favor, llena todos los campos.")
		return

	registrar_usuario(email, password)

func registrar_usuario(email: String, password: String) -> void:
	var error = Supabase.make_request(http_request, "/auth/v1/signup", {
		"email": email,
		"password": password
	})

	if error != OK:
		print("Error al intentar conectar con Supabase: ", error)

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	Supabase.handle_response(
		response_code,
		body,
		Callable(self, "_on_register_success"),
		Callable(self, "_on_register_error")
	)

func _on_register_success(_data) -> void:
	print("Registro exitoso, redirigiendo al login...")
	get_tree().change_scene_to_file("res://scenes/login_ui.tscn")

func _on_register_error(msg: String) -> void:
	print(msg)

func _on_btn_redirect_login_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/login_ui.tscn")
