extends CharacterBody2D

# Velocidad de movimiento en píxeles por segundo
const velocidad = 310.0 

# --- NUEVAS VARIABLES PARA LOS ITEMS ---
var tiene_item: bool = false
var zona_actual: String = ""

# --- REFERENCIAS A NODOS ---
@onready var animation = $"MovementPlayer"
@onready var item_hand = $ItemHandsPlayer

func _physics_process(_delta: float):
	# 1. Reiniciamos la velocidad a 0
	velocity = Vector2.ZERO
	
	if Input.is_action_just_pressed("ui_accept"):
		interactuar()

	var sufijo = ""
	if tiene_item:
		sufijo = "-pickup"
	
	# ---> AQUÍ ESTÁ LA NUEVA LÍNEA: Lee el joystick en 360 grados <---
	var dir = Input.get_vector("left", "right", "up", "down")
	
	# Si el joystick se está moviendo (la dirección es mayor a 0)...
	if dir.length() > 0:
		# Comparamos si el empuje horizontal (x) es mayor al vertical (y)
		if abs(dir.x) > abs(dir.y):
			# --- MOVIMIENTO HORIZONTAL ---
			if dir.x > 0: # Derecha
				velocity.x = velocidad
				animation.play("right" + sufijo)
				item_hand.position = Vector2(50, -30) 
				item_hand.z_index = 1
			else:         # Izquierda
				velocity.x = -velocidad
				animation.play("left" + sufijo)
				item_hand.position = Vector2(-50, -30) 
				item_hand.z_index = 1
		else:
			# --- MOVIMIENTO VERTICAL ---
			if dir.y > 0: # Abajo
				velocity.y = velocidad
				animation.play("down" + sufijo)
				item_hand.position = Vector2(5, -37) 
				item_hand.z_index = 1
			else:         # Arriba
				velocity.y = -velocidad
				animation.play("up" + sufijo)
				item_hand.position = Vector2(0, -25) 
				item_hand.z_index = -1 
	else:
		# --- QUIETO ---
		animation.stop()
		animation.play("down" + sufijo) 
		item_hand.position = Vector2(5, -35)
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
		
		# Asignamos la imagen correcta
		if zona_actual == "oils":
			item_hand.texture = load("res://objetos/work1.png") 
		elif zona_actual == "filters":
			item_hand.texture = load("res://objetos/airFlow5.png")
		elif zona_actual == "lights":
			item_hand.texture = load("res://objetos/light5.png")
		elif zona_actual == "keys":
			item_hand.texture = load("res://objetos/boxKeys.png")
			
		print("Barry recogió: ", zona_actual)
		
	# Lógica opcional para soltar el objeto si ya tiene uno
	elif tiene_item:
		tiene_item = false
		item_hand.visible = false
		print("Barry soltó el objeto.")

# --- SEÑALES DE LAS ZONAS DE INTERACCIÓN ---
func _on_aceites_body_entered(body):
	if body.name == "Barry":
		print("🚨 BARRY ENTRÓ AL ÁREA DE ACEITES")
		zona_actual = "oils"

func _on_aceites_body_exited(body):
	if body.name == "Barry" and zona_actual == "oils":
		zona_actual = ""
		print("👋 Barry salió de aceites, memoria borrada")

func _on_filters_body_entered(body):
	if body.name == "Barry":
		print("🚨 BARRY ENTRÓ AL ÁREA DE FILTROS")
		zona_actual = "filters"

func _on_filters_body_exited(body):
	if body.name == "Barry" and zona_actual == "filters":
		zona_actual = ""
		print("👋 Barry salió de filtros, memoria borrada")

func _on_lights_2_body_entered(body):
	if body.name == "Barry":
		print("🚨 BARRY ENTRÓ AL ÁREA DE LUCES")
		zona_actual = "lights"

func _on_lights_2_body_exited(body):
	if body.name == "Barry" and zona_actual == "lights":
		zona_actual = ""
		print("👋 Barry salió de luces, memoria borrada")

func _on_keys_body_entered(body):
	if body.name == "Barry":
		print("🚨 BARRY ENTRÓ AL ÁREA DE CERRAJERÍA")
		zona_actual = "keys"

func _on_keys_body_exited(body):
	if body.name == "Barry" and zona_actual == "keys":
		zona_actual = ""
		print("👋 Barry salió de cerrajería, memoria borrada")
