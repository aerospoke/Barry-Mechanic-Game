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
#
# Trae su propia animacion: crece un poco al agarrarlo, rebota al acomodarse
# en el destino y tiembla (como diciendo "no") si se solto en otro lado.

signal agarrado
signal soltado_en_destino
signal soltado_fuera

@export var destino: Node2D
@export var radio_destino: float = 50.0
@export var radio_agarre: float = 60.0
@export var habilitado: bool = true
@export var tiempo_acomodo: float = 0.2
# Cuanto crece la pieza mientras se arrastra.
@export var escala_agarre: float = 1.15

var _arrastrando: bool = false
var _offset: Vector2
var _posicion_original: Vector2
var _escala_base: Vector2
var _tween_escala: Tween

# Mientras se acomoda (tween post-suelte) no se puede volver a agarrar: evita
# un segundo arrastre a mitad de la animacion de vuelta.
var _acomodando: bool = false

func _ready() -> void:
	_posicion_original = global_position
	_escala_base = scale

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
				_animar_escala(_escala_base * escala_agarre, 0.12)
				agarrado.emit()
		elif _arrastrando:
			_arrastrando = false
			z_index = 0
			_animar_escala(_escala_base, 0.15)
			_evaluar_soltado()
	elif event is InputEventMouseMotion and _arrastrando:
		global_position = event.position + _offset

# Para piezas que se mueven solas (ej. la cinta del minijuego de reciclaje):
# libre() dice si se la puede mover sin pelear con el arrastre o el acomodo,
# y fijar_base() cambia el lugar al que vuelve si se suelta fuera.
func libre() -> bool:
	return not _arrastrando and not _acomodando

func fijar_base(pos: Vector2) -> void:
	_posicion_original = pos

func _evaluar_soltado() -> void:
	_acomodando = true
	if destino and global_position.distance_to(destino.global_position) <= radio_destino:
		await _acomodar_en(destino.global_position)
		_acomodando = false
		_rebotar()
		soltado_en_destino.emit()
	else:
		await _acomodar_en(_posicion_original)
		_acomodando = false
		_negar()
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

func _animar_escala(objetivo: Vector2, duracion: float) -> void:
	if _tween_escala:
		_tween_escala.kill()
	_tween_escala = create_tween()
	_tween_escala.set_trans(Tween.TRANS_BACK)
	_tween_escala.set_ease(Tween.EASE_OUT)
	_tween_escala.tween_property(self, "scale", objetivo, duracion)

# Aplastado corto al caer en su lugar.
func _rebotar() -> void:
	if _tween_escala:
		_tween_escala.kill()
	_tween_escala = create_tween()
	_tween_escala.tween_property(self, "scale", _escala_base * Vector2(1.2, 0.8), 0.07)
	_tween_escala.tween_property(self, "scale", _escala_base, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Movimiento de "no" (rotacion de lado a lado) al soltarse en otro lado.
func _negar() -> void:
	var tween := create_tween()
	for angulo in [0.25, -0.25, 0.15, -0.15, 0.0]:
		tween.tween_property(self, "rotation", angulo, 0.05)
