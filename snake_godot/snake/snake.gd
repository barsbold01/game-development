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


func _ready() -> void:
	randomize()
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
	food = random_free_cell()
	queue_redraw()


func _process(delta: float) -> void:
	if game_over:
		if Input.is_action_just_pressed("ui_accept"):
			start_game()
		return

	read_input()

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


func read_input() -> void:
	# Одоогийн чиглэлийн эсрэг тийш эргэж болохгүй
	if Input.is_action_just_pressed("ui_up") and dir != Vector2i.DOWN:
		next_dir = Vector2i.UP
	elif Input.is_action_just_pressed("ui_down") and dir != Vector2i.UP:
		next_dir = Vector2i.DOWN
	elif Input.is_action_just_pressed("ui_left") and dir != Vector2i.RIGHT:
		next_dir = Vector2i.LEFT
	elif Input.is_action_just_pressed("ui_right") and dir != Vector2i.LEFT:
		next_dir = Vector2i.RIGHT


func step() -> void:
	dir = next_dir
	var head: Vector2i = snake[0] + dir

	# ДҮРЭМ 1: Ханыг нэвтэлж эсрэг талаас гарч ирнэ
	head.x = wrapi(head.x, 0, COLS)
	head.y = wrapi(head.y, 0, ROWS)

	# Өөрийгөө эсвэл саадыг мөргөвөл ялагдана
	if head in snake or head in walls:
		game_over = true
		queue_redraw()
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


func _draw() -> void:
	# Талбай
	draw_rect(Rect2(0, HUD, COLS * CELL, ROWS * CELL), Color(0.1, 0.1, 0.12))

	for w in walls:
		draw_cell(w, Color.GRAY)
	draw_cell(food, Color.RED)
	if gold != NONE:
		draw_cell(gold, Color.GOLD)
	if poison != NONE:
		draw_cell(poison, Color.MEDIUM_PURPLE)

	for i in snake.size():
		draw_cell(snake[i], Color.YELLOW_GREEN if i == 0 else Color.FOREST_GREEN)

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(10, 28), "Score: %d   Length: %d   Speed: %.2fs" % [score, snake.size(), step_time],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20)

	if game_over:
		draw_string(font, Vector2(0, HUD + ROWS * CELL / 2), "GAME OVER - press Enter",
			HORIZONTAL_ALIGNMENT_CENTER, COLS * CELL, 28, Color.WHITE)


func draw_cell(c: Vector2i, color: Color) -> void:
	draw_rect(Rect2(c.x * CELL + 1, HUD + c.y * CELL + 1, CELL - 2, CELL - 2), color)
