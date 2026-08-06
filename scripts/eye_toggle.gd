extends Button

# Botón de "mostrar/ocultar contraseña". El ojo se dibuja por código en vez de
# usar una textura: no hay asset de ojo en el proyecto y la fuente por defecto
# no incluye el emoji, así que dibujarlo garantiza que se vea nítido en
# cualquier resolución sin añadir dependencias.

@export var color_normal: Color = Color(0.75, 0.75, 0.78)
@export var color_activo: Color = Color(1.0, 1.0, 1.0)

var _line_edit: LineEdit

func _ready() -> void:
	_line_edit = get_parent() as LineEdit
	flat = true
	focus_mode = Control.FOCUS_NONE
	toggle_mode = true
	# El botón arranca "apagado" = contraseña oculta, que es el estado inicial
	# del LineEdit con secret = true.
	button_pressed = false
	toggled.connect(_on_toggled)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _on_toggled(activado: bool) -> void:
	if is_instance_valid(_line_edit):
		_line_edit.secret = not activado
	queue_redraw()

func _draw() -> void:
	var c: Color = color_activo if button_pressed else color_normal
	var centro := size / 2.0
	var ancho := size.x * 0.38
	var alto := size.y * 0.24
	var grosor := maxf(1.5, size.x * 0.07)

	# Párpados: dos parábolas espejadas que forman la silueta del ojo.
	var superior := PackedVector2Array()
	var inferior := PackedVector2Array()
	var pasos := 16
	for i in range(pasos + 1):
		var t := lerpf(-1.0, 1.0, float(i) / float(pasos))
		var dy := alto * (1.0 - t * t)
		superior.append(centro + Vector2(t * ancho, -dy))
		inferior.append(centro + Vector2(t * ancho, dy))

	draw_polyline(superior, c, grosor, true)
	draw_polyline(inferior, c, grosor, true)

	# Iris.
	draw_circle(centro, alto * 0.62, c)

	if not button_pressed:
		# Oculto: barra diagonal cruzando el ojo.
		var a := centro + Vector2(-ancho, -ancho) * 0.85
		var b := centro + Vector2(ancho, ancho) * 0.85
		draw_line(a, b, c, grosor, true)
