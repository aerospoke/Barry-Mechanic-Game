extends CharacterBody2D

const SPEED = 310.0

const ShopCatalog = preload("res://scripts/shop_catalog.gd")

# Minijuego que se abre al llevar cada item al motor, y palabra clave que debe
# tener el nombre del trabajo activo para que ese minijuego sea el correcto.
const MINIGAMES = {
	"oils": {"escena": "res://scenes/miniGameOil.tscn", "clave": "aceite"},
}

const TutorialModal = preload("res://scripts/tutorial_modal.gd")

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

var tiene_item: bool = false
var item_en_mano: String = ""
var en_search_work: bool = false
var en_work_zone: bool = false

# Key de la pieza que se puede agarrar gratis del estante en el que esta
# parado Barry ahora mismo (ver RoomObjectCatalog.pieza_gratis), o "" si no
# hay ninguno cerca.
var en_pieza_gratis: String = ""

# Congela al jugador mientras el modal de bienvenida está en pantalla.
var _en_tutorial: bool = false

@onready var animation = $MovementPlayer
@onready var item_hand = $ItemHandsPlayer

# Lo cachea room.tscn (CanvasLayer/SearchWorkUI) para poder abrir el menu de
# la PC desde interactuar().
var searchwork_ui: Node = null

func _ready() -> void:
	var padre := get_parent()
	if padre.has_node("CanvasLayer/SearchWorkUI"):
		searchwork_ui = padre.get_node("CanvasLayer/SearchWorkUI")

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

# Solo la primera vez de la sesión: al volver de un minijuego no se repite.
func _mostrar_tutorial_bienvenida() -> void:
	if Supabase.tutorial_visto:
		return
	Supabase.tutorial_visto = true

	_en_tutorial = true
	var modal = TutorialModal.crear(self, TUTORIAL_BIENVENIDA)
	await modal.terminado
	_en_tutorial = false

func _physics_process(_delta: float) -> void:
	velocity = Vector2.ZERO

	if _en_tutorial:
		return

	if Input.is_action_just_pressed("ui_accept"):
		interactuar()

	var sufijo = "-pickup" if tiene_item else ""
	var dir = Input.get_vector("left", "right", "up", "down")

	if dir.length() > 0:
		if abs(dir.x) > abs(dir.y):
			if dir.x > 0:
				velocity.x = SPEED
				_animar("right" + sufijo)
				item_hand.position = Vector2(50, -30)
				item_hand.z_index = 1
			else:
				velocity.x = -SPEED
				_animar("left" + sufijo)
				item_hand.position = Vector2(-50, -30)
				item_hand.z_index = 1
		else:
			if dir.y > 0:
				velocity.y = SPEED
				_animar("down" + sufijo)
				item_hand.position = Vector2(5, -37)
				item_hand.z_index = 1
			else:
				velocity.y = -SPEED
				_animar("up" + sufijo)
				item_hand.position = Vector2(0, -25)
				item_hand.z_index = -1
	else:
		_quieto("down" + sufijo)
		item_hand.position = Vector2(5, -35)
		item_hand.z_index = 1

	move_and_slide()

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

	if tiene_item:
		tiene_item = false
		item_en_mano = ""
		item_hand.visible = false

# Pone una pieza en la mano de Barry. Lo llama la tienda de la PC
# (searchwork_ui.gd) al comprar, y tambien interactuar() al agarrar gratis
# de un estante ya pagado (ver en_pieza_gratis mas arriba).
func recibir_item_comprado(key: String) -> void:
	tiene_item = true
	item_en_mano = key
	item_hand.visible = true
	item_hand.texture = ShopCatalog.icono_mano(key)

func _intentar_minijuego() -> void:
	if not MINIGAMES.has(item_en_mano):
		return
	if Supabase.active_work_name == "":
		print("No tienes un trabajo activo")
		return

	var config = MINIGAMES[item_en_mano]
	if not Supabase.active_work_name.to_lower().contains(config["clave"]):
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
