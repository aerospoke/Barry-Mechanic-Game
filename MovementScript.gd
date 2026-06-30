extends CharacterBody2D

# Velocidad de movimiento en píxeles por segundo
const velocidad = 280.0 

# --- NUEVAS VARIABLES PARA LOS ITEMS ---
var tiene_item: bool = false
var zona_actual: String = ""

# --- REFERENCIAS A NODOS ---
@onready var animation = $"MovementPlayer"
@onready var item_hand = $ItemHandsPlayer

func _physics_process(delta: float):
	# 1. Reiniciamos la velocidad a 0 en cada frame
	velocity.x = 0
	velocity.y = 0
	
	# --- NUEVO: Detectar el botón de acción (el Tick ✔️) ---
	if Input.is_action_just_pressed("ui_accept"):
		interactuar()
		print("hola")

	# -------------------------------------------------------
	
	# --- VARIABLE PARA SABER QUÉ ANIMACIÓN REPRODUCIR ---
	var sufijo = ""
	if tiene_item:
		sufijo = "-pickup"
	
	# 2. Comprobamos las acciones con IF y ELIF para evitar diagonales
	# Y POSICIONAMOS EL ÍTEM SEGÚN LA DIRECCIÓN
	if Input.is_action_pressed("left"):
		velocity.x = -velocidad
		animation.play("left" + sufijo)
		# Movemos el ítem a la izquierda y lo ponemos frente a Barry
		item_hand.position = Vector2(-55, -190) 
		item_hand.z_index = 1 
		
	elif Input.is_action_pressed("right"):
		velocity.x = velocidad
		animation.play("right" + sufijo)
		# Movemos el ítem a la derecha y lo ponemos frente a Barry
		item_hand.position = Vector2(55, -190) 
		item_hand.z_index = 1
		
	elif Input.is_action_pressed("up"):
		velocity.y = -velocidad
		animation.play("up" + sufijo)
		# Movemos el ítem un poco más arriba, pero lo mandamos DETRÁS de la espalda de Barry
		item_hand.position = Vector2(0, -25) 
		item_hand.z_index = -1 
		
	elif Input.is_action_pressed("down"):
		velocity.y = velocidad
		animation.play("down" + sufijo)
		# Movemos el ítem al centro del pecho y frente a Barry
		item_hand.position = Vector2(5, -160) 
		item_hand.z_index = 1
		
	else:
		# Si el jugador no presiona NINGUNA tecla, detenemos la animación
		animation.stop()
		animation.play("down" + sufijo) 
		# Como vuelve a mirar hacia abajo por defecto, aseguramos la posición
		item_hand.position = Vector2(5, -160)
		item_hand.z_index = 1

	# 3. Movemos al personaje de forma limpia
	move_and_slide()

# --- NUEVA FUNCIÓN PARA INTERACTUAR ---
func interactuar():
	# Si estamos frente a un estante y no tenemos nada en las manos
	print("zona actual ",zona_actual)
	if zona_actual != "" and not tiene_item:
		tiene_item = true
		item_hand.visible = true
		
		# Asignamos la imagen correcta (¡Asegúrate de que estas rutas sean correctas en tu proyecto!)
		if zona_actual == "oils":
			item_hand.texture = load("res://objetos/work1.png") 
		elif zona_actual == "filters":
			item_hand.texture = load("res://objetos/boxFilters.png")
		elif zona_actual == "lights":
			item_hand.texture = load("res://objetos/boxLights.png")
		elif zona_actual == "keys":
			item_hand.texture = load("res://objetos/boxKeys.png")
			
		print("Barry recogió: ", zona_actual)
		
	# Lógica opcional para soltar el objeto si ya tiene uno
	elif tiene_item:
		tiene_item = false
		item_hand.visible = false
		print("Barry soltó el objeto.")

# --- SEÑALES DE LAS ZONAS DE INTERACCIÓN ---
# (Recuerda conectar estas señales desde los nodos Area2D en la interfaz de Godot a este script)

# --- ACEITES ---
func _on_aceites_body_entered(body):
	if body.name == "Barry":
		print("🚨 BARRY ENTRÓ AL ÁREA DE ACEITES")
		zona_actual = "oils"

func _on_aceites_body_exited(body):
	if body.name == "Barry" and zona_actual == "oils":
		zona_actual = ""
		print("👋 Barry salió de aceites, memoria borrada")

# --- FILTROS ---
func _on_filters_body_entered(body):
	if body.name == "Barry":
		print("🚨 BARRY ENTRÓ AL ÁREA DE FILTROS")
		zona_actual = "filters"

func _on_filters_body_exited(body):
	if body.name == "Barry" and zona_actual == "filters":
		zona_actual = ""
		print("👋 Barry salió de filtros, memoria borrada")

# --- LUCES ---
func _on_lights_2_body_entered(body):
	if body.name == "Barry":
		print("🚨 BARRY ENTRÓ AL ÁREA DE LUCES")
		zona_actual = "lights"

func _on_lights_2_body_exited(body):
	if body.name == "Barry" and zona_actual == "lights":
		zona_actual = ""
		print("👋 Barry salió de luces, memoria borrada")

# --- CERRAJERÍA ---
func _on_keys_body_entered(body):
	if body.name == "Barry":
		print("🚨 BARRY ENTRÓ AL ÁREA DE CERRAJERÍA")
		zona_actual = "keys"

func _on_keys_body_exited(body):
	if body.name == "Barry" and zona_actual == "keys":
		zona_actual = ""
		print("👋 Barry salió de cerrajería, memoria borrada")
