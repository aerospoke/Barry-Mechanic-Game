extends "res://scripts/minijuego_base.gd"

# Minijuego del compresor de aire: inflar las 4 llantas del carro. Cada toque
# al boton mete aire (la llanta se hincha y sube el manometro) y la llanta
# pierde un poco sola. Hay que dejar la aguja dentro de la zona verde un
# momento para que quede lista. Si te pasas del maximo... ¡PUM! revienta,
# cuenta como error y vuelve a quedar desinflada.
# Cada llanta pide una presion distinta, y las ultimas pierden mas rapido.

const LLANTA_TEXTURA := preload("res://objetos/work0.png")

const LLANTAS := 4
const PRESION_INICIAL := 8.0
const PRESION_MAXIMA := 50.0
const PRESION_POR_TOQUE := 2.6
const ANCHO_ZONA := 6.0
# Segundos que hay que aguantar dentro de la zona verde.
const TIEMPO_LISTA := 1.0
const FUGA_INICIAL := 2.0
const FUGA_PASO := 1.2

const CENTRO_LLANTA := Vector2(210, 300)
const TAMANO_LLANTA := 210.0
const CENTRO_MANOMETRO := Vector2(210, 545)
const RADIO_MANOMETRO := 70.0
# El manometro va de 0 (abajo a la izquierda) a PRESION_MAXIMA (abajo a la
# derecha), recorriendo 270 grados por arriba.
const ANGULO_CERO := 2.3561945  # 135 grados
const ANGULO_RECORRIDO := 4.712389  # 270 grados

var llanta_actual: int = 0
var presion: float = PRESION_INICIAL
var zona_minima: float = 0.0
var tiempo_en_zona: float = 0.0
var fuga: float = FUGA_INICIAL
var inflando: bool = false

var llanta: Node2D
var llanta_sprite: Sprite2D
var aguja: Line2D
var zona_arco: Line2D
var barra_lista: ColorRect
var label_presion: Label
var label_llanta: Label
var boton: Button
var marcas_llantas: Array = []

func _init() -> void:
	id_tutorial = "minigame_inflar"
	instruccion = "Toca INFLAR hasta dejar la aguja en verde"
	texto_final = "¡Llantas listas!"
	tutorial = [
		{
			"titulo": "Inflar llantas",
			"texto": "Las 4 llantas del carro estan desinfladas. ¡Hay que llenarlas de aire con el compresor!",
		},
		{
			"titulo": "Inflar",
			"texto": "Cada toque al boton INFLAR mete aire. Mira el manometro: deja la aguja en la zona VERDE un ratito y la llanta queda lista.",
		},
		{
			"titulo": "¡Cuidado!",
			"texto": "Las llantas pierden aire solas, asi que no te quedes quieto.\n\nY si te pasas de la zona roja... ¡PUM! Revienta y cuenta como error.",
		},
	]

func _construir() -> void:
	llanta = Node2D.new()
	llanta.position = CENTRO_LLANTA
	contenedor_juego.add_child(llanta)
	llanta_sprite = Sprite2D.new()
	llanta_sprite.texture = LLANTA_TEXTURA
	var lado := maxf(LLANTA_TEXTURA.get_width(), LLANTA_TEXTURA.get_height())
	llanta_sprite.scale = Vector2.ONE * TAMANO_LLANTA / lado
	llanta.add_child(llanta_sprite)

	label_llanta = _label(Vector2(20, 125), Vector2(380, 24), 15, HORIZONTAL_ALIGNMENT_CENTER)

	# Puntitos con las llantas que faltan.
	for i in LLANTAS:
		var marca := circulo(8, Color(0.3, 0.3, 0.33))
		marca.position = Vector2(210 + (i - (LLANTAS - 1) / 2.0) * 26, 425)
		contenedor_juego.add_child(marca)
		marcas_llantas.append(marca)

	_construir_manometro()

	barra_lista = ColorRect.new()
	barra_lista.color = COLOR_OK
	barra_lista.position = Vector2(150, 630)
	barra_lista.size = Vector2(0, 8)
	contenedor_juego.add_child(barra_lista)

	boton = boton_grande("INFLAR", Vector2(210, 700))
	boton.disabled = true
	boton.button_down.connect(_bombear)

	_preparar_llanta()

func _construir_manometro() -> void:
	var fondo := circulo(RADIO_MANOMETRO + 8, Color(0.85, 0.86, 0.9), 40)
	fondo.position = CENTRO_MANOMETRO
	contenedor_juego.add_child(fondo)
	var cara := circulo(RADIO_MANOMETRO, Color(0.12, 0.12, 0.15), 40)
	cara.position = CENTRO_MANOMETRO
	contenedor_juego.add_child(cara)

	# Zona roja (pasarse) del 85% para arriba.
	contenedor_juego.add_child(_arco(PRESION_MAXIMA * 0.85, PRESION_MAXIMA, Color(0.9, 0.25, 0.25)))
	zona_arco = _arco(0, 0, COLOR_OK)
	contenedor_juego.add_child(zona_arco)

	aguja = Line2D.new()
	aguja.width = 4.0
	aguja.default_color = Color(1, 0.4, 0.2)
	aguja.position = CENTRO_MANOMETRO
	aguja.points = PackedVector2Array([Vector2.ZERO, Vector2(RADIO_MANOMETRO - 12, 0)])
	contenedor_juego.add_child(aguja)
	var eje := circulo(7, Color(0.85, 0.86, 0.9))
	eje.position = CENTRO_MANOMETRO
	contenedor_juego.add_child(eje)

	label_presion = _label(CENTRO_MANOMETRO + Vector2(-50, 22), Vector2(100, 24), 16, HORIZONTAL_ALIGNMENT_CENTER)

func _arco(desde: float, hasta: float, color: Color) -> Line2D:
	var arco := Line2D.new()
	arco.width = 10.0
	arco.default_color = color
	arco.position = CENTRO_MANOMETRO
	_pintar_arco(arco, desde, hasta)
	return arco

func _pintar_arco(arco: Line2D, desde: float, hasta: float) -> void:
	var puntos := PackedVector2Array()
	for i in 13:
		var p := lerpf(desde, hasta, i / 12.0)
		puntos.append(Vector2.from_angle(_angulo(p)) * (RADIO_MANOMETRO - 8))
	arco.points = puntos

func _angulo(p: float) -> float:
	return ANGULO_CERO + ANGULO_RECORRIDO * clampf(p / PRESION_MAXIMA, 0.0, 1.0)

func _preparar_llanta() -> void:
	presion = PRESION_INICIAL
	tiempo_en_zona = 0.0
	fuga = FUGA_INICIAL + llanta_actual * FUGA_PASO
	zona_minima = randf_range(26.0, 34.0)
	_pintar_arco(zona_arco, zona_minima, zona_minima + ANCHO_ZONA)
	label_llanta.text = "Llanta %d de %d  ·  Pide %d PSI" % [llanta_actual + 1, LLANTAS, int(zona_minima + ANCHO_ZONA / 2.0)]

	# Entra rodando desde la derecha.
	llanta.position = CENTRO_LLANTA + Vector2(320, 0)
	llanta.rotation = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(llanta, "position", CENTRO_LLANTA, 0.5)
	tween.parallel().tween_property(llanta, "rotation", -TAU, 0.5)
	_actualizar_visual()

func _empezar() -> void:
	inflando = true
	boton.disabled = false

func _bombear() -> void:
	if not inflando:
		return
	presion += PRESION_POR_TOQUE * randf_range(0.8, 1.2)
	Efectos.nube(contenedor_juego, CENTRO_LLANTA + Vector2(TAMANO_LLANTA * 0.42, 0), Color(0.85, 0.95, 1.0, 0.8), 4, 35.0, 0.35)
	if presion >= PRESION_MAXIMA:
		_reventar()

func _process(delta: float) -> void:
	if not juego_activo or not inflando:
		return

	if Input.is_action_just_pressed("ui_accept"):
		_bombear()

	presion = maxf(PRESION_INICIAL * 0.5, presion - fuga * delta)

	if presion >= zona_minima and presion <= zona_minima + ANCHO_ZONA:
		tiempo_en_zona += delta
		if tiempo_en_zona >= TIEMPO_LISTA:
			_llanta_lista()
	else:
		tiempo_en_zona = maxf(0.0, tiempo_en_zona - delta * 2.0)

	_actualizar_visual()

# La llanta se ve aplastada abajo cuando le falta aire y redonda cuando esta
# en su punto; la aguja sigue la presion.
func _actualizar_visual() -> void:
	var lleno := clampf(presion / (zona_minima + ANCHO_ZONA / 2.0), 0.0, 1.2)
	llanta.scale = Vector2(lerpf(1.15, 1.0, minf(lleno, 1.0)) + maxf(0.0, lleno - 1.0) * 0.3, lerpf(0.7, 1.0, minf(lleno, 1.0)) + maxf(0.0, lleno - 1.0) * 0.3)
	aguja.rotation = _angulo(presion)
	label_presion.text = "%d PSI" % int(presion)
	barra_lista.size.x = 120.0 * clampf(tiempo_en_zona / TIEMPO_LISTA, 0.0, 1.0)

func _reventar() -> void:
	inflando = false
	Efectos.nube(contenedor_juego, CENTRO_LLANTA, Color(0.2, 0.2, 0.22), 24, 130.0, 0.6)
	Efectos.sacudir(contenedor_juego, 10.0, 0.35)
	Efectos.texto_flotante(contenedor_juego, "¡PUM!", CENTRO_LLANTA, Color.WHITE, 44)
	error("¡Se paso de aire!", CENTRO_LLANTA + Vector2(0, -130))

	presion = PRESION_INICIAL
	tiempo_en_zona = 0.0
	var tween := create_tween()
	tween.tween_property(llanta, "scale", Vector2(1.3, 0.5), 0.1)
	tween.tween_interval(0.5)
	await tween.finished
	_actualizar_visual()
	inflando = true

func _llanta_lista() -> void:
	inflando = false
	Efectos.rebote(llanta, llanta.scale, Vector2(1.1, 0.9))
	Efectos.nube(contenedor_juego, CENTRO_LLANTA, COLOR_CHISPA, 14, 120.0, 0.5)
	acierto(["¡Perfecta!", "¡Redondita!", "¡Al punto!"].pick_random(), CENTRO_LLANTA + Vector2(0, -130))
	marcas_llantas[llanta_actual].color = COLOR_OK
	Efectos.rebote(marcas_llantas[llanta_actual], Vector2.ONE, Vector2(1.6, 1.6))

	await get_tree().create_timer(0.5).timeout

	# Sale rodando por la izquierda.
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(llanta, "position", CENTRO_LLANTA + Vector2(-340, 0), 0.45)
	tween.parallel().tween_property(llanta, "rotation", llanta.rotation - TAU, 0.45)
	await tween.finished

	llanta_actual += 1
	if llanta_actual >= LLANTAS:
		boton.disabled = true
		terminar()
		return
	_preparar_llanta()
	inflando = true
