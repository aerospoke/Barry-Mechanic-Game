extends CanvasLayer

# Mini menu "Elige la mascota del taller": una tarjeta por mascota de
# PetCatalog. Mismo estilo que TutorialModal / ConfirmModal. Pausa la sala
# mientras esta abierto.
#
# Uso:
#   var menu = PetPicker.crear(self, "nami")   # actual (resaltada), o ""
#   var id: String = await menu.elegido        # "" si se cancelo

signal elegido(id: String)

const COLOR_FONDO := Color(0, 0, 0, 0.72)
const COLOR_PANEL := Color(0.13, 0.14, 0.17, 0.98)
const COLOR_BORDE := Color(0.42, 0.34, 0.18)
const COLOR_TITULO := Color(0.93, 0.76, 0.35)
const COLOR_TEXTO := Color(0.88, 0.88, 0.9)
const COLOR_TARJETA := Color(0.2, 0.18, 0.3)
const COLOR_TARJETA_ACTUAL := Color(0.32, 0.26, 0.12)

var _actual: String = ""
var _pausa_previa: bool = false

static func crear(padre: Node, actual: String = "") -> CanvasLayer:
	var menu = load("res://scripts/pet_picker.gd").new()
	menu.name = "PetPicker"
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
	panel.custom_minimum_size = Vector2(340, 0)
	panel.add_theme_stylebox_override("panel", _estilo(COLOR_PANEL, COLOR_BORDE, 14))
	centrado.add_child(panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 14)
	panel.add_child(caja)

	var titulo := Label.new()
	titulo.text = "Elige la mascota del taller"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_color_override("font_color", COLOR_TITULO)
	titulo.add_theme_font_size_override("font_size", 22)
	caja.add_child(titulo)

	for id in PetCatalog.MASCOTAS:
		caja.add_child(_tarjeta(id))

	var cancelar := Button.new()
	cancelar.text = "Ahora no"
	cancelar.custom_minimum_size = Vector2(0, 44)
	cancelar.pressed.connect(_cerrar.bind(""))
	caja.add_child(cancelar)

	# Entrada con un pop.
	panel.pivot_offset = panel.get_combined_minimum_size() / 2.0
	panel.scale = Vector2(0.8, 0.8)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.25)

# Tarjeta tocable: icono grande, nombre y descripcion.
func _tarjeta(id: String) -> Control:
	var boton := Button.new()
	boton.custom_minimum_size = Vector2(0, 110)
	var es_actual := id == _actual
	boton.add_theme_stylebox_override("normal", _estilo(COLOR_TARJETA_ACTUAL if es_actual else COLOR_TARJETA, COLOR_BORDE, 10))
	boton.add_theme_stylebox_override("hover", _estilo(COLOR_TARJETA.lightened(0.15), COLOR_TITULO, 10))
	boton.add_theme_stylebox_override("pressed", _estilo(COLOR_TARJETA.lightened(0.25), COLOR_TITULO, 10))
	boton.pressed.connect(_cerrar.bind(id))

	var fila := HBoxContainer.new()
	fila.set_anchors_preset(Control.PRESET_FULL_RECT)
	fila.offset_left = 12
	fila.offset_right = -12
	fila.add_theme_constant_override("separation", 12)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boton.add_child(fila)

	var icono := TextureRect.new()
	icono.texture = PetCatalog.icono(id)
	icono.custom_minimum_size = Vector2(88, 88)
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(icono)

	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.alignment = BoxContainer.ALIGNMENT_CENTER
	textos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(textos)

	var nombre := Label.new()
	nombre.text = PetCatalog.nombre(id) + ("  (actual)" if es_actual else "")
	nombre.add_theme_font_size_override("font_size", 20)
	nombre.add_theme_color_override("font_color", COLOR_TITULO)
	nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	textos.add_child(nombre)

	var descripcion := Label.new()
	descripcion.text = PetCatalog.descripcion(id)
	descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	descripcion.custom_minimum_size = Vector2(190, 0)
	descripcion.add_theme_font_size_override("font_size", 13)
	descripcion.add_theme_color_override("font_color", COLOR_TEXTO)
	descripcion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	textos.add_child(descripcion)

	return boton

func _cerrar(id: String) -> void:
	get_tree().paused = _pausa_previa
	elegido.emit(id)
	queue_free()

func _estilo(fondo: Color, borde: Color, radio: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.border_color = borde
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(radio)
	estilo.set_content_margin_all(16)
	return estilo
