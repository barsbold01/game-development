class_name Wolf
extends Agent
## ЧОНО — хашаанаас гадуурх хамгийн ойр хонийг агнана. Нохой ойртох эсвэл
## хуцахад айж зугтана. Хонь барьвал цадаж хэсэг хугацаанд тайван тэнэнэ.
## Хонинууд чоноос нохойноос ч илүү холоос айдаг (FEAR_RADIUS).

enum Mode { PROWL, HUNT, FLEE }

const PROWL_SPEED := 45.0
const HUNT_SPEED := 120.0
const FLEE_SPEED := 200.0
const DOG_FEAR := 70.0      # Нохой үүнээс ойртвол зугтана
const CATCH := 10.0
const FEAR_RADIUS := 100.0  # Хонь чоноос айж эхлэх зай
const FUR := Color("6f7580")
const FUR_DARK := Color("4b5059")

var mode := Mode.PROWL
var heard_mode := Mode.PROWL   # Sounds хамгийн сүүлд дуугаргасан төлөв
var show_target := false
var _timer := 3.0           # PROWL ба FLEE үргэлжлэх хугацаа
var _wander := Vector2.LEFT
var _target := Vector2.INF
var _angle := PI


func _init() -> void:
	radius = 7.0


## Нэг алхам. Барьсан хонио буцаана, бариагүй бол null.
func think(sheep: Array[Sheep], dog_pos: Vector2, field: Field, delta: float) -> Sheep:
	_timer -= delta
	var from_dog := position - dog_pos
	if from_dog.length() < DOG_FEAR and mode != Mode.FLEE:
		flee()
	var want := Vector2.ZERO
	var speed := PROWL_SPEED
	var caught: Sheep = null
	_target = Vector2.INF
	match mode:
		Mode.FLEE:
			want = from_dog.normalized()
			speed = FLEE_SPEED
			if _timer <= 0.0:
				mode = Mode.PROWL
				_timer = 2.0
		Mode.PROWL:
			_wander = _wander.rotated(randf_range(-2.0, 2.0) * delta)
			if not Field.AREA.grow(-30.0).has_point(position):
				_wander = (Field.AREA.get_center() - position).normalized()
			want = _wander
			if _timer <= 0.0:
				mode = Mode.HUNT
		Mode.HUNT:
			var prey := _nearest(sheep, field)
			if prey == null:
				mode = Mode.PROWL
				_timer = 2.0
			else:
				_target = prey.position
				var to := prey.position - position
				want = to.normalized()
				speed = HUNT_SPEED
				if to.length() < CATCH + prey.radius:
					caught = prey
					mode = Mode.PROWL
					_timer = 5.0   # Цадсан
	if field.in_water(position):
		speed *= 0.5   # Чоно сэлж чадна, гэхдээ удаан
	velocity = velocity.lerp(want * speed, minf(1.0, 4.0 * delta))
	position += velocity * delta
	if velocity.length() > 5.0:
		_angle = velocity.angle()
	queue_redraw()
	return caught


func flee() -> void:
	mode = Mode.FLEE
	_timer = 2.5


func _nearest(sheep: Array[Sheep], field: Field) -> Sheep:
	var best: Sheep = null
	var best_d := INF
	for s in sheep:
		if field.is_inside(s.position):
			continue
		var d := position.distance_squared_to(s.position)
		if d < best_d:
			best_d = d
			best = s
	return best


func _draw() -> void:
	if show_target and _target != Vector2.INF:
		draw_dashed_line(Vector2.ZERO, _target - position, Color(1, 0.42, 0.36, 0.8), 1.5, 4.0)
	if show_target:
		draw_arc(Vector2.ZERO, FEAR_RADIUS, 0.0, TAU, 48, Color(1, 0.42, 0.36, 0.35), 1.0)
	var dir := Vector2.from_angle(_angle)
	var side := dir.orthogonal()
	draw_line(-dir * 9.0, -dir * 17.0 + side * 2.0, FUR_DARK, 3.0)
	draw_set_transform(Vector2.ZERO, _angle, Vector2(1.0, 0.62))
	draw_circle(Vector2.ZERO, 10.5, FUR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(dir * 10.0, 5.0, FUR)
	draw_circle(dir * 8.0 + side * 3.5, 2.2, FUR_DARK)
	draw_circle(dir * 8.0 - side * 3.5, 2.2, FUR_DARK)
	var eye := Color("ff5a3c") if mode == Mode.HUNT else Color("ffd43b")
	draw_circle(dir * 12.0 + side * 1.8, 1.1, eye)
	draw_circle(dir * 12.0 - side * 1.8, 1.1, eye)
