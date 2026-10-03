extends Node2D

# Componente generico para arrastrar un Node2D con mouse/touch (el proyecto
# emula mouse desde touch, ver project.godot). Emite `agarrado` al tomarlo.
# Se agarra dentro de `radio_agarre`, y al soltar SIEMPRE se acomoda con una
# animacion corta: si quedo a `radio_destino` o menos de `destino`, se ajusta
# ahi y emite `soltado_en_destino`; si no, vuelve a la ultima posicion valida
# y emite `soltado_fuera`. Nunca se queda flotando donde se solto.
#
# `destino` se puede reasignar en tiempo de ejecucion (ej: primero arrastrar
# hacia afuera, despues devolver al mismo lugar) para reusar la misma pieza
# en dos pasos distintos de un minijuego.

signal agarrado
signal soltado_en_destino
signal soltado_fuera

@export var destino: Node2D
@export var radio_destino: float = 50.0
@export var radio_agarre: float = 60.0
@export var habilitado: bool = true
@export var tiempo_acomodo: float = 0.2

var _arrastrando: bool = false
var _offset: Vector2
var _posicion_original: Vector2

# Mientras se acomoda (tween post-suelte) no se puede volver a agarrar: evita
# un segundo arrastre a mitad de la animacion de vuelta.
var _acomodando: bool = false

func _ready() -> void:
	_posicion_original = global_position

func _input(event: InputEvent) -> void:
	if not habilitado and not _arrastrando:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if habilitado and not _acomodando and global_position.distance_to(event.position) <= radio_agarre:
				_arrastrando = true
				_offset = global_position - event.position
				z_index = 100
				get_viewport().set_input_as_handled()
				agarrado.emit()
		elif _arrastrando:
			_arrastrando = false
			z_index = 0
			_evaluar_soltado()
	elif event is InputEventMouseMotion and _arrastrando:
		global_position = event.position + _offset

func _evaluar_soltado() -> void:
	_acomodando = true
	if destino and global_position.distance_to(destino.global_position) <= radio_destino:
		await _acomodar_en(destino.global_position)
		_acomodando = false
		soltado_en_destino.emit()
	else:
		await _acomodar_en(_posicion_original)
		_acomodando = false
		soltado_fuera.emit()

# Anima la vuelta a `pos` (destino o ultima posicion valida) en vez de
# teletransportarse: asi la pieza siempre "se acomoda" al soltarla.
func _acomodar_en(pos: Vector2) -> void:
	_posicion_original = pos
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", pos, tiempo_acomodo)
	await tween.finished
