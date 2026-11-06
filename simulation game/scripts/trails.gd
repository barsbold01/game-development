class_name Trails
extends Node2D
## МӨР — T товчоор асаана. Хонь бүрийн сүүлийн 4 секундын замыг зурж,
## сүрэг ус шиг хэрхэн урсдагийг харуулна.

var sheep: Array[Sheep] = []


func _ready() -> void:
	visible = false


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	for s in sheep:
		var t := s.trail
		for i in range(1, t.size()):
			draw_line(t[i - 1], t[i], Color(1, 1, 1, 0.45 * i / t.size()), 1.5)
