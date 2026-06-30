extends Control

# --- CONFIGURACIÓN DE SUPABASE ---
const SUPABASE_URL = "https://lnjvrrggobgfawwxdjou.supabase.co"
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxuanZycmdnb2JnZmF3d3hkam91Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI3NzU1MzQsImV4cCI6MjA5ODM1MTUzNH0.SaZpfLPxmAXDAX2xyZzw-LxJm4dbEAy9hp0RITF7mW4" # <-- ¡Pega aquí tu clave anon/public!

@onready var email_input = $EmailInput
@onready var password_input = $PasswordInput
@onready var btn_registrar = $BtnRegistrar
@onready var http_request = $HTTPRequest

func _ready():
	# Conectamos las señales por código
	btn_registrar.pressed.connect(_on_btn_registrar_pressed)
	http_request.request_completed.connect(_on_request_completed)

func _on_btn_registrar_pressed():
	var email = email_input.text
	var password = password_input.text
	
	if email == "" or password == "":
		print("Por favor, llena todos los campos.")
		return
		
	registrar_usuario(email, password)

func registrar_usuario(email: String, password: String):
	print("Enviando datos a Supabase...")
	
	var url = SUPABASE_URL + "/auth/v1/signup"
	
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
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, body_json)
	
	if error != OK:
		print("Error al intentar conectar con Supabase: ", error)

func _on_request_completed(result, response_code, headers, body):
	var json = JSON.new()
	var error = json.parse(body.get_string_from_utf8())
	
	if error == OK:
		var response_data = json.get_data()
		if response_code == 200 or response_code == 201:
			print("¡Registro exitoso en la base de datos!")
			print("Respuesta: ", response_data)
		else:
			print("Error en el registro. Código: ", response_code)
			if response_data.has("msg"):
				print("Motivo: ", response_data["msg"])
	else:
		print("Error leyendo la respuesta del servidor.")
