extends CanvasLayer

# Modal de tutorial por pasos. Se crea por código y va en un CanvasLayer para
# quedar siempre por encima de la escena (los minijuegos son Node2D y juegan
# con z_index, así no hay que pelearse con el orden de dibujado).
#
# Uso:
#   var tuto = TutorialModal.crear(self, [
#       {"titulo": "...", "texto": "..."},
#   ])
#   await tuto.terminado
#
# El emisor decide qué hacer al cerrarse; el modal no toca la lógica del juego.

signal terminado

const COLOR_FONDO := Color(0, 0, 0, 0.72)
const COLOR_PANEL := Color(0.13, 0.14, 0.17, 0.98)
const COLOR_BORDE := Color(0.42, 0.34, 0.18)
const COLOR_TITULO := Color(0.93, 0.76, 0.35)
const COLOR_TEXTO := Color(0.88, 0.88, 0.9)
const COLOR_PASO := Color(0.55, 0.55, 0.6)

const MARGEN_LATERAL := 26.0
const FADE := 0.25

var _paginas: Array = []
var _indice: int = 0

var _fondo: ColorRect
var _panel: PanelContainer
var _titulo: Label
var _texto: Label
var _paso: Label
var _boton: Button

static func crear(padre: Node, paginas: Array) -> CanvasLayer:
	var modal = load("res://scripts/tutorial_modal.gd").new()
	modal.name = "TutorialModal"
	modal._paginas = paginas
	padre.add_child(modal)
	return modal

func _ready() -> void:
	# El tutorial se muestra con el árbol pausado, así que tiene que seguir
	# procesando para que el botón responda y el fade corra.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128

	_fondo = ColorRect.new()
	_fondo.color = COLOR_FONDO
	_fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Come los toques para que no lleguen a los controles del minijuego.
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

	_titulo = Label.new()
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_titulo.add_theme_color_override("font_color", COLOR_TITULO)
	_titulo.add_theme_font_size_override("font_size", 24)
	caja.add_child(_titulo)

	_texto = Label.new()
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.add_theme_color_override("font_color", COLOR_TEXTO)
	_texto.add_theme_font_size_override("font_size", 17)
	_texto.custom_minimum_size = Vector2(300, 0)
	caja.add_child(_texto)

	_paso = Label.new()
	_paso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paso.add_theme_color_override("font_color", COLOR_PASO)
	_paso.add_theme_font_size_override("font_size", 13)
	caja.add_child(_paso)

	_boton = Button.new()
	_boton.custom_minimum_size = Vector2(0, 52)
	_boton.add_theme_font_size_override("font_size", 19)
	_boton.pressed.connect(_siguiente)
	caja.add_child(_boton)

	_pintar_pagina()

	# Aparece con fade para que no salte encima de la cinemática.
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

func _pintar_pagina() -> void:
	var pagina: Dictionary = _paginas[_indice]
	_titulo.text = str(pagina.get("titulo", ""))
	_texto.text = str(pagina.get("texto", ""))

	# Por defecto la última página arranca el juego; con "boton" se puede poner
	# otro texto (el modal también se usa para la pantalla de resultado).
	var ultima := _indice == _paginas.size() - 1
	_boton.text = str(pagina.get("boton", "Empezar" if ultima else "Continuar"))
	# Con una sola página el contador sobra.
	_paso.visible = _paginas.size() > 1
	_paso.text = "%d / %d" % [_indice + 1, _paginas.size()]

func _siguiente() -> void:
	if _indice < _paginas.size() - 1:
		_indice += 1
		_pintar_pagina()
		return

	_cerrar()

func _cerrar() -> void:
	# Se desactiva ya: el fade dura lo suyo y no queremos un segundo toque.
	_boton.disabled = true

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_fondo, "modulate:a", 0.0, FADE)
	tween.parallel().tween_property(_panel, "modulate:a", 0.0, FADE)
	await tween.finished

	terminado.emit()
	queue_free()
