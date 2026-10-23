extends Control

@onready var button_profile = $buttonProfile
@onready var fondo_oscuro = $fondoOscuro

@onready var label_nick = $fondoOscuro/PanelProfile/LabelNick
@onready var label_money = $fondoOscuro/PanelMoney/LabelNick
@onready var label_points = $fondoOscuro/PanelPoints/LabelNick
@onready var label_work = $fondoOscuro/PanelWork/LabelWork
@onready var btn_editar_sala: Button = $fondoOscuro/BtnEditarSala
@onready var btn_logout: Button = $fondoOscuro/BtnLogout

@onready var button_action: TouchScreenButton = $buttonAction

const AjustesSonido = preload("res://scripts/ajustes_sonido.gd")
const Vestidor = preload("res://scripts/vestidor.gd")

@onready var http_profile = $HTTPRequestProfile
@onready var http_active_work = $HTTPRequestActiveWork

var _fetching_work_details: bool = false

# --- Icono del boton de accion ---
# Barry pide el icono segun lo que tiene cerca (PC, estante, carro, o la lupa
# si lleva una pieza para soltar; ver _icono_contextual en
# movement_script.gd) con set_icono_accion(): se cambia al marco vacio y se
# dibuja ese icono encima. Sin nada que hacer, el boton se oculta.
const BOTON_VACIO_NORMAL := preload("res://buttons_ui/buttonClean_normal.png")
const BOTON_VACIO_PRESIONADO := preload("res://buttons_ui/buttonClean_pressed.png")
# Centro de la cara del boton en pixeles de su textura (1442x1609): al
# presionarlo la cara baja, asi que el icono baja con ella.
const ICONO_CENTRO_NORMAL := Vector2(716, 684)
const ICONO_CENTRO_PRESIONADO := Vector2(716, 815)
# Lado maximo del icono, tambien en pixeles de la textura del boton.
const ICONO_LADO := 820.0

var _escala_boton: Vector2
var _posicion_boton: Vector2
var _tween_boton: Tween
# Estado logico del boton: mientras se anima la salida sigue visible, pero ya
# cuenta como oculto.
var _boton_mostrado: bool = false
var _icono_accion: Sprite2D

func _ready() -> void:
	fondo_oscuro.visible = false
	button_profile.pressed.connect(_on_button_profile_pressed)
	http_profile.request_completed.connect(_on_profile_request_completed)
	http_active_work.request_completed.connect(_on_active_work_request_completed)

	btn_editar_sala.pressed.connect(_on_btn_editar_sala_pressed)
	# Solo tiene sentido dentro de una sala (room.gd expone activar_edicion());
	# en el taller no hay nada que mover todavia.
	btn_editar_sala.visible = _raiz_editable() != null
	btn_logout.pressed.connect(_on_btn_logout_pressed)
	$fondoOscuro/BtnSonido.pressed.connect(func(): AjustesSonido.crear(self))
	$fondoOscuro/BtnVestidor.pressed.connect(_abrir_vestidor)
	_modernizar_perfil()

	_escala_boton = button_action.scale
	_posicion_boton = button_action.position
	# Arranca oculto: Barry lo muestra (con su animacion) apenas tiene algo
	# cerca, sin que se vea encogerse al entrar a la sala.
	button_action.visible = false
	_icono_accion = Sprite2D.new()
	_icono_accion.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icono_accion.position = ICONO_CENTRO_NORMAL
	_icono_accion.visible = false
	button_action.add_child(_icono_accion)
	button_action.pressed.connect(func(): _icono_accion.position = ICONO_CENTRO_PRESIONADO)
	button_action.released.connect(func(): _icono_accion.position = ICONO_CENTRO_NORMAL)

# Lo llama Barry (movement_script.gd) cuando cambia lo que tiene cerca.
# null oculta el boton: no hay nada que accionar.
func set_icono_accion(textura: Texture2D) -> void:
	if textura == null:
		if _boton_mostrado:
			_boton_mostrado = false
			_desaparecer_boton()
		return

	if not _boton_mostrado:
		_boton_mostrado = true
		_aparecer_boton()

	button_action.texture_normal = BOTON_VACIO_NORMAL
	button_action.texture_pressed = BOTON_VACIO_PRESIONADO
	_icono_accion.texture = textura
	var lado := maxf(textura.get_width(), textura.get_height())
	_icono_accion.scale = Vector2.ONE * (ICONO_LADO / lado)
	_icono_accion.visible = true

# Pequeño pop al reaparecer, para que se note que ahora hay algo que hacer.
func _aparecer_boton() -> void:
	button_action.visible = true
	button_action.modulate.a = 1.0
	_animar_tamano_boton(0.6, 1.0, Tween.EASE_OUT)

# La misma animacion al reves: se infla un toque, se achica y desaparece.
func _desaparecer_boton() -> void:
	_animar_tamano_boton(1.0, 0.6, Tween.EASE_IN)
	_tween_boton.parallel().tween_property(button_action, "modulate:a", 0.0, 0.2)
	_tween_boton.tween_callback(func():
		button_action.visible = false
		# Si se oculto mientras estaba apretado no llega el "released".
		_icono_accion.position = ICONO_CENTRO_NORMAL
	)

# El TouchScreenButton escala desde su esquina, asi que se corrige la
# posicion para que crezca y se achique desde el centro.
func _animar_tamano_boton(desde: float, hasta: float, curva: Tween.EaseType) -> void:
	if _tween_boton:
		_tween_boton.kill()
	var tam_textura := Vector2(BOTON_VACIO_NORMAL.get_size())
	_tween_boton = create_tween()
	_tween_boton.set_trans(Tween.TRANS_BACK)
	_tween_boton.set_ease(curva)
	_tween_boton.tween_method(func(f: float):
		button_action.scale = _escala_boton * f
		button_action.position = _posicion_boton + tam_textura * _escala_boton * (1.0 - f) / 2.0
	, desde, hasta, 0.2)

func _raiz_editable() -> Node:
	var raiz := get_parent().get_parent()
	if is_instance_valid(raiz) and raiz.has_method("activar_edicion"):
		return raiz
	return null

func _on_btn_editar_sala_pressed() -> void:
	var raiz := _raiz_editable()
	if raiz != null:
		raiz.activar_edicion()
	# Cierra el panel de perfil y despausa, igual que un segundo toque al
	# boton de Barry: el modo edicion necesita el juego corriendo.
	_on_button_profile_pressed()

# Panel de Barry con el mismo estilo que la computadora (EstiloUI): fondo
# morado, tarjetas de informacion a lo ancho y botones grandes. Las
# posiciones vienen de ui.tscn; aca solo se ensanchan y se estilizan.
func _modernizar_perfil() -> void:
	fondo_oscuro.theme = EstiloUI.tema()
	fondo_oscuro.color = Color(EstiloUI.FONDO, 0.97)

	var titulo := Label.new()
	titulo.text = "Barry"
	titulo.position = Vector2(30, 40)
	titulo.size = Vector2(370, 34)
	EstiloUI.titulo(titulo, 26)
	fondo_oscuro.add_child(titulo)

	var ancho := 370.0
	var y := 90.0
	for nombre in ["PanelProfile", "PanelMoney", "PanelPoints", "PanelWork"]:
		var panel: Control = fondo_oscuro.get_node(nombre)
		panel.position = Vector2(30, y)
		panel.size = Vector2(ancho, 64)
		y += 74.0
		# El titulo de cada tarjeta, mas tenue; el dato, grande.
		for hijo in panel.get_children():
			if hijo is Label:
				var es_titulo: bool = hijo.position.y < 20
				hijo.add_theme_color_override("font_color", EstiloUI.TEXTO_SUAVE if es_titulo else EstiloUI.TEXTO)
				hijo.add_theme_font_size_override("font_size", 14 if es_titulo else 18)
				hijo.size.x = ancho - hijo.position.x - 12

	y += 10.0
	for nombre in ["BtnEditarSala", "BtnVestidor", "BtnSonido", "BtnLogout"]:
		var boton: Button = fondo_oscuro.get_node(nombre)
		boton.position = Vector2(30, y)
		boton.size = Vector2(ancho, 54)
		y += 64.0
	EstiloUI.boton_primario($fondoOscuro/BtnVestidor)
	EstiloUI.boton_secundario(btn_logout)

# Cierra el panel de perfil (que pausa la sala) y abre el vestidor: asi al
# elegir traje Barry puede festejar con la sala andando.
func _abrir_vestidor() -> void:
	fondo_oscuro.visible = false
	get_tree().paused = false
	Vestidor.crear(self)

func _on_btn_logout_pressed() -> void:
	Supabase.clear_session()
	# El panel de perfil pausa el arbol al abrirse; hay que despausar antes de
	# cambiar de escena o el login arranca congelado.
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/login_ui.tscn")

func _on_button_profile_pressed() -> void:
	if fondo_oscuro.visible == true:
		fondo_oscuro.visible = false
		get_tree().paused = false
	else:
		fondo_oscuro.visible = true
		get_tree().paused = true
		if Supabase.profile_loaded:
			_show_cached_profile()
		else:
			_fetch_profile()
		_fetch_active_work()

func _show_cached_profile() -> void:
	label_nick.text = str(Supabase.profile_name)
	label_money.text = str(Supabase.profile_balance)
	label_points.text = _texto_puntos()
	_show_active_work()

# "120 pts · Nivel 4 Tecnico (faltan 20)": los puntos con lo que significan.
func _texto_puntos() -> String:
	var puntos := Supabase.profile_points
	var nivel := Economia.nivel(puntos)
	var texto := "%d pts · Nivel %d %s" % [puntos, nivel, Economia.nombre_nivel(nivel)]
	if not Economia.es_nivel_maximo(nivel):
		texto += " (faltan %d)" % (Economia.rango_nivel(puntos).y - puntos)
	return texto

func _show_active_work() -> void:
	if Supabase.active_work_name != "":
		label_work.text = Supabase.active_work_name
	else:
		label_work.text = "Sin trabajo activo"

func _fetch_profile() -> void:
	if not Supabase.is_logged_in():
		label_nick.text = "userName: --"
		label_money.text = "Creditos: --"
		label_points.text = "Puntos: --"
		label_work.text = "Sin trabajo activo"
		return

	label_nick.text = "Cargando..."
	label_money.text = "Cargando..."
	label_points.text = "Cargando..."

	var endpoint = "/rest/v1/profiles?id=eq." + Supabase.user_id + "&select=name,balance,points"
	var error = Supabase.make_auth_request(http_profile, endpoint, HTTPClient.METHOD_GET)

	if error != OK:
		label_nick.text = "userName: Error"
		label_money.text = "Creditos: Error"
		label_points.text = "Puntos: Error"

func _on_profile_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var json = JSON.new()
		var parse_error = json.parse(body.get_string_from_utf8())
		if parse_error != OK:
			label_nick.text = "userName: Error"
			label_money.text = "Creditos: Error"
			label_points.text = "Puntos: Error"
			return

		var data = json.get_data()
		if data is Array and data.size() > 0:
			var profile = data[0]
			Supabase.profile_name = str(profile.get("name", ""))
			Supabase.profile_balance = int(profile.get("balance", 0))
			Supabase.profile_points = int(profile.get("points", 0))
			Supabase.profile_loaded = true
			_show_cached_profile()
		else:
			label_nick.text = "username: Sin datos"
			label_money.text = "Creditos: Sin datos"
			label_points.text = "Puntos: Sin datos"
	else:
		label_nick.text = "Nickname: Error al cargar"
		label_money.text = "Creditos: Error al cargar"
		label_points.text = "Puntos: Error al cargar"

func _fetch_active_work() -> void:
	if not Supabase.is_logged_in():
		label_work.text = "Sin trabajo activo"
		return

	label_work.text = "Cargando..."
	_fetching_work_details = false
	var endpoint = "/rest/v1/usersWorks?select=work,state&userId=eq." + Supabase.user_id + "&state=eq.active"
	Supabase.make_auth_request(http_active_work, endpoint, HTTPClient.METHOD_GET)

func _on_active_work_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		label_work.text = "Error al cargar trabajo (%d)" % response_code
		_fetching_work_details = false
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		label_work.text = "Sin trabajo activo"
		return

	var data = json.get_data()
	if not data is Array or data.size() == 0:
		if not _fetching_work_details:
			Supabase.active_work_id = ""
			Supabase.active_work_name = ""
			Supabase.active_work_key = ""
			Supabase.active_work_payment = 0
			Supabase.active_work_points = 0
			label_work.text = "Sin trabajo activo"
		return

	if _fetching_work_details:
		var work = data[0]
		Supabase.active_work_name = str(work.get("name", ""))
		Supabase.active_work_key = str(work.get("key", ""))
		Supabase.active_work_payment = int(work.get("payment", 0))
		Supabase.active_work_points = int(work.get("points", 0))
		Supabase.active_work_nivel = int(work.get("nivel_minimo", 1) if work.get("nivel_minimo") != null else 1)
		_show_active_work()
	else:
		var work_id = int(data[0].get("work", 0))
		if work_id == 0:
			label_work.text = "Sin trabajo activo"
			return
		Supabase.active_work_id = str(work_id)
		_fetching_work_details = true
		# select=*: trae tambien nivel_minimo (ver sql/economia.sql) sin romper
		# si la columna todavia no existe.
		var endpoint = "/rest/v1/WorkList?id=eq." + str(work_id) + "&select=*"
		Supabase.make_auth_request(http_active_work, endpoint, HTTPClient.METHOD_GET)
