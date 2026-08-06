extends Node

const SUPABASE_URL = "https://lnjvrrggobgfawwxdjou.supabase.co"
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxuanZycmdnb2JnZmF3d3hkam91Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI3NzU1MzQsImV4cCI6MjA5ODM1MTUzNH0.SaZpfLPxmAXDAX2xyZzw-LxJm4dbEAy9hp0RITF7mW4"

var access_token: String = ""
var user_id: String = ""
var user_email: String = ""

var profile_name: String = ""
var profile_balance: int = 0
var profile_points: int = 0
var profile_loaded: bool = false

var active_work_id: String = ""
var active_work_name: String = ""
var active_work_points: int = 0
var active_work_payment: int = 0

signal work_completed(success: bool, payment: int, points: int)

func is_logged_in() -> bool:
	return access_token != ""

func get_headers() -> PackedStringArray:
	return [
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SUPABASE_ANON_KEY,
		"Content-Type: application/json"
	]

func get_auth_headers() -> PackedStringArray:
	return [
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json"
	]

func make_request(http_request: HTTPRequest, endpoint: String, body_dict: Dictionary) -> int:
	var url = SUPABASE_URL + endpoint
	var body_json = JSON.stringify(body_dict)
	return http_request.request(url, get_headers(), HTTPClient.METHOD_POST, body_json)

func make_auth_request(http_request: HTTPRequest, endpoint: String, method: int, body_dict: Dictionary = {}) -> int:
	var url = SUPABASE_URL + endpoint
	var body_json = JSON.stringify(body_dict) if not body_dict.is_empty() else ""
	return http_request.request(url, get_auth_headers(), method, body_json)

func set_session(data: Dictionary) -> void:
	access_token = data.get("access_token", "")
	var user = data.get("user", {})
	user_id = user.get("id", "")
	user_email = user.get("email", "")

func clear_session() -> void:
	access_token = ""
	user_id = ""
	user_email = ""
	profile_name = ""
	profile_balance = 0
	profile_points = 0
	profile_loaded = false
	active_work_id = ""
	active_work_name = ""
	active_work_points = 0
	active_work_payment = 0

func _request_sync(endpoint: String, method: int, body_dict: Dictionary = {}) -> Array:
	var http := HTTPRequest.new()
	add_child(http)
	var err = make_auth_request(http, endpoint, method, body_dict)
	if err != OK:
		http.queue_free()
		return [0, null]
	var result = await http.request_completed
	http.queue_free()

	var response_code: int = result[1]
	var body: PackedByteArray = result[3]
	var json = JSON.new()
	var data = null
	if json.parse(body.get_string_from_utf8()) == OK:
		data = json.get_data()
	return [response_code, data]

# Marca el trabajo activo como completado y abona pago + puntos al perfil.
func complete_active_work() -> bool:
	if not is_logged_in() or active_work_name == "":
		work_completed.emit(false, 0, 0)
		return false

	var payment := active_work_payment
	var points := active_work_points

	if not profile_loaded:
		var profile_res = await _request_sync(
			"/rest/v1/profiles?id=eq." + user_id + "&select=name,balance,points",
			HTTPClient.METHOD_GET
		)
		if profile_res[0] != 200 or not profile_res[1] is Array or profile_res[1].is_empty():
			work_completed.emit(false, 0, 0)
			return false
		var profile = profile_res[1][0]
		profile_name = str(profile.get("name", ""))
		profile_balance = int(profile.get("balance", 0))
		profile_points = int(profile.get("points", 0))
		profile_loaded = true

	var work_res = await _request_sync(
		"/rest/v1/usersWorks?userId=eq." + user_id + "&state=eq.active",
		HTTPClient.METHOD_PATCH,
		{"state": "completed"}
	)
	if work_res[0] != 200 and work_res[0] != 204:
		push_error("No se pudo cerrar el trabajo (%d)" % work_res[0])
		work_completed.emit(false, 0, 0)
		return false

	var pay_res = await _request_sync(
		"/rest/v1/profiles?id=eq." + user_id,
		HTTPClient.METHOD_PATCH,
		{"balance": profile_balance + payment, "points": profile_points + points}
	)
	if pay_res[0] != 200 and pay_res[0] != 204:
		push_error("No se pudo pagar el trabajo (%d)" % pay_res[0])
		work_completed.emit(false, 0, 0)
		return false

	profile_balance += payment
	profile_points += points
	active_work_id = ""
	active_work_name = ""
	active_work_payment = 0
	active_work_points = 0

	work_completed.emit(true, payment, points)
	return true

func handle_response(response_code: int, body: PackedByteArray, success_callable: Callable, error_callable: Callable) -> void:
	var json = JSON.new()
	var error = json.parse(body.get_string_from_utf8())

	if error != OK:
		if error_callable.is_valid():
			error_callable.call("Error parseando la respuesta del servidor.")
		return

	var response_data = json.get_data()

	if response_code == 200 or response_code == 201:
		if success_callable.is_valid():
			success_callable.call(response_data)
	else:
		var msg = "Error en la peticion. Codigo: %d" % response_code
		if response_data is Dictionary:
			if response_data.has("error_description"):
				msg += " - " + response_data["error_description"]
			elif response_data.has("msg"):
				msg += " - " + response_data["msg"]
		if error_callable.is_valid():
			error_callable.call(msg)
