extends CanvasLayer

# Mini menu generico para elegir la version de un objeto (ej. que bandera
# muestra la bandera). Una grilla de tarjetas con la imagen y el nombre de
# cada variante (ver "variantes" en RoomObjectCatalog). Mismo estilo que los
# otros modales; pausa la sala mientras esta abierto.
#
#   var menu = SelectorVariante.crear(self, "Elige la bandera", variantes, actual)
#   var id: String = await menu.elegido   # "" si se cancelo

signal elegido(id: String)

const COLOR_FONDO := Color(0, 0, 0, 0.72)
const COLOR_PANEL := Color(0.13, 0.14, 0.17, 0.98)
const COLOR_BORDE := Color(0.42, 0.34, 0.18)
const COLOR_TITULO := Color(0.93, 0.76, 0.35)
const COLOR_TARJETA := Color(0.2, 0.18, 0.3)

var _titulo: String = ""
var _variantes: Dictionary = {}
var _actual: String = ""
var _pausa_previa: bool = false

static func crear(padre: Node, titulo: String, variantes: Dictionary, actual: String = "") -> CanvasLayer:
	var menu = load("res://scripts/selector_variante.gd").new()
	menu.name = "SelectorVariante"
	menu._titulo = titulo
	menu._variantes = variantes
	menu._actual = actual
	padre.add_child(menu)
	return menu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	_pausa_previa = get_tree().paused
	get_tree().paused = true

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
	panel.custom_minimum_size = Vector2(350, 0)
	panel.add_theme_stylebox_override("panel", _caja(COLOR_PANEL, COLOR_BORDE, 14, 16))
	centrado.add_child(panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 12)
	panel.add_child(caja)

	var titulo := Label.new()
	titulo.text = _titulo
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_color_override("font_color", COLOR_TITULO)
	titulo.add_theme_font_size_override("font_size", 22)
	caja.add_child(titulo)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	caja.add_child(scroll)

	var grilla := GridContainer.new()
	grilla.columns = 3
	grilla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grilla.add_theme_constant_override("h_separation", 8)
	grilla.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grilla)

	for id in _variantes:
		grilla.add_child(_tarjeta(id, _variantes[id]))

	var cancelar := Button.new()
	cancelar.text = "Ahora no"
	cancelar.custom_minimum_size = Vector2(0, 44)
	cancelar.pressed.connect(_cerrar.bind(""))
	caja.add_child(cancelar)

func _tarjeta(id: String, datos: Dictionary) -> Control:
	var boton := Button.new()
	boton.custom_minimum_size = Vector2(100, 120)
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var es_actual := id == _actual
	boton.add_theme_stylebox_override("normal", _caja(COLOR_TARJETA.lightened(0.15) if es_actual else COLOR_TARJETA, COLOR_TITULO if es_actual else COLOR_BORDE, 10, 6))
	boton.add_theme_stylebox_override("hover", _caja(COLOR_TARJETA.lightened(0.2), COLOR_TITULO, 10, 6))
	boton.add_theme_stylebox_override("pressed", _caja(COLOR_TARJETA.lightened(0.3), COLOR_TITULO, 10, 6))
	boton.pressed.connect(_cerrar.bind(id))

	var columna := VBoxContainer.new()
	columna.set_anchors_preset(Control.PRESET_FULL_RECT)
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boton.add_child(columna)

	var imagen := TextureRect.new()
	imagen.texture = datos.get("textura")
	imagen.custom_minimum_size = Vector2(0, 92)
	imagen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(imagen)

	var nombre := Label.new()
	nombre.text = datos.get("nombre", id)
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nombre.add_theme_font_size_override("font_size", 13)
	nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(nombre)
	return boton

func _cerrar(id: String) -> void:
	get_tree().paused = _pausa_previa
	elegido.emit(id)
	queue_free()

func _caja(fondo: Color, borde: Color, radio: int, margen: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.border_color = borde
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(radio)
	estilo.set_content_margin_all(margen)
	return estilo
