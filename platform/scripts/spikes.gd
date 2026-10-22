extends Area2D
## ӨРГӨС — газар дээр байрлана, хүрвэл гүйгч үхнэ.
## Банз тус болохгүй: трамплинаар дээгүүр нь үсэргэх ёстой.
## Байрлал (position) нь өргөсний зүүн доод булан.

var width := 16.0   # 8px-ийн олон шүд


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width - 4.0, 4.0)   # Ирмэг дээр нь бага зэрэг өршөөнө
	shape.shape = rect
	shape.position = Vector2(width / 2.0, -2.0)
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	for i in int(width / 8.0):
		var x := i * 8.0
		var tri := PackedVector2Array([Vector2(x, 0), Vector2(x + 4.0, -7.0), Vector2(x + 8.0, 0)])
		draw_colored_polygon(tri, Color("b8c2cc"))
		draw_line(Vector2(x + 4.0, -7.0), Vector2(x + 8.0, 0), Color("6b7682"))


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.hurt()
