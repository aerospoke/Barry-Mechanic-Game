extends Control

# 1. Cambiamos el nombre de la variable y el nodo para que tenga sentido
@onready var username_input = $UsernameInput 
@onready var password_input = $PasswordInput
@onready var btn_login = $BtnLogin
@onready var btn_registro: Button = $BtnRedirectRegister
@onready var tarjeta: Panel = $Tarjeta
@onready var titulo: Label = $Titulo

@onready var http_request = $HTTPRequest
@onready var http_get_email = $HTTPRequest_GetEmail

const EyeToggle = preload("res://scripts/eye_toggle.gd")

const StatusLabel = preload("res://scripts/status_label.gd")

var status_label: Label

# Mismos colores que la tienda (searchwork_ui) y los modales.
const COLOR_FONDO := Color(0.1, 0.08, 0.18)
const COLOR_TARJETA := Color(0.15, 0.13, 0.25)
const COLOR_CAMPO := Color(0.08, 0.07, 0.14)
const COLOR_BORDE := Color(0.32, 0.28, 0.45)
const COLOR_DORADO := Color(1.0, 0.82, 0.3)
const COLOR_TEXTO := Color(0.92, 0.92, 0.96)
const COLOR_TEXTO_SUAVE := Color(0.7, 0.68, 0.8)

func _ready() -> void:
	_aplicar_estilos()
	# Entre el campo de contraseña (termina en y=510) y el botón (y=576).
	status_label = StatusLabel.crear(self, Vector2(40.0, 512.0), 340.0)
	_agregar_ojo(password_input)

	# Precarga de datos para pruebas rapidas. Sacar antes de compartir/subir
	# el proyecto a algun lado publico.
	username_input.text = "aerospoke"
	password_input.text = "202020"
	btn_login.pressed.connect(_on_btn_login_pressed)
	# Al corregir los datos se borra el error anterior, que ya no aplica.
	username_input.text_changed.connect(func(_t): status_label.limpiar())
	password_input.text_changed.connect(func(_t): status_label.limpiar())
	http_request.request_completed.connect(_on_request_completed)
	http_get_email.request_completed.connect(_on_get_email_completed)

# --- Estilo -------------------------------------------------------------------

func _aplicar_estilos() -> void:

	tarjeta.add_theme_stylebox_override("panel", _caja(COLOR_TARJETA, COLOR_BORDE, 18, 2))

	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", COLOR_DORADO)

	for label in [$"Label - username", $"Label - password"]:
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", COLOR_TEXTO_SUAVE)

	for campo in [username_input, password_input]:
		var normal := _caja(COLOR_CAMPO, COLOR_BORDE, 12, 2)
		normal.content_margin_left = 14
		normal.content_margin_right = 14
		var foco: StyleBoxFlat = normal.duplicate()
		foco.border_color = COLOR_DORADO
		campo.add_theme_stylebox_override("normal", normal)
		campo.add_theme_stylebox_override("focus", foco)
		campo.add_theme_font_size_override("font_size", 18)
		campo.add_theme_color_override("font_color", COLOR_TEXTO)
		campo.add_theme_color_override("font_placeholder_color", Color(COLOR_TEXTO_SUAVE, 0.5))
		campo.add_theme_color_override("caret_color", COLOR_DORADO)

	# Boton principal: dorado con texto oscuro, se oscurece al apretarlo.
	btn_login.add_theme_stylebox_override("normal", _caja(COLOR_DORADO, COLOR_DORADO.darkened(0.3), 14, 0, 4))
	btn_login.add_theme_stylebox_override("hover", _caja(COLOR_DORADO.lightened(0.1), COLOR_DORADO.darkened(0.3), 14, 0, 4))
	btn_login.add_theme_stylebox_override("pressed", _caja(COLOR_DORADO.darkened(0.15), COLOR_DORADO.darkened(0.3), 14, 0, 1))
	btn_login.add_theme_stylebox_override("disabled", _caja(COLOR_DORADO.darkened(0.45), COLOR_DORADO.darkened(0.5), 14, 0, 4))
	btn_login.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for estado in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn_login.add_theme_color_override(estado, Color(0.15, 0.1, 0.05))
	btn_login.add_theme_font_size_override("font_size", 21)

	# Registro: enlace de texto, sin caja.
	for estado in ["normal", "hover", "pressed", "focus"]:
		btn_registro.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
	btn_registro.add_theme_color_override("font_color", COLOR_TEXTO_SUAVE)
	btn_registro.add_theme_color_override("font_hover_color", COLOR_DORADO)
	btn_registro.add_theme_color_override("font_pressed_color", COLOR_DORADO)
	btn_registro.add_theme_font_size_override("font_size", 16)

func _caja(fondo: Color, borde: Color, radio: int, grosor_borde: int, sombra_abajo: int = 0) -> StyleBoxFlat:
	var caja := StyleBoxFlat.new()
	caja.bg_color = fondo
	caja.border_color = borde
	caja.set_border_width_all(grosor_borde)
	if sombra_abajo > 0:
		# "Borde" grueso solo abajo: da relieve de boton apretable.
		caja.border_width_bottom = sombra_abajo
		caja.border_color = borde
	caja.set_corner_radius_all(radio)
	caja.content_margin_top = 8
	caja.content_margin_bottom = 8
	return caja

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
	# Cada estado por separado, para no perder el borde dorado del foco.
	for estado in ["normal", "focus"]:
		var estilo: StyleBox = campo.get_theme_stylebox(estado).duplicate()
		estilo.content_margin_right = lado + 10.0
		campo.add_theme_stylebox_override(estado, estilo)

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

	# Se usa load_profile() del autoload (en vez de una peticion propia) porque
	# marca el perfil como cargado, asi profile_balance/profile_points ya
	# quedan listos para cuando la sala los necesite.
	if not await Supabase.load_profile():
		status_label.mostrar_error("No se pudo cargar tu perfil. Revisa las politicas RLS de SELECT en profiles.")
		return

	await Supabase.redirigir_tras_login()

func _on_login_error(msg: String) -> void:
	btn_login.disabled = false
	status_label.mostrar_error(msg)
