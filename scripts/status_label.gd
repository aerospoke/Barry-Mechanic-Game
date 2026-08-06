extends Label

# Etiqueta de estado para los formularios de login y registro. Se crea por
# código porque ninguna de las dos escenas tenía dónde mostrar los errores:
# antes solo se imprimían por consola, invisible en el APK.

const COLOR_ERROR := Color(0.95, 0.35, 0.35)
const COLOR_INFO := Color(0.8, 0.8, 0.85)
const COLOR_OK := Color(0.45, 0.85, 0.5)

static func crear(padre: Control, pos: Vector2, ancho: float) -> Label:
	var lbl = load("res://scripts/status_label.gd").new()
	lbl.name = "StatusLabel"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.position = pos
	lbl.size = Vector2(ancho, 60.0)
	padre.add_child(lbl)
	return lbl

func mostrar_error(msg: String) -> void:
	add_theme_color_override("font_color", COLOR_ERROR)
	text = msg
	# Se mantiene el print para poder verlo también con adb logcat.
	print(msg)

func mostrar_info(msg: String) -> void:
	add_theme_color_override("font_color", COLOR_INFO)
	text = msg

func mostrar_ok(msg: String) -> void:
	add_theme_color_override("font_color", COLOR_OK)
	text = msg

func limpiar() -> void:
	text = ""
