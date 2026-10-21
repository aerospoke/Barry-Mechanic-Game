extends CanvasLayer

# Vestidor: elegir el traje de Barry. Vista previa grande del sprite con el
# traje aplicado, flechas para recorrerlos y el requisito de los que todavia
# estan bloqueados. Mismo estilo que los otros modales.
#
#   Vestidor.crear(self)

const COLOR_FONDO := Color(0, 0, 0, 0.72)
const COLOR_PANEL := Color(0.13, 0.14, 0.17, 0.98)
const COLOR_BORDE := Color(0.42, 0.34, 0.18)
const COLOR_TITULO := Color(0.93, 0.76, 0.35)
const COLOR_TEXTO := Color(0.88, 0.88, 0.9)
const COLOR_BLOQUEADO := Color(0.6, 0.58, 0.65)

const HOJA_BARRY := preload("res://objetos/mecanicomovement_principal.png")
# Primer cuadro de frente de la hoja (ver barry.tscn).
const CUADRO_FRENTE := Rect2(0, 0, 260, 256)

var _ids: Array = []
var _indice: int = 0
var _vista: TextureRect
var _nombre: Label
var _requisito: Label
var _boton: Button
var _puntos: HBoxContainer

static func crear(padre: Node) -> CanvasLayer:
	var panel = load("res://scripts/vestidor.gd").new()
	panel.name = "Vestidor"
	padre.add_child(panel)
	return panel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	_ids = Vestuario.ids()
	_indice = maxi(0, _ids.find(Supabase.profile_outfit))

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
	panel.add_theme_stylebox_override("panel", _caja(COLOR_PANEL, COLOR_BORDE, 14, 20))
	centrado.add_child(panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 12)
	panel.add_child(caja)

	var titulo := _label(24, COLOR_TITULO)
	titulo.text = "Vestidor"
	caja.add_child(titulo)

	var puntos_label := _label(14, COLOR_TEXTO.darkened(0.2))
	puntos_label.text = "Tus puntos: %d" % Supabase.profile_points
	caja.add_child(puntos_label)

	# Vista previa: flecha | Barry | flecha.
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_child(fila)
	var anterior := _flecha("izq")
	anterior.pressed.connect(func(): _mostrar(_indice - 1))
	fila.add_child(anterior)

	var atlas := AtlasTexture.new()
	atlas.atlas = HOJA_BARRY
	atlas.region = CUADRO_FRENTE
	_vista = TextureRect.new()
	_vista.texture = atlas
	_vista.custom_minimum_size = Vector2(200, 200)
	_vista.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vista.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_vista.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_vista.pivot_offset = Vector2(100, 100)
	fila.add_child(_vista)

	var siguiente := _flecha("der")
	siguiente.pressed.connect(func(): _mostrar(_indice + 1))
	fila.add_child(siguiente)

	_puntos = HBoxContainer.new()
	_puntos.alignment = BoxContainer.ALIGNMENT_CENTER
	_puntos.add_theme_constant_override("separation", 6)
	caja.add_child(_puntos)

	_nombre = _label(22, Color.WHITE)
	caja.add_child(_nombre)
	_requisito = _label(14, COLOR_TEXTO)
	caja.add_child(_requisito)

	_boton = Button.new()
	_boton.custom_minimum_size = Vector2(0, 50)
	_boton.add_theme_font_size_override("font_size", 19)
	_boton.pressed.connect(_poner)
	caja.add_child(_boton)

	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.custom_minimum_size = Vector2(0, 44)
	cerrar.pressed.connect(queue_free)
	caja.add_child(cerrar)

	_mostrar(_indice, false)

func _mostrar(indice: int, animar: bool = true) -> void:
	_indice = posmod(indice, _ids.size())
	var id: String = _ids[_indice]
	var libre := Vestuario.desbloqueado(id)

	_vista.material = Vestuario.material(id)
	# Bloqueado: Barry en silueta oscura, para dar ganas de desbloquearlo.
	_vista.modulate = Color.WHITE if libre else Color(0.15, 0.15, 0.2)
	_nombre.text = Vestuario.nombre(id) if libre else "???  " + Vestuario.nombre(id)
	_requisito.text = Vestuario.requisito(id)
	_requisito.add_theme_color_override("font_color", COLOR_TEXTO if libre else COLOR_BLOQUEADO)

	var puesto := id == Supabase.profile_outfit
	_boton.disabled = not libre or puesto
	_boton.text = "Lo llevas puesto" if puesto else ("Ponermelo" if libre else "Bloqueado")

	for punto in _puntos.get_children():
		punto.queue_free()
	for i in _ids.size():
		var punto := ColorRect.new()
		punto.custom_minimum_size = Vector2(9, 9)
		punto.color = COLOR_TITULO if i == _indice else Color(0.35, 0.33, 0.42)
		_puntos.add_child(punto)

	if animar:
		_vista.scale = Vector2(0.85, 0.85)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(_vista, "scale", Vector2.ONE, 0.25)

func _poner() -> void:
	var id: String = _ids[_indice]
	_boton.disabled = true
	_boton.text = "Guardando..."
	if not await Supabase.guardar_traje(id):
		_boton.text = "No se pudo guardar"
		_boton.disabled = false
		return
	_mostrar(_indice, false)
	# Barry festeja con su traje nuevo apenas se cierra el vestidor.
	queue_free()
	var barry = get_tree().current_scene.get_node_or_null("Barry")
	if barry != null and barry.has_method("festejar"):
		barry.festejar("¡%s!" % Vestuario.nombre(id))

func _flecha(direccion: String) -> Button:
	var boton := Button.new()
	boton.icon = Iconos.flecha(direccion, false, 26)
	boton.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boton.custom_minimum_size = Vector2(46, 80)
	return boton

func _label(tam: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", tam)
	label.add_theme_color_override("font_color", color)
	return label

func _caja(fondo: Color, borde: Color, radio: int, margen: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.border_color = borde
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(radio)
	estilo.set_content_margin_all(margen)
	return estilo
