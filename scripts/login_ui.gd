extends Control

@onready var email_input = $EmailInput
@onready var password_input = $PasswordInput
@onready var btn_login = $BtnLogin
@onready var http_request = $HTTPRequest

func _ready() -> void:
	btn_login.pressed.connect(_on_btn_login_pressed)
	http_request.request_completed.connect(_on_request_completed)

func _on_btn_redirect_register_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/registro_ui.tscn")

func _on_btn_login_pressed() -> void:
	var email = email_input.text
	var password = password_input.text

	if email == "" or password == "":
		print("Por favor, llena todos los campos.")
		return

	iniciar_sesion(email, password)

func iniciar_sesion(email: String, password: String) -> void:
	var error = Supabase.make_request(http_request, "/auth/v1/token?grant_type=password", {
		"email": email,
		"password": password
	})

	if error != OK:
		print("Error al intentar conectar con Supabase: ", error)

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	Supabase.handle_response(
		response_code,
		body,
		Callable(self, "_on_login_success"),
		Callable(self, "_on_login_error")
	)

func _on_login_success(_data) -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_login_error(msg: String) -> void:
	print(msg)
