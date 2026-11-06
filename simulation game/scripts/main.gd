extends Node2D
## ҮНДСЭН СЦЕН — түвшинг ачаалж, сүрэг, чоно, салхийг ажиллуулна.
## Тоглоомын төлөв, цаг, хуцалт, ахиц (од), симуляцийн хэмжилтийг удирдана.
## Цэс дээр нохой өөрөө хонь хариулж, сонгосон түвшинг үзүүлнэ.

enum State { MENU, PLAY, OVER }

const SAVE_PATH := "user://progress.cfg"
const DEFAULT_RULES := {"cohesion": true, "alignment": true, "separation": true, "fear": true, "contagion": true}
const WOLF_SPAWNS := [Vector2(330, 40), Vector2(330, 262)]
const GUST_FORCE := 120.0
const GUST_TIME := 1.8
const GROUP_LINK := 30.0    # Үүнээс ойр хонинууд нэг бүлэгт тооцогдоно
const HISTORY := 40         # Самбарын график: 0.25 сек тутам, 10 секунд

## Сүргийн 5 дүрэм. 1–5 товчоор асааж унтраагаад дүрэм бүр юу хийдгийг харуулна.
var rules: Dictionary = DEFAULT_RULES.duplicate()
var show_forces := false
var state := State.MENU
var level_index := 0
var level: Dictionary = {}
var time_left := 0.0
var inside := 0
var eaten := 0
var experiment := false     # Дүрэм өөрчилсөн тоглолтод од хадгалахгүй
var best_stars: Array[int] = []
var sheep: Array[Sheep] = []
var wolves: Array[Wolf] = []
var wind := Vector2.ZERO
var fear_history := PackedFloat32Array()
var group_history := PackedFloat32Array()
var _next_level := 0
var _gust_timer := 0.0
var _gust_left := 0.0
var _gust_dir := Vector2.RIGHT
var _gust_warned := false
var _wolf_delay := 0.0
var _demo_time := 0.0
var _sample_timer := 0.0

@onready var field: Field = $Field
@onready var trails: Trails = $Trails
@onready var flock: Node2D = $Flock
@onready var dog: Dog = $Dog
@onready var effects: Effects = $Effects
@onready var sounds: Sounds = $Sounds
@onready var hud: Hud = $HUD


func _ready() -> void:
	trails.sheep = sheep
	_load_progress()
	_load_level(0)
	_show_menu()
	_refresh_rules()


func _physics_process(delta: float) -> void:
	if state == State.MENU:
		_auto_herd()
		_demo_time += delta
	_update_wind(delta)
	_update_wolves(delta)
	var threats: Array[Vector3] = [Vector3(dog.position.x, dog.position.y, Sheep.FEAR_RADIUS)]
	for w in wolves:
		threats.append(Vector3(w.position.x, w.position.y, Wolf.FEAR_RADIUS))
	for s in sheep:
		s.think(sheep, threats, rules, wind, delta)
		field.collide(s, false, true)
	_count_pen()
	_measure(delta)
	sounds.update(sheep, wolves, dog.position, wind != Vector2.ZERO, delta)
	match state:
		State.MENU:
			# Цэсний жишээ тоглолт дуусвал шинээр эхэлнэ
			if inside >= level["goal"] or sheep.size() < level["goal"] or _demo_time > 50.0:
				_load_level(level_index)
		State.PLAY:
			time_left = maxf(time_left - delta, 0.0)
			if inside >= level["goal"]:
				_finish(true, "")
			elif sheep.size() < level["goal"]:
				_finish(false, "eaten")
			elif time_left <= 0.0:
				_finish(false, "time")
	hud.update_status(level_index + 1, level["name"], inside, level["goal"], time_left,
		eaten, level["sheep"] - level["goal"], level["wolves"] > 0, dog.bark_ready())


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		match key.keycode:
			KEY_1: _toggle("cohesion")
			KEY_2: _toggle("alignment")
			KEY_3: _toggle("separation")
			KEY_4: _toggle("fear")
			KEY_5: _toggle("contagion")
			KEY_D:
				show_forces = not show_forces
				for s in sheep:
					s.show_forces = show_forces
				for w in wolves:
					w.show_target = show_forces
				dog.show_fear = show_forces
				_refresh_rules()
			KEY_T:
				trails.visible = not trails.visible
				_refresh_rules()
			KEY_TAB:
				hud.toggle_stats()
				_refresh_rules()
			KEY_R:
				_start(level_index)
			KEY_ESCAPE:
				_load_level(level_index)
				_show_menu()
			KEY_LEFT:
				if state == State.MENU:
					_select(level_index - 1)
			KEY_RIGHT:
				if state == State.MENU:
					_select(level_index + 1)
	var mouse := event as InputEventMouseButton
	var pressed: bool = (mouse and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed("ui_accept")
	if not pressed:
		return
	match state:
		State.MENU:
			_start(level_index)
		State.PLAY:
			_bark()
		State.OVER:
			_start(_next_level)


func _load_level(i: int) -> void:
	level_index = i
	level = Levels.LIST[i]
	field.setup(level)
	sounds.set_level(level)
	_spawn()
	time_left = float(level["time"])
	eaten = 0
	wind = Vector2.ZERO
	_gust_timer = randf_range(6.0, 9.0)
	_gust_left = 0.0
	_gust_warned = false
	_wolf_delay = 5.0
	_demo_time = 0.0
	fear_history.clear()
	group_history.clear()


func _spawn() -> void:
	for s in sheep:
		s.queue_free()
	sheep.clear()
	for w in wolves:
		w.queue_free()
	wolves.clear()
	for i in level["sheep"]:
		var s := Sheep.new()
		s.position = field.spawn_point()
		s.stubborn = i == 0     # Нэг хар хонь зөрүүд — сүргээс салж бие даан тэнэнэ
		s.show_forces = show_forces
		flock.add_child(s)
		sheep.append(s)
	dog.reset()


func _start(i: int) -> void:
	_load_level(i)
	state = State.PLAY
	dog.active = true
	sounds.set_quiet(false)
	experiment = rules != DEFAULT_RULES
	hud.hide_panel()
	_refresh_rules()


func _show_menu() -> void:
	state = State.MENU
	dog.active = false
	sounds.set_quiet(true)
	hud.show_menu(level_index + 1, Levels.LIST.size(), level["name"], level["desc"], level["sheep"],
		level["goal"], level["time"], best_stars[level_index], level_index > 0, _unlocked(level_index + 1))
	_refresh_rules()


func _select(i: int) -> void:
	if i >= 0 and _unlocked(i):
		_load_level(i)
		_show_menu()


func _unlocked(i: int) -> bool:
	return i < Levels.LIST.size() and (i == 0 or best_stars[i - 1] > 0)


func _bark() -> void:
	if not dog.bark():
		return
	sounds.bark(dog.position)
	for s in sheep:
		s.scare(dog.position, Dog.BARK_RADIUS)
	for w in wolves:
		if w.position.distance_to(dog.position) < Dog.BARK_RADIUS:
			w.flee()


func _finish(win: bool, reason: String) -> void:
	state = State.OVER
	dog.active = false
	sounds.set_quiet(true)
	var star_count := 0
	if win:
		var left := time_left / float(level["time"])
		star_count = 3 if left > 0.4 else (2 if left > 0.2 else 1)
		if not experiment and star_count > best_stars[level_index]:
			best_stars[level_index] = star_count
			_save_progress()
	var has_next := win and level_index + 1 < Levels.LIST.size()
	_next_level = level_index + 1 if has_next else level_index
	hud.show_result(win, star_count, reason, level_index + 1, level["name"], inside, level["goal"],
		float(level["time"]) - time_left, has_next, experiment)


func _toggle(rule: String) -> void:
	rules[rule] = not rules[rule]
	if state == State.PLAY:
		experiment = true
	_refresh_rules()


func _refresh_rules() -> void:
	hud.set_experiment(experiment and state != State.MENU)


## Хашаанд орсон, гарсан хонь бүрт «+1 / -1» гаргаж тоолно
func _count_pen() -> void:
	inside = 0
	for s in sheep:
		var now := field.is_inside(s.position)
		if now != s.in_pen and state == State.PLAY:
			effects.text(s.position + Vector2(-6, -10), "+1" if now else "-1", Color("7cf0b6") if now else Color("ff8a75"))
			if now:
				sounds.bleat(s)
		s.in_pen = now
		if now:
			inside += 1


func _update_wolves(delta: float) -> void:
	if wolves.size() < level["wolves"]:
		_wolf_delay -= delta
		if _wolf_delay <= 0.0:
			var w := Wolf.new()
			w.position = WOLF_SPAWNS[wolves.size() % WOLF_SPAWNS.size()]
			w.show_target = show_forces
			flock.add_child(w)
			wolves.append(w)
			_wolf_delay = 8.0
			sounds.howl(w.position)
			if state == State.PLAY:
				hud.flash("Чоно гарч ирлээ!")
	for w in wolves:
		var prey := w.think(sheep, dog.position, field, delta)
		field.collide(w, true, false)
		if prey:
			sheep.erase(prey)
			sounds.caught(prey.position)
			effects.puff(prey.position, Color("f7f5ef"))
			effects.text(prey.position + Vector2(-6, -10), "-1", Color("ff6b5b"))
			prey.queue_free()
			eaten += 1


## Шуургатай түвшинд 8–12 секунд тутам салхи 1.8 секунд үлээнэ
func _update_wind(delta: float) -> void:
	wind = Vector2.ZERO
	if level["wind"]:
		if _gust_left > 0.0:
			_gust_left -= delta
			wind = _gust_dir * GUST_FORCE
		else:
			_gust_timer -= delta
			if _gust_timer <= 1.2 and not _gust_warned and state == State.PLAY:
				_gust_warned = true
				hud.flash("Салхи ирж байна!")
			if _gust_timer <= 0.0:
				_gust_left = GUST_TIME
				_gust_dir = Vector2.from_angle(randf() * TAU)
				_gust_timer = randf_range(8.0, 12.0)
				_gust_warned = false
	effects.wind = wind


## Симуляцийн хэмжилт: дундаж айдас, бүлгийн тоо, төвөөс дундаж зай
func _measure(delta: float) -> void:
	if sheep.is_empty():
		return
	var center := Vector2.ZERO
	var fear_sum := 0.0
	for s in sheep:
		center += s.position
		fear_sum += s.fear
	center /= sheep.size()
	var spread := 0.0
	for s in sheep:
		spread += s.position.distance_to(center)
	spread /= sheep.size()
	var avg := fear_sum / sheep.size()
	var groups := _count_groups()
	_sample_timer -= delta
	if _sample_timer <= 0.0:
		_sample_timer = 0.25
		fear_history.append(avg)
		group_history.append(groups)
		if fear_history.size() > HISTORY:
			fear_history.remove_at(0)
			group_history.remove_at(0)
	hud.update_stats(avg, groups, spread, fear_history, group_history)


## Ойрхон (GROUP_LINK) хонинуудыг холбож хэдэн тусдаа бүлэг байгааг тоолно
func _count_groups() -> int:
	var seen := {}
	var groups := 0
	for s in sheep:
		if seen.has(s):
			continue
		groups += 1
		seen[s] = true
		var stack: Array[Sheep] = [s]
		while not stack.is_empty():
			var a: Sheep = stack.pop_back()
			for b in sheep:
				if not seen.has(b) and a.position.distance_to(b.position) < GROUP_LINK:
					seen[b] = true
					stack.append(b)
	return groups


## Цэсний автомат нохой: хамгийн хол тасарсан хонийг сүрэг рүү нь буцааж,
## сүрэг цугларсан бол ардаас нь хашаа (голтой бол гүүр) руу шахна. Агнаж буй чоно ойртвол хуцна.
func _auto_herd() -> void:
	for w in wolves:
		if w.mode == Wolf.Mode.HUNT and w.position.distance_to(dog.position) < 120.0:
			_bark()
	var out: Array[Sheep] = []
	for s in sheep:
		if not field.is_inside(s.position):
			out.append(s)
	if out.is_empty():
		return
	var center := Vector2.ZERO
	for s in out:
		center += s.position
	center /= out.size()
	var far := out[0]
	for s in out:
		if s.position.distance_to(center) > far.position.distance_to(center):
			far = s
	var spread := 18.0 + sqrt(out.size()) * 8.0
	if far.position.distance_to(center) > spread:
		dog.target = far.position + (far.position - center).normalized() * 20.0
	else:
		dog.target = center + (center - field.aim_for(center)).normalized() * (spread + 22.0)


func _load_progress() -> void:
	best_stars.resize(Levels.LIST.size())
	best_stars.fill(0)
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		for i in best_stars.size():
			best_stars[i] = cfg.get_value("stars", str(i), 0)


func _save_progress() -> void:
	var cfg := ConfigFile.new()
	for i in best_stars.size():
		cfg.set_value("stars", str(i), best_stars[i])
	cfg.save(SAVE_PATH)
