class_name Effects
extends Node2D
## ТҮР ЗУУРЫН ЭФФЕКТ — «+1» бичиг, ноосны үүл, салхины зураас.

var wind := Vector2.ZERO
var _items: Array[Dictionary] = []


func text(pos: Vector2, s: String, color: Color) -> void:
	_items.append({"pos": pos, "vel": Vector2(0, -28), "life": 1.0, "text": s, "color": color})


func puff(pos: Vector2, color: Color) -> void:
	for i in 16:
		_items.append({"pos": pos, "vel": Vector2.from_angle(randf() * TAU) * randf_range(20.0, 80.0),
			"life": randf_range(0.4, 0.9), "color": color, "size": randf_range(1.5, 3.0)})


func _process(delta: float) -> void:
	if wind != Vector2.ZERO and randf() < 0.7:
		var start := Vector2(randf() * Field.SIZE.x, randf_range(Field.AREA.position.y, Field.AREA.end.y))
		_items.append({"pos": start, "vel": wind.normalized() * 260.0, "life": 0.5, "streak": true, "color": Color.WHITE})
	for i in range(_items.size() - 1, -1, -1):
		var it := _items[i]
		it["pos"] += it["vel"] * delta
		it["life"] -= delta
		if it["life"] <= 0.0:
			_items.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for it in _items:
		var col: Color = it["color"]
		col.a = clampf(it["life"], 0.0, 1.0)
		if it.has("text"):
			draw_string(ThemeDB.fallback_font, it["pos"], it["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
		elif it.has("streak"):
			col.a *= 0.5
			draw_line(it["pos"], it["pos"] - it["vel"] * 0.08, col, 1.5)
		else:
			draw_circle(it["pos"], it["size"], col)
