extends RefCounted

# Efectos visuales cortos y reutilizables para los minijuegos ("jugo"):
# textos que saltan y se desvanecen, nubes de particulas, sacudidas y rebotes.
# Todo se dibuja por codigo con tweens, sin sprites ni escenas nuevas.
#
# Uso:
#   const Efectos = preload("res://scripts/efectos.gd")
#   Efectos.texto_flotante(contenedor, "¡Bien!", pos, Color.GREEN)

# Texto que aparece con un pop, sube y se desvanece.
static func texto_flotante(padre: Node, texto: String, pos: Vector2, color: Color, tam: int = 24) -> void:
	var label := Label.new()
	label.text = texto
	label.z_index = 50
	label.add_theme_font_size_override("font_size", tam)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	padre.add_child(label)

	var tam_label := label.get_combined_minimum_size()
	label.position = pos - tam_label / 2.0
	label.pivot_offset = tam_label / 2.0
	label.scale = Vector2(0.5, 0.5)

	var tween := label.create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.25)
	tween.tween_property(label, "position:y", label.position.y - 40.0, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)

# Nube de bolitas que salen disparadas desde `pos` y se desvanecen. Sirve
# para polvo, salpicaduras o chispas segun el color.
static func nube(padre: Node, pos: Vector2, color: Color, cantidad: int = 10, distancia: float = 40.0, duracion: float = 0.6) -> void:
	for i in cantidad:
		var bolita := _circulo(randf_range(3.0, 7.0), color)
		bolita.position = pos
		bolita.z_index = 40
		padre.add_child(bolita)

		var destino := pos + Vector2.from_angle(randf() * TAU) * randf_range(distancia * 0.4, distancia)
		var tween := bolita.create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(bolita, "position", destino, duracion)
		tween.parallel().tween_property(bolita, "scale", Vector2(1.6, 1.6), duracion)
		tween.parallel().tween_property(bolita, "modulate:a", 0.0, duracion)
		tween.tween_callback(bolita.queue_free)

# Confeti de colores para festejar el final.
static func confeti(padre: Node, pos: Vector2, cantidad: int = 30) -> void:
	var colores := [Color(1, 0.85, 0.3), Color(0.4, 0.9, 0.5), Color(0.4, 0.75, 1), Color(1, 0.5, 0.6)]
	for i in cantidad:
		nube(padre, pos, colores.pick_random(), 1, 160.0, 1.0)

# Sacude un nodo alrededor de su posicion y lo deja donde estaba. Si llega
# otra sacudida a mitad de una, usa la misma base (guardada en una meta) para
# que el nodo no termine corrido.
static func sacudir(nodo: Node2D, fuerza: float = 6.0, duracion: float = 0.25) -> void:
	var base: Vector2 = nodo.get_meta("_base_sacudida", nodo.position)
	nodo.set_meta("_base_sacudida", base)
	var tween := nodo.create_tween()
	var pasos := 5
	for i in pasos:
		var offset := Vector2(randf_range(-fuerza, fuerza), randf_range(-fuerza, fuerza))
		tween.tween_property(nodo, "position", base + offset, duracion / (pasos + 1))
	tween.tween_property(nodo, "position", base, duracion / (pasos + 1))
	tween.tween_callback(func(): nodo.remove_meta("_base_sacudida"))

# Aplastado rapido (estilo dibujo animado) que vuelve a `escala_base`.
static func rebote(nodo: Node2D, escala_base: Vector2, aplastado: Vector2 = Vector2(1.2, 0.8)) -> void:
	var tween := nodo.create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(nodo, "scale", escala_base * aplastado, 0.07)
	tween.tween_property(nodo, "scale", escala_base, 0.25)

static func _circulo(radio: float, color: Color) -> Polygon2D:
	var puntos := PackedVector2Array()
	for i in 10:
		puntos.append(Vector2.from_angle(TAU * i / 10.0) * radio)
	var p := Polygon2D.new()
	p.polygon = puntos
	p.color = color
	return p
