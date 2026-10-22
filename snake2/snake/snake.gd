extends Node2D

# ================== ТОХИРГОО ==================
const CELL := 20          # нэг нүдний хэмжээ (пиксел)
const COLS := 30          # баганын тоо
const ROWS := 20          # мөрийн тоо
const HUD := 40           # дээд талын оноо харуулах хэсэг
const NONE := Vector2i(-1, -1)

# ================== ТӨЛӨВ ==================
var snake: Array[Vector2i] = []
var dir := Vector2i.RIGHT
var next_dir := Vector2i.RIGHT
var grow := 0
var score := 0
var eaten := 0
var game_over := false

var step_time := 0.15     # хэдэн секунд тутамд нэг алхам хийх
var timer := 0.0

var food := NONE          # улаан алим
var gold := NONE          # алтан алим (ДҮРЭМ 2)
var gold_timer := 0.0
var poison := NONE        # хорт алим (ДҮРЭМ 3)
var walls: Array[Vector2i] = []   # саад (ДҮРЭМ 4)

# ================== ОНОО ХАДГАЛАХ ==================
const SAVE_PATH := "user://highscore.cfg"
var high_score := 0       # хамгийн өндөр оноо
var new_record := false   # энэ тоглолтод рекорд эвдсэн эсэх


func _ready() -> void:
	randomize()
	load_high_score()
	start_game()


func start_game() -> void:
	snake = [Vector2i(5, 10), Vector2i(4, 10), Vector2i(3, 10)]
	dir = Vector2i.RIGHT
	next_dir = dir
	grow = 0
	score = 0
	eaten = 0
	step_time = 0.15
	timer = 0.0
	walls.clear()
	gold = NONE
	poison = NONE
	food = NONE
	game_over = false
	new_record = false
	food = random_free_cell()
	queue_redraw()


func _process(delta: float) -> void:
	if game_over:
		return

	# Алтан алим 5 секундийн дараа алга болно
	if gold != NONE:
		gold_timer -= delta
		if gold_timer <= 0.0:
			gold = NONE

	timer += delta
	if timer >= step_time:
		timer = 0.0
		step()
	queue_redraw()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	# physical_keycode: гарын байрлал (EN/MN) өөр байсан ч ажиллана
	match key.physical_keycode:
		KEY_UP, KEY_W:
			if dir != Vector2i.DOWN:
				next_dir = Vector2i.UP
		KEY_DOWN, KEY_S:
			if dir != Vector2i.UP:
				next_dir = Vector2i.DOWN
		KEY_LEFT, KEY_A:
			if dir != Vector2i.RIGHT:
				next_dir = Vector2i.LEFT
		KEY_RIGHT, KEY_D:
			if dir != Vector2i.LEFT:
				next_dir = Vector2i.RIGHT
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if game_over:
				start_game()


func step() -> void:
	dir = next_dir
	var head: Vector2i = snake[0] + dir

	# ДҮРЭМ 1: Ханыг нэвтэлж эсрэг талаас гарч ирнэ
	head.x = wrapi(head.x, 0, COLS)
	head.y = wrapi(head.y, 0, ROWS)

	# Өөрийгөө эсвэл саадыг мөргөвөл ялагдана
	if head in snake or head in walls:
		end_game()
		return

	snake.insert(0, head)
	var ate_poison := false

	if head == food:
		score += 1
		eaten += 1
		grow += 1
		food = random_free_cell()

		# ДҮРЭМ 4: 5 алим идэх тутамд хурдасч, шинэ саад гарна
		if eaten % 5 == 0:
			step_time = max(0.05, step_time - 0.015)
			walls.append(random_free_cell())

		# ДҮРЭМ 2: 25% магадлалаар алтан алим гарна
		if gold == NONE and randf() < 0.25:
			gold = random_free_cell()
			gold_timer = 5.0

		# ДҮРЭМ 3: 30% магадлалаар хорт алим гарна
		if poison == NONE and randf() < 0.3:
			poison = random_free_cell()

	elif head == gold:
		score += 5      # алтан алим = +5 оноо
		grow += 3       # 3 нүдээр уртасна
		gold = NONE

	elif head == poison:
		score = max(0, score - 3)   # хорт алим = -3 оноо
		poison = NONE
		ate_poison = true

	# Сүүлийг хасах (уртсах ёстой бол хасахгүй)
	if grow > 0:
		grow -= 1
	else:
		snake.pop_back()

	# Хорт алим идвэл 2 нүдээр богиносно (хамгийн багадаа 2 урт)
	if ate_poison:
		for i in 2:
			if snake.size() > 2:
				snake.pop_back()


func end_game() -> void:
	game_over = true
	if score > high_score:
		high_score = score
		new_record = true
		save_high_score()
	queue_redraw()


func load_high_score() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		high_score = cfg.get_value("game", "high_score", 0)


func save_high_score() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "high_score", high_score)
	cfg.save(SAVE_PATH)


func random_free_cell() -> Vector2i:
	while true:
		var c := Vector2i(randi() % COLS, randi() % ROWS)
		if c in snake or c in walls or c == food or c == gold or c == poison:
			continue
		# Могойн толгойн хэт ойрхон гаргахгүй
		if snake.size() > 0 and absi(c.x - snake[0].x) + absi(c.y - snake[0].y) < 4:
			continue
		return c
	return NONE


# ================== ӨНГӨ ==================
const C_BG := Color(0.08, 0.09, 0.11)          # талбайн дэвсгэр
const C_GRID := Color(0.12, 0.13, 0.16)        # нүдний шугам
const C_FOOD := Color(0.93, 0.16, 0.16)        # улаан алим
const C_LEAF := Color(0.30, 0.80, 0.25)        # алимны навч
const C_GOLD := Color(1.0, 0.80, 0.0)          # алтан алим
const C_POISON := Color(0.62, 0.20, 0.85)      # хорт алим (нил ягаан)
const C_WALL := Color(0.55, 0.40, 0.30)        # саад (тоосго)
const C_WALL_DARK := Color(0.35, 0.24, 0.17)
const C_HEAD := Color(0.20, 0.55, 1.0)         # могойн толгой (цэнхэр)
const C_BODY := Color(0.15, 0.75, 0.95)        # могойн бие (цайвар цэнхэр)
const LEGEND := 30        # доод талын тайлбар хэсэг


func _draw() -> void:
	var font := ThemeDB.fallback_font

	# Талбай + нүдний шугам (нүдийг ялгахад амар)
	draw_rect(Rect2(0, HUD, COLS * CELL, ROWS * CELL), C_BG)
	for x in range(1, COLS):
		draw_line(Vector2(x * CELL, HUD), Vector2(x * CELL, HUD + ROWS * CELL), C_GRID)
	for y in range(1, ROWS):
		draw_line(Vector2(0, HUD + y * CELL), Vector2(COLS * CELL, HUD + y * CELL), C_GRID)

	for w in walls:
		draw_wall(w)
	draw_food(food)
	if gold != NONE:
		# Сүүлийн 1.5 секундэд анивчина (алга болох гэж байгааг анхааруулна)
		if gold_timer > 1.5 or int(gold_timer * 8) % 2 == 0:
			draw_gold(gold)
	if poison != NONE:
		draw_poison(poison)
	draw_snake()

	# Дээд самбар
	draw_string(font, Vector2(10, 28), "Score: %d   Length: %d   Speed: %.2fs" % [score, snake.size(), step_time],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	draw_string(font, Vector2(0, 28), "Best: %d" % high_score,
		HORIZONTAL_ALIGNMENT_RIGHT, COLS * CELL - 10, 20, C_GOLD)

	draw_legend(font)

	if game_over:
		draw_rect(Rect2(0, HUD, COLS * CELL, ROWS * CELL), Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(0, HUD + ROWS * CELL / 2), "GAME OVER - press Enter",
			HORIZONTAL_ALIGNMENT_CENTER, COLS * CELL, 28, Color.WHITE)
		if new_record:
			draw_string(font, Vector2(0, HUD + ROWS * CELL / 2 + 40), "NEW RECORD: %d" % high_score,
				HORIZONTAL_ALIGNMENT_CENTER, COLS * CELL, 24, C_GOLD)


# Нүдний төв цэг (пикселээр)
func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * CELL + CELL / 2.0, HUD + c.y * CELL + CELL / 2.0)


func draw_cell(c: Vector2i, color: Color) -> void:
	draw_rect(Rect2(c.x * CELL + 1, HUD + c.y * CELL + 1, CELL - 2, CELL - 2), color)


# Улаан алим: дугуй + ногоон навч
func draw_food_at(p: Vector2) -> void:
	draw_circle(p + Vector2(0, 1), 7, C_FOOD)
	draw_circle(p + Vector2(-2, -1), 2, Color(1, 1, 1, 0.5))
	draw_line(p + Vector2(0, -5), p + Vector2(1, -9), Color(0.4, 0.25, 0.1), 2)
	draw_circle(p + Vector2(3, -7), 2.5, C_LEAF)


func draw_food(c: Vector2i) -> void:
	draw_food_at(cell_center(c))


# Алтан алим: гэрэлтсэн алтан дугуй + "5" + үлдсэн хугацааны цагираг
func draw_gold_at(p: Vector2, time_left: float) -> void:
	draw_circle(p, 10, Color(1, 0.85, 0.2, 0.25))
	draw_circle(p, 8, C_GOLD)
	draw_string(ThemeDB.fallback_font, p + Vector2(-4, 5), "5",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.35, 0.2, 0))
	if time_left > 0.0:
		draw_arc(p, 10, -PI / 2, -PI / 2 + TAU * time_left / 5.0, 24, Color.WHITE, 1.5)


func draw_gold(c: Vector2i) -> void:
	draw_gold_at(cell_center(c), gold_timer)


# Хорт алим: нил ягаан дугуй + цагаан "X"
func draw_poison_at(p: Vector2) -> void:
	draw_circle(p, 8, C_POISON)
	draw_line(p + Vector2(-4, -4), p + Vector2(4, 4), Color.WHITE, 2)
	draw_line(p + Vector2(4, -4), p + Vector2(-4, 4), Color.WHITE, 2)


func draw_poison(c: Vector2i) -> void:
	draw_poison_at(cell_center(c))


# Саад: хүрэн тоосго
func draw_wall_at(p: Vector2) -> void:
	var r := Rect2(p - Vector2(CELL / 2.0, CELL / 2.0), Vector2(CELL, CELL))
	draw_rect(r, C_WALL)
	draw_rect(r.grow(-1), C_WALL_DARK, false, 2)
	draw_line(r.position + Vector2(0, CELL / 2.0), r.position + Vector2(CELL, CELL / 2.0), C_WALL_DARK, 1)
	draw_line(r.position + Vector2(CELL / 2.0, 0), r.position + Vector2(CELL / 2.0, CELL / 2.0), C_WALL_DARK, 1)


func draw_wall(c: Vector2i) -> void:
	draw_wall_at(cell_center(c))


# Могой: цэнхэр бие (сүүл рүүгээ бараан), толгой нь нүдтэй
func draw_snake() -> void:
	var n := snake.size()
	for i in range(n - 1, 0, -1):
		var t := float(i) / maxi(1, n - 1)
		draw_cell(snake[i], C_BODY.darkened(t * 0.45))

	var head := snake[0]
	draw_cell(head, C_HEAD)
	var p := cell_center(head)
	var fwd := Vector2(dir)
	var side := Vector2(-fwd.y, fwd.x)
	for s: int in [-1, 1]:
		var eye: Vector2 = p + fwd * 3 + side * 4 * s
		draw_circle(eye, 2.5, Color.WHITE)
		draw_circle(eye + fwd, 1.2, Color.BLACK)


# Доод талын тайлбар: аль дүрс юу болохыг харуулна
func draw_legend(font: Font) -> void:
	var y := HUD + ROWS * CELL
	draw_rect(Rect2(0, y, COLS * CELL, LEGEND), Color(0.05, 0.05, 0.07))
	var cy := y + LEGEND / 2.0
	var ty := cy + 5
	var x := 20.0
	draw_food_at(Vector2(x, cy))
	draw_string(font, Vector2(x + 14, ty), "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, C_FOOD)
	x += 110
	draw_gold_at(Vector2(x, cy), 0.0)
	draw_string(font, Vector2(x + 14, ty), "+5 (5 sec)", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, C_GOLD)
	x += 150
	draw_poison_at(Vector2(x, cy))
	draw_string(font, Vector2(x + 14, ty), "-3", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, C_POISON.lightened(0.3))
	x += 110
	draw_wall_at(Vector2(x, cy))
	draw_string(font, Vector2(x + 16, ty), "Wall", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, C_WALL.lightened(0.3))
