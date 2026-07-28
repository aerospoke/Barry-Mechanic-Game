extends Node

const SUPABASE_URL = "https://lnjvrrggobgfawwxdjou.supabase.co"
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxuanZycmdnb2JnZmF3d3hkam91Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI3NzU1MzQsImV4cCI6MjA5ODM1MTUzNH0.SaZpfLPxmAXDAX2xyZzw-LxJm4dbEAy9hp0RITF7mW4"

var access_token: String = ""
var user_id: String = ""
var user_email: String = ""

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
