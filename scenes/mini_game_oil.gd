extends Node2D

# --- NODOS DE LA CINEMÁTICA ---
@onready var engine_sprite = $Sprite2D
@onready var filtro_oscuro = $ColorRect2 

# --- NODOS DEL MINIJUEGO ---
@onready var contenedor_juego = $ContenedorJuego
@onready var botella_aceite = $ContenedorJuego/Aceite
@onready var label_porcentaje = $ContenedorJuego/Label
@onready var label_embudo = $ContenedorJuego/LabelEmbudo
@onready var chorro_aceite = $ContenedorJuego/Aceite/ChorroAceite
@onready var button_action = $ContenedorJuego/buttonAction
@onready var liquido_shader = $ContenedorJuego/LiquidoShader

var escala_original: Vector2 

var engine_textures = [
	preload("res://enginesCars/engine1.png"),
	preload("res://enginesCars/engine2.png"),
	preload("res://enginesCars/engine3.png"),
	preload("res://enginesCars/engine4.png")
]

# --- VARIABLES DEL MINIJUEGO ---
enum EstadoEmbudo { LLENANDO, DRENANDO, BLOQUEADO }
var estado_embudo: EstadoEmbudo = EstadoEmbudo.LLENANDO

var nivel_embudo: float = 0.0
var nivel_aceite_total: float = 0.0

var velocidad_llenado_embudo: float = 40.0
var velocidad_drenaje_embudo: float = 80.0
var velocidad_drenaje_desbordado: float = 30.0
var ratio_embudo_a_total: float = 0.333

func _ready():
	escala_original = engine_sprite.scale 
	
	contenedor_juego.visible = false
	chorro_aceite.emitting = false
	
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
	
	var tween_motor = create_tween()
	tween_motor.set_trans(Tween.TRANS_SINE)
	tween_motor.set_ease(Tween.EASE_IN_OUT)
	tween_motor.tween_property(engine_sprite, "position", punto_fin, 10.0)
	tween_motor.parallel().tween_property(engine_sprite, "scale", escala_original, 10.0)
	
	var tween_filtro = create_tween()
	
	tween_filtro.tween_property(filtro_oscuro, "modulate:a", 0.0, 1.5)
	tween_filtro.tween_interval(2.0)
	tween_filtro.tween_property(filtro_oscuro, "modulate:a", 1.0, 1.5)
	
	tween_filtro.tween_callback(iniciar_juego_aceite)

func iniciar_juego_aceite():
	engine_sprite.visible = false
	
	contenedor_juego.visible = true
	
	var tween_revelar = create_tween()
	tween_revelar.tween_property(filtro_oscuro, "modulate:a", 0.0, 1.0)

func _process(delta):
	if not contenedor_juego.visible:
		return
	
	match estado_embudo:
		EstadoEmbudo.LLENANDO:
			_procesar_llenado(delta)
		EstadoEmbudo.DRENANDO:
			_procesar_drenaje(delta)
		EstadoEmbudo.BLOQUEADO:
			_procesar_bloqueado(delta)
	
	_actualizar_ui()

func _procesar_llenado(delta):
	if button_action.is_pressed():
		botella_aceite.rotation = lerp_angle(botella_aceite.rotation, deg_to_rad(-80), 5.0 * delta)
		
		if botella_aceite.rotation < deg_to_rad(-60):
			chorro_aceite.emitting = true
			
			nivel_embudo += velocidad_llenado_embudo * delta
			
			if nivel_embudo >= 100.0:
				nivel_embudo = 100.0
				_estado_drenando()
		else:
			chorro_aceite.emitting = false
	else:
		chorro_aceite.emitting = false
		botella_aceite.rotation = lerp_angle(botella_aceite.rotation, 0.0, 5.0 * delta)
		
		if nivel_embudo > 0.0:
			_drenar(delta)

func _drenar(delta, desbordado = false):
	var velocidad = velocidad_drenaje_desbordado if desbordado else velocidad_drenaje_embudo
	
	nivel_embudo -= velocidad * delta
	if nivel_embudo < 0.0:
		nivel_embudo = 0.0
	
	var drenado = velocidad * delta
	nivel_aceite_total += drenado * ratio_embudo_a_total
	if nivel_aceite_total > 100.0:
		nivel_aceite_total = 100.0
	
	if nivel_embudo <= 0.0 and estado_embudo == EstadoEmbudo.DRENANDO:
		estado_embudo = EstadoEmbudo.LLENANDO

func _procesar_drenaje(delta):
	chorro_aceite.emitting = false
	botella_aceite.rotation = lerp_angle(botella_aceite.rotation, 0.0, 5.0 * delta)
	_drenar(delta, true)

func _procesar_bloqueado(delta):
	chorro_aceite.emitting = false
	botella_aceite.rotation = lerp_angle(botella_aceite.rotation, 0.0, 5.0 * delta)

func _estado_drenando():
	estado_embudo = EstadoEmbudo.DRENANDO

func _actualizar_ui():
	label_porcentaje.text = str(int(nivel_aceite_total)) + "%"
	label_embudo.text = "Embudo: " + str(int(nivel_embudo)) + "%"
	
	if liquido_shader:
		liquido_shader.material.set_shader_parameter("fV", nivel_embudo / 100.0)
