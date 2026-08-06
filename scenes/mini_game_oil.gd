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

const TutorialModal = preload("res://scripts/tutorial_modal.gd")

# Páginas del tutorial que se muestra al entrar, antes de poder verter.
const TUTORIAL := [
	{
		"titulo": "Cambio de aceite",
		"texto": "Tu trabajo es llenar el motor de aceite hasta el 100%.\n\nManten pulsado el boton para inclinar la botella y verter.",
	},
	{
		"titulo": "Los dos niveles",
		"texto": "MOTOR: el porcentaje grande. Es tu objetivo, solo sube.\n\nEMBUDO: el de arriba a la izquierda. Es lo que estas vertiendo y todavia no entro al motor.",
	},
	{
		"titulo": "Cuidado con desbordar",
		"texto": "El embudo cuela mas lento de lo que tu viertes.\n\nSi llega al 100% se desborda: la botella se endereza sola y no puedes verter hasta que el embudo se vacie del todo.",
	},
	{
		"titulo": "El truco",
		"texto": "No lo vacies ni lo desbordes: manten el embudo a media carga.\n\nVierte en tandas cortas y sueltalo antes de llenarlo. Asi el aceite cae al motor sin parar y terminas mucho mas rapido.",
	},
]

var escala_original: Vector2

# Bloquea la lógica del minijuego mientras el modal está en pantalla.
var tutorial_activo: bool = false

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
	# El tutorial sale con el minijuego ya visible detrás, para que se entienda
	# de qué está hablando cada paso.
	tween_revelar.tween_callback(mostrar_tutorial)

func mostrar_tutorial():
	tutorial_activo = true
	# Se pinta el estado inicial (0% / embudo 0%) antes de tapar la pantalla:
	# si no, los labels salen vacíos detrás del modal.
	_actualizar_ui()

	var modal = TutorialModal.crear(self, TUTORIAL)
	await modal.terminado
	tutorial_activo = false

func _process(delta):
	if not contenedor_juego.visible or juego_terminado or tutorial_activo:
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
	label_embudo.text = ""

	# Mismo modal que el tutorial, ahora con el resultado. El jugador cierra
	# cuando quiere en vez de comerse un timer fijo.
	var modal = TutorialModal.crear(self, [_pagina_resultado(ok, payment, points)])
	await modal.terminado

	var tween_salida = create_tween()
	tween_salida.set_trans(Tween.TRANS_SINE)
	tween_salida.set_ease(Tween.EASE_IN)
	tween_salida.tween_property(filtro_oscuro, "modulate:a", 1.0, CINE_SALIDA)
	tween_salida.parallel().tween_property(contenedor_juego, "modulate:a", 0.0, CINE_SALIDA * 0.9)
	tween_salida.tween_interval(CINE_NEGRO)
	tween_salida.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))

# Texto del modal de cierre. Si el guardado falló se avisa: el jugador tiene
# que saber que ese pago no le entró antes de volver al mapa.
func _pagina_resultado(ok: bool, payment: int, points: int) -> Dictionary:
	if not ok:
		return {
			"titulo": "Trabajo terminado",
			"texto": "Llenaste el motor, pero no se pudo guardar el pago.\n\nRevisa tu conexion e intentalo de nuevo.",
			"boton": "Continuar",
		}

	return {
		"titulo": "Trabajo completado!",
		"texto": "Dejaste el motor a punto.\n\n+ $%d\n+ %d puntos" % [payment, points],
		"boton": "Continuar",
	}

func _actualizar_ui():
	label_porcentaje.text = str(int(nivel_aceite_total)) + "%"
	label_embudo.text = "Embudo: " + str(int(nivel_embudo)) + "%"
	
	if liquido_shader:
		liquido_shader.material.set_shader_parameter("fV", nivel_embudo / 100.0)
