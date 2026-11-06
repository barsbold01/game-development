class_name Field
extends Node2D
## БЭЛЧЭЭР — өвс, хашаа, бут, голыг зурж, амьтдыг тэдгээрээр нэвтрүүлэхгүй.
## Түвшин бүр setup()-аар өөрийн бут, усыг ачаална.

const SIZE := Vector2(480, 300)
const AREA := Rect2(0, 22, 480, 258)   # HUD-ийн дээд, доод мөрийн хоорондох талбай
const PEN := Rect2(381, 96, 86, 108)   # Хашааны дотор тал
const GATE := [Vector2(380, 122), Vector2(380, 178)]
const GRASS := Color("86c766")
const TUFT := Color("74b556")
const FENCE := Color("7a4e2b")
const WATER := Color("4a8fc9")

## Хана бүр [эхлэл, төгсгөл]. Зүүн ханад хаалганы нүх (y 122–178) үлдээнэ.
var walls := [
	[Vector2(380, 95), Vector2(468, 95)],
	[Vector2(468, 95), Vector2(468, 205)],
	[Vector2(468, 205), Vector2(380, 205)],
	[Vector2(380, 95), Vector2(380, 122)],
	[Vector2(380, 178), Vector2(380, 205)],
]
var bushes: Array[Vector3] = []   # x, y, радиус
var water: Array[Rect2] = []
var _tufts: Array[Vector3] = []


func _ready() -> void:
	for i in 70:
		_tufts.append(Vector3(randf() * SIZE.x, randf() * SIZE.y, randf_range(2.0, 4.0)))


func setup(level: Dictionary) -> void:
	bushes.assign(level["bushes"])
	water.assign(level["water"])
	queue_redraw()


func is_inside(p: Vector2) -> bool:
	return PEN.has_point(p)


func in_water(p: Vector2) -> bool:
	for r in water:
		if r.has_point(p):
			return true
	return false


## Бут, уснаас хол санамсаргүй цэг (зүүн талд)
func spawn_point() -> Vector2:
	for i in 40:
		var p := Vector2(randf_range(40, 200), randf_range(45, 255))
		var ok := not in_water(p)
		for b in bushes:
			if p.distance_to(Vector2(b.x, b.y)) < b.z + 10.0:
				ok = false
		if ok:
			return p
	return Vector2(60, 150)


## Автомат нохой сүргийг хаашаа шахах вэ: голтой бол эхлээд гүүр рүү
func aim_for(p: Vector2) -> Vector2:
	if not water.is_empty() and p.x < 285.0:
		return Vector2(330, 150)
	return Vector2(400, 150) if p.x < 372.0 else Vector2(424, 150)


## Амьтныг хана, бут, ус, дэлгэцийн захаар нэвтрүүлэхгүй, хурдыг нь ойлгоно
func collide(a: Agent, block_gate: bool, block_water: bool) -> void:
	for w in walls:
		_segment(a, w[0], w[1])
	if block_gate:
		_segment(a, GATE[0], GATE[1])
	for b in bushes:
		var c := Vector2(b.x, b.y)
		var off := a.position - c
		var min_d := b.z + a.radius
		if off.length() < min_d and off.length() > 0.0001:
			var n := off.normalized()
			a.position = c + n * min_d
			var vn := a.velocity.dot(n)
			if vn < 0.0:
				a.velocity -= n * vn
	if block_water:
		for r in water:
			_rect(a, r.grow(a.radius))
	var lo := AREA.position + Vector2.ONE * a.radius
	var hi := AREA.end - Vector2.ONE * a.radius
	if a.position.x < lo.x or a.position.x > hi.x:
		a.velocity.x = -a.velocity.x
	if a.position.y < lo.y or a.position.y > hi.y:
		a.velocity.y = -a.velocity.y
	a.position = a.position.clamp(lo, hi)


func _segment(a: Agent, from: Vector2, to: Vector2) -> void:
	var closest := Geometry2D.get_closest_point_to_segment(a.position, from, to)
	var off := a.position - closest
	var d := off.length()
	if d < a.radius and d > 0.0001:
		var n := off / d
		a.position = closest + n * a.radius
		var vn := a.velocity.dot(n)
		if vn < 0.0:
			a.velocity -= n * vn * 1.5


## Тэгш өнцөгт орсон бол хамгийн ойр ирмэг рүү түлхэнэ
func _rect(a: Agent, r: Rect2) -> void:
	var p := a.position
	if not r.has_point(p):
		return
	var left := p.x - r.position.x
	var right := r.end.x - p.x
	var top := p.y - r.position.y
	var bottom := r.end.y - p.y
	var m := minf(minf(left, right), minf(top, bottom))
	if m == left:
		a.position.x = r.position.x
		a.velocity.x = minf(a.velocity.x, 0.0)
	elif m == right:
		a.position.x = r.end.x
		a.velocity.x = maxf(a.velocity.x, 0.0)
	elif m == top:
		a.position.y = r.position.y
		a.velocity.y = minf(a.velocity.y, 0.0)
	else:
		a.position.y = r.end.y
		a.velocity.y = maxf(a.velocity.y, 0.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), GRASS)
	for t in _tufts:
		draw_circle(Vector2(t.x, t.y), t.z, TUFT)
	for r in water:
		draw_rect(r, WATER)
		for y in range(int(r.position.y) + 8, int(r.end.y) - 4, 14):
			draw_line(Vector2(r.position.x + 4, y), Vector2(r.end.x - 6, y + 3), Color(1, 1, 1, 0.25), 1.0)
	if water.size() >= 2:
		# Гүүр: хоёр усны хоорондох зай
		var top := water[0].end.y
		var bottom := water[1].position.y
		for x in range(int(water[0].position.x) - 4, int(water[0].end.x) + 5, 5):
			draw_line(Vector2(x, top), Vector2(x, bottom), Color("9c6b3e"), 4.0)
		draw_line(Vector2(water[0].position.x - 4, top), Vector2(water[0].end.x + 4, top), FENCE, 2.0)
		draw_line(Vector2(water[0].position.x - 4, bottom), Vector2(water[0].end.x + 4, bottom), FENCE, 2.0)
	for b in bushes:
		draw_circle(Vector2(b.x, b.y), b.z, Color("3f7d32"))
		draw_circle(Vector2(b.x - b.z * 0.3, b.y - b.z * 0.3), b.z * 0.55, Color("4f9a3f"))
		draw_circle(Vector2(b.x + b.z * 0.35, b.y + b.z * 0.1), b.z * 0.4, Color("468c38"))
	draw_rect(PEN, Color("c8a56e"))
	for w in walls:
		draw_line(w[0], w[1], FENCE, 4.0)
	for p in [Vector2(380, 95), Vector2(424, 95), Vector2(468, 95), Vector2(468, 205),
			Vector2(424, 205), Vector2(380, 205), Vector2(380, 122), Vector2(380, 178)]:
		draw_circle(p, 4.0, Color("5e3a1e"))
	draw_string(ThemeDB.fallback_font, Vector2(PEN.position.x, 116), "ХАШАА", HORIZONTAL_ALIGNMENT_CENTER, PEN.size.x, 11, Color(1, 1, 1, 0.75))
