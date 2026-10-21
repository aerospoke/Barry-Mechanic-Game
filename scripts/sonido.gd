extends Node

# Autoload "Sonido": efectos, musica y volumen de todo el juego.
#
#   Sonido.efecto("moneda")          # un efecto de res://sonidos/<nombre>.wav
#   Sonido.efecto("click", 1.2)      # con otro tono (pitch)
#
# - La musica cambia sola segun la escena (ver MUSICA_POR_ESCENA): no hay
#   que llamarla desde cada pantalla.
# - Todos los botones del juego suenan solos al tocarlos (ver _on_node_added).
# - El volumen de musica y efectos se guarda en user://ajustes.cfg y se
#   cambia desde el panel de ajustes (scripts/ajustes_sonido.gd).
#
# Los sonidos se generan con herramientas_dev/generar_sonidos.py.

const CARPETA := "res://sonidos/"
const ARCHIVO_AJUSTES := "user://ajustes.cfg"

# Escena (o prefijo de ruta) -> musica. La primera que coincide gana.
# Cada minijuego tiene su cancion; todo lo demas (sala, login, tienda) usa
# la del taller.
const MUSICA_POR_ESCENA := [
	["res://scenes/miniGameOil", "musica_aceite"],
	["res://scenes/miniGameKeys", "musica_cerradura"],
	["res://scenes/miniGameFilter", "musica_filtro"],
	["res://scenes/miniGameCables", "musica_cables"],
	["res://scenes/miniGameHerramientas", "musica_herramientas"],
	["res://scenes/miniGameInflar", "musica_inflar"],
	["res://scenes/miniGamePintura", "musica_pintura"],
	["res://scenes/miniGameReciclaje", "musica_reciclaje"],
	# En la sala la musica sale del equipo de sonido (ver radio_equipo.gd),
	# no de aca: "" = sin musica global.
	["res://scenes/room", ""],
	# Login y registro, en silencio.
	["res://scenes/login_ui", ""],
	["res://scenes/registro_ui", ""],
	["res://scenes/", "musica_taller"],
]

# Canales simultaneos de efectos: si suenan mas a la vez, se pisa el mas viejo.
const CANALES := 8
const BUS_MUSICA := "Musica"
const BUS_EFECTOS := "Efectos"

# Emisoras del equipo de sonido de la sala (ver radio_equipo.gd y
# radio_panel.gd), una por genero: que cada quien encuentre la suya. Varias
# son tambien las canciones de los minijuegos.
const EMISORAS := [
	{"id": "musica_taller", "genero": "Reggaeton", "nombre": "Perreo del Taller"},
	{"id": "musica_tropipop", "genero": "Tropipop", "nombre": "Tropical del Garaje"},
	{"id": "musica_kpop", "genero": "K-pop", "nombre": "Seul Turbo"},
	{"id": "musica_reggae", "genero": "Reggae", "nombre": "Good Vibes Mecanico"},
	{"id": "musica_dancehall", "genero": "Dancehall", "nombre": "Riddim del Motor"},
	{"id": "musica_cumbia", "genero": "Cumbia", "nombre": "Cumbia de la Llave"},
	{"id": "musica_salsa", "genero": "Salsa", "nombre": "Salsa con Tuercas"},
	{"id": "musica_bachata", "genero": "Bachata", "nombre": "Bachata Bajo el Capo"},
	{"id": "musica_trap", "genero": "Trap", "nombre": "Trap del Turbo"},
	{"id": "musica_afro", "genero": "Afrobeats", "nombre": "Afro Piston"},
	{"id": "musica_aceite", "genero": "Funk", "nombre": "Funk Aceitoso"},
	{"id": "musica_filtro", "genero": "Rock", "nombre": "Rock de Garaje"},
	{"id": "musica_cables", "genero": "Electronica", "nombre": "Electro Circuito"},
	{"id": "musica_herramientas", "genero": "Lo-fi", "nombre": "Lo-fi del Banco"},
	{"id": "musica_pintura", "genero": "Jazz", "nombre": "Jazz de Pintura"},
]

# Avisa al equipo de sonido que se prendio/apago o cambio de emisora.
signal radio_cambio

var radio_encendida: bool = true
# Modo aleatorio: al terminar cada cancion el equipo salta a otro genero al
# azar (ver radio_equipo.gd).
var radio_aleatorio: bool = false
var emisora: int = 0

var volumen_musica: float = 0.45
# Por defecto los efectos van bajitos (20%): la musica manda. Si el jugador
# los cambia, se respeta lo que eligio (ver _efectos_elegidos).
var volumen_efectos: float = 0.2
# true cuando el jugador movio el volumen de efectos alguna vez. Hasta
# entonces siempre se usa el valor por defecto, aunque haya ajustes viejos
# guardados (antes se guardaba 0.8 aunque nunca lo hubiera tocado).
var _efectos_elegidos: bool = false

var _canales: Array[AudioStreamPlayer] = []
var _siguiente_canal: int = 0
var _musica: AudioStreamPlayer
var _musica_actual: String = ""
var _escena_actual: Node = null
var _cache: Dictionary = {}

func _ready() -> void:
	# Suena aunque el arbol este pausado (menus de la PC, modales).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_crear_bus(BUS_MUSICA)
	_crear_bus(BUS_EFECTOS)

	for i in CANALES:
		var canal := AudioStreamPlayer.new()
		canal.bus = BUS_EFECTOS
		add_child(canal)
		_canales.append(canal)

	_musica = AudioStreamPlayer.new()
	_musica.bus = BUS_MUSICA
	add_child(_musica)

	_cargar_ajustes()
	get_tree().node_added.connect(_on_node_added)

# Buses creados por codigo (en vez de un default_bus_layout.tres) para que
# todo el audio viva en este archivo.
func _crear_bus(nombre: String) -> void:
	if AudioServer.get_bus_index(nombre) != -1:
		return
	AudioServer.add_bus()
	var indice := AudioServer.bus_count - 1
	AudioServer.set_bus_name(indice, nombre)
	AudioServer.set_bus_send(indice, "Master")

func _process(_delta: float) -> void:
	# Cambio de escena: elegir la musica que le toca.
	var escena := get_tree().current_scene
	if escena != _escena_actual and escena != null:
		_escena_actual = escena
		_musica_para(escena.scene_file_path)

# --- Efectos -----------------------------------------------------------------

func efecto(nombre: String, tono: float = 1.0, volumen_db: float = 0.0) -> void:
	var stream := _cargar(nombre)
	if stream == null:
		return
	var canal := _canales[_siguiente_canal]
	_siguiente_canal = (_siguiente_canal + 1) % CANALES
	canal.stream = stream
	canal.pitch_scale = tono
	canal.volume_db = volumen_db
	canal.play()

# Efecto con una leve variacion de tono al azar: los sonidos repetidos (gotas,
# clicks) suenan mas vivos y menos "maquina".
func efecto_variado(nombre: String, variacion: float = 0.08) -> void:
	efecto(nombre, randf_range(1.0 - variacion, 1.0 + variacion))

func _cargar(nombre: String) -> AudioStream:
	if _cache.has(nombre):
		return _cache[nombre]
	var ruta := CARPETA + nombre + ".wav"
	var stream: AudioStream = load(ruta) if ResourceLoader.exists(ruta) else null
	if stream == null:
		push_warning("Sonido no encontrado: " + ruta)
	_cache[nombre] = stream
	return stream

# --- Musica ------------------------------------------------------------------

func _musica_para(ruta_escena: String) -> void:
	for regla in MUSICA_POR_ESCENA:
		if ruta_escena.begins_with(regla[0]):
			musica(regla[1])
			return

# Cancion lista para repetirse en loop (la usa tambien el equipo de sonido).
func stream_musica(nombre: String) -> AudioStream:
	var stream := _cargar(nombre)
	if stream is AudioStreamWAV:
		# Los WAV generados no traen el loop marcado: se marca aca.
		var wav: AudioStreamWAV = stream
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	return stream

func musica(nombre: String) -> void:
	if nombre == _musica_actual:
		return
	_musica_actual = nombre
	var stream: AudioStream = stream_musica(nombre) if nombre != "" else null

	# Fundido corto entre una musica y otra.
	var tween := create_tween()
	if _musica.playing:
		tween.tween_property(_musica, "volume_db", -40.0, 0.4)
	tween.tween_callback(func():
		_musica.stream = stream
		_musica.volume_db = -40.0
		if stream != null:
			_musica.play()
		else:
			_musica.stop()
	)
	tween.tween_property(_musica, "volume_db", 0.0, 0.6)

# --- Equipo de sonido ---------------------------------------------------------

func emisora_actual() -> Dictionary:
	return EMISORAS[emisora]

func radio_alternar() -> void:
	radio_encendida = not radio_encendida
	_guardar_ajustes()
	radio_cambio.emit()

func radio_alternar_aleatorio() -> void:
	radio_aleatorio = not radio_aleatorio
	_guardar_ajustes()
	radio_cambio.emit()

# Otra emisora al azar (nunca la misma que esta sonando).
func radio_al_azar() -> void:
	var otra := randi() % (EMISORAS.size() - 1)
	if otra >= emisora:
		otra += 1
	radio_elegir(otra)

# Salta directo a una emisora (botones de genero del panel).
func radio_elegir(indice: int) -> void:
	emisora = clampi(indice, 0, EMISORAS.size() - 1)
	radio_encendida = true
	_guardar_ajustes()
	radio_cambio.emit()

func radio_cambiar(paso: int) -> void:
	emisora = posmod(emisora + paso, EMISORAS.size())
	radio_encendida = true
	_guardar_ajustes()
	radio_cambio.emit()

# --- Botones -----------------------------------------------------------------

# Cualquier boton que aparezca en el arbol suena al tocarlo, sin tener que
# conectarlo a mano en cada pantalla.
func _on_node_added(nodo: Node) -> void:
	if nodo is BaseButton:
		nodo.pressed.connect(_sonar_boton)
	elif nodo is TouchScreenButton and nodo.action == "":
		# Los TouchScreenButton con accion (el boton de accion de la sala, el
		# de verter del aceite...) no hacen "blip": la accion ya tiene su
		# propio sonido (agarrar, soltar...) y los dos juntos chirriaban.
		nodo.pressed.connect(_sonar_boton)

func _sonar_boton() -> void:
	efecto("boton", randf_range(0.95, 1.05), -4.0)

# --- Volumen -----------------------------------------------------------------

func set_volumen_musica(valor: float) -> void:
	volumen_musica = clampf(valor, 0.0, 1.0)
	_aplicar_volumen(BUS_MUSICA, volumen_musica)
	_guardar_ajustes()

func set_volumen_efectos(valor: float) -> void:
	volumen_efectos = clampf(valor, 0.0, 1.0)
	_efectos_elegidos = true
	_aplicar_volumen(BUS_EFECTOS, volumen_efectos)
	_guardar_ajustes()

func _aplicar_volumen(bus: String, valor: float) -> void:
	var indice := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(indice, valor <= 0.001)
	AudioServer.set_bus_volume_db(indice, linear_to_db(maxf(valor, 0.001)))

func _cargar_ajustes() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ARCHIVO_AJUSTES) == OK:
		volumen_musica = float(cfg.get_value("sonido", "musica", volumen_musica))
		_efectos_elegidos = bool(cfg.get_value("sonido", "efectos_elegidos", false))
		if _efectos_elegidos:
			volumen_efectos = float(cfg.get_value("sonido", "efectos", volumen_efectos))
		radio_encendida = bool(cfg.get_value("radio", "encendida", radio_encendida))
		radio_aleatorio = bool(cfg.get_value("radio", "aleatorio", radio_aleatorio))
		emisora = clampi(int(cfg.get_value("radio", "emisora", emisora)), 0, EMISORAS.size() - 1)
	_aplicar_volumen(BUS_MUSICA, volumen_musica)
	_aplicar_volumen(BUS_EFECTOS, volumen_efectos)

func _guardar_ajustes() -> void:
	var cfg := ConfigFile.new()
	cfg.load(ARCHIVO_AJUSTES)
	cfg.set_value("sonido", "musica", volumen_musica)
	cfg.set_value("sonido", "efectos", volumen_efectos)
	cfg.set_value("sonido", "efectos_elegidos", _efectos_elegidos)
	cfg.set_value("radio", "encendida", radio_encendida)
	cfg.set_value("radio", "aleatorio", radio_aleatorio)
	cfg.set_value("radio", "emisora", emisora)
	cfg.save(ARCHIVO_AJUSTES)
