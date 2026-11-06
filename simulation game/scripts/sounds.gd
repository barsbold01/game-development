class_name Sounds
extends Node
## ДУУ — хонь, нохой, чоно, салхи, голын дууг тоглуулна. Симуляцид нөлөөлөхгүй,
## зөвхөн сонсоно. Шуугиан болохгүйн тулд нэг дор ердөө 1–2 хонь л майлна.
## Амьтны дуу байрлалаасаа хамаарч зүүн, баруун чихэнд сонсогдоно. Эх сурвалж: sounds/CREDITS.md

const BLEATS := [
	preload("res://sounds/sheep_bleat_1.ogg"), preload("res://sounds/sheep_bleat_2.ogg"),
	preload("res://sounds/sheep_bleat_3.ogg"), preload("res://sounds/sheep_bleat_4.ogg"),
	preload("res://sounds/sheep_bleat_5.ogg"),
]
const BLEAT_FAR := preload("res://sounds/sheep_far.ogg")
const BARKS := [
	preload("res://sounds/dog_bark_1.ogg"), preload("res://sounds/dog_bark_2.ogg"),
	preload("res://sounds/dog_bark_3.ogg"), preload("res://sounds/dog_bark_4.ogg"),
	preload("res://sounds/dog_bark_5.ogg"), preload("res://sounds/dog_bark_6.ogg"),
]
const DOG_GROWL := preload("res://sounds/dog_growl.ogg")
const HOWLS := [preload("res://sounds/wolf_howl_1.ogg"), preload("res://sounds/wolf_howl_2.ogg")]
const WOLF_GROWL := preload("res://sounds/wolf_growl.ogg")
const WOLF_YELP := preload("res://sounds/wolf_yelp.ogg")
const WIND := preload("res://sounds/wind_loop.ogg")
const RIVER := preload("res://sounds/river_loop.ogg")
const RUN := preload("res://sounds/flock_run.ogg")

const VOICES := 6           # Нохой, чонын зэрэг тоглох дууны дээд тоо
const SHEEP_VOICES := 2     # Зэрэг майлах хонины дээд тоо
const PANIC_GAP := 1.2      # Сандарсан хонинууд хэдэн секундын зайтай майлах вэ
const RUN_SPEED := 110.0    # Сүргийн дундаж хурд үүнд хүрвэл туурайн дуу бүрэн сонсогдоно
const DOG_GROWL_RANGE := 110.0
const BREEZE_DB := -24.0
const GUST_DB := -7.0
const RIVER_DB := -4.0
const RUN_DB := -9.0
const QUIET_DB := -12.0     # Цэс, үр дүнгийн үед бүх дууг намсгана

var _pool: Array[AudioStreamPlayer2D] = []
var _sheep_pool: Array[AudioStreamPlayer2D] = []
var _wind: AudioStreamPlayer
var _river: AudioStreamPlayer
var _run: AudioStreamPlayer
var _calm_timer := 2.0
var _panic_timer := 0.0
var _howl_timer := 25.0
var _wolf_growl_timer := 0.0
var _dog_growl_timer := 0.0


func _ready() -> void:
	_pool = _voices(VOICES)
	_sheep_pool = _voices(SHEEP_VOICES)
	_wind = _loop(WIND, BREEZE_DB)
	_river = _loop(RIVER, RIVER_DB)
	_run = _loop(RUN, -60.0)
	_wind.play()
	_run.play()


## Түвшин солигдоход хуучин дууг зогсоож, гол байвал урсгалын дууг асаана
func set_level(level: Dictionary) -> void:
	for p in _pool + _sheep_pool:
		p.stop()
	_calm_timer = randf_range(1.0, 3.0)
	_panic_timer = 0.0
	_howl_timer = randf_range(20.0, 35.0)
	_wolf_growl_timer = 0.0
	_dog_growl_timer = 0.0
	if level["water"].is_empty():
		_river.stop()
	elif not _river.playing:
		_river.play()


func set_quiet(quiet: bool) -> void:
	AudioServer.set_bus_volume_db(0, QUIET_DB if quiet else 0.0)


## Кадр бүрт main.gd дуудна: сүргийн байдлаас ямар дуу гарахыг шийднэ
func update(sheep: Array[Sheep], wolves: Array[Wolf], dog_pos: Vector2, gust: bool, delta: float) -> void:
	_panic_timer -= delta
	_calm_timer -= delta
	_wolf_growl_timer -= delta
	_dog_growl_timer -= delta
	_update_flock(sheep, delta)
	_update_wolves(wolves, dog_pos, delta)
	_wind.volume_db = move_toward(_wind.volume_db, GUST_DB if gust else BREEZE_DB, 40.0 * delta)


func bleat(s: Sheep) -> void:
	_play(_sheep_pool, BLEATS.pick_random(), s.position, -9.0, _pitch(s))


func bark(pos: Vector2) -> void:
	_play(_pool, BARKS.pick_random(), pos, 0.0, randf_range(0.95, 1.05))


func howl(pos: Vector2) -> void:
	_howl_timer = randf_range(20.0, 35.0)
	_play(_pool, HOWLS.pick_random(), pos, -5.0, randf_range(0.95, 1.05))


## Чоно хонь барихад: архирах чимээ ба хонины хашгираан
func caught(pos: Vector2) -> void:
	_play(_pool, WOLF_GROWL, pos, -1.0, 1.1)
	_play(_pool, BLEATS.pick_random(), pos, -3.0, 1.3)


func _update_flock(sheep: Array[Sheep], delta: float) -> void:
	var speed := 0.0
	var alarmed: Sheep = null
	var calm: Array[Sheep] = []
	for s in sheep:
		speed += s.velocity.length()
		if s.fear < 0.35:
			s.alarmed = false
			calm.append(s)
		elif s.fear > 0.6 and not s.alarmed and alarmed == null:
			alarmed = s
	# Айсан хонь бүр нэг удаа л майлна, тэгээд ч зөвхөн PANIC_GAP тутам нэг хонь
	if alarmed and _panic_timer <= 0.0:
		alarmed.alarmed = true
		_panic_timer = PANIC_GAP
		_play(_sheep_pool, BLEATS.pick_random(), alarmed.position, -6.0, _pitch(alarmed) * randf_range(1.05, 1.2))
	if _calm_timer <= 0.0:
		_calm_timer = randf_range(4.0, 9.0)
		if not calm.is_empty():
			var s: Sheep = calm.pick_random()
			if randf() < 0.25:
				_play(_sheep_pool, BLEAT_FAR, s.position, -10.0, _pitch(s))
			else:
				bleat(s)
	var pace := 0.0 if sheep.is_empty() else clampf(speed / sheep.size() / RUN_SPEED, 0.0, 1.0)
	var target := linear_to_db(maxf(pace, 0.001)) + RUN_DB
	_run.volume_db = move_toward(_run.volume_db, target, 60.0 * delta)


func _update_wolves(wolves: Array[Wolf], dog_pos: Vector2, delta: float) -> void:
	if wolves.is_empty():
		return
	_howl_timer -= delta
	if _howl_timer <= 0.0:
		howl(wolves.pick_random().position)
	for w in wolves:
		if w.position.distance_to(dog_pos) < DOG_GROWL_RANGE and _dog_growl_timer <= 0.0:
			_dog_growl_timer = 6.0
			_play(_pool, DOG_GROWL, dog_pos, -4.0, 0.85)
		if w.mode == w.heard_mode:
			continue
		w.heard_mode = w.mode
		if w.mode == Wolf.Mode.HUNT and _wolf_growl_timer <= 0.0:
			_wolf_growl_timer = 5.0
			_play(_pool, WOLF_GROWL, w.position, -5.0, randf_range(0.75, 0.85))
		elif w.mode == Wolf.Mode.FLEE:
			_play(_pool, WOLF_YELP, w.position, -6.0, randf_range(0.75, 0.9))


## Хонь бүр өөр дуутай, зөрүүд хар хонь бүдүүн дуутай
func _pitch(s: Sheep) -> float:
	return s.voice * (0.8 if s.stubborn else 1.0)


## Чөлөөтэй дуу хайж тоглуулна. Бүгд завгүй бол энэ дууг алгасна
func _play(pool: Array[AudioStreamPlayer2D], stream: AudioStream, pos: Vector2, db: float, pitch: float) -> void:
	for p in pool:
		if not p.playing:
			p.stream = stream
			p.position = pos
			p.volume_db = db
			p.pitch_scale = pitch
			p.play()
			return


func _voices(count: int) -> Array[AudioStreamPlayer2D]:
	var pool: Array[AudioStreamPlayer2D] = []
	for i in count:
		var p := AudioStreamPlayer2D.new()
		p.max_distance = 700.0
		add_child(p)
		pool.append(p)
	return pool


func _loop(stream: AudioStreamOggVorbis, db: float) -> AudioStreamPlayer:
	stream.loop = true
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	add_child(p)
	return p
