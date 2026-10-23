extends CharacterBody2D

const SPEED = 310.0

const ShopCatalog = preload("res://scripts/shop_catalog.gd")

# Minijuego que se abre al llevar cada item al motor, y codigo exacto que
# debe tener el trabajo activo (columna WorkList.key, ver sql/worklist_key.sql)
# para que ese minijuego sea el correcto.
const MINIGAMES = {
	"oils": {"escena": "res://scenes/miniGameOil.tscn", "clave": "change_oil"},
	"keys": {"escena": "res://scenes/miniGameKeys.tscn", "clave": "key_fix"},
	"filters": {"escena": "res://scenes/miniGameFilter.tscn", "clave": "change_air_filter"},
	"cables": {"escena": "res://scenes/miniGameCables.tscn", "clave": "electric_fix"},
	"tools": {"escena": "res://scenes/miniGameHerramientas.tscn", "clave": "organize_tools"},
	"air": {"escena": "res://scenes/miniGameInflar.tscn", "clave": "inflate_tires"},
	"paint": {"escena": "res://scenes/miniGamePintura.tscn", "clave": "paint_job"},
}

const TutorialModal = preload("res://scripts/tutorial_modal.gd")
const Efectos = preload("res://scripts/efectos.gd")
# Icono del boton de accion cerca de un estante: agarrar la pieza.
const ICONO_AGARRAR := preload("res://objetos/mano.png")
# Icono del boton de accion cerca de la PC: usar la computadora.
const ICONO_PC := preload("res://objetos/network.png")
# Minijuego que se abre al interactuar con una caneca llena.
const ESCENA_RECICLAJE := "res://scenes/miniGameReciclaje.tscn"

# Icono del boton de accion junto al equipo de sonido.
const ICONO_RADIO := preload("res://objetos/radio.png")

# Icono del boton de accion junto a una caneca llena.
const ICONO_RECICLAR := preload("res://objetos/reciclaje.png")

# Icono con una pieza en la mano y nada cerca: el boton la suelta.
const ICONO_LUPA := preload("res://objetos/lupa.png")

# Explicación de la sala al entrar por primera vez en la sesión. Toda escena
# jugable es una sala (no existe un "taller" aparte), así que esto se muestra
# siempre, sin condicion de en cual estas.
const TUTORIAL_BIENVENIDA := [
	{
		"titulo": "Bienvenido",
		"texto": "Esta es tu sala. Muevete con el joystick de la izquierda.\n\nEl boton de accion sirve para todo: hablar con la PC, agarrar repuestos y empezar los trabajos.",
	},
	{
		"titulo": "El boton de Barry",
		"texto": "Arriba tienes el boton con la cara de Barry.\n\nAhi ves tu dinero, tu experiencia y cual es el trabajo que tienes activo. Si te pierdes, revisalo.",
	},
	{
		"titulo": "La computadora",
		"texto": "Acercate a la PC y pulsa accion para ver los precios y aceptar un trabajo.\n\nSolo puedes tener un trabajo activo a la vez.",
	},
	{
		"titulo": "La tienda",
		"texto": "En la PC tambien puedes comprar repuestos: aceites, filtros, bombillos y cerraduras.\n\nCompra el que pide tu trabajo: te descuenta el precio del saldo y Barry lo lleva en la mano. Pulsa accion para soltarlo.",
	},
	{
		"titulo": "El carro",
		"texto": "Con el repuesto en la mano, acercate al carro y pulsa accion para empezar el trabajo.\n\nAl terminarlo te pagan y sumas puntos.",
	},
]

# El origen de Barry esta en sus pies (centro de CollisionPlayer en
# barry.tscn): la sala ordena por profundidad con ese punto.
var tiene_item: bool = false
# Avisa con item_en_mano_cambiado al agarrar o soltar algo (ver room.gd,
# que deja de resaltar el estante cuando Barry ya tiene la pieza del trabajo).
var item_en_mano: String = "":
	set(value):
		if value == item_en_mano:
			return
		item_en_mano = value
		item_en_mano_cambiado.emit()

signal item_en_mano_cambiado
var en_search_work: bool = false
var en_work_zone: bool = false

# Key de la pieza que se puede agarrar gratis del estante en el que esta
# parado Barry ahora mismo (ver RoomObjectCatalog.pieza_gratis), o "" si no
# hay ninguno cerca.
var en_pieza_gratis: String = ""

# Parado junto a una caneca (ver RoomObjectCatalog "reciclaje"). Solo hace
# algo si esta llena (Supabase.basura_llena()).
var en_reciclaje: bool = false

# Guacal de la mascota junto al que esta parado Barry (o null): tocarlo abre
# "Elige la mascota del taller" (ver room.gd abrir_selector_mascota).
var en_guacal: Area2D = null
# Junto al equipo de sonido: tocarlo abre el panel de la musica.
var en_radio: bool = false
# Junto a un objeto que se toca (luz, bandera...), o null.
var en_accion: Area2D = null
var _iconos_mascota: Dictionary = {}

# Boton de accion de la UI (CanvasLayer/UI en room.tscn) y el icono que se
# le pidio por ultima vez, para avisarle solo cuando cambia.
var ui: Node = null
var _icono_accion: Texture2D = null
# El primer null tambien hay que mandarlo (para ocultar el boton al entrar).
var _icono_inicializado: bool = false

# Congela al jugador mientras el modal de bienvenida está en pantalla.
var _en_tutorial: bool = false

@onready var animation = $MovementPlayer
@onready var item_hand = $ItemHandsPlayer

# Lo cachea room.tscn (CanvasLayer/SearchWorkUI) para poder abrir el menu de
# la PC desde interactuar().
var searchwork_ui: Node = null

# Respiracion en reposo: escala y posicion originales del sprite, y un reloj.
var _escala_sprite: Vector2
var _posicion_sprite: Vector2
var _respiro: float = 0.0
var _festejando: bool = false
# Mitad del alto de un cuadro de la hoja de sprites (256 px).
const MEDIO_CUADRO := 128.0

func _ready() -> void:
	_escala_sprite = animation.scale
	_posicion_sprite = animation.position
	aplicar_traje()
	Supabase.traje_cambio.connect(aplicar_traje)
	_festejar_si_toca()

	var padre := get_parent()
	if padre.has_node("CanvasLayer/SearchWorkUI"):
		searchwork_ui = padre.get_node("CanvasLayer/SearchWorkUI")
	if padre.has_node("CanvasLayer/UI"):
		ui = padre.get_node("CanvasLayer/UI")

	_mostrar_tutorial_bienvenida()

# Lo llama room.gd (via call(): movement_script.gd no tiene class_name, y de
# tenerlo tipado igual el chequeo estatico de GDScript no encontraria este
# metodo en CharacterBody2D) al instanciar un objeto que necesita interaccion
# (la PC, el auto, un estante). Los objetos se cargan de forma asincrona
# despues de que la sala ya esta lista, asi que la conexion se hace a mano en
# vez de escanear InteractionZone en _ready(). Un objeto puramente decorativo
# no matchea ninguna rama y no queda conectado a nada.
func conectar_objeto(objeto: Area2D) -> void:
	if objeto.name == "SearchWork":
		objeto.body_entered.connect(_on_search_work_entered.bind(objeto))
		objeto.body_exited.connect(_on_search_work_exited.bind(objeto))
	elif objeto.name == "WorkZone":
		objeto.body_entered.connect(_on_work_zone_entered)
		objeto.body_exited.connect(_on_work_zone_exited)
	elif objeto.has_meta("pieza_gratis"):
		# A diferencia de la PC/el auto puede haber mas de un estante por
		# sala (incluso del mismo tipo), asi que esto no se identifica por
		# nombre de nodo sino por la key que trae la meta.
		var key: String = objeto.get_meta("pieza_gratis")
		objeto.body_entered.connect(_on_pieza_gratis_entered.bind(key))
		objeto.body_exited.connect(_on_pieza_gratis_exited.bind(key))
	elif objeto.has_meta("accion"):
		# Objetos que se tocan: luces, banderas... (ver room.gd
		# interactuar_objeto).
		objeto.body_entered.connect(_on_accion_entered.bind(objeto))
		objeto.body_exited.connect(_on_accion_exited.bind(objeto))
	elif objeto.has_meta("radio"):
		objeto.body_entered.connect(_on_radio_entered)
		objeto.body_exited.connect(_on_radio_exited)
	elif objeto.has_meta("guacal"):
		objeto.body_entered.connect(_on_guacal_entered.bind(objeto))
		objeto.body_exited.connect(_on_guacal_exited.bind(objeto))
	elif objeto.has_meta("reciclaje"):
		objeto.body_entered.connect(_on_reciclaje_entered)
		objeto.body_exited.connect(_on_reciclaje_exited)

# "bienvenida" es el id en el catalogo `tutorials` (ver sql/tutorials.sql).
const ID_TUTORIAL_BIENVENIDA := "bienvenida"

# Se muestra una unica vez por cuenta, para siempre (no por sesion): queda
# registrado en userTutorials, así que ni volviendo a iniciar sesión otro día
# vuelve a salir.
func _mostrar_tutorial_bienvenida() -> void:
	if await Supabase.tutorial_fue_visto(ID_TUTORIAL_BIENVENIDA):
		return
	Supabase.marcar_tutorial_visto(ID_TUTORIAL_BIENVENIDA)

	_en_tutorial = true
	var modal = TutorialModal.crear(self, TUTORIAL_BIENVENIDA)
	await modal.terminado
	_en_tutorial = false

func _physics_process(_delta: float) -> void:
	velocity = Vector2.ZERO

	if _en_tutorial:
		return

	_actualizar_icono_accion()

	if Input.is_action_just_pressed("ui_accept"):
		interactuar()

	var sufijo = "-pickup" if tiene_item else ""
	var dir = Input.get_vector("left", "right", "up", "down")

	if dir.length() > 0:
		if abs(dir.x) > abs(dir.y):
			if dir.x > 0:
				velocity.x = SPEED
				_animar("right" + sufijo)
				item_hand.position = Vector2(50, -54)
				_mano_delante(true)
			else:
				velocity.x = -SPEED
				_animar("left" + sufijo)
				item_hand.position = Vector2(-50, -54)
				_mano_delante(true)
		else:
			if dir.y > 0:
				velocity.y = SPEED
				_animar("down" + sufijo)
				item_hand.position = Vector2(5, -61)
				_mano_delante(true)
			else:
				velocity.y = -SPEED
				_animar("up" + sufijo)
				item_hand.position = Vector2(0, -49)
				_mano_delante(false)
	else:
		_quieto("down" + sufijo)
		item_hand.position = Vector2(5, -59)
		_mano_delante(true)

	if dir.length() > 0:
		_respiro = 0.0
		if not _festejando:
			animation.scale = _escala_sprite
			animation.position = _posicion_sprite
	elif not _festejando:
		_respirar(_delta)

	move_and_slide()

# Quieto, Barry respira: el pecho sube y baja apenas. Se estira desde los
# pies (se corrige la posicion) para que no "flote".
func _respirar(delta: float) -> void:
	_respiro += delta
	var k := sin(_respiro * 2.4) * 0.5 + 0.5
	var escala := _escala_sprite * Vector2(1.0 - 0.008 * k, 1.0 + 0.018 * k)
	animation.scale = escala
	animation.position.y = _posicion_sprite.y - MEDIO_CUADRO * (escala.y - _escala_sprite.y)

# --- Trajes y festejos -------------------------------------------------------

# Pone el traje elegido (ver Vestuario). Tambien se llama cuando se cambia
# desde el vestidor.
func aplicar_traje() -> void:
	animation.material = Vestuario.material(Supabase.profile_outfit)

# Al volver de un trabajo: salto, confeti y lo que cobro. Si con los puntos
# nuevos se desbloqueo un traje, tambien lo anuncia.
func _festejar_si_toca() -> void:
	if Supabase.festejo_pendiente.is_empty():
		return
	var festejo: Dictionary = Supabase.festejo_pendiente
	Supabase.festejo_pendiente = {}
	# Que la sala termine de aparecer antes de festejar.
	await get_tree().create_timer(0.7).timeout
	festejar("+$%d   +%d pts" % [festejo["pago"], festejo["puntos"]])

	var puntos_antes: int = festejo["puntos_antes"]
	var puntos_despues: int = puntos_antes + int(festejo["puntos"])

	# El bono del dia se anuncia aparte: es el gancho para volver manana.
	for bono in festejo.get("bonos", []):
		if str(bono).begins_with("¡Primer"):
			await get_tree().create_timer(0.9).timeout
			Efectos.texto_flotante(get_parent(), str(bono), global_position + Vector2(0, -210), Color(0.5, 0.9, 1.0), 20)

	# Subio de nivel: el festejo grande.
	var nivel_antes := Economia.nivel(puntos_antes)
	var nivel_ahora := Economia.nivel(puntos_despues)
	if nivel_ahora > nivel_antes:
		await get_tree().create_timer(1.2).timeout
		festejar("¡Nivel %d: %s!" % [nivel_ahora, Economia.nombre_nivel(nivel_ahora)])
		Efectos.confeti(get_parent(), global_position + Vector2(0, -140), 50)
	for id in Vestuario.nuevos_entre(puntos_antes, puntos_antes + int(festejo["puntos"])):
		await get_tree().create_timer(1.3).timeout
		Sonido.efecto("acierto")
		Efectos.texto_flotante(get_parent(), "¡Nuevo traje: %s!" % Vestuario.nombre(id), global_position + Vector2(0, -190), Color(1.0, 0.85, 0.3), 22)

# Barry salta dos veces con confeti y un texto arriba de la cabeza.
func festejar(texto: String = "") -> void:
	_festejando = true
	animation.scale = _escala_sprite
	animation.position = _posicion_sprite
	Sonido.efecto("victoria")
	Efectos.confeti(get_parent(), global_position + Vector2(0, -110), 30)
	if texto != "":
		Efectos.texto_flotante(get_parent(), texto, global_position + Vector2(0, -170), Color(0.45, 1.0, 0.55), 24)

	var arriba := _posicion_sprite + Vector2(0, -34)
	var tween := create_tween()
	for salto in 2:
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(animation, "position", arriba, 0.16)
		tween.parallel().tween_property(animation, "scale", _escala_sprite * Vector2(0.92, 1.08), 0.16)
		tween.set_ease(Tween.EASE_IN)
		tween.tween_property(animation, "position", _posicion_sprite, 0.14)
		tween.parallel().tween_property(animation, "scale", _escala_sprite * Vector2(1.12, 0.88), 0.14)
		tween.tween_property(animation, "scale", _escala_sprite, 0.08)
	await tween.finished
	_festejando = false

# Pone la pieza en la mano delante o detras del sprite de Barry cambiando el
# orden de los hijos, no su z_index: con la sala ordenada por profundidad
# (y_sort en room.tscn) un z_index mayor la haria flotar encima de los
# muebles aunque Barry este detras de ellos.
func _mano_delante(delante: bool) -> void:
	var destino := get_child_count() - 1 if delante else 0
	if item_hand.get_index() != destino:
		move_child(item_hand, destino)

# Reproduce una animación de caminar solo si no era ya la que estaba sonando,
# para no reiniciarla en cada frame.
func _animar(nombre: String) -> void:
	if animation.animation != nombre or not animation.is_playing():
		animation.play(nombre)

# Reposo: deja el sprite congelado en el primer frame de la animación en vez de
# dejarla corriendo. Antes se hacía stop() + play() cada frame, que dependía del
# orden de reseteo interno y podía dejar al personaje andando en el sitio.
func _quieto(nombre: String) -> void:
	if animation.animation != nombre:
		animation.play(nombre)
	animation.frame = 0
	animation.pause()

# Mismo orden de prioridad que interactuar(): el icono muestra lo que va a
# pasar si se pulsa el boton ahora. null = no hay nada que hacer y el boton
# se oculta.
func _icono_contextual() -> Texture2D:
	if en_search_work and not tiene_item:
		return ICONO_PC
	if en_work_zone and tiene_item:
		return RoomObjectCatalog.textura("car")
	if en_pieza_gratis != "" and not tiene_item:
		return ICONO_AGARRAR
	if en_radio and not tiene_item:
		return ICONO_RADIO
	if is_instance_valid(en_accion) and not tiene_item:
		# El propio objeto como icono (la lampara, la bandera...).
		return en_accion.get("textura")
	if is_instance_valid(en_guacal) and not tiene_item:
		return _icono_mascota(str(en_guacal.get_meta("mascota_id", PetCatalog.POR_DEFECTO)))
	if en_reciclaje and not tiene_item and Supabase.basura_llena():
		return ICONO_RECICLAR
	if tiene_item:
		return ICONO_LUPA
	return null

func _actualizar_icono_accion() -> void:
	var icono := _icono_contextual()
	if icono == _icono_accion and _icono_inicializado or ui == null:
		return
	_icono_inicializado = true
	_icono_accion = icono
	ui.call("set_icono_accion", icono)

func interactuar() -> void:
	if en_search_work and not tiene_item and searchwork_ui != null:
		searchwork_ui.open()
		return

	if en_work_zone and tiene_item:
		_intentar_minijuego()
		return

	if en_pieza_gratis != "" and not tiene_item:
		recibir_item_comprado(en_pieza_gratis)
		return

	if is_instance_valid(en_guacal) and not tiene_item:
		get_parent().call("abrir_selector_mascota", en_guacal)
		return

	if en_radio and not tiene_item:
		get_parent().call("abrir_radio")
		return

	if is_instance_valid(en_accion) and not tiene_item:
		get_parent().call("interactuar_objeto", en_accion)
		return

	if en_reciclaje and not tiene_item and Supabase.basura_llena():
		get_tree().paused = false
		get_tree().change_scene_to_file(ESCENA_RECICLAJE)
		return

	if tiene_item:
		Sonido.efecto("soltar")
		tiene_item = false
		item_en_mano = ""
		item_hand.visible = false

# Pone una pieza en la mano de Barry. Lo llama la tienda de la PC
# (searchwork_ui.gd) al comprar, y tambien interactuar() al agarrar gratis
# de un estante ya pagado (ver en_pieza_gratis mas arriba).
func recibir_item_comprado(key: String) -> void:
	Sonido.efecto("agarrar")
	tiene_item = true
	item_en_mano = key
	item_hand.visible = true
	item_hand.texture = ShopCatalog.icono_mano(key)
	item_hand.scale = Vector2.ONE * ShopCatalog.escala_mano(key)

func _intentar_minijuego() -> void:
	if not MINIGAMES.has(item_en_mano):
		return
	if Supabase.active_work_name == "":
		print("No tienes un trabajo activo")
		return

	var config = MINIGAMES[item_en_mano]
	if Supabase.active_work_key != config["clave"]:
		print("Tu trabajo activo no es este: %s" % Supabase.active_work_name)
		return

	get_tree().paused = false
	get_tree().change_scene_to_file(config["escena"])

func _on_search_work_entered(body: Node2D, _zone: Area2D) -> void:
	if body == self:
		en_search_work = true

func _on_search_work_exited(body: Node2D, _zone: Area2D) -> void:
	if body == self:
		en_search_work = false

func _on_work_zone_entered(body: Node2D) -> void:
	if body == self:
		en_work_zone = true

func _on_work_zone_exited(body: Node2D) -> void:
	if body == self:
		en_work_zone = false

func _on_pieza_gratis_entered(body: Node2D, key: String) -> void:
	if body == self:
		en_pieza_gratis = key

func _on_pieza_gratis_exited(body: Node2D, key: String) -> void:
	if body == self and en_pieza_gratis == key:
		en_pieza_gratis = ""

func _on_reciclaje_entered(body: Node2D) -> void:
	if body == self:
		en_reciclaje = true

func _on_reciclaje_exited(body: Node2D) -> void:
	if body == self:
		en_reciclaje = false

func _on_guacal_entered(body: Node2D, guacal: Area2D) -> void:
	if body == self:
		en_guacal = guacal

func _on_guacal_exited(body: Node2D, guacal: Area2D) -> void:
	if body == self and en_guacal == guacal:
		en_guacal = null

# PetCatalog.icono() arma una textura nueva en cada llamada: se guarda una
# por mascota para que el boton no crea que el icono cambio en cada frame.
func _icono_mascota(id: String) -> Texture2D:
	if not _iconos_mascota.has(id):
		_iconos_mascota[id] = PetCatalog.icono(id)
	return _iconos_mascota[id]

func _on_radio_entered(body: Node2D) -> void:
	if body == self:
		en_radio = true

func _on_radio_exited(body: Node2D) -> void:
	if body == self:
		en_radio = false

func _on_accion_entered(body: Node2D, objeto: Area2D) -> void:
	if body == self:
		en_accion = objeto

func _on_accion_exited(body: Node2D, objeto: Area2D) -> void:
	if body == self and en_accion == objeto:
		en_accion = null
