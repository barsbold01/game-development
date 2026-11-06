class_name Sheep
extends Agent
## НЭГ ХОНЬ — зөвхөн ойрхон хөршүүдээ харж 5 энгийн дүрмээр хөдөлнө.
## Сүрэг гэж хаана ч бичээгүй: сүргийн зан төлөв эдгээр дүрмээс өөрөө үүснэ.

const SIGHT := 45.0         # Хөршөө харах зай
const PERSONAL := 13.0      # Үүнээс ойр бол түлхэлцэнэ
const FEAR_RADIUS := 85.0   # Нохойноос айж эхлэх зай
const PANIC_SHARE := 0.8    # Сандрал халдах: ойрхон хөршийн айдсын 80% шилжинэ
const CALM_SPEED := 36.0    # Тайван бэлчих хурд
const PANIC_SPEED := 168.0  # Сандарсан үеийн дээд хурд
const TRAIL_LEN := 40       # Мөр: 0.1 сек тутам, 4 секунд

const WOOL := Color("f7f5ef")
const WOOL_BLACK := Color("3a3742")
const WOOL_SCARED := Color("ff9e8c")
const FACE := Color("2b2b33")
## Debug сумны өнгө: ойртох, дагах, зай барих, айх
const FORCE_COLORS: Array[Color] = [Color("4cd97b"), Color("4dabf7"), Color("ffd43b"), Color("ff6b5b")]

var fear := 0.0             # 0 = тайван бэлчинэ, 1 = сандарч гүйнэ
var stubborn := false       # Хар хонь: сүргээ бага дагаж, нохойноос бага айна
var show_forces := false
var in_pen := false
var voice := randf_range(0.9, 1.12)   # Хонь бүрийн дууны өндөр
var alarmed := false        # Энэ удаагийн сандралд аль хэдийн майлсан
var trail := PackedVector2Array()
var _trail_timer := 0.0
var _angle := randf() * TAU
var _forces: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]


## Нэг алхам бодно. threats: Vector3(x, y, айх зай) — нохой ба чононууд.
## Тоонуудыг тоглож байж тааруулсан (px/сек).
func think(flock: Array[Sheep], threats: Array[Vector3], rules: Dictionary, wind: Vector2, delta: float) -> void:
	var center := Vector2.ZERO
	var heading := Vector2.ZERO
	var push := Vector2.ZERO
	var panic := 0.0
	var n := 0
	for other in flock:
		if other == self:
			continue
		var d := position.distance_to(other.position)
		if d < SIGHT:
			n += 1
			center += other.position
			heading += other.velocity
			if d < SIGHT * 0.6:
				panic = maxf(panic, other.fear)
			if d < PERSONAL:
				push += (position - other.position) / maxf(d, 0.01) * (PERSONAL - d) / PERSONAL

	# 4. Айх: аюул бүрээс холдоно, ойр байх тусам хүчтэй
	var flee := Vector2.ZERO
	var scared := 0.0
	if rules["fear"]:
		for t in threats:
			var away := position - Vector2(t.x, t.y)
			var dist := maxf(away.length(), 0.01)
			var s := clampf(1.0 - dist / t.z, 0.0, 1.0)
			flee += away / dist * s * 1260.0
			scared = maxf(scared, s)
	if stubborn:
		flee *= 0.5
	# 5. Сандрал халдах: айсан хөршөөс айдас дамжина — сандрал давалгаа шиг тархана
	var caught := panic * PANIC_SHARE if rules["contagion"] and panic > 0.3 else 0.0
	fear = maxf(fear * pow(0.97, delta * 60.0), maxf(scared, caught))
	if wind != Vector2.ZERO:
		fear = maxf(fear, 0.2)

	var social := 0.3 if stubborn else 1.0
	var cohesion := Vector2.ZERO
	var alignment := Vector2.ZERO
	if n > 0:
		cohesion = (center / n - position) * 7.2 * (1.0 + fear * 3.0) * social   # 1. Ойртох: хөршүүдийнхээ төв рүү
		alignment = (heading / n - velocity) * 2.4 * (0.3 + fear) * social       # 2. Дагах: хөршүүдтэйгээ ижил чиглэлд
	var separation := push * 900.0                                               # 3. Зай барих: хэт ойрхоноос холдох
	if not rules["cohesion"]:
		cohesion = Vector2.ZERO
	if not rules["alignment"]:
		alignment = Vector2.ZERO
	if not rules["separation"]:
		separation = Vector2.ZERO
	_forces = [cohesion, alignment, separation, flee]

	var wander := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 110.0
	velocity += (cohesion + alignment + separation + flee + wander + wind) * delta
	velocity *= pow(0.93, delta * 60.0)
	velocity = velocity.limit_length(CALM_SPEED + fear * (PANIC_SPEED - CALM_SPEED))
	position += velocity * delta
	if velocity.length() > 7.0:
		_angle = velocity.angle()

	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = 0.1
		trail.append(position)
		if trail.size() > TRAIL_LEN:
			trail.remove_at(0)
	queue_redraw()


## Нохой хуцахад: ойрхон байвал шууд сандарч зугтана
func scare(from: Vector2, range_px: float) -> void:
	var away := position - from
	if away.length() < range_px:
		fear = 1.0
		velocity += away.normalized() * 120.0


func _draw() -> void:
	var dir := Vector2.from_angle(_angle)
	# Айсан хонь улайна — сандрал хэрхэн тархаж байгааг нүдээр харна
	var wool := (WOOL_BLACK if stubborn else WOOL).lerp(WOOL_SCARED, clampf((fear - 0.2) / 0.8, 0.0, 1.0) * 0.85)
	draw_circle(-dir * 3.0, 5.0, wool)
	draw_circle(Vector2.ZERO, 6.5, wool)
	draw_circle(dir * 6.5, 3.0, FACE)
	if fear > 0.6:
		draw_string(ThemeDB.fallback_font, Vector2(-2, -10), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e8452c"))
	if show_forces:
		draw_arc(Vector2.ZERO, SIGHT, 0.0, TAU, 32, Color(1, 1, 1, 0.1), 1.0)
		for i in _forces.size():
			var f := _forces[i] * 0.15
			if f.length() > 1.0:
				draw_line(Vector2.ZERO, f.limit_length(30.0), FORCE_COLORS[i], 2.0)
