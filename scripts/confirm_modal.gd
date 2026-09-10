extends CanvasLayer

# Modal de confirmacion si/no. Mismo estilo visual que TutorialModal (ver
# tutorial_modal.gd) pero con dos botones en vez de un flujo de paginas, para
# decisiones que se pueden cancelar (ej. borrar un objeto de la sala).
#
# Uso:
#   var modal = ConfirmModal.crear(self, "Titulo", "Texto...", "Si, borrar")
#   var confirmado = await modal.resuelto

signal resuelto(confirmado: bool)

const COLOR_FONDO := Color(0, 0, 0, 0.72)
const COLOR_PANEL := Color(0.13, 0.14, 0.17, 0.98)
const COLOR_BORDE := Color(0.42, 0.34, 0.18)
const COLOR_TITULO := Color(0.93, 0.76, 0.35)
const COLOR_TEXTO := Color(0.88, 0.88, 0.9)

const MARGEN_LATERAL := 26.0
const FADE := 0.25

var _titulo_txt: String
var _texto_txt: String
var _texto_confirmar: String
var _texto_cancelar: String

var _fondo: ColorRect
var _panel: PanelContainer
var _btn_confirmar: Button
var _btn_cancelar: Button

static func crear(padre: Node, titulo: String, texto: String, texto_confirmar: String = "Si", texto_cancelar: String = "Cancelar") -> CanvasLayer:
	var modal = load("res://scripts/confirm_modal.gd").new()
	modal.name = "ConfirmModal"
	modal._titulo_txt = titulo
	modal._texto_txt = texto
	modal._texto_confirmar = texto_confirmar
	modal._texto_cancelar = texto_cancelar
	padre.add_child(modal)
	return modal

func _ready() -> void:
	# Puede abrirse con el arbol pausado (ej. menus de la PC), asi que tiene
	# que seguir procesando para que los botones respondan.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128

	_fondo = ColorRect.new()
	_fondo.color = COLOR_FONDO
	_fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fondo)

	var centrado := CenterContainer.new()
	centrado.set_anchors_preset(Control.PRESET_FULL_RECT)
	centrado.offset_left = MARGEN_LATERAL
	centrado.offset_right = -MARGEN_LATERAL
	centrado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centrado)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _estilo_panel())
	centrado.add_child(_panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 14)
	_panel.add_child(caja)

	var titulo := Label.new()
	titulo.text = _titulo_txt
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo.add_theme_color_override("font_color", COLOR_TITULO)
	titulo.add_theme_font_size_override("font_size", 22)
	caja.add_child(titulo)

	var texto := Label.new()
	texto.text = _texto_txt
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.add_theme_color_override("font_color", COLOR_TEXTO)
	texto.add_theme_font_size_override("font_size", 16)
	texto.custom_minimum_size = Vector2(300, 0)
	caja.add_child(texto)

	_btn_confirmar = Button.new()
	_btn_confirmar.text = _texto_confirmar
	_btn_confirmar.custom_minimum_size = Vector2(0, 48)
	_btn_confirmar.add_theme_font_size_override("font_size", 18)
	_btn_confirmar.pressed.connect(_on_confirmar)
	caja.add_child(_btn_confirmar)

	_btn_cancelar = Button.new()
	_btn_cancelar.text = _texto_cancelar
	_btn_cancelar.custom_minimum_size = Vector2(0, 44)
	_btn_cancelar.pressed.connect(_on_cancelar)
	caja.add_child(_btn_cancelar)

	# Aparece con fade, igual que TutorialModal.
	_fondo.modulate.a = 0.0
	_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_fondo, "modulate:a", 1.0, FADE)
	tween.parallel().tween_property(_panel, "modulate:a", 1.0, FADE)

func _estilo_panel() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COLOR_PANEL
	estilo.set_corner_radius_all(16)
	estilo.set_border_width_all(2)
	estilo.border_color = COLOR_BORDE
	estilo.content_margin_left = 22
	estilo.content_margin_right = 22
	estilo.content_margin_top = 22
	estilo.content_margin_bottom = 22
	return estilo

func _on_confirmar() -> void:
	_cerrar(true)

func _on_cancelar() -> void:
	_cerrar(false)

func _cerrar(confirmado: bool) -> void:
	_btn_confirmar.disabled = true
	_btn_cancelar.disabled = true

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_fondo, "modulate:a", 0.0, FADE)
	tween.parallel().tween_property(_panel, "modulate:a", 0.0, FADE)
	await tween.finished

	resuelto.emit(confirmado)
	queue_free()
