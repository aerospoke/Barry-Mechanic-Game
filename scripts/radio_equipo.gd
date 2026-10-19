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

var reproductor: AudioStreamPlayer2D
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
	reproductor = AudioStreamPlayer2D.new()
	reproductor.bus = "Musica"
	reproductor.max_distance = 1600.0
	reproductor.attenuation = 1.3
	reproductor.volume_db = VOLUMEN_EQUIPO_DB
	add_child(reproductor)

	Sonido.radio_cambio.connect(aplicar)
	aplicar()

func aplicar() -> void:
	if not Sonido.radio_encendida:
		reproductor.stop()
		_objeto.scale = Vector2.ONE
		return
	var stream := Sonido.stream_musica(Sonido.emisora_actual()["id"])
	if reproductor.stream != stream or not reproductor.playing:
		reproductor.stream = stream
		reproductor.play()

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
	_objeto.scale = Vector2(1.0 + 0.03 * (1.0 - golpe), 1.0 + 0.05 * golpe)

	_proxima_nota -= delta
	if _proxima_nota <= 0.0:
		_proxima_nota = randf_range(0.5, 0.9)
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
	nota.position = Vector2(randf_range(-40, 20), -60)
	add_child(nota)

	var destino := nota.position + Vector2(randf_range(-30, 30), -70)
	var tween := nota.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(nota, "position", destino, 1.4)
	tween.parallel().tween_property(nota, "rotation", randf_range(-0.5, 0.5), 1.4)
	tween.parallel().tween_property(nota, "modulate:a", 0.0, 1.4).set_delay(0.5)
	tween.tween_callback(nota.queue_free)
