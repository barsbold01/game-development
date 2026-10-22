extends Node2D
## ҮНДСЭН СЦЕН — камер, гүйгч, дэлхийг холбоно. Эхлэх/дахин тоглохыг удирдана.

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera
@onready var world: Node2D = $World


func _ready() -> void:
	Game.reset()
	player.died.connect(_on_player_died)
	_follow_camera()


func _process(_delta: float) -> void:
	_follow_camera()


## Камер гүйгчийн урд талыг (баруун) илүү харуулна — тоглогч нүхийг урьдчилж харна
func _follow_camera() -> void:
	camera.position = Vector2(player.position.x + 80.0, 72.0)


## Дарах эсвэл Space: эхлүүлэх / дахин эхлүүлэх
func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) or event.is_action_pressed("ui_accept")
	if not pressed:
		return
	match Game.state:
		Game.State.MENU:
			Game.start()
		Game.State.OVER:
			get_tree().reload_current_scene()


func _on_player_died() -> void:
	if Game.use_shield():   # Хамгаалалт амийг авч үлдэнэ — зөвхөн аюулгүй газар дахин төрнө
		player.respawn(world.safe_position_after(player.global_position.x))
		return
	Game.lose_life()
	if Game.state == Game.State.PLAY:
		player.respawn(world.safe_position_after(player.global_position.x))
