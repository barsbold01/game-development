extends "res://scripts/draggable.gd"
## ТРАМПЛИН — чирж болдог хэсэг (draggable.gd-г өвлөнө).
## Гүйгч дээрээс нь буухад өндөрт шиднэ.

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	super()
	connect("body_entered", _on_body_entered)   # Area2D-ийн дохио (эх класс нь CollisionObject2D тул нэрээр холбоно)


func _on_body_entered(body: Node2D) -> void:
	# Зөвхөн гүйгч, зөвхөн доошоо унаж байхад, зөвхөн чирээгүй үед
	if body.is_in_group("player") and body.velocity.y >= 0.0 and not dragging:
		body.bounce()
		sprite.frame = 1   # Шахагдсан кадр
		get_tree().create_timer(0.2).timeout.connect(func() -> void: sprite.frame = 0)
