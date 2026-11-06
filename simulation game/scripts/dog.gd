class_name Dog
extends Node2D
## НОХОЙ — тоглож байх үед хулганыг дагана. Хуцахад ойрхон хонинууд сандарна.
## Цэс дээр main.gd `target`-ийг нь өөрөө тавьж, автоматаар хонь хариулна.

const SPEED := 204.0
const BARK_RADIUS := 150.0
const BARK_COOLDOWN := 2.0
const BROWN := Color("7a4a2a")
const START := Vector2(30, 150)

var active := false         # true үед хулганыг дагана
var show_fear := false      # D товч: хонь айж эхлэх тойргийг харуулна
var target := START
var _cooldown := 0.0
var _ring := 0.0            # Хуцалтын цагираг: 1 → 0 болж тэлнэ
var _angle := 0.0


func _physics_process(delta: float) -> void:
	if active:
		target = get_global_mouse_position()
	var to := target - position
	if to.length() > 0.5:
		position += to.normalized() * minf(to.length(), SPEED * delta)
		_angle = to.angle()
	position = position.clamp(Field.AREA.position + Vector2(6, 6), Field.AREA.end - Vector2(6, 6))
	_cooldown = maxf(_cooldown - delta, 0.0)
	_ring = maxf(_ring - delta * 2.5, 0.0)
	queue_redraw()


func bark() -> bool:
	if _cooldown > 0.0:
		return false
	_cooldown = BARK_COOLDOWN
	_ring = 1.0
	return true


func bark_ready() -> bool:
	return _cooldown <= 0.0


func reset() -> void:
	position = START
	target = START
	_cooldown = 0.0
	_ring = 0.0


func _draw() -> void:
	if show_fear:
		draw_circle(Vector2.ZERO, Sheep.FEAR_RADIUS, Color(1, 0.42, 0.36, 0.12))
		draw_arc(Vector2.ZERO, Sheep.FEAR_RADIUS, 0.0, TAU, 48, Color(1, 0.42, 0.36, 0.6), 1.5)
	if _ring > 0.0:
		draw_arc(Vector2.ZERO, 10.0 + (BARK_RADIUS - 10.0) * (1.0 - _ring), 0.0, TAU, 48, Color(1, 1, 1, _ring * 0.8), 2.0)
	var dir := Vector2.from_angle(_angle)
	draw_line(-dir * 8.0, -dir * 14.0 + dir.orthogonal() * 3.0, BROWN, 2.5)
	draw_set_transform(Vector2.ZERO, _angle, Vector2(1.0, 0.7))
	draw_circle(Vector2.ZERO, 9.0, BROWN)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(dir * 9.0, 4.5, BROWN)
	draw_circle(dir * 12.0, 1.8, Color("1b1b1b"))
	# Хуцах дахин бэлэн болох явц
	if _cooldown > 0.0:
		draw_arc(Vector2.ZERO, 14.0, -PI / 2, -PI / 2 + TAU * (1.0 - _cooldown / BARK_COOLDOWN), 24, Color(1, 1, 1, 0.7), 1.5)
