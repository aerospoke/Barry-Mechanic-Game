extends Node2D

# --- NODOS DE LA CINEMÁTICA ---
@onready var engine_sprite = $Sprite2D
@onready var filtro_oscuro = $ColorRect2 

# --- NODOS DEL MINIJUEGO ---
@onready var contenedor_juego = $ContenedorJuego
@onready var botella_aceite = $ContenedorJuego/Aceite
@onready var label_porcentaje = $ContenedorJuego/Label
@onready var chorro_aceite = $ContenedorJuego/Aceite/ChorroAceite
@onready var button_action = $ContenedorJuego/buttonAction # Botón
@onready var liquido_shader = $ContenedorJuego/LiquidoShader # <-- NUEVO NODO DEL SHADER

var escala_original: Vector2 

var engine_textures = [
	preload("res://enginesCars/engine1.png"),
	preload("res://enginesCars/engine2.png"),
	preload("res://enginesCars/engine3.png"),
	preload("res://enginesCars/engine4.png")
]

# --- VARIABLES DEL MINIJUEGO ---
var nivel_aceite = 0.0
var velocidad_llenado = 15.0 # Sube 15% por segundo

func _ready():
	escala_original = engine_sprite.scale 
	
	# Asegurarnos de que el minijuego esté oculto y las partículas apagadas al inicio
	contenedor_juego.visible = false
	chorro_aceite.emitting = false
	
	# Empezamos con el filtro totalmente NEGRO (a = 1.0)
	filtro_oscuro.modulate.a = 1.0 
	filtro_oscuro.visible = true 
	
	engine_sprite.texture = engine_textures.pick_random()
	
	iniciar_cinematica()

func iniciar_cinematica():
	var centro_pantalla = get_viewport_rect().size / 2
	var direccion_aleatoria = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	
	var distancia_paneo = 350.0 
	
	var punto_inicio = centro_pantalla + (direccion_aleatoria * distancia_paneo)
	var punto_fin = centro_pantalla - (direccion_aleatoria * distancia_paneo)
	
	engine_sprite.scale = escala_original * 1.4 
	engine_sprite.position = punto_inicio 
	
	# --- 1. ANIMACIÓN DEL MOTOR ---
	var tween_motor = create_tween()
	tween_motor.set_trans(Tween.TRANS_SINE)
	tween_motor.set_ease(Tween.EASE_IN_OUT)
	tween_motor.tween_property(engine_sprite, "position", punto_fin, 10.0)
	tween_motor.parallel().tween_property(engine_sprite, "scale", escala_original, 10.0)
	
	# --- 2. ANIMACIÓN DEL FILTRO OSCURO (Efecto Cine) ---
	var tween_filtro = create_tween()
	
	# Aclaramos, pausa, oscurecemos
	tween_filtro.tween_property(filtro_oscuro, "modulate:a", 0.0, 1.5)
	tween_filtro.tween_interval(2.0)
	tween_filtro.tween_property(filtro_oscuro, "modulate:a", 1.0, 1.5)
	
	# Al terminar de oscurecer, llamamos a la función que inicia el minijuego
	tween_filtro.tween_callback(iniciar_juego_aceite)

func iniciar_juego_aceite():
	# 1. Ocultamos el motor para que no estorbe en el fondo
	engine_sprite.visible = false
	
	# 2. Hacemos visible todo lo del minijuego
	contenedor_juego.visible = true
	
	# 3. Volvemos a aclarar el filtro oscuro suavemente para revelar el embudo y el aceite
	var tween_revelar = create_tween()
	tween_revelar.tween_property(filtro_oscuro, "modulate:a", 0.0, 1.0)

# --- LÓGICA CONSTANTE DEL MINIJUEGO ---
func _process(delta):
	# Si el contenedor del juego aún no es visible, no hacemos nada
	if not contenedor_juego.visible:
		return
		
	if button_action.is_pressed():
		# 1. Giramos la botella suavemente hacia la izquierda (-80 grados)
		botella_aceite.rotation = lerp_angle(botella_aceite.rotation, deg_to_rad(-80), 5.0 * delta)
		
		# 2. MAGIA AQUÍ: Solo sale aceite si la botella ya superó los -60 grados de inclinación
		if botella_aceite.rotation < deg_to_rad(-60):
			chorro_aceite.emitting = true
			
			# Aumentamos el porcentaje de aceite solo cuando de verdad está saliendo
			nivel_aceite += velocidad_llenado * delta
			
			# Evitamos que pase de 100
			if nivel_aceite > 100.0:
				nivel_aceite = 100.0
		else:
			# Si apenas se está inclinando, todavía no sale aceite ni sube el nivel
			chorro_aceite.emitting = false
			
	else:
		# Si soltamos el botón, se apaga el chorro INMEDIATAMENTE
		chorro_aceite.emitting = false
		
		# Regresamos la botella a su posición original (0 grados) suavemente
		botella_aceite.rotation = lerp_angle(botella_aceite.rotation, 0.0, 5.0 * delta)
		
	# Actualizamos el texto en pantalla
	label_porcentaje.text = str(int(nivel_aceite)) + "%"
	
	# --- ACTUALIZACIÓN DEL SHADER ---
	# Verificamos que el nodo exista y mandamos el nivel de aceite al shader
	# (dividimos entre 100 porque el shader usa valores de 0.0 a 1.0)
	if liquido_shader:
		liquido_shader.material.set_shader_parameter("fV", nivel_aceite / 100.0)
