extends CanvasLayer

# Panel del equipo de sonido de la sala: prender/apagar, cambiar de emisora
# y el volumen de la musica. Es el unico lugar donde se maneja la musica (el
# panel de ajustes solo tiene los efectos). Mismo estilo que los otros
# modales.
#
#   RadioPanel.crear(self)

const COLOR_FONDO := Color(0, 0, 0, 0.72)
const COLOR_PANEL := Color(0.13, 0.14, 0.17, 0.98)
const COLOR_BORDE := Color(0.42, 0.34, 0.18)
const COLOR_TITULO := Color(0.93, 0.76, 0.35)
const COLOR_TEXTO := Color(0.88, 0.88, 0.9)
const COLOR_PANTALLA := Color(0.08, 0.16, 0.1)
const COLOR_LCD := Color(0.45, 1.0, 0.55)

var _emisora: Label
var _genero: Label
var _estado: Label
var _boton_encender: Button
var _boton_aleatorio: Button
var _botones_genero: Array[Button] = []
var _volumen: Label

# true si la sala tiene el equipo profesional (cambia titulo e imagen).
var _pro: bool = false

static func crear(padre: Node, pro: bool = false) -> CanvasLayer:
	var panel = load("res://scripts/radio_panel.gd").new()
	panel.name = "RadioPanel"
	panel._pro = pro
	padre.add_child(panel)
	return panel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128

	var fondo := ColorRect.new()
	fondo.color = COLOR_FONDO
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fondo)

	var centrado := CenterContainer.new()
	centrado.set_anchors_preset(Control.PRESET_FULL_RECT)
	centrado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centrado)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 0)
	panel.add_theme_stylebox_override("panel", _caja(COLOR_PANEL, COLOR_BORDE, 14, 20))
	centrado.add_child(panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 14)
	panel.add_child(caja)

	var titulo := Label.new()
	titulo.text = "Equipo PRO" if _pro else "Equipo de sonido"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_color_override("font_color", COLOR_TITULO)
	titulo.add_theme_font_size_override("font_size", 24)
	caja.add_child(titulo)

	var imagen := TextureRect.new()
	imagen.texture = preload("res://objetos/radio_pro.png") if _pro else preload("res://objetos/radio.png")
	imagen.custom_minimum_size = Vector2(0, 64)
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	caja.add_child(imagen)

	var cobertura := _label(13, COLOR_TEXTO.darkened(0.2))
	cobertura.text = "Suena fuerte en TODO el taller" if _pro else "Se escucha mejor cerca del equipo"
	caja.add_child(cobertura)

	# "Pantallita" verde tipo radio vieja con la emisora.
	var pantalla := PanelContainer.new()
	pantalla.add_theme_stylebox_override("panel", _caja(COLOR_PANTALLA, Color(0.2, 0.3, 0.22), 8, 10))
	caja.add_child(pantalla)
	var textos := VBoxContainer.new()
	pantalla.add_child(textos)
	_estado = _label(13, COLOR_LCD.darkened(0.3))
	textos.add_child(_estado)
	_genero = _label(22, COLOR_LCD)
	textos.add_child(_genero)
	_emisora = _label(15, COLOR_LCD.darkened(0.15))
	textos.add_child(_emisora)

	var controles := HBoxContainer.new()
	controles.add_theme_constant_override("separation", 10)
	caja.add_child(controles)
	# Flechas dibujadas (Iconos): los simbolos de texto no se ven en iOS.
	var anterior := _boton("", 70)
	anterior.icon = Iconos.flecha("izq", true, 20)
	anterior.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	anterior.pressed.connect(func(): Sonido.radio_cambiar(-1))
	controles.add_child(anterior)
	_boton_encender = _boton("", 0)
	_boton_encender.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boton_encender.pressed.connect(Sonido.radio_alternar)
	controles.add_child(_boton_encender)
	var siguiente := _boton("", 70)
	siguiente.icon = Iconos.flecha("der", true, 20)
	siguiente.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	siguiente.pressed.connect(func(): Sonido.radio_cambiar(1))
	controles.add_child(siguiente)

	_boton_aleatorio = _boton("", 0)
	_boton_aleatorio.toggle_mode = true
	# Alto para las dos lineas del texto cuando esta prendido.
	_boton_aleatorio.custom_minimum_size = Vector2(0, 58)
	_boton_aleatorio.pressed.connect(Sonido.radio_alternar_aleatorio)
	caja.add_child(_boton_aleatorio)

	# Un boton por genero: saltar directo al tuyo.
	var generos := GridContainer.new()
	generos.columns = 3
	generos.add_theme_constant_override("h_separation", 6)
	generos.add_theme_constant_override("v_separation", 6)
	caja.add_child(generos)
	for indice in Sonido.EMISORAS.size():
		var boton := Button.new()
		boton.text = Sonido.EMISORAS[indice]["genero"]
		boton.custom_minimum_size = Vector2(0, 34)
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.add_theme_font_size_override("font_size", 13)
		boton.pressed.connect(Sonido.radio_elegir.bind(indice))
		generos.add_child(boton)
		_botones_genero.append(boton)

	var fila_volumen := HBoxContainer.new()
	caja.add_child(fila_volumen)
	var etiqueta := _label(16, COLOR_TEXTO)
	etiqueta.text = "Volumen"
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_volumen.add_child(etiqueta)
	_volumen = _label(16, COLOR_TITULO)
	fila_volumen.add_child(_volumen)

	var deslizador := HSlider.new()
	deslizador.min_value = 0.0
	deslizador.max_value = 1.0
	deslizador.step = 0.05
	deslizador.value = Sonido.volumen_musica
	deslizador.custom_minimum_size = Vector2(0, 36)
	deslizador.value_changed.connect(func(v: float):
		Sonido.set_volumen_musica(v)
		_actualizar()
	)
	caja.add_child(deslizador)

	var listo := _boton("Listo", 0)
	listo.pressed.connect(queue_free)
	caja.add_child(listo)

	Sonido.radio_cambio.connect(_actualizar)
	_actualizar()

func _actualizar() -> void:
	var emisora: Dictionary = Sonido.emisora_actual()
	_genero.text = emisora["genero"].to_upper() if Sonido.radio_encendida else "- - -"
	_emisora.text = emisora["nombre"] if Sonido.radio_encendida else ""
	_estado.text = "EMISORA %d/%d" % [Sonido.emisora + 1, Sonido.EMISORAS.size()] if Sonido.radio_encendida else "APAGADO"
	if Sonido.radio_aleatorio and Sonido.radio_encendida:
		_estado.text += "  ·  ALEATORIO"
	_boton_aleatorio.text = "Aleatorio: SI\n(cambia de genero solo)" if Sonido.radio_aleatorio else "Aleatorio: NO"
	_boton_aleatorio.set_pressed_no_signal(Sonido.radio_aleatorio)
	# El genero que suena se marca en dorado.
	for indice in _botones_genero.size():
		var actual: bool = Sonido.radio_encendida and indice == Sonido.emisora
		var boton := _botones_genero[indice]
		if actual:
			boton.add_theme_stylebox_override("normal", _caja(COLOR_TITULO.darkened(0.35), COLOR_TITULO, 8, 4))
			boton.add_theme_color_override("font_color", Color.WHITE)
		else:
			boton.remove_theme_stylebox_override("normal")
			boton.remove_theme_color_override("font_color")
	_boton_encender.text = "Apagar" if Sonido.radio_encendida else "Encender"
	_volumen.text = "%d%%" % int(round(Sonido.volumen_musica * 100))

func _label(tam: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", tam)
	label.add_theme_color_override("font_color", color)
	return label

func _boton(texto: String, ancho: float) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(ancho, 48)
	boton.add_theme_font_size_override("font_size", 18)
	return boton

func _caja(fondo: Color, borde: Color, radio: int, margen: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.border_color = borde
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(radio)
	estilo.set_content_margin_all(margen)
	return estilo
