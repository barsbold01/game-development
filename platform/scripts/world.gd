extends Node2D
## ДЭЛХИЙ ҮҮСГЭГЧ — газар, нүх, саад, зоосыг тоглоомын явцад автоматаар үүсгэнэ.
## Камерын урд талд шинэ хэсэг нэмж, ард хоцорсныг устгана (endless runner).
## Саадууд аажмаар нэмэгдэнэ: нүх → өндөрлөг → өргөс → цох.

const GROUND_Y := 112.0
const STEP_H := 16.0                # Өндөрлөгийн өндөр — трамплингүйгээр гарч чадахгүй
const GROUND_TEX := preload("res://sprites/ground.png")
const PIT_TEX := preload("res://sprites/pit.png")
const Coin := preload("res://scripts/coin.gd")
const Spikes := preload("res://scripts/spikes.gd")
const Enemy := preload("res://scripts/enemy.gd")

# Хэдэн пиксел явсны дараа шинэ саад гарч эхлэх вэ
const HIGH_FROM := 500.0
const SPIKES_FROM := 1000.0
const ENEMY_FROM := 1600.0

## Хэсэг бүр: {x, w, ground, kind ("ground"/"high"/"pit"), top, node, scored, bonus, safe_from}
## top: гадаргын y, bonus: амьд давбал өгөх оноо, safe_from: дахин төрж болох хамгийн бага x (өргөсний ард)
var segments: Array[Dictionary] = []
var next_x := -64.0
var rng := RandomNumberGenerator.new()
var camera: Camera2D
var player: Node2D
var introduced := {}   # Шинэ саадыг анх удаа гаргахад нэг удаа тайлбарлана


func _ready() -> void:
	add_to_group("world")
	rng.randomize()
	_add_ground(next_x, 280.0, false)   # Эхний аюулгүй газар
	player = get_tree().get_first_node_in_group("player")


func _process(_delta: float) -> void:
	if camera == null:
		camera = get_viewport().get_camera_2d()
		if camera == null:
			return
	var left := camera.global_position.x - 128.0
	var right := camera.global_position.x + 128.0

	# Урд тал: дэлгэц дүүрэх хүртэл шинэ хэсэг үүсгэнэ
	while next_x < right + 64.0:
		_spawn_next()

	# Ар тал: хоцорсон хэсгийг устгана
	for s in segments.duplicate():
		if s.x + s.w < left - 64.0:
			s.node.queue_free()
			segments.erase(s)

	_check_bonus()


## Газрын дараа нүх эсвэл өндөрлөг, тэдгээрийн дараа заавал энгийн газар.
## Ингэснээр нүхний хоёр ирмэг үргэлж GROUND_Y түвшинд байж банз магнитлана.
func _spawn_next() -> void:
	var last: Dictionary = segments.back()
	if last.kind != "ground":
		_add_ground(next_x, rng.randf_range(110.0, 220.0))
	elif Game.distance >= HIGH_FROM and rng.randf() < 0.3:
		_add_high(next_x, rng.randf_range(48.0, 96.0))
	else:
		# Хамгийн өргөн нүх = 92px: 2 банз (2×48 = 96) заавал хүрэлцэнэ
		var w := 36.0 + minf(40.0, Game.distance / 15.0) + rng.randf_range(0.0, 16.0)
		_add_pit(next_x, w)


func _add_ground(x: float, w: float, decorate := true) -> void:
	var after_high: bool = not segments.is_empty() and segments.back().kind == "high"
	var seg := _add_solid(x, w, GROUND_Y, "ground")
	if after_high:
		_coin_row(seg.node, w / 2.0, -8.0, 3)   # Өндөрлөгөөс буусны дараа амрах газар — саадгүй
	elif decorate:
		_decorate_ground(seg)


## Өндөрлөг: гүйгч хананд нь гацна — урд нь трамплин тавьж гаргана. Дээр нь зоос байна.
func _add_high(x: float, w: float) -> void:
	_introduce("high", "ШИНЭ: ӨНДӨРЛӨГ — трамплин тавь!")
	var top := GROUND_Y - STEP_H
	var seg := _add_solid(x, w, top, "high")
	seg.bonus = 30
	# Доод хэсгийг шороогоор дүүргэнэ (tile-ийн доод хагас)
	var dirt := _tiled_sprite(GROUND_TEX, w, STEP_H)
	dirt.region_rect.position.y = 16.0
	dirt.position.y = 32.0
	seg.node.add_child(dirt)
	_coin_row(seg.node, w / 2.0, -8.0, 2)


func _add_pit(x: float, w: float) -> void:
	var spr := _tiled_sprite(PIT_TEX, w)
	spr.position = Vector2(x, GROUND_Y)
	add_child(spr)
	segments.append(_segment(x, w, "pit", GROUND_Y, spr, 50))
	next_x = x + w
	# Нүхний дээр зоос: трамплинаар нүхийг дээгүүр нь үсэрвэл авна (эрсдэлтэй ч ашигтай)
	if Game.distance >= 200.0 and rng.randf() < 0.5:
		_coin_arc(spr, w / 2.0, -52.0)


## Газар/өндөрлөгийн хатуу бие (StaticBody2D) + зураг. top = гадаргын y.
func _add_solid(x: float, w: float, top: float, kind: String) -> Dictionary:
	var body := StaticBody2D.new()
	body.position = Vector2(x, top)
	var h := GROUND_Y + 32.0 - top   # Дэлгэцийн доод ирмэг хүртэл

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	shape.shape = rect
	shape.position = Vector2(w / 2.0, h / 2.0)
	body.add_child(shape)

	body.add_child(_tiled_sprite(GROUND_TEX, w))
	add_child(body)
	var seg := _segment(x, w, kind, top, body, 0)
	segments.append(seg)
	next_x = x + w
	return seg


func _segment(x: float, w: float, kind: String, top: float, node: Node2D, bonus: int) -> Dictionary:
	return {"x": x, "w": w, "ground": kind != "pit", "kind": kind, "top": top, "node": node,
		"scored": false, "bonus": bonus, "safe_from": -INF}


## Энгийн газар дээр: цох, өргөс эсвэл амархан зоосны эгнээ
func _decorate_ground(seg: Dictionary) -> void:
	var w: float = seg.w
	var roll := rng.randf()
	if Game.distance >= ENEMY_FROM and w >= 140.0 and roll < 0.3:
		_introduce("enemy", "ШИНЭ: ЦОХ — трамплинаар дээрээс нь гишгэ!")
		var e := Enemy.new()
		e.position = Vector2(w * 0.7, 0.0)
		e.min_x = 48.0
		e.max_x = w - 12.0
		seg.node.add_child(e)
	elif Game.distance >= SPIKES_FROM and w >= 120.0 and roll < 0.6:
		_introduce("spikes", "ШИНЭ: ӨРГӨС — трамплинаар үсэргэ!")
		var sp := Spikes.new()
		sp.width = 16.0 if rng.randf() < 0.6 else 32.0
		sp.position = Vector2(rng.randf_range(72.0, w - 40.0 - sp.width), 0.0)
		seg.node.add_child(sp)
		seg.bonus = 30
		seg.safe_from = seg.x + sp.position.x + sp.width + 8.0
		_coin_arc(seg.node, sp.position.x + sp.width / 2.0, -44.0)
	elif rng.randf() < 0.45:
		_coin_row(seg.node, w / 2.0, -8.0, 3)   # Явган хүрэх өндөрт — хялбар зоос


## Хэвтээ эгнээ зоос (cx, y — эцэг node-ийн координатаар)
func _coin_row(parent: Node2D, cx: float, y: float, count: int) -> void:
	for i in count:
		_coin(parent, Vector2(cx + (i - (count - 1) / 2.0) * 12.0, y))


## Нуман хэлбэрийн 3 зоос — трамплины үсрэлтийн замд
func _coin_arc(parent: Node2D, cx: float, top_y: float) -> void:
	_coin(parent, Vector2(cx - 14.0, top_y + 8.0))
	_coin(parent, Vector2(cx, top_y))
	_coin(parent, Vector2(cx + 14.0, top_y + 8.0))


func _coin(parent: Node2D, pos: Vector2) -> void:
	var c := Coin.new()
	c.position = pos
	parent.add_child(c)


## Шинэ саадыг анх удаа гаргахад дэлгэц дээр тайлбар харуулна
func _introduce(key: String, text: String) -> void:
	if not introduced.has(key):
		introduced[key] = true
		Game.message.emit(text)


## 16px-ийн tile-ийг хүссэн өргөнөөр давтаж зурдаг Sprite2D
func _tiled_sprite(tex: Texture2D, w: float, h := 32.0) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.region_enabled = true
	spr.region_rect = Rect2(0, 0, w, h)
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	return spr


## Нүх, өндөрлөг, өргөсийг амьд давсан бол урамшуулал өгнө
func _check_bonus() -> void:
	if player == null or Game.state != Game.State.PLAY:
		return
	for s in segments:
		if s.bonus > 0 and not s.scored and player.global_position.x > s.x + s.w:
			s.scored = true
			Game.add_bonus(s.bonus)


## Үхсэний дараа дахин төрөх аюулгүй цэг: дараагийн газар (өргөсний ард).
## Унасан/мөргөсөн саадад урамшуулал өгөхгүй — алгассан хэсгүүдийг "scored" болгоно.
func safe_position_after(px: float) -> Vector2:
	var pos := Vector2(px, GROUND_Y - 12.0)
	for s in segments:
		if not s.ground:
			continue
		var x := maxf(maxf(s.x + 12.0, px), s.safe_from)
		if x < s.x + s.w - 12.0:
			pos = Vector2(x, s.top - 12.0)
			break
	for s in segments:
		if s.bonus > 0 and s.x < pos.x:
			s.scored = true
	return pos
