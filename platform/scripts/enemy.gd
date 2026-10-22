extends Area2D
## ЦОХ (дайсан) — өөрийн газар дээр нааш цааш алхана.
## Хажуунаас мөргөвөл гүйгч үхнэ. Трамплинаар үсэрч дээрээс нь буувал цох үхэж урамшуулал өгнө.
## Байрлал (position) нь цохны доод голын цэг.

const SPEED := 18.0
const STOMP_BONUS := 40

var min_x := 0.0   # Алхах хязгаар (эцэг node-ийн координатаар)
var max_x := 0.0
var dir := -1.0    # Эхлээд гүйгч рүү (зүүн тийш) алхана
var t := 0.0


func _ready() -> void:
	add_to_group("hazard")   # Трамплины PERFECT: саадын өмнө тавьсан эсэхийг шалгана
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 8)
	shape.shape = rect
	shape.position = Vector2(0, -4)
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if Game.state != Game.State.PLAY:
		return
	t += delta
	position.x += dir * SPEED * delta
	if position.x < min_x:
		position.x = min_x
		dir = 1.0
	elif position.x > max_x:
		position.x = max_x
		dir = -1.0
	queue_redraw()


func _draw() -> void:
	var step := int(t * 8.0) % 2   # Хөл ээлжлэн хөдөлнө
	draw_rect(Rect2(-5, -2, 2, 2 - step), Color("2f3542"))
	draw_rect(Rect2(3, -2, 2, 1 + step), Color("2f3542"))
	draw_rect(Rect2(-6, -8, 12, 6), Color("8e2b2b"))      # Хуяг
	draw_rect(Rect2(-4, -8, 6, 2), Color("c44545"))       # Гялбаа
	draw_rect(Rect2(dir * 6.0 - 2.0, -6, 4, 4), Color("2f3542"))   # Толгой
	draw_rect(Rect2(dir * 6.0 - 0.5 + dir, -5, 1, 1), Color.WHITE)  # Нүд


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	# Гүйгч дээрээс унаж ирсэн бол — гишгэж ялна
	if body.velocity.y > 0.0 and body.global_position.y < global_position.y - 10.0:
		body.stomp()
		Game.add_bonus(STOMP_BONUS)
		queue_free()
	elif body.hurt():
		queue_free()   # Мөргөсөн цох алга болно — дахин төрөхөд саад болохгүй
