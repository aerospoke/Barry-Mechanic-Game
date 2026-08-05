extends CharacterBody2D

const SPEED = 310.0

const ZONE_MAP = {
	"Aceites": "oils",
	"Filters": "filters",
	"Lights": "lights",
	"Keys": "keys"
}

const ZONE_TEXTURES = {
	"oils": preload("res://objetos/work1.png"),
	"filters": preload("res://objetos/airFlow5.png"),
	"lights": preload("res://objetos/light5.png"),
	"keys": preload("res://objetos/boxKeys.png"),
}

var tiene_item: bool = false
var zona_actual: String = ""
var en_search_work: bool = false

@onready var animation = $MovementPlayer
@onready var item_hand = $ItemHandsPlayer
@onready var searchwork_ui = get_parent().get_node("CanvasLayer/SearchWorkUI")

func _ready() -> void:
	var interaction_zone = get_parent().get_node("InteractionZone")
	for child in interaction_zone.get_children():
		if child is Area2D and child.name in ZONE_MAP:
			child.body_entered.connect(_on_zone_entered.bind(child))
			child.body_exited.connect(_on_zone_exited.bind(child))
		elif child is Area2D and child.name == "SearchWork":
			child.body_entered.connect(_on_search_work_entered.bind(child))
			child.body_exited.connect(_on_search_work_exited.bind(child))

func _physics_process(_delta: float) -> void:
	velocity = Vector2.ZERO

	if Input.is_action_just_pressed("ui_accept"):
		interactuar()

	var sufijo = "-pickup" if tiene_item else ""
	var dir = Input.get_vector("left", "right", "up", "down")

	if dir.length() > 0:
		if abs(dir.x) > abs(dir.y):
			if dir.x > 0:
				velocity.x = SPEED
				animation.play("right" + sufijo)
				item_hand.position = Vector2(50, -30)
				item_hand.z_index = 1
			else:
				velocity.x = -SPEED
				animation.play("left" + sufijo)
				item_hand.position = Vector2(-50, -30)
				item_hand.z_index = 1
		else:
			if dir.y > 0:
				velocity.y = SPEED
				animation.play("down" + sufijo)
				item_hand.position = Vector2(5, -37)
				item_hand.z_index = 1
			else:
				velocity.y = -SPEED
				animation.play("up" + sufijo)
				item_hand.position = Vector2(0, -25)
				item_hand.z_index = -1
	else:
		animation.stop()
		animation.play("down" + sufijo)
		item_hand.position = Vector2(5, -35)
		item_hand.z_index = 1

	move_and_slide()

func interactuar() -> void:
	if en_search_work and not tiene_item:
		searchwork_ui.open()
		return

	if zona_actual != "" and not tiene_item:
		tiene_item = true
		item_hand.visible = true

		if ZONE_TEXTURES.has(zona_actual):
			item_hand.texture = ZONE_TEXTURES[zona_actual]

	elif tiene_item:
		tiene_item = false
		item_hand.visible = false

func _on_zone_entered(body: Node2D, zone: Area2D) -> void:
	if body == self:
		zona_actual = ZONE_MAP[zone.name]

func _on_zone_exited(body: Node2D, zone: Area2D) -> void:
	if body == self and zona_actual == ZONE_MAP[zone.name]:
		zona_actual = ""

func _on_search_work_entered(body: Node2D, _zone: Area2D) -> void:
	if body == self:
		en_search_work = true

func _on_search_work_exited(body: Node2D, _zone: Area2D) -> void:
	if body == self:
		en_search_work = false
