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
@onready var base_solida: CollisionPolygon2D = $CuerpoSolido/CollisionPolygon2D

# Posicion del sprite tal como esta en world_object.tscn (centro de la imagen).
var _sprite_pos_escena: Vector2
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

# Contorno pulsante para el estante que pide el trabajo activo (ver room.gd
# _resaltar_estante_del_trabajo). Comparte shader con la seleccion de
# edicion: mientras el objeto esta seleccionado manda la seleccion (contorno
# fijo + rebote) y al soltarlo vuelve el resaltado.
const COLOR_SELECCION := Color(1, 1, 1, 1)
const COLOR_RESALTADO := Color(1, 1, 1, 1)

var _tween_seleccion: Tween
var _tween_resaltado: Tween
var _resaltado: bool = false
var _seleccionado: bool = false

func _ready() -> void:
	_sprite_pos_escena = sprite.position
	if not Engine.is_editor_hint():
		# El objeto se ordena por profundidad (y_sort) desde el centro de su
		# base, no desde su origen: ver _aplicar_escala.
		y_sort_enabled = true
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

	_seleccionado = activo
	if activo:
		_detener_resaltado()
		sprite.material.set_shader_parameter("color_contorno", COLOR_SELECCION)
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
		if _resaltado:
			_iniciar_resaltado()

# Barrita de nivel sobre el objeto (ej. la caneca, ver room.gd). Se crea la
# primera vez que se pide. `fraccion` va de 0 a 1; llena se pone roja y late.
const MEDIDOR_ANCHO := 70.0
const MEDIDOR_ALTO := 10.0

var _medidor: Node2D
var _medidor_relleno: ColorRect
var _medidor_texto: Label
var _tween_medidor: Tween

func set_medidor(fraccion: float, texto: String, posicion: Vector2) -> void:
	if Engine.is_editor_hint():
		return
	if _medidor == null:
		_crear_medidor()
	_medidor.position = posicion

	fraccion = clampf(fraccion, 0.0, 1.0)
	_medidor_relleno.size.x = (MEDIDOR_ANCHO - 4.0) * fraccion
	_medidor_texto.text = texto
	if fraccion >= 1.0:
		_medidor_relleno.color = Color(0.95, 0.3, 0.25)
	elif fraccion >= 0.6:
		_medidor_relleno.color = Color(0.95, 0.65, 0.2)
	else:
		_medidor_relleno.color = Color(0.4, 0.85, 0.45)

	if is_instance_valid(_tween_medidor):
		_tween_medidor.kill()
	_medidor.scale = Vector2.ONE
	if fraccion >= 1.0:
		_tween_medidor = create_tween()
		_tween_medidor.set_loops()
		_tween_medidor.set_trans(Tween.TRANS_SINE)
		_tween_medidor.tween_property(_medidor, "scale", Vector2(1.15, 1.15), 0.5)
		_tween_medidor.tween_property(_medidor, "scale", Vector2.ONE, 0.5)

func _crear_medidor() -> void:
	_medidor = Node2D.new()
	# Siempre encima: es informacion, no parte del mueble que se ordena por
	# profundidad.
	_medidor.z_index = 20
	add_child(_medidor)

	var fondo := ColorRect.new()
	fondo.color = Color(0.08, 0.08, 0.1, 0.9)
	fondo.position = Vector2(-MEDIDOR_ANCHO / 2.0, -MEDIDOR_ALTO / 2.0)
	fondo.size = Vector2(MEDIDOR_ANCHO, MEDIDOR_ALTO)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_medidor.add_child(fondo)

	_medidor_relleno = ColorRect.new()
	_medidor_relleno.position = fondo.position + Vector2(2, 2)
	_medidor_relleno.size = Vector2(0, MEDIDOR_ALTO - 4.0)
	_medidor_relleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_medidor.add_child(_medidor_relleno)

	_medidor_texto = Label.new()
	_medidor_texto.add_theme_font_size_override("font_size", 13)
	_medidor_texto.add_theme_color_override("font_outline_color", Color.BLACK)
	_medidor_texto.add_theme_constant_override("outline_size", 4)
	_medidor_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_medidor_texto.position = Vector2(-MEDIDOR_ANCHO / 2.0, -MEDIDOR_ALTO / 2.0 - 20.0)
	_medidor_texto.size = Vector2(MEDIDOR_ANCHO, 18)
	_medidor_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_medidor.add_child(_medidor_texto)

func set_resaltado(activo: bool) -> void:
	if Engine.is_editor_hint() or activo == _resaltado:
		return
	_resaltado = activo
	if _seleccionado:
		return
	if activo:
		_iniciar_resaltado()
	else:
		_detener_resaltado()
		sprite.material.set_shader_parameter("activo", 0.0)

func _iniciar_resaltado() -> void:
	_detener_resaltado()
	sprite.material.set_shader_parameter("color_contorno", COLOR_RESALTADO)
	sprite.material.set_shader_parameter("activo", 1.0)

	_tween_resaltado = create_tween()
	_tween_resaltado.set_trans(Tween.TRANS_SINE)
	_tween_resaltado.set_ease(Tween.EASE_IN_OUT)
	_tween_resaltado.set_loops()
	_tween_resaltado.tween_property(sprite.material, "shader_parameter/activo", 0.3, 0.7)
	_tween_resaltado.tween_property(sprite.material, "shader_parameter/activo", 1.0, 0.7)

func _detener_resaltado() -> void:
	if is_instance_valid(_tween_resaltado):
		_tween_resaltado.kill()

func _aplicar_textura() -> void:
	if is_instance_valid(sprite):
		sprite.texture = textura

func _aplicar_escala() -> void:
	if is_instance_valid(sprite):
		sprite.scale = escala_sprite
		_ubicar_sprite_en_base()

# La sala ordena por profundidad (y_sort en room.tscn) y este nodo tambien
# (ver _ready), asi que lo que cuenta es la posicion del Sprite2D. Se lo pone
# en el centro de la base solida (lo que pisa el piso) y se compensa con
# offset para que la imagen se siga viendo en el mismo lugar: asi Barry pasa
# delante del mueble solo cuando sus pies estan por delante de esa base. De
# paso, el rebote de seleccion crece desde la base en vez de desde el medio.
func _ubicar_sprite_en_base() -> void:
	if Engine.is_editor_hint() or not is_instance_valid(base_solida):
		return
	var base := _centro_base()
	sprite.position = base
	sprite.offset = (_sprite_pos_escena - base) / escala_sprite

func _centro_base() -> Vector2:
	var centro := Vector2.ZERO
	for punto in base_solida.polygon:
		centro += base_solida.get_global_transform() * punto
	centro /= max(base_solida.polygon.size(), 1)
	return get_global_transform().affine_inverse() * centro

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
