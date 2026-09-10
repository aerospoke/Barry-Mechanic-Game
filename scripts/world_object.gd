@tool
extends Area2D
class_name WorldObject

# Objeto de mundo genérico: un sprite + su zona de interacción en un solo
# nodo. Reemplaza el patrón anterior (arte pintado en un TileMapLayer aparte
# + un Area2D invisible ajustado a ojo para que coincida). Cada instancia se
# configura desde el Inspector (textura y escala), sin escribir un script por
# objeto.
#
# @tool: para poder previsualizar cada objeto en el editor (sprite + caja de
# colisión) sin correr el juego. Ver world_object.tscn y el paso a paso que
# te fui guiando en el chat.
#
# La raíz sigue siendo Area2D a propósito: movement_script.gd detecta las
# zonas de InteractionZone por nombre de nodo Area2D, así que una instancia
# de esta escena renombrada "SearchWork", "WorkZone" o "Trash" sigue
# funcionando exactamente igual que antes.
#
# Un Area2D nunca bloquea el paso (solo detecta superposición), así que el
# bloqueo físico de Barry contra el objeto lo da CuerpoSolido, un StaticBody2D
# aparte con su propia forma (más chica, el "pie" del objeto). El tamaño de
# cada colisión (la de interacción y la sólida) se ajusta por instancia desde
# el editor, según el tamaño real del sprite de cada objeto.

@export var textura: Texture2D:
	set(value):
		textura = value
		_aplicar_textura()

@export var escala_sprite: Vector2 = Vector2(0.35, 0.35):
	set(value):
		escala_sprite = value
		_aplicar_escala()

# Rectángulo de respaldo si nadie define un polígono (ver poligono_colision
# más abajo, que es lo que usa RoomObjectCatalog en la práctica). Solo entra
# en juego para un WorldObject suelto que no pasó por ese catálogo.
@export var tamano_colision: Vector2 = Vector2(90, 60):
	set(value):
		tamano_colision = value
		_aplicar_forma_colision()

# Inclinacion de esa caja, en grados, para que se acomode al angulo de las
# baldosas isometricas en vez de quedar derecha. Separado del tamaño a
# propósito: rotation_degrees no toca escala ni posicion, asi no se puede
# terminar con una caja espejada/deformada como pasaba arrastrando a mano.
# Solo se usa si poligono_colision esta vacio (ver mas abajo).
@export var rotacion_colision: float = 0.0:
	set(value):
		rotacion_colision = value
		_aplicar_forma_colision()

# Forma a medida del "pie" del objeto, en pixeles, en vez del rectangulo
# generico. Si tiene 3 o mas puntos, pisa a tamano_colision/rotacion_colision
# por completo. Pensado para un objeto puntual que necesita calzar bien con
# su sprite (ej. la PC); el resto sigue usando el rectangulo comun.
@export var poligono_colision: PackedVector2Array = PackedVector2Array():
	set(value):
		poligono_colision = value
		_aplicar_forma_colision()

@onready var sprite: Sprite2D = $Sprite2D
@onready var forma_solida: CollisionShape2D = $CuerpoSolido/CollisionShape2D

# Contorno blanco + rebote de escala para marcar el objeto que se esta
# arrastrando en el modo de edicion de sala (ver room.gd _unhandled_input).
# Un solo shader compartido por instancia en vez de un sprite duplicado por
# cada objeto: mas liviano y no depende de la forma de cada textura.
const ShaderContorno := preload("res://scripts/outline.gdshader")

# Grosor del contorno en pixeles de pantalla, mas o menos (ver
# _grosor_contorno: el shader trabaja en texeles de la textura fuente, que no
# es lo mismo si el sprite esta escalado chico).
const GROSOR_CONTORNO_PX := 3.0

var _tween_seleccion: Tween

func _ready() -> void:
	_aplicar_textura()
	_aplicar_escala()
	_aplicar_forma_colision()

	if not Engine.is_editor_hint():
		var material := ShaderMaterial.new()
		material.shader = ShaderContorno
		material.set_shader_parameter("ancho", _grosor_contorno())
		sprite.material = material

# Un objeto chico (ver escala_sprite, normalmente 0.3-0.5) necesita mas
# texeles de textura fuente para el mismo grosor visible en pantalla que uno
# grande. Sin esto, el contorno se veia fino o invisible en los objetos mas
# chicos aunque "ancho" fuera alto.
func _grosor_contorno() -> float:
	var escala := maxf(escala_sprite.x, 0.05)
	return clampf(GROSOR_CONTORNO_PX / escala, 1.0, 14.0)

# Lo llama room.gd al agarrar/soltar un objeto en modo edicion: prende el
# contorno blanco y un rebote de escala en loop mientras esta seleccionado,
# para que sea obvio cual es el que se esta moviendo.
func set_seleccionado(activo: bool) -> void:
	if Engine.is_editor_hint():
		return

	if is_instance_valid(_tween_seleccion):
		_tween_seleccion.kill()

	if activo:
		sprite.material.set_shader_parameter("activo", 1.0)

		_tween_seleccion = create_tween()
		_tween_seleccion.set_trans(Tween.TRANS_SINE)
		_tween_seleccion.set_ease(Tween.EASE_IN_OUT)
		_tween_seleccion.set_loops()
		_tween_seleccion.tween_property(sprite, "scale", escala_sprite * 1.08, 1.0)
		_tween_seleccion.tween_property(sprite, "scale", escala_sprite, 1.0)
	else:
		sprite.material.set_shader_parameter("activo", 0.0)
		sprite.scale = escala_sprite

func _aplicar_textura() -> void:
	if is_instance_valid(sprite):
		sprite.texture = textura

func _aplicar_escala() -> void:
	if is_instance_valid(sprite):
		sprite.scale = escala_sprite

func _aplicar_forma_colision() -> void:
	if not is_instance_valid(forma_solida):
		return

	if poligono_colision.size() >= 3:
		var forma_poligono := ConvexPolygonShape2D.new()
		forma_poligono.points = poligono_colision
		forma_solida.shape = forma_poligono
		# El poligono ya viene con la forma final calcada del sprite: no hace
		# falta (ni corresponde) rotarlo aparte.
		forma_solida.rotation_degrees = 0.0
		return

	var forma_rect := RectangleShape2D.new()
	forma_rect.size = tamano_colision
	forma_solida.shape = forma_rect
	forma_solida.rotation_degrees = rotacion_colision
