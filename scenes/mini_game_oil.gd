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

# --- TIEMPOS DE LA CINEMÁTICA (segundos) ---
const CINE_FADE_IN: float = 1.2      # el negro se abre y aparece el motor
const CINE_VISIBLE: float = 3.5      # tiempo real mirando el motor
const CINE_FADE_OUT: float = 1.2     # el negro vuelve a cerrar
const CINE_NEGRO: float = 0.6        # pausa en negro antes del minijuego
const CINE_REVELAR: float = 1.0      # el negro se abre sobre el minijuego
const CINE_SALIDA: float = 1.4       # el negro cierra al terminar el juego

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

var juego_terminado: bool = false

# Caudal que entra al embudo desde la botella mientras se vierte.
var velocidad_llenado_embudo: float = 40.0
# Caudal de salida del embudo hacia el motor. Actúa SIEMPRE que haya
# líquido en el embudo, se esté vertiendo o no: es un embudo, no un vaso.
# Debe ser menor que el llenado para que se pueda desbordar al verter seguido.
var velocidad_drenaje_embudo: float = 25.0
# Cuánto del aceite drenado cuenta para el total del motor. Es la palanca
# principal de duración de la partida: más bajo = partida más larga.
# Con el drenaje actual el techo teórico es 25 * ratio puntos por segundo.
var ratio_embudo_a_total: float = 0.23

func _ready():
	escala_original = engine_sprite.scale 
	
	contenedor_juego.visible = false
	contenedor_juego.modulate.a = 0.0
	chorro_aceite.emitting = false

	filtro_oscuro.modulate.a = 1.0
	filtro_oscuro.visible = true
	# En el árbol ContenedorJuego va después del filtro, así que se dibujaría
	# encima de él. Lo forzamos al frente para que el fade tape todo.
	filtro_oscuro.z_index = 100
	
	engine_sprite.texture = engine_textures.pick_random()
	
	iniciar_cinematica()

func iniciar_cinematica():
	var centro_pantalla = get_viewport_rect().size / 2
	var direccion_aleatoria = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	
	# El paneo dura exactamente lo que dura la cinemática, así el motor
	# nunca se corta a mitad de movimiento.
	var duracion_paneo = CINE_FADE_IN + CINE_VISIBLE + CINE_FADE_OUT

	# Distancia desde el centro a cada extremo del paneo. Cuanto más baja,
	# más lento y sutil se ve el movimiento (recorre menos en el mismo tiempo).
	var distancia_paneo = 120.0

	var punto_inicio = centro_pantalla + (direccion_aleatoria * distancia_paneo)
	var punto_fin = centro_pantalla - (direccion_aleatoria * distancia_paneo)

	engine_sprite.scale = escala_original * 1.15
	engine_sprite.position = punto_inicio

	var tween_motor = create_tween()
	tween_motor.set_trans(Tween.TRANS_SINE)
	tween_motor.set_ease(Tween.EASE_IN_OUT)
	tween_motor.tween_property(engine_sprite, "position", punto_fin, duracion_paneo)
	tween_motor.parallel().tween_property(engine_sprite, "scale", escala_original, duracion_paneo)

	var tween_filtro = create_tween()
	tween_filtro.set_trans(Tween.TRANS_SINE)

	tween_filtro.tween_property(filtro_oscuro, "modulate:a", 0.0, CINE_FADE_IN).set_ease(Tween.EASE_OUT)
	tween_filtro.tween_interval(CINE_VISIBLE)
	tween_filtro.tween_property(filtro_oscuro, "modulate:a", 1.0, CINE_FADE_OUT).set_ease(Tween.EASE_IN)

	# Pausa en negro: separa las dos escenas en vez de saltar de golpe.
	tween_filtro.tween_interval(CINE_NEGRO)
	tween_filtro.tween_callback(iniciar_juego_aceite)

func iniciar_juego_aceite():
	engine_sprite.visible = false

	contenedor_juego.visible = true
	contenedor_juego.modulate.a = 0.0

	var tween_revelar = create_tween()
	tween_revelar.set_trans(Tween.TRANS_SINE)
	tween_revelar.set_ease(Tween.EASE_OUT)
	# El minijuego aparece junto con el negro que se abre, no detrás de él.
	tween_revelar.tween_property(filtro_oscuro, "modulate:a", 0.0, CINE_REVELAR)
	tween_revelar.parallel().tween_property(contenedor_juego, "modulate:a", 1.0, CINE_REVELAR * 0.8)

func _process(delta):
	if not contenedor_juego.visible or juego_terminado:
		return

	if nivel_aceite_total >= 100.0:
		_terminar_juego()
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
	var vertiendo := false

	if button_action.is_pressed():
		botella_aceite.rotation = lerp_angle(botella_aceite.rotation, deg_to_rad(-80), 5.0 * delta)
		# Solo sale aceite cuando la botella está lo bastante inclinada.
		vertiendo = botella_aceite.rotation < deg_to_rad(-60)
	else:
		botella_aceite.rotation = lerp_angle(botella_aceite.rotation, 0.0, 5.0 * delta)

	chorro_aceite.emitting = vertiendo

	if vertiendo:
		nivel_embudo += velocidad_llenado_embudo * delta

	# El drenaje es independiente de si se está virtiendo: mientras quede
	# aceite en el embudo, sigue cayendo al motor.
	_drenar(delta)

	if nivel_embudo >= 100.0:
		nivel_embudo = 100.0
		_estado_drenando()

func _drenar(delta):
	if nivel_embudo <= 0.0:
		nivel_embudo = 0.0
		return

	var drenado = min(velocidad_drenaje_embudo * delta, nivel_embudo)

	nivel_embudo -= drenado

	nivel_aceite_total += drenado * ratio_embudo_a_total
	if nivel_aceite_total > 100.0:
		nivel_aceite_total = 100.0

	if nivel_embudo <= 0.0:
		nivel_embudo = 0.0
		if estado_embudo == EstadoEmbudo.DRENANDO:
			estado_embudo = EstadoEmbudo.LLENANDO

func _procesar_drenaje(delta):
	# Desbordado: la botella se endereza sola y hay que esperar a que vacíe.
	chorro_aceite.emitting = false
	botella_aceite.rotation = lerp_angle(botella_aceite.rotation, 0.0, 5.0 * delta)
	_drenar(delta)

func _procesar_bloqueado(delta):
	chorro_aceite.emitting = false
	botella_aceite.rotation = lerp_angle(botella_aceite.rotation, 0.0, 5.0 * delta)

func _estado_drenando():
	estado_embudo = EstadoEmbudo.DRENANDO

func _terminar_juego():
	juego_terminado = true
	estado_embudo = EstadoEmbudo.BLOQUEADO
	chorro_aceite.emitting = false
	button_action.visible = false

	var payment = Supabase.active_work_payment
	var points = Supabase.active_work_points
	label_porcentaje.text = "100%"
	label_embudo.text = "Trabajo completado! Guardando..."

	var ok = await Supabase.complete_active_work()
	if ok:
		label_embudo.text = "+$%d  |  +%d pts" % [payment, points]
	else:
		label_embudo.text = "No se pudo guardar el trabajo"

	await get_tree().create_timer(2.0).timeout

	var tween_salida = create_tween()
	tween_salida.set_trans(Tween.TRANS_SINE)
	tween_salida.set_ease(Tween.EASE_IN)
	tween_salida.tween_property(filtro_oscuro, "modulate:a", 1.0, CINE_SALIDA)
	tween_salida.parallel().tween_property(contenedor_juego, "modulate:a", 0.0, CINE_SALIDA * 0.9)
	tween_salida.tween_interval(CINE_NEGRO)
	tween_salida.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))

func _actualizar_ui():
	label_porcentaje.text = str(int(nivel_aceite_total)) + "%"
	label_embudo.text = "Embudo: " + str(int(nivel_embudo)) + "%"
	
	if liquido_shader:
		liquido_shader.material.set_shader_parameter("fV", nivel_embudo / 100.0)
