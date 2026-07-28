extends CharacterBody2D

const SPEED = 130.0 
var direction = Vector2.ZERO

@onready var anim = $AnimatedSprite2D
var timer: Timer # Guardamos una referencia al temporizador

func _ready() -> void:
	timer = Timer.new()
	timer.timeout.connect(elegir_nueva_direccion)
	add_child(timer)
	
	# Le damos una dirección inicial
	elegir_nueva_direccion()

func _physics_process(_delta: float) -> void:
	# 1. Aplicamos la velocidad en X y en Y (sin gravedad)
	velocity = direction * SPEED

	# 2. Si choca contra una pared o caja, que elija otra dirección
	if is_on_wall():
		elegir_nueva_direccion()

	# 3. Elegir la animación correcta
	if velocity.length() > 0:
		if abs(direction.x) > abs(direction.y):
			if direction.x > 0:
				anim.play("cat_right")
			else:
				anim.play("cat_left")
		else:
			if direction.y > 0:
				anim.play("cat_down")
			else:
				anim.play("cat_up") 
	else:
		anim.stop() # Nos aseguramos de que deje de mover las patas si no hay velocidad

	# 4. Movemos al gato
	move_and_slide()

# Esta función elige una dirección y un TIEMPO al azar
func elegir_nueva_direccion() -> void:
	# 40% de probabilidad de quedarse quieto
	if randf() > 0.6: 
		direction = Vector2.ZERO
		# Decide quedarse quieto entre 1 y 4 segundos
		timer.wait_time = randf_range(1.0, 4.0)
	else:
		# Decide caminar en una dirección aleatoria
		direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		# Decide caminar por un rato corto (entre 0.5 y 2.5 segundos)
		timer.wait_time = randf_range(0.5, 2.5)
		
	# Reiniciamos el temporizador con el nuevo tiempo que acaba de decidir
	timer.start()
