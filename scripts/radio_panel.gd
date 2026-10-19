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
var _estado: Label
var _boton_encender: Button
var _volumen: Label

static func crear(padre: Node) -> CanvasLayer:
	var panel = load("res://scripts/radio_panel.gd").new()
	panel.name = "RadioPanel"
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
	titulo.text = "Equipo de sonido"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_color_override("font_color", COLOR_TITULO)
	titulo.add_theme_font_size_override("font_size", 24)
	caja.add_child(titulo)

	var imagen := TextureRect.new()
	imagen.texture = preload("res://objetos/radio.png")
	imagen.custom_minimum_size = Vector2(0, 110)
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	caja.add_child(imagen)

	# "Pantallita" verde tipo radio vieja con la emisora.
	var pantalla := PanelContainer.new()
	pantalla.add_theme_stylebox_override("panel", _caja(COLOR_PANTALLA, Color(0.2, 0.3, 0.22), 8, 10))
	caja.add_child(pantalla)
	var textos := VBoxContainer.new()
	pantalla.add_child(textos)
	_estado = _label(13, COLOR_LCD.darkened(0.3))
	textos.add_child(_estado)
	_emisora = _label(20, COLOR_LCD)
	textos.add_child(_emisora)

	var controles := HBoxContainer.new()
	controles.add_theme_constant_override("separation", 10)
	caja.add_child(controles)
	var anterior := _boton("◀◀", 70)
	anterior.pressed.connect(func(): Sonido.radio_cambiar(-1))
	controles.add_child(anterior)
	_boton_encender = _boton("", 0)
	_boton_encender.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boton_encender.pressed.connect(Sonido.radio_alternar)
	controles.add_child(_boton_encender)
	var siguiente := _boton("▶▶", 70)
	siguiente.pressed.connect(func(): Sonido.radio_cambiar(1))
	controles.add_child(siguiente)

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
	_emisora.text = emisora["nombre"] if Sonido.radio_encendida else "- - -"
	_estado.text = "EMISORA %d/%d" % [Sonido.emisora + 1, Sonido.EMISORAS.size()] if Sonido.radio_encendida else "APAGADO"
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
