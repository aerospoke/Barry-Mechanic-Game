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

# Última posición conocida del jugador en el mapa. Vive en el autoload, así que
# sobrevive a los cambios de escena (ir a un minijuego y volver) además de
# persistirse en el perfil para recuperarla al reiniciar sesión.
var player_pos: Vector2 = Vector2.ZERO
var has_player_pos: bool = false

# El tutorial del taller se muestra una vez por sesión. Vive aquí y no en la
# escena porque main.tscn se recrea cada vez que se vuelve de un minijuego, y
# repetir la explicación en cada regreso sería insoportable.
var tutorial_taller_visto: bool = false

# Salas creadas por el jugador (estilo Habbo). Se guardan en la tabla `rooms`
# (ver sql/rooms.sql); aquí vive la copia en memoria porque la sala es una
# escena aparte del taller y al entrar necesita saber qué estilo construir.
# Solo se persiste nombre y estilo: la geometría la genera room_styles.gd.
var rooms: Array = []
var current_room: Dictionary = {}

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
	player_pos = Vector2.ZERO
	has_player_pos = false
	tutorial_taller_visto = false
	rooms = []
	current_room = {}

func _request_sync(endpoint: String, method: int, body_dict: Dictionary = {}, extra_headers: PackedStringArray = []) -> Array:
	var http := HTTPRequest.new()
	# Los menús de la PC pausan el árbol mientras están abiertos. Un HTTPRequest
	# que herede ese modo no avanza nunca y la petición se queda colgada, así
	# que se marca para que corra igualmente.
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http)
	var headers := get_auth_headers()
	for h in extra_headers:
		headers.append(h)
	var body_json = JSON.stringify(body_dict) if not body_dict.is_empty() else ""
	var err = http.request(SUPABASE_URL + endpoint, headers, method, body_json)
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

# Carga el perfil (saldo, puntos y última posición) desde la base de datos.
# Solo golpea la red la primera vez salvo que se fuerce con recargar.
func load_profile(recargar: bool = false) -> bool:
	if profile_loaded and not recargar:
		return true
	if not is_logged_in():
		return false

	var res = await _request_sync(
		"/rest/v1/profiles?id=eq." + user_id + "&select=name,balance,points,pos_x,pos_y",
		HTTPClient.METHOD_GET
	)
	if res[0] != 200 or not res[1] is Array or res[1].is_empty():
		push_error("No se pudo cargar el perfil (%d)" % res[0])
		return false

	var profile = res[1][0]
	profile_name = str(profile.get("name", ""))
	profile_balance = int(profile.get("balance", 0))
	profile_points = int(profile.get("points", 0))

	# pos_x/pos_y son NULL hasta la primera partida guardada: en ese caso el
	# jugador debe aparecer donde lo ponga la escena, no en (0,0).
	var px = profile.get("pos_x")
	var py = profile.get("pos_y")
	if px != null and py != null:
		player_pos = Vector2(float(px), float(py))
		has_player_pos = true

	profile_loaded = true
	return true

# Guarda la posición del jugador en memoria y la persiste en el perfil.
func save_player_position(pos: Vector2) -> bool:
	player_pos = pos
	has_player_pos = true

	if not is_logged_in():
		return false

	# Se pide la fila de vuelta (return=representation) porque un PATCH que RLS
	# filtra responde 204 igualmente, sin haber escrito nada: sin esto un fallo
	# de permisos es indistinguible de un guardado correcto.
	var res = await _request_sync(
		"/rest/v1/profiles?id=eq." + user_id,
		HTTPClient.METHOD_PATCH,
		{"pos_x": pos.x, "pos_y": pos.y},
		["Prefer: return=representation"]
	)

	return _update_ok(res, "No se pudo guardar la posicion")

# Valida la respuesta de un PATCH que pidió return=representation: además del
# código HTTP comprueba que de verdad se modificó alguna fila.
func _update_ok(res: Array, contexto: String) -> bool:
	if res[0] != 200 and res[0] != 204:
		push_error("%s (HTTP %d)" % [contexto, res[0]])
		return false
	if not res[1] is Array or res[1].is_empty():
		push_error("%s: 0 filas afectadas (revisa las politicas RLS)" % contexto)
		return false
	return true

# Marca el trabajo activo como completado y abona pago + puntos al perfil.
# El minijuego puede sumar un bono por precisión, o restar (bono negativo) si
# el jugador se pasó. El saldo nunca baja de cero.
func complete_active_work(bono_pago: int = 0, bono_puntos: int = 0) -> bool:
	if not is_logged_in() or active_work_name == "":
		work_completed.emit(false, 0, 0)
		return false

	var payment := active_work_payment + bono_pago
	var points := active_work_points + bono_puntos

	if not await load_profile():
		work_completed.emit(false, 0, 0)
		return false

	# Igual que al guardar la posición: se pide la fila de vuelta para poder
	# distinguir un update real de uno que RLS filtró (ambos responden 204).
	var work_res = await _request_sync(
		"/rest/v1/usersWorks?userId=eq." + user_id + "&state=eq.active",
		HTTPClient.METHOD_PATCH,
		{"state": "completed"},
		["Prefer: return=representation"]
	)
	if not _update_ok(work_res, "No se pudo cerrar el trabajo"):
		work_completed.emit(false, 0, 0)
		return false

	var pay_res = await _request_sync(
		"/rest/v1/profiles?id=eq." + user_id,
		HTTPClient.METHOD_PATCH,
		{
			"balance": max(0, profile_balance + payment),
			"points": max(0, profile_points + points),
		},
		["Prefer: return=representation"]
	)
	if not _update_ok(pay_res, "No se pudo pagar el trabajo"):
		work_completed.emit(false, 0, 0)
		return false

	# Mismo clamp que se mandó al servidor, si no la copia local se desincroniza.
	profile_balance = max(0, profile_balance + payment)
	profile_points = max(0, profile_points + points)
	active_work_id = ""
	active_work_name = ""
	active_work_payment = 0
	active_work_points = 0

	work_completed.emit(true, payment, points)
	return true

# --- Salas -----------------------------------------------------------------

# Crea una sala y devuelve la fila guardada, o {} si falló. Se pide la fila de
# vuelta para quedarse con el id que genera la base de datos.
func create_room(nombre: String, estilo: String) -> Dictionary:
	if not is_logged_in():
		return {}

	var res = await _request_sync(
		"/rest/v1/rooms",
		HTTPClient.METHOD_POST,
		{"owner": user_id, "name": nombre, "style": estilo},
		["Prefer: return=representation"]
	)
	if res[0] != 201 and res[0] != 200:
		push_error("No se pudo crear la sala (HTTP %d)" % res[0])
		return {}
	if not res[1] is Array or res[1].is_empty():
		push_error("La sala no se guardo: 0 filas (revisa las politicas RLS)")
		return {}

	var sala: Dictionary = res[1][0]
	rooms.append(sala)
	return sala

# Recarga las salas del jugador desde la base de datos.
func load_rooms() -> bool:
	if not is_logged_in():
		return false

	var res = await _request_sync(
		"/rest/v1/rooms?owner=eq." + user_id + "&select=id,name,style,created_at&order=created_at.desc",
		HTTPClient.METHOD_GET
	)
	if res[0] != 200 or not res[1] is Array:
		push_error("No se pudieron cargar las salas (HTTP %d)" % res[0])
		return false

	rooms = res[1]
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
