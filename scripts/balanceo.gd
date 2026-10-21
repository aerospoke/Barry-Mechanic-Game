extends Node

# Balanceo suave de "brisa" para objetos de la sala (plantas): inclina el
# sprite del WorldObject padre de un lado al otro desde su base, cada uno con
# su propio ritmo para que no se muevan todos iguales. Ver "balanceo" en
# RoomObjectCatalog y room.gd _instanciar_objeto.

const AMPLITUD := 0.045

var _tiempo: float = randf() * 10.0
var _velocidad: float = randf_range(1.0, 1.6)
var _sprite: Sprite2D

func _ready() -> void:
	_sprite = get_parent().get("sprite")

func _process(delta: float) -> void:
	if _sprite == null:
		return
	_tiempo += delta * _velocidad
	# Dos ondas mezcladas: se ve mas natural que un vaiven perfecto.
	_sprite.skew = (sin(_tiempo) + 0.35 * sin(_tiempo * 2.7)) * AMPLITUD
