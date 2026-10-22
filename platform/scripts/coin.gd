extends Area2D
## ЗООС — гүйгч хүрэхэд цуглуулагдана.
## Хангалттай цуглуулбал нэг удаагийн хамгаалалт авна (game.gd → add_coin).
## Зургийг кодоор зурна (sprite файлгүй).

const RADIUS := 5.0

var t := 0.0


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	t = randf() * TAU   # Бүх зоос нэгэн зэрэг эргэхгүй


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


## Эргэж буй мэт: хэвтээ чиглэлд нарийсч өргөснө
func _draw() -> void:
	var sx := maxf(0.25, absf(cos(t * 3.0)))
	draw_set_transform(Vector2(0, sin(t * 2.0)), 0.0, Vector2(sx, 1.0))
	draw_circle(Vector2.ZERO, 4.0, Color("c98a1b"))
	draw_circle(Vector2.ZERO, 3.0, Color("ffd93d"))
	draw_rect(Rect2(-0.5, -2.0, 1.0, 4.0), Color("fff3b0"))


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		Game.add_coin()
		set_deferred("monitoring", false)
		queue_free()
