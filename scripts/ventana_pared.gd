extends Node2D

# Ventana estilo Habbo que se cuelga en una pared de la sala: marco de
# madera, cielo con degrade, sol y nubes que pasan despacio. Se dibuja toda
# por codigo, en el plano de la pared: la sala le pone un transform
# "inclinado" como el de la TV Gold (ver room.gd _colocar_ventana), asi que
# aca se arma en coordenadas planas, con el centro en (0, 0).
#
# Donde esta: `pared` (0 o 1, ver room.gd _paredes) y `t` (0..1 a lo largo
# de esa pared). Se guarda en room_objects como x = t, y = pared.

const COLOR_MARCO := Color(0.42, 0.28, 0.17)
const COLOR_MARCO_CLARO := Color(0.6, 0.42, 0.27)
const COLOR_CONTORNO := Color(0.12, 0.09, 0.07)
const CIELO_ARRIBA := Color(0.36, 0.64, 0.93)
const CIELO_ABAJO := Color(0.72, 0.87, 1.0)
const COLOR_SOL := Color(1.0, 0.85, 0.35)
const NUBES := 4

var pared: int = 0
var t: float = 0.5
var tam: Vector2 = Vector2.ZERO

var _cielo_tam: Vector2
# Cada nube: {"nodo": Node2D, "velocidad": float}
var _nubes: Array = []

func configurar(tamano: Vector2) -> void:
	tam = tamano
	var grosor := tam.x * 0.08
	_cielo_tam = tam - Vector2.ONE * grosor * 2.0
	var esquina := -tam / 2.0

	_rect(Rect2(esquina - Vector2(3, 3), tam + Vector2(6, 6)), COLOR_CONTORNO)
	_rect(Rect2(esquina, tam), COLOR_MARCO)

	# Cielo: degrade de arriba a abajo. Recorta a sus hijos (sol y nubes)
	# con clip_children, que respeta la inclinacion de la pared.
	var degrade := Gradient.new()
	degrade.set_color(0, CIELO_ARRIBA)
	degrade.set_color(1, CIELO_ABAJO)
	var textura := GradientTexture2D.new()
	textura.gradient = degrade
	textura.fill_from = Vector2(0, 0)
	textura.fill_to = Vector2(0, 1)
	textura.width = 8
	textura.height = 64

	var cielo := TextureRect.new()
	cielo.texture = textura
	cielo.position = esquina + Vector2.ONE * grosor
	cielo.size = _cielo_tam
	cielo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cielo.stretch_mode = TextureRect.STRETCH_SCALE
	cielo.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	cielo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cielo)

	var sol := _circulo(_cielo_tam.y * 0.13, COLOR_SOL)
	sol.position = Vector2(_cielo_tam.x * 0.78, _cielo_tam.y * 0.22)
	cielo.add_child(sol)

	for i in NUBES:
		var nube := _nube(_cielo_tam.y * randf_range(0.09, 0.14))
		nube.position = Vector2(randf_range(0, _cielo_tam.x), _cielo_tam.y * randf_range(0.2, 0.75))
		cielo.add_child(nube)
		_nubes.append({"nodo": nube, "velocidad": randf_range(6.0, 14.0)})

	# Parteluces en cruz y alfeizar.
	_rect(Rect2(Vector2(-grosor * 0.4, esquina.y), Vector2(grosor * 0.8, tam.y)), COLOR_MARCO_CLARO)
	_rect(Rect2(Vector2(esquina.x, -grosor * 0.4), Vector2(tam.x, grosor * 0.8)), COLOR_MARCO_CLARO)
	_rect(Rect2(Vector2(esquina.x - grosor, -esquina.y), Vector2(tam.x + grosor * 2.0, grosor * 1.2)), COLOR_CONTORNO)
	_rect(Rect2(Vector2(esquina.x - grosor + 2, -esquina.y + 2), Vector2(tam.x + grosor * 2.0 - 4, grosor * 1.2 - 4)), COLOR_MARCO_CLARO)

# Las nubes cruzan el cielo y vuelven a entrar por el otro lado.
func _process(delta: float) -> void:
	for nube in _nubes:
		var nodo: Node2D = nube["nodo"]
		nodo.position.x += nube["velocidad"] * delta
		if nodo.position.x > _cielo_tam.x + _cielo_tam.y * 0.4:
			nodo.position.x = -_cielo_tam.y * 0.4

# Toque dentro de la ventana, deshaciendo el transform inclinado de la pared.
func contiene(mundo: Vector2) -> bool:
	var local := transform.affine_inverse() * mundo
	return absf(local.x) <= tam.x * 0.5 and absf(local.y) <= tam.y * 0.5

# Nube "de dibujo": tres bolitas blancas pegadas.
func _nube(radio: float) -> Node2D:
	var nube := Node2D.new()
	for parte in [[Vector2(-radio, 0), 1.0], [Vector2(0, -radio * 0.5), 1.3], [Vector2(radio * 1.1, 0), 0.9]]:
		var bola := _circulo(radio * parte[1], Color(1, 1, 1, 0.95))
		bola.position = parte[0]
		nube.add_child(bola)
	return nube

func _rect(rect: Rect2, color: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	p.color = color
	add_child(p)

func _circulo(radio: float, color: Color) -> Polygon2D:
	var puntos := PackedVector2Array()
	for i in 16:
		puntos.append(Vector2.from_angle(TAU * i / 16.0) * radio)
	var p := Polygon2D.new()
	p.polygon = puntos
	p.color = color
	return p
