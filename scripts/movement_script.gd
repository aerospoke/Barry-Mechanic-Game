extends CharacterBody2D

const SPEED = 310.0

const ZONE_MAP = {
	"Aceites": "oils",
	"Filters": "filters",
	"Lights": "lights",
	"Keys": "keys"
}

const ZONE_TEXTURES = {
	"oils": preload("res://objetos/work1.png"),
	"filters": preload("res://objetos/airFlow5.png"),
	"lights": preload("res://objetos/light5.png"),
	"keys": preload("res://objetos/boxKeys.png"),
}

# Minijuego que se abre al llevar cada item al motor, y palabra clave que debe
# tener el nombre del trabajo activo para que ese minijuego sea el correcto.
const MINIGAMES = {
	"oils": {"escena": "res://scenes/miniGameOil.tscn", "clave": "aceite"},
}

var tiene_item: bool = false
var item_en_mano: String = ""
var zona_actual: String = ""
var en_search_work: bool = false
var en_work_zone: bool = false

# Bloquea el control mientras se consulta la posición guardada, para que el
# jugador no se mueva y luego lo teletransporte la respuesta del servidor.
var _restaurando: bool = true

@onready var animation = $MovementPlayer
@onready var item_hand = $ItemHandsPlayer
@onready var searchwork_ui = get_parent().get_node("CanvasLayer/SearchWorkUI")

func _ready() -> void:
	_restaurar_posicion()

	var interaction_zone = get_parent().get_node("InteractionZone")
	for child in interaction_zone.get_children():
		if child is Area2D and child.name in ZONE_MAP:
			child.body_entered.connect(_on_zone_entered.bind(child))
			child.body_exited.connect(_on_zone_exited.bind(child))
		elif child is Area2D and child.name == "SearchWork":
			child.body_entered.connect(_on_search_work_entered.bind(child))
			child.body_exited.connect(_on_search_work_exited.bind(child))
		elif child is Area2D and child.name == "WorkZone":
			child.body_entered.connect(_on_work_zone_entered)
			child.body_exited.connect(_on_work_zone_exited)

func _restaurar_posicion() -> void:
	# Si el autoload ya trae posición (venimos de un minijuego) se usa directa.
	if Supabase.has_player_pos:
		global_position = Supabase.player_pos
		_restaurando = false
		return

	# Arranque de sesión: hay que esperar al perfil antes de colocar al jugador.
	if not Supabase.is_logged_in():
		_restaurando = false
		return

	await Supabase.load_profile()
	if Supabase.has_player_pos:
		global_position = Supabase.player_pos
	_restaurando = false

func _exit_tree() -> void:
	# Cubre el cambio de escena hacia un minijuego: el autoload conserva la
	# posición exacta aunque no se haya escrito en la base de datos.
	# Si ya no hay sesión (logout) no se guarda nada: esa posición pertenecía
	# al usuario anterior y heredarla colocaría mal al siguiente que entre.
	if not Supabase.is_logged_in():
		return
	Supabase.player_pos = global_position
	Supabase.has_player_pos = true

# Punto único de guardado: se llama al entrar en cualquier zona de interacción.
func _guardar_posicion() -> void:
	Supabase.player_pos = global_position
	Supabase.has_player_pos = true
	Supabase.save_player_position(global_position)

func _physics_process(_delta: float) -> void:
	velocity = Vector2.ZERO

	if _restaurando:
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
	if en_search_work and not tiene_item:
		searchwork_ui.open()
		return

	if en_work_zone and tiene_item:
		_intentar_minijuego()
		return

	if zona_actual != "" and not tiene_item:
		tiene_item = true
		item_en_mano = zona_actual
		item_hand.visible = true

		if ZONE_TEXTURES.has(zona_actual):
			item_hand.texture = ZONE_TEXTURES[zona_actual]

	elif tiene_item:
		tiene_item = false
		item_en_mano = ""
		item_hand.visible = false

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

func _on_zone_entered(body: Node2D, zone: Area2D) -> void:
	if body == self:
		zona_actual = ZONE_MAP[zone.name]
		_guardar_posicion()

func _on_zone_exited(body: Node2D, zone: Area2D) -> void:
	if body == self and zona_actual == ZONE_MAP[zone.name]:
		zona_actual = ""

func _on_search_work_entered(body: Node2D, _zone: Area2D) -> void:
	if body == self:
		en_search_work = true
		_guardar_posicion()

func _on_search_work_exited(body: Node2D, _zone: Area2D) -> void:
	if body == self:
		en_search_work = false

func _on_work_zone_entered(body: Node2D) -> void:
	if body == self:
		en_work_zone = true
		_guardar_posicion()

func _on_work_zone_exited(body: Node2D) -> void:
	if body == self:
		en_work_zone = false
