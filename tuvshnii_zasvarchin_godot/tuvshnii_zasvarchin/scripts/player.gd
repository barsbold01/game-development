extends CharacterBody2D
## ГҮЙГЧ — ТОГЛОГЧ УДИРДДАГГҮЙ!
## Өөрөө баруун тийш гүйнэ. Тоглогчийн ажил бол түүнийг аварч
## замд нь банз, трамплин тавих.

signal died   # Нүхэнд унахад main.gd сонсоно

const GRAVITY := 380.0
const BOUNCE_FORCE := -230.0   # Трамплинаас хэр өндөр үсрэх
const STOMP_FORCE := -170.0    # Цохыг гишгээд дээш ойх хүч
const DEATH_Y := 170.0         # Үүнээс доош унавал үхнэ
const STUCK_WARN := 0.4        # Хананд гацаад хэдэн секундын дараа өргөс ургаж эхлэх вэ
const STUCK_LIMIT := 1.6       # Хэдэн секунд гацвал өргөсөнд хатгуулж үхэх вэ

@onready var sprite: Sprite2D = $Sprite
@onready var alert: Label = $Alert        # Унаж байхад толгой дээр "!" гарна
@onready var dust: CPUParticles2D = $Dust  # Хөлний тоос

var anim_time := 0.0
var blink_time := 0.0   # Дахин төрсний дараа анивчих хугацаа
var stuck_time := 0.0   # Хананд гацсан хугацаа — тоглоом үүрд зогсохоос сэргийлнэ
var wall_spikes: Node2D # Хананаас ургаж гарах өргөс (гүйгчийн дүрсний дээр зурагдана)


func _ready() -> void:
	wall_spikes = Node2D.new()
	wall_spikes.z_index = 1
	wall_spikes.draw.connect(_draw_wall_spikes)
	add_child(wall_spikes)


func _physics_process(delta: float) -> void:
	if Game.state != Game.State.PLAY:
		dust.emitting = false
		return

	# 1. Хөдөлгөөн: тогтмол баруун тийш, доошоо таталцал
	velocity.x = Game.speed
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	move_and_slide()

	# 2. Хөдөлгөөнт дүрс: 2 кадр ээлжилнэ (hero.png дээр hframes = 2)
	anim_time += delta
	sprite.frame = int(anim_time * 8) % 2 if is_on_floor() else 1
	dust.emitting = is_on_floor()
	alert.visible = (not is_on_floor() and velocity.y > 40.0) or is_on_wall()   # Унаж эсвэл хананд гацаж байна
	queue_redraw()   # Хамгаалалтын бөмбөлөг

	# 3б. Хананд гацсан уу? Удаан гацвал хананаас өргөс ургаж гүйгчийг хатгана
	if is_on_wall() and is_on_floor():
		stuck_time += delta
		if stuck_time >= STUCK_LIMIT:
			stuck_time = 0.0
			hurt()
	else:
		stuck_time = 0.0
	wall_spikes.queue_redraw()

	# 3. Анивчих (дахин төрсний дараа)
	if blink_time > 0.0:
		blink_time -= delta
		sprite.visible = int(blink_time * 12) % 2 == 0
	else:
		sprite.visible = true

	# 4. Явсан зайг тэмдэглэх (оноо үүнээс гарна)
	Game.distance = maxf(Game.distance, global_position.x - 40.0)

	# 5. Нүхэнд унасан уу?
	if global_position.y > DEATH_Y:
		died.emit()


## Хамгаалалттай бол гүйгчийг тойруулан цэнхэр бөмбөлөг зурна
func _draw() -> void:
	if not Game.has_shield:
		return
	var r := 11.0 + sin(anim_time * 6.0) * 0.5
	draw_circle(Vector2.ZERO, r, Color(0.45, 0.9, 1.0, 0.2))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(0.55, 0.95, 1.0, 0.9), 1.0)


## Хананы нүүрнээс (гүйгчийн баруун ирмэг) зүүн тийш ургах 3 өргөс
func _draw_wall_spikes() -> void:
	var grow := clampf((stuck_time - STUCK_WARN) / (STUCK_LIMIT - STUCK_WARN), 0.0, 1.0)
	if grow <= 0.0:
		return
	var wall_x := 5.0   # Гүйгчийн хагас өргөн — хана яг энд байна
	for y in [-6.0, -1.0, 4.0]:
		var tri := PackedVector2Array([Vector2(wall_x, y - 2.5), Vector2(wall_x - 8.0 * grow, y), Vector2(wall_x, y + 2.5)])
		wall_spikes.draw_colored_polygon(tri, Color("b8c2cc"))


## Өргөс, цох мөргөхөд дуудагдана. Дахин төрөөд анивчиж байхад гэмтэхгүй.
## Үхсэн бол true буцаана.
func hurt() -> bool:
	if blink_time > 0.0 or Game.state != Game.State.PLAY:
		return false
	died.emit()
	return true


## Цохыг гишгэхэд дуудагдана
func stomp() -> void:
	velocity.y = STOMP_FORCE
	Game.sfx.beep(700, 0.08)


## Трамплин дээр буухад дуудагдана
func bounce() -> void:
	velocity.y = BOUNCE_FORCE
	Game.sfx.beep(520, 0.12)


## Шинэ байрлалд дахин төрүүлнэ
func respawn(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	blink_time = 1.2
	stuck_time = 0.0
