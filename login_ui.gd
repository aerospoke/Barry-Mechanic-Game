extends Control

# --- CONFIGURACIÓN DE SUPABASE ---
const SUPABASE_URL = "https://lnjvrrggobgfawwxdjou.supabase.co"
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxuanZycmdnb2JnZmF3d3hkam91Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI3NzU1MzQsImV4cCI6MjA5ODM1MTUzNH0.SaZpfLPxmAXDAX2xyZzw-LxJm4dbEAy9hp0RITF7mW4"

# --- REFERENCIAS A LOS NODOS ---
@onready var email_input = $EmailInput
@onready var password_input = $PasswordInput
@onready var btn_login = $BtnLogin
@onready var http_request = $HTTPRequest

# Se llama cuando el nodo entra al árbol de escenas por primera vez
func _ready() -> void:
	# Conectamos las señales del botón Login y de la respuesta de Supabase por código
	btn_login.pressed.connect(_on_btn_login_pressed)
	http_request.request_completed.connect(_on_request_completed)

# Se llama cada fotograma (puedes borrar esta función si no la usas)
func _process(delta: float) -> void:
	pass

# --- NAVEGACIÓN ---
# Tu función original para ir a registrarse
func _on_btn_redirect_register_pressed() -> void:
	get_tree().change_scene_to_file("res://registro_ui.tscn")

# --- LÓGICA DE LOGIN (SUPABASE) ---
func _on_btn_login_pressed() -> void:
	var email = email_input.text
	var password = password_input.text
	
	# Validación para evitar campos vacíos
	if email == "" or password == "":
		print("Por favor, llena todos los campos.")
		return
		
	iniciar_sesion(email, password)

func iniciar_sesion(email: String, password: String) -> void:
	print("Verificando datos en Supabase...")
	
	# URL específica para validar usuarios
	var url = SUPABASE_URL + "/auth/v1/token?grant_type=password"
	
	var headers = [
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SUPABASE_ANON_KEY,
		"Content-Type: application/json"
	]
	
	var body_dict = {
		"email": email,
		"password": password
	}
	var body_json = JSON.stringify(body_dict)
	
	# Hacemos la petición
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, body_json)
	
	if error != OK:
		print("Error al intentar conectar con Supabase: ", error)

# Recibe la respuesta del servidor
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var json = JSON.new()
	var error = json.parse(body.get_string_from_utf8())
	
	if error == OK:
		var response_data = json.get_data()
		
		# 200 = Login Exitoso
		if response_code == 200:
			print("¡Login exitoso! Entrando al juego...")
			
			# ¡AQUÍ ESTÁ LA TRANSICIÓN AL JUEGO!
			# Asegúrate de poner el nombre exacto de tu escena principal (vi en tu captura que tenías una pestaña llamada "mapa")
			get_tree().change_scene_to_file("res://node_2d.tscn")
			
		else:
			print("Error en el login. Código: ", response_code)
			if response_data.has("error_description"):
				print("Motivo: ", response_data["error_description"])
	else:
		print("Error leyendo la respuesta del servidor.")
