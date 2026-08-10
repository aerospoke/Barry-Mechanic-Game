extends CharacterBody2D

const SPEED = 310.0

const ShopCatalog = preload("res://scripts/shop_catalog.gd")

# Minijuego que se abre al llevar cada item al motor, y palabra clave que debe
# tener el nombre del trabajo activo para que ese minijuego sea el correcto.
const MINIGAMES = {
	"oils": {"escena": "res://scenes/miniGameOil.tscn", "clave": "aceite"},
}

const TutorialModal = preload("res://scripts/tutorial_modal.gd")

# Explicación del taller al entrar por primera vez en la sesión.
const TUTORIAL_TALLER := [
	{
		"titulo": "Bienvenido al taller",
		"texto": "Este es tu taller. Muevete con el joystick de la izquierda.\n\nEl boton de accion sirve para todo: hablar con la PC, agarrar repuestos y empezar los trabajos.",
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

# Bloquea el control mientras se consulta la posición guardada, para que el
# jugador no se mueva y luego lo teletransporte la respuesta del servidor.
var _restaurando: bool = true

# Congela al jugador mientras el modal de bienvenida está en pantalla.
var _en_tutorial: bool = false

@onready var animation = $MovementPlayer
@onready var item_hand = $ItemHandsPlayer

# El mismo jugador se usa en el taller y en las salas creadas por el jugador.
# Las salas también tienen su propia PC (InteractionZone/SearchWork), pero a
# diferencia del taller no hay tutorial ni posición guardada que restaurar:
# se detecta por los nodos que la escena padre trae, en vez de duplicar el
# script. "Taller" es el nombre del nodo raíz de taller.tscn, así que solo
# está presente ahí, nunca en una sala.
var searchwork_ui: Node = null
var _es_taller: bool = true

func _ready() -> void:
	var padre := get_parent()
	if padre.has_node("CanvasLayer/SearchWorkUI"):
		searchwork_ui = padre.get_node("CanvasLayer/SearchWorkUI")

	_es_taller = padre.has_node("Taller")
	if _es_taller:
		# Se espera a la restauración para que el modal no salga mientras el
		# jugador todavía puede aparecer en otro sitio.
		await _restaurar_posicion()
		_mostrar_tutorial_taller()
	else:
		# Sala: la escena decide dónde aparece el jugador y no hay tutorial.
		_restaurando = false

	if padre.has_node("InteractionZone"):
		var interaction_zone = padre.get_node("InteractionZone")
		for child in interaction_zone.get_children():
			_conectar_zona(child)

# Punto de conexion compartido entre las zonas estaticas del taller (arriba,
# detectadas al arrancar) y los objetos dinamicos de una sala (room.gd los
# instancia despues de una peticion de red, ya con este _ready() terminado,
# asi que ahi hace falta llamarlo a mano: ver conectar_objeto()).
func _conectar_zona(child: Node) -> void:
	if child is Area2D and child.name == "SearchWork":
		child.body_entered.connect(_on_search_work_entered.bind(child))
		child.body_exited.connect(_on_search_work_exited.bind(child))
	elif child is Area2D and child.name == "WorkZone":
		child.body_entered.connect(_on_work_zone_entered)
		child.body_exited.connect(_on_work_zone_exited)

# Lo llama room.gd (via call(), ver ahi el porque) al instanciar un objeto
# dinamico que necesita interaccion, como la PC.
func conectar_objeto(objeto: Area2D) -> void:
	_conectar_zona(objeto)

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

# Solo la primera vez de la sesión: al volver de un minijuego no se repite.
func _mostrar_tutorial_taller() -> void:
	if Supabase.tutorial_taller_visto:
		return
	Supabase.tutorial_taller_visto = true

	_en_tutorial = true
	var modal = TutorialModal.crear(self, TUTORIAL_TALLER)
	await modal.terminado
	_en_tutorial = false

func _exit_tree() -> void:
	# Cubre el cambio de escena hacia un minijuego: el autoload conserva la
	# posición exacta aunque no se haya escrito en la base de datos.
	# Si ya no hay sesión (logout) no se guarda nada: esa posición pertenecía
	# al usuario anterior y heredarla colocaría mal al siguiente que entre.
	# En una sala tampoco: esa coordenada no significa nada en el taller.
	if not _es_taller or not Supabase.is_logged_in():
		return
	Supabase.player_pos = global_position
	Supabase.has_player_pos = true

# Punto único de guardado: se llama al entrar en cualquier zona de interacción.
# Las coordenadas que persiste son las del taller (profiles.pos_x/pos_y): en
# una sala no significan nada, así que ahí no se toca nada.
func _guardar_posicion() -> void:
	if not _es_taller:
		return
	Supabase.player_pos = global_position
	Supabase.has_player_pos = true
	Supabase.save_player_position(global_position)

func _physics_process(_delta: float) -> void:
	velocity = Vector2.ZERO

	if _restaurando or _en_tutorial:
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

	if tiene_item:
		tiene_item = false
		item_en_mano = ""
		item_hand.visible = false

# Lo llama la tienda de la PC (searchwork_ui.gd) al comprar una pieza: pone el
# item en la mano de Barry igual que antes hacia recoger del estante.
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
