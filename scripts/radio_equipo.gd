extends Node2D

# El equipo de sonido de la sala: es de donde sale la musica cuando estas en
# el taller (Sonido no pone musica global en room.tscn). Se cuelga como hijo
# del WorldObject "radio" (ver room.gd _instanciar_objeto).
#
# - Suena con audio posicional: mas fuerte cuanto mas cerca esta la camara
#   (o sea Barry) del equipo.
# - Mientras suena, el equipo rebota al ritmo y van saliendo notas.
# - Se prende/apaga y se cambia de emisora desde radio_panel.gd; el estado
#   vive en Sonido (radio_encendida / emisora) para que se recuerde.

const COLORES_NOTAS := [Color(1.0, 0.82, 0.3), Color(0.5, 0.85, 1.0), Color(1.0, 0.5, 0.7), Color(0.55, 1.0, 0.6)]

# AudioStreamPlayer2D (equipo comun: suena mas fuerte cerca) o
# AudioStreamPlayer (profesional: igual de fuerte en todo el taller). Sin
# tipo porque puede ser cualquiera de los dos.
var reproductor

# Equipo profesional (ver "radio_pro" en RoomObjectCatalog).
var es_pro: bool = false

# Solo suena el equipo activo de la sala (lo elige room.gd
# _elegir_radio_activa).
var activo: bool = false:
	set(valor):
		activo = valor
		if is_node_ready():
			aplicar()

# En modo aleatorio, cuenta cuanto falta para cambiar de cancion.
var _cambio_aleatorio: Timer
var _objeto: Node2D
var _tiempo: float = 0.0
var _proxima_nota: float = 0.0
# Volumen propio del equipo, por debajo del de los efectos: las canciones
# vienen normalizadas fuerte y tapaban todo. El deslizador del panel sigue
# subiendo/bajando encima de esto (bus "Musica").
const VOLUMEN_EQUIPO_DB := -10.0

# Pulsos por segundo del rebote (un poco por debajo del tempo de las
# canciones: se ve "al ritmo" sin tener que sincronizarlo de verdad).
const PULSO := 1.55

func _ready() -> void:
	_objeto = get_parent()
	if es_pro:
		var global := AudioStreamPlayer.new()
		global.volume_db = VOLUMEN_EQUIPO_DB + 2.0
		reproductor = global
	else:
		var posicional := AudioStreamPlayer2D.new()
		posicional.max_distance = 1600.0
		posicional.attenuation = 1.3
		posicional.volume_db = VOLUMEN_EQUIPO_DB
		reproductor = posicional
	reproductor.bus = "Musica"
	add_child(reproductor)

	_cambio_aleatorio = Timer.new()
	_cambio_aleatorio.one_shot = true
	_cambio_aleatorio.timeout.connect(Sonido.radio_al_azar)
	add_child(_cambio_aleatorio)

	Sonido.radio_cambio.connect(aplicar)
	aplicar()

func aplicar() -> void:
	if not activo or not Sonido.radio_encendida:
		reproductor.stop()
		_cambio_aleatorio.stop()
		_objeto.scale = Vector2.ONE
		return
	var stream := Sonido.stream_musica(Sonido.emisora_actual()["id"])
	var cambio: bool = reproductor.stream != stream or not reproductor.playing
	if cambio:
		reproductor.stream = stream
		reproductor.play()

	# Aleatorio: cuando termina la vuelta completa de la cancion, otra al
	# azar. Si se cambio a mano, la cuenta arranca de nuevo.
	if not Sonido.radio_aleatorio:
		_cambio_aleatorio.stop()
	elif cambio or _cambio_aleatorio.is_stopped():
		_cambio_aleatorio.start(maxf(stream.get_length() - reproductor.get_playback_position(), 5.0))

func _process(delta: float) -> void:
	if not reproductor.playing:
		return
	# En modo edicion no rebota: ahi se lo arrastra y gira.
	var sala = _objeto.get_parent().get_parent()
	if sala != null and sala.get("editando") == true:
		_objeto.scale = Vector2.ONE
		return

	_tiempo += delta
	var golpe := absf(sin(_tiempo * PI * PULSO))
	# El profesional "late" mas fuerte y suelta mas notas.
	var fuerza := 1.8 if es_pro else 1.0
	_objeto.scale = Vector2(1.0 + 0.03 * fuerza * (1.0 - golpe), 1.0 + 0.05 * fuerza * golpe)

	_proxima_nota -= delta
	if _proxima_nota <= 0.0:
		_proxima_nota = randf_range(0.25, 0.5) if es_pro else randf_range(0.5, 0.9)
		_soltar_nota()

# Notita musical dibujada (cabeza + plica + bandera) que sube flotando y se
# desvanece. Dibujada en vez de "♪" porque la fuente no trae ese simbolo.
func _soltar_nota() -> void:
	var nota := Node2D.new()
	var color: Color = COLORES_NOTAS.pick_random()
	var cabeza := Polygon2D.new()
	var puntos := PackedVector2Array()
	for i in 10:
		puntos.append(Vector2.from_angle(TAU * i / 10.0) * Vector2(6, 4.5))
	cabeza.polygon = puntos
	cabeza.color = color
	cabeza.rotation = -0.4
	nota.add_child(cabeza)
	var plica := Line2D.new()
	plica.points = PackedVector2Array([Vector2(5, -1), Vector2(5, -18), Vector2(11, -12)])
	plica.width = 2.5
	plica.default_color = color
	nota.add_child(plica)

	nota.z_index = 30
	nota.position = Vector2(randf_range(-40, 20), -130 if es_pro else -60)
	add_child(nota)

	var destino := nota.position + Vector2(randf_range(-30, 30), -70)
	var tween := nota.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(nota, "position", destino, 1.4)
	tween.parallel().tween_property(nota, "rotation", randf_range(-0.5, 0.5), 1.4)
	tween.parallel().tween_property(nota, "modulate:a", 0.0, 1.4).set_delay(0.5)
	tween.tween_callback(nota.queue_free)
