extends Node2D

@onready var engine_sprite = $Sprite2D
@onready var filtro_oscuro = $ColorRect2 

var escala_original: Vector2 

var engine_textures = [
	preload("res://enginesCars/engine1.png"),
	preload("res://enginesCars/engine2.png"),
	preload("res://enginesCars/engine3.png"),
	preload("res://enginesCars/engine4.png")
]

func _ready():
	escala_original = engine_sprite.scale 
	
	# Empezamos con el filtro totalmente NEGRO (a = 1.0)
	filtro_oscuro.modulate.a = 1.0 
	filtro_oscuro.visible = true 
	
	engine_sprite.texture = engine_textures.pick_random()
	
	iniciar_cinematica()

func iniciar_cinematica():
	var centro_pantalla = get_viewport_rect().size / 2
	var direccion_aleatoria = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	
	# Reducimos la distancia para un movimiento más sutil y controlado
	var distancia_paneo = 350.0 
	
	var punto_inicio = centro_pantalla + (direccion_aleatoria * distancia_paneo)
	var punto_fin = centro_pantalla - (direccion_aleatoria * distancia_paneo)
	
	engine_sprite.scale = escala_original * 1.4 
	engine_sprite.position = punto_inicio 
	
	# --- 1. ANIMACIÓN DEL MOTOR ---
	var tween_motor = create_tween()
	tween_motor.set_trans(Tween.TRANS_SINE)
	tween_motor.set_ease(Tween.EASE_IN_OUT)
	# Subimos el tiempo a 10.0 segundos para que se mueva con mucha calma
	tween_motor.tween_property(engine_sprite, "position", punto_fin, 10.0)
	tween_motor.parallel().tween_property(engine_sprite, "scale", escala_original, 10.0)
	
	# --- 2. ANIMACIÓN DEL FILTRO OSCURO (Efecto Cine) ---
	var tween_filtro = create_tween()
	
	# Paso 1: Aclaramos la pantalla de negro a transparente (1.5 segundos)
	tween_filtro.tween_property(filtro_oscuro, "modulate:a", 0.0, 1.5)
	
	# Paso 2: PAUSA REDUCIDA. Solo esperamos 2.0 segundos antes de empezar a oscurecer
	tween_filtro.tween_interval(2.0)
	
	# Paso 3: Volvemos a fundir a negro (1.5 segundos)
	tween_filtro.tween_property(filtro_oscuro, "modulate:a", 1.0, 1.5)
	
	# Paso 4: Una vez que está todo negro de nuevo, llamamos a tu minijuego
	tween_filtro.tween_callback(iniciar_juego_aceite)

func iniciar_juego_aceite():
	print("¡Cinemática lista! Aquí aparecerá el embudo.")
