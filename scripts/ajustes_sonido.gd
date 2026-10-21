extends CanvasLayer

# Panel de volumen de los efectos, con un boton para silenciarlos. La musica
# se maneja desde el equipo de sonido de la sala (radio_panel.gd). Mismo estilo que los otros modales. Los cambios se aplican y se
# guardan al momento (ver Sonido.set_volumen_*).
#
#   AjustesSonido.crear(self)

const COLOR_FONDO := Color(0, 0, 0, 0.72)
const COLOR_PANEL := Color(0.13, 0.14, 0.17, 0.98)
const COLOR_BORDE := Color(0.42, 0.34, 0.18)
const COLOR_TITULO := Color(0.93, 0.76, 0.35)
const COLOR_TEXTO := Color(0.88, 0.88, 0.9)

static func crear(padre: Node) -> CanvasLayer:
	var panel = load("res://scripts/ajustes_sonido.gd").new()
	panel.name = "AjustesSonido"
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
	panel.custom_minimum_size = Vector2(320, 0)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COLOR_PANEL
	estilo.border_color = COLOR_BORDE
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(14)
	estilo.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", estilo)
	centrado.add_child(panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 16)
	panel.add_child(caja)

	var titulo := Label.new()
	titulo.text = "Sonido"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_color_override("font_color", COLOR_TITULO)
	titulo.add_theme_font_size_override("font_size", 24)
	caja.add_child(titulo)

	caja.add_child(_control("Efectos", Sonido.volumen_efectos, Sonido.set_volumen_efectos, true))

	# La musica del taller se maneja solo desde el equipo de sonido.
	var nota := Label.new()
	nota.text = "La musica se maneja desde el equipo de sonido de tu taller (lo consigues gratis en la tienda)."
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nota.custom_minimum_size = Vector2(280, 0)
	nota.add_theme_font_size_override("font_size", 13)
	nota.add_theme_color_override("font_color", COLOR_TEXTO.darkened(0.25))
	caja.add_child(nota)

	var listo := Button.new()
	listo.text = "Listo"
	listo.custom_minimum_size = Vector2(0, 46)
	listo.pressed.connect(queue_free)
	caja.add_child(listo)

# Una fila: nombre, deslizador y boton de silencio. Al soltar el deslizador
# de efectos suena una moneda para escuchar como quedo.
func _control(nombre: String, valor: float, al_cambiar: Callable, probar: bool) -> Control:
	var fila := VBoxContainer.new()

	var cabecera := HBoxContainer.new()
	fila.add_child(cabecera)

	var etiqueta := Label.new()
	etiqueta.text = nombre
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	etiqueta.add_theme_color_override("font_color", COLOR_TEXTO)
	etiqueta.add_theme_font_size_override("font_size", 18)
	cabecera.add_child(etiqueta)

	var porcentaje := Label.new()
	porcentaje.add_theme_color_override("font_color", COLOR_TITULO)
	cabecera.add_child(porcentaje)

	var deslizador := HSlider.new()
	deslizador.min_value = 0.0
	deslizador.max_value = 1.0
	deslizador.step = 0.05
	deslizador.value = valor
	deslizador.custom_minimum_size = Vector2(0, 36)
	fila.add_child(deslizador)

	var silenciar := Button.new()
	silenciar.custom_minimum_size = Vector2(0, 38)
	fila.add_child(silenciar)

	# Volumen al que vuelve al quitar el silencio.
	var ultimo_volumen := [valor if valor > 0.0 else 0.6]

	var refrescar := func(v: float) -> void:
		porcentaje.text = "%d%%" % int(round(v * 100))
		silenciar.text = "Activar" if v <= 0.0 else "Silenciar"

	deslizador.value_changed.connect(func(v: float) -> void:
		al_cambiar.call(v)
		if v > 0.0:
			ultimo_volumen[0] = v
		refrescar.call(v)
	)
	if probar:
		deslizador.drag_ended.connect(func(_cambio: bool) -> void: Sonido.efecto("moneda"))
	silenciar.pressed.connect(func() -> void:
		deslizador.value = 0.0 if deslizador.value > 0.0 else ultimo_volumen[0]
	)
	refrescar.call(valor)
	return fila
