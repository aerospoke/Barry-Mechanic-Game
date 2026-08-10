extends Area2D
class_name WorldObject

# Objeto de mundo genérico: un sprite + su zona de interacción en un solo
# nodo. Reemplaza el patrón anterior (arte pintado en un TileMapLayer aparte
# + un Area2D invisible ajustado a ojo para que coincida). Cada instancia se
# configura desde el Inspector (textura y escala), sin escribir un script por
# objeto.
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

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_aplicar_textura()
	_aplicar_escala()

func _aplicar_textura() -> void:
	if is_instance_valid(sprite):
		sprite.texture = textura

func _aplicar_escala() -> void:
	if is_instance_valid(sprite):
		sprite.scale = escala_sprite
