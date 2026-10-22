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
		_launch(body)


## ХАНАНД ГАЦСАН ГҮЙГЧИЙГ АВРАХ: гүйгч аль хэдийн зогсож байгаа газарт трамплин тавихад
## body_entered дохио найдвартай ирэхгүй (бие нь "орж ирээгүй", аль хэдийн тэнд байсан).
## Тиймээс физик кадр бүрт гүйгч трамплин дээр газарт зогсож байгаа эсэхийг өөрөө шалгана.
func _physics_process(_delta: float) -> void:
	if in_tray or dragging:
		return
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null or not player.is_on_floor():
		return
	if _player_rect().intersects(_shape_rect()):
		_launch(player)


func _launch(body: Node2D) -> void:
	body.bounce()
	sprite.frame = 1   # Шахагдсан кадр
	get_tree().create_timer(0.2).timeout.connect(func() -> void: sprite.frame = 0)
