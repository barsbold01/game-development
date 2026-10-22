extends CollisionObject2D
## ЧИРЖ БОЛДОГ ХЭСЭГ (банз, трамплины ерөнхий класс)
## - Эхэндээ дэлгэцийн дээд "тавиур" дээр хүлээнэ (камерыг дагана).
## - Тоглогч хулганаар чирэхээр дэлхий дээр тогтоно.
## - Газрын түвшинд ойр тавивал газартай тэгшилж "наалдана".
## - Дэлгэцийн зүүн ирмэгээс гарч хоцорвол тавиур руугаа буцна.
## - ТАВИУР РУУ ЗАЙ ХАЛАХГҮЙ: дэлгэцийн ХААНА Ч дарахад дараагийн хэсэг хулганан дээр ирнэ.
## - МАГНИТ: банзыг нүх рүү ойртуулахад нүхэнд яг тохирох байрлалд өөрөө очиж наалдана.

const GROUND_Y: float = preload("res://scripts/world.gd").GROUND_Y
const SNAP_DIST := 20.0   # Газрын түвшингээс хэдэн пикселийн дотор тавьвал наалдах вэ
const MAGNET_X := 30.0    # Нүхний ирмэгээс хэдэн пикселийн зайд банз магнитлах вэ
const MAGNET_Y := 36.0    # Газрын түвшингээс дээш/доош хэдэн пикселийн дотор магнитлах вэ
const PLANK_OVERLAP := 2.0   # Банз нүхний ирмэг дээр хэдэн пиксел гарч хэвтэх вэ
const SPRING_WALL_GAP := 10.0   # Трамплиныг өндөрлөгийн хананаас хэдэн px өмнө тавих вэ

@export var tray_offset := Vector2(28, 24)  # Тавиур дахь байрлал (дэлгэцийн зүүн дээд булангаас)
@export var snap_bottom := false            # true: доод ирмэгээр (трамплин), false: дээд гадаргаар (банз) тэгшилнэ

var in_tray := true
var dragging := false
var drag_offset := Vector2.ZERO
var mouse_world := Vector2.ZERO   # Хулганы сүүлийн байрлал (дэлхийн координатаар)
var camera: Camera2D


func _ready() -> void:
	in_tray = true
	add_to_group("draggable")


func _process(_delta: float) -> void:
	if camera == null:
		camera = get_viewport().get_camera_2d()
		if camera == null:
			return
	var left := camera.global_position.x - 128.0   # Дэлгэцийн зүүн ирмэг (дэлхийн координатаар)

	if dragging:
		var target := mouse_world - drag_offset
		target.x = clampf(target.x, left + 8.0, left + 248.0)
		target.y = clampf(target.y, 22.0, GROUND_Y + 8.0)
		global_position = _magnet(target)
	elif in_tray:
		global_position = Vector2(left, 0.0) + tray_offset
	elif _is_behind_player() or global_position.x < left - 40.0:
		in_tray = true   # Гүйгч давж гарсан хэсгийг шууд тавиурт буцаана — дараагийн нүхэнд бэлэн
		Game.sfx.beep(300, 0.05)

	# Тавиурт байх эсвэл чирэгдэж байхад гүйгчтэй мөргөлдөхгүй
	var active := not in_tray and not dragging
	collision_layer = 1 if active else 0
	collision_mask = 1 if active else 0
	modulate.a = 1.0 if active else 0.75


## Гүйгч энэ хэсгийг бүхэлд нь давж гарсан уу?
func _is_behind_player() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	return player != null and _shape_rect().end.x < player.global_position.x - 12.0


## Хулганаар дарах / тавих.
## Physics picking (_input_event) ашиглахгүй: тэнгэрийн ColorRect хулганыг "залгиж",
## one-way банзыг picking алгасдаг тул өөрсдөө тэгш өнцөгтөөр шалгана.
func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		mouse_world = get_canvas_transform().affine_inverse() * event.position
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		if Game.dragging != null or Game.state != Game.State.PLAY:
			return
		var on_me := _hit_rect().has_point(mouse_world)
		if not on_me and not _is_grab_owner():
			return
		dragging = true
		in_tray = false
		Game.dragging = self
		# Хэсэг дээр нь дарсан бол барьсан цэгээ хадгална; хаа нэгтээ дарсан бол хулганан дээр шууд ирнэ
		drag_offset = mouse_world - global_position if on_me else Vector2.ZERO
		Game.sfx.beep(400, 0.04)
		get_viewport().set_input_as_handled()
	elif dragging:
		dragging = false
		Game.dragging = null
		_snap_to_ground()


## Хулгана хаана ч дарсан бол тавиур дахь дараагийн хэсгийг (нэг л хэсэг) барина.
## Өөр хэсэг дээр дарсан бол тэр хэсэг өөрөө авна — тиймээс энд false.
func _is_grab_owner() -> bool:
	var first: Node = null
	for p in get_tree().get_nodes_in_group("draggable"):
		if p._hit_rect().has_point(mouse_world):
			return false
		if first == null and p.in_tray and not p.dragging:
			first = p
	return first == self


## Банзыг нүх рүү магнитлана: нүх нарийн бол голлуулж, өргөн бол ойр ирмэгийн дээр тавина.
## (Өргөн нүхийг 2 банзаар хаана: нэгийг зүүн, нөгөөг баруун ирмэг дээр.)
## Трамплиныг өндөрлөгийн хананд ойртуулбал хананы яг өмнө газар дээр тавина.
func _magnet(target: Vector2) -> Vector2:
	var world := get_tree().get_first_node_in_group("world")
	if world == null:
		return target
	if snap_bottom:
		return _magnet_spring(target, world)
	var half := _shape_rect().size.x / 2.0
	var top_offset := _shape_rect().position.y - global_position.y   # Банзны дээд ирмэг төвөөс хэдэн px дээр
	var ground_y: float = GROUND_Y - top_offset                      # Дээд ирмэг нь газартай тэгш байх y
	if absf(target.y - ground_y) > MAGNET_Y:
		return target
	var best_x := INF
	var best_d := INF
	for s in world.segments:
		if s.ground:
			continue
		var center: float = s.x + s.w / 2.0
		var d := absf(target.x - center)
		if d > s.w / 2.0 + MAGNET_X or d >= best_d:
			continue
		best_d = d
		if s.w <= 2.0 * half - 8.0:
			best_x = center                                   # Нарийн нүх: голлуулна
		elif target.x < center:
			best_x = s.x - PLANK_OVERLAP + half               # Зүүн ирмэг дээр
		else:
			best_x = s.x + s.w + PLANK_OVERLAP - half         # Баруун ирмэг дээр
	if best_x == INF:
		return target
	return Vector2(best_x, ground_y)


## Трамплин: гүйгч хараахан давж амжаагүй өндөрлөгийн орчимд (хананаас 64px өмнөөс
## өндөрлөгийн төгсгөл хүртэл, ямар ч өндөрт) тавьбал хананы яг өмнө газарт наалдана.
## Ингэснээр хананд гацсан гүйгчийн хөл дор трамплин заавал очиж, үсрээд давна.
func _magnet_spring(target: Vector2, world: Node) -> Vector2:
	var spr := get_node_or_null("Sprite") as Sprite2D
	var bottom := spr.get_rect().end.y if spr else 8.0   # Трамплины доод ирмэг төвөөс хэдэн px доор
	var ground_y: float = GROUND_Y - bottom
	var player := get_tree().get_first_node_in_group("player") as Node2D
	for s in world.segments:
		if s.kind != "high" or (player and player.global_position.x > s.x):
			continue   # Гүйгч аль хэдийн давсан өндөрлөгийг тоохгүй
		if target.x > s.x - 64.0 and target.x < s.x + s.w:
			return Vector2(s.x - SPRING_WALL_GAP, ground_y)
	return target


## Банзыг газрын гадаргатай яг тэгшилнэ — эс тэгвээс гүйгч хажуунаас нь
## мөргөж (one-way тул) нэвт гараад нүхэнд унана.
func _snap_to_ground() -> void:
	var edge := _shape_rect().position.y
	if snap_bottom:
		var spr := get_node_or_null("Sprite") as Sprite2D
		edge = global_position.y + (spr.get_rect().end.y if spr else _shape_rect().end.y - global_position.y)
	if absf(edge - GROUND_Y) <= SNAP_DIST:
		global_position.y += GROUND_Y - edge


## Collision хэлбэрийн дөрвөлжин (дэлхийн координатаар)
func _shape_rect() -> Rect2:
	var col := get_node_or_null("Collision") as CollisionShape2D
	if col and col.shape is RectangleShape2D:
		var size := (col.shape as RectangleShape2D).size
		return Rect2(col.global_position - size / 2.0, size)
	return Rect2(global_position - Vector2(8, 8), Vector2(16, 16))


## Дарж болох дөрвөлжин — жижиг хэсгийг ч амар барихаар бага зэрэг томсгоно
func _hit_rect() -> Rect2:
	var r := _shape_rect()
	var size := r.size.max(Vector2(16, 16)) + Vector2(4, 4)
	return Rect2(r.get_center() - size / 2.0, size)
