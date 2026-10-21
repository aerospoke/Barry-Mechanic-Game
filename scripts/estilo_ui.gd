extends RefCounted
class_name EstiloUI

# Estilo comun de los menus (computadora, tienda, panel de Barry...): mismo
# lenguaje visual que el login y los modales. Un Theme de Godot que se asigna
# a la raiz de cada menu y lo heredan todos sus hijos, mas unas ayudas para
# lo que se arma por codigo (tarjetas, chips, boton dorado).
#
#   control.theme = EstiloUI.tema()
#   EstiloUI.boton_primario(boton)

const FONDO := Color(0.1, 0.08, 0.18)
const FONDO_BARRA := Color(0.07, 0.05, 0.13)
const TARJETA := Color(0.17, 0.15, 0.28)
const TARJETA_CLARA := Color(0.22, 0.2, 0.36)
const BORDE := Color(0.32, 0.28, 0.48)
const DORADO := Color(1.0, 0.82, 0.3)
const TEXTO := Color(0.93, 0.93, 0.97)
const TEXTO_SUAVE := Color(0.7, 0.68, 0.82)
const VERDE := Color(0.45, 0.9, 0.55)
const ROJO := Color(1.0, 0.45, 0.42)

static var _tema: Theme

static func caja(fondo: Color, borde: Color = BORDE, radio: int = 14, grosor: int = 2, sombra_abajo: int = 0, margen: int = 10) -> StyleBoxFlat:
	var c := StyleBoxFlat.new()
	c.bg_color = fondo
	c.border_color = borde
	c.set_border_width_all(grosor)
	if sombra_abajo > 0:
		# Borde grueso abajo: relieve de boton apretable.
		c.border_width_bottom = sombra_abajo
	c.set_corner_radius_all(radio)
	c.set_content_margin_all(margen)
	c.anti_aliasing = true
	return c

static func tema() -> Theme:
	if _tema != null:
		return _tema
	var t := Theme.new()
	t.default_font_size = 17

	# Botones: tarjeta con relieve abajo, se "hunde" al apretar.
	t.set_stylebox("normal", "Button", caja(TARJETA, BORDE, 14, 2, 4))
	t.set_stylebox("hover", "Button", caja(TARJETA_CLARA, DORADO.darkened(0.2), 14, 2, 4))
	t.set_stylebox("pressed", "Button", caja(TARJETA.darkened(0.15), DORADO, 14, 2, 1))
	t.set_stylebox("disabled", "Button", caja(TARJETA.darkened(0.3), BORDE.darkened(0.3), 14, 2, 4))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXTO)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", DORADO)
	t.set_color("font_disabled_color", "Button", TEXTO_SUAVE.darkened(0.3))
	t.set_constant("h_separation", "Button", 8)

	t.set_color("font_color", "Label", TEXTO)

	# Paneles (tarjetas de informacion).
	t.set_stylebox("panel", "Panel", caja(TARJETA, BORDE, 16, 2))
	t.set_stylebox("panel", "PanelContainer", caja(TARJETA, BORDE, 16, 2, 0, 14))

	# Campos de texto.
	var campo := caja(Color(0.08, 0.07, 0.14), BORDE, 12, 2, 0, 12)
	var campo_foco := campo.duplicate()
	campo_foco.border_color = DORADO
	t.set_stylebox("normal", "LineEdit", campo)
	t.set_stylebox("focus", "LineEdit", campo_foco)
	t.set_color("font_color", "LineEdit", TEXTO)
	t.set_color("font_placeholder_color", "LineEdit", Color(TEXTO_SUAVE, 0.5))
	t.set_color("caret_color", "LineEdit", DORADO)

	# Barras de scroll finitas y deslizadores.
	var barra := caja(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 4, 0, 0, 0)
	var agarre := caja(BORDE, Color(0, 0, 0, 0), 4, 0, 0, 0)
	agarre.content_margin_left = 3
	agarre.content_margin_right = 3
	t.set_stylebox("scroll", "VScrollBar", barra)
	t.set_stylebox("grabber", "VScrollBar", agarre)
	t.set_stylebox("grabber_highlight", "VScrollBar", agarre)
	t.set_stylebox("grabber_pressed", "VScrollBar", caja(DORADO, Color(0, 0, 0, 0), 4, 0, 0, 0))
	t.set_stylebox("slider", "HSlider", caja(Color(0.08, 0.07, 0.14), BORDE, 6, 1, 0, 3))
	t.set_stylebox("grabber_area", "HSlider", caja(DORADO.darkened(0.2), Color(0, 0, 0, 0), 6, 0, 0, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", caja(DORADO, Color(0, 0, 0, 0), 6, 0, 0, 3))

	_tema = t
	return t

# Accion principal: dorado con texto oscuro.
static func boton_primario(boton: Button) -> void:
	boton.add_theme_stylebox_override("normal", caja(DORADO, DORADO.darkened(0.35), 14, 0, 4))
	boton.add_theme_stylebox_override("hover", caja(DORADO.lightened(0.1), DORADO.darkened(0.35), 14, 0, 4))
	boton.add_theme_stylebox_override("pressed", caja(DORADO.darkened(0.15), DORADO.darkened(0.35), 14, 0, 1))
	boton.add_theme_stylebox_override("disabled", caja(DORADO.darkened(0.5), DORADO.darkened(0.6), 14, 0, 4))
	for estado in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		boton.add_theme_color_override(estado, Color(0.15, 0.1, 0.05))

# Accion secundaria (Volver, Cancelar): sin relleno, solo borde.
static func boton_secundario(boton: Button) -> void:
	boton.add_theme_stylebox_override("normal", caja(Color(0, 0, 0, 0), BORDE, 14, 2))
	boton.add_theme_stylebox_override("hover", caja(Color(1, 1, 1, 0.05), TEXTO_SUAVE, 14, 2))
	boton.add_theme_stylebox_override("pressed", caja(Color(1, 1, 1, 0.08), DORADO, 14, 2))
	boton.add_theme_color_override("font_color", TEXTO_SUAVE)

# Etiqueta con fondo redondeado ("chip"): saldo, puntos, recompensas.
static func chip(texto: String, color: Color, tam: int = 15) -> Label:
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", tam)
	label.add_theme_color_override("font_color", color)
	label.add_theme_stylebox_override("normal", caja(Color(color, 0.14), Color(color, 0.5), 10, 1, 0, 6))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

# Titulo de pantalla: grande y dorado.
static func titulo(label: Label, tam: int = 26) -> void:
	label.add_theme_font_size_override("font_size", tam)
	label.add_theme_color_override("font_color", DORADO)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
