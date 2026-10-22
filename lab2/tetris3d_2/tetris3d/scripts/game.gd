extends Node3D

# =============================================================================
#  3D TETRIS — үндсэн скрипт
# =============================================================================
#  Энэ файл нь 3 зүйл хариуцна:
#    1. Тоонуудыг (Board) дэлгэц дээрх шоо болгон зурах
#    2. Товчлуурын оролтыг Board руу дамжуулах
#    3. Цаг тоолох (дүрс автоматаар унах)
#
#  Тоглоомын ЛОГИК бүхэлдээ board.gd дотор байгааг анхаараарай.
# =============================================================================

# --- Талбайн хэмжээ. Эндээс өөрчилж болно ---
#  Мөр цэвэрлэхэд X-мөрд W ширхэг, Z-мөрд D ширхэг нүд дүүрэхэд хангалттай.
#  5x5 бол нэг давхаргад 10 боломжит мөр байна.
const W: int = 5    # өргөн
const D: int = 5    # гүн
const H: int = 12   # өндөр

# --- Оноо ---
#  Устгасан ШОО бүрд оноо нэмэгдэнэ.
#  Гинжин урвал (chain) үргэлжлэх тусам үржүүлэгч нь өснө: x1, x2, x3 ...
const POINTS_PER_BLOCK: int = 12   # устгасан шоо тутамд
const ROW_BONUS: int = 30          # цэвэрлэсэн мөр тутамд нэмэлт
const HARD_DROP_POINTS: int = 2    # шидэхэд унасан нүд тутамд

const SAVE_PATH: String = "user://tetris3d.cfg"

# --- Камерын 4 байрлалд харгалзах "баруун" ба "урагш" чиглэл ---
#  Энэ бол тоглоомыг тоглох боломжтой болгож буй гол заль.
#  Хэрэглэгч "баруун" товч дарахад ДЭЛГЭЦЭН ДЭЭР баруун тийш явах ёстой,
#  талбайн +X тийш биш. Камер эргэхэд чиглэлүүд нь дагаж эргэнэ.
const DIRS: Array = [
	{"right": Vector3i(1, 0, 0),  "fwd": Vector3i(0, 0, -1)},
	{"right": Vector3i(0, 0, -1), "fwd": Vector3i(-1, 0, 0)},
	{"right": Vector3i(-1, 0, 0), "fwd": Vector3i(0, 0, 1)},
	{"right": Vector3i(0, 0, 1),  "fwd": Vector3i(1, 0, 0)},
]

# --- Scene доторх зангилаанууд ---
@onready var cam_pivot: Node3D = $CamPivot
@onready var camera: Camera3D = $CamPivot/Camera3D
@onready var sun: DirectionalLight3D = $DirectionalLight3D

# --- Тоглоомын төлөв ---
var board: Board

var shape: Array = []       # одоогийн дүрсний offset-ууд
var pos: Vector3i           # одоогийн дүрсний байрлал
var piece_id: int = 0       # ямар дүрс вэ (өнгө нь ч бас үүгээр тодорхойлогдоно)
var next_id: int = 0

var fall_interval: float = 0.85
var fall_timer: float = 0.0
var soft_drop: bool = false

var paused: bool = false
var game_over: bool = false
var score: int = 0
var rows_cleared: int = 0
var blocks_destroyed: int = 0
var best_chain: int = 1
var level: int = 1

# --- Дээд амжилт (диск дээр хадгалагдана) ---
var high_score: int = 0
var high_rows: int = 0
var record_beaten: bool = false

# --- Түр гарч алга болдог мэдэгдэл ---
var toast_text: String = ""
var toast_time: float = 0.0

var cam_step: int = 0
var cam_yaw_target: float = 0.0

# --- Зурах зориулалттай зангилаанууд ---
var locked_root: Node3D
var piece_root: Node3D
var ghost_root: Node3D
var cube_mesh: BoxMesh
var _materials: Dictionary = {}

var hud: Label
var big_label: Label
var toast_label: Label


# =============================================================================
#  ЭХЛҮҮЛЭХ
# =============================================================================
func _ready() -> void:
	randomize()

	board = Board.new(W, D, H)
	_load_stats()

	locked_root = Node3D.new()
	piece_root = Node3D.new()
	ghost_root = Node3D.new()
	add_child(locked_root)
	add_child(piece_root)
	add_child(ghost_root)

	cube_mesh = BoxMesh.new()
	cube_mesh.size = Vector3(0.92, 0.92, 0.92)

	_setup_camera()
	_setup_light()
	_build_well()
	_build_hud()

	next_id = randi() % Pieces.SHAPES.size()
	_spawn()


func _setup_camera() -> void:
	# Пивот нь худгийн голд байрлана; камер үүний хүүхэд учраас
	# пивотыг эргүүлэхэд камер тойрч эргэнэ.
	cam_pivot.position = Vector3(0, H * 0.30, 0)
	camera.position = Vector3(0, H * 0.38, maxf(W, D) * 2.6 + 6.0)
	camera.look_at(cam_pivot.global_position)


func _setup_light() -> void:
	sun.rotation_degrees = Vector3(-55, -40, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true


# -----------------------------------------------------------------------------
#  ТОРНЫ НҮДИЙГ ЕРТӨНЦИЙН КООРДИНАТ РУУ ХӨРВҮҮЛЭХ
# -----------------------------------------------------------------------------
#  Талбайг эхийн цэг дээр төвлүүлнэ: шал нь y = 0 дээр, x, z нь 0-ын эргэн тойронд.
#  +0.5 нь шоог нүдний ТӨВД тавихын тулд (шоо нь төвөөрөө байрладаг учраас).
# -----------------------------------------------------------------------------
func cell_to_world(c: Vector3i) -> Vector3:
	return Vector3(
		float(c.x) - W * 0.5 + 0.5,
		float(c.y) + 0.5,
		float(c.z) - D * 0.5 + 0.5
	)


# =============================================================================
#  ХУДГИЙН ТОР ЗУРАХ  (ImmediateMesh ашиглан шугам зурна)
# =============================================================================
func _build_well() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)

	var hx: float = W * 0.5
	var hz: float = D * 0.5

	# --- Шалны тор ---
	var floor_col := Color(0.50, 0.62, 0.85, 0.65)
	for i in range(W + 1):
		_line(im, Vector3(-hx + i, 0, -hz), Vector3(-hx + i, 0, hz), floor_col, floor_col)
	for i in range(D + 1):
		_line(im, Vector3(-hx, 0, -hz + i), Vector3(hx, 0, -hz + i), floor_col, floor_col)

	# --- 4 булангийн босоо ирмэг (дээшээ бүдгэрнэ) ---
	var edge_a := Color(0.45, 0.58, 0.85, 0.55)
	var edge_b := Color(0.45, 0.58, 0.85, 0.0)
	for p in [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]:
		_line(im, Vector3(p.x, 0, p.y), Vector3(p.x, H, p.y), edge_a, edge_b)

	# --- 4 давхар тутамд хэвтээ хүрээ (өндрийг мэдрэхэд тусална) ---
	var ring := Color(0.35, 0.45, 0.70, 0.22)
	for y in range(4, H, 4):
		var pts := [
			Vector3(-hx, y, -hz), Vector3(hx, y, -hz),
			Vector3(hx, y, hz), Vector3(-hx, y, hz)
		]
		for i in 4:
			_line(im, pts[i], pts[(i + 1) % 4], ring, ring)

	im.surface_end()

	var mi := MeshInstance3D.new()
	mi.mesh = im
	add_child(mi)


func _line(im: ImmediateMesh, a: Vector3, b: Vector3, ca: Color, cb: Color) -> void:
	im.surface_set_color(ca)
	im.surface_add_vertex(a)
	im.surface_set_color(cb)
	im.surface_add_vertex(b)


# =============================================================================
#  МАТЕРИАЛ
# =============================================================================
func _material(id: int, ghost: bool) -> StandardMaterial3D:
	var key: String = "%d|%s" % [id, ghost]
	if _materials.has(key):
		return _materials[key]

	var c: Color = Pieces.COLORS[id]
	var m := StandardMaterial3D.new()
	if ghost:
		# "Сүүдэр" — дүрс хаана буухыг урьдчилан харуулна
		m.albedo_color = Color(c.r, c.g, c.b, 0.20)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		m.albedo_color = c
		m.metallic = 0.15
		m.roughness = 0.35
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.22
	_materials[key] = m
	return m


# =============================================================================
#  ЗУРАХ
# =============================================================================

# Түгжигдсэн бүх шоог Board-ын өгөгдлөөс дахин үүсгэнэ.
# "Массив бол үнэн, дэлгэц бол түүний зураг" гэсэн зарчмын шууд илэрхийлэл.
func _refresh_locked() -> void:
	for child in locked_root.get_children():
		child.queue_free()

	for y in H:
		for z in D:
			for x in W:
				var id: int = board.cells[y][z][x]
				if id >= 0:
					var mi := MeshInstance3D.new()
					mi.mesh = cube_mesh
					mi.material_override = _material(id, false)
					mi.position = cell_to_world(Vector3i(x, y, z))
					locked_root.add_child(mi)


# Идэвхтэй дүрс + түүний сүүдрийг шинэчилнэ
func _sync_piece() -> void:
	_fill(piece_root, shape, pos, piece_id, false)

	# Сүүдрийн байрлал: боломжтой хамгийн доод цэг хүртэл уналаа гэж бодъё
	var g: Vector3i = pos
	while board.can_place(shape, g + Vector3i(0, -1, 0)):
		g.y -= 1
	_fill(ghost_root, shape, g, piece_id, true)


func _fill(root: Node3D, sh: Array, p: Vector3i, id: int, ghost: bool) -> void:
	while root.get_child_count() < sh.size():
		var mi := MeshInstance3D.new()
		mi.mesh = cube_mesh
		root.add_child(mi)

	for i in root.get_child_count():
		var node: MeshInstance3D = root.get_child(i)
		if i < sh.size():
			node.visible = true
			node.material_override = _material(id, ghost)
			node.position = cell_to_world(p + sh[i])
			node.scale = Vector3.ONE * (0.80 if ghost else 1.0)
		else:
			node.visible = false


# =============================================================================
#  HUD
# =============================================================================
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	hud = Label.new()
	hud.position = Vector2(18, 14)
	hud.add_theme_font_size_override("font_size", 15)
	hud.add_theme_color_override("font_color", Color(0.9, 0.93, 1.0))
	hud.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	hud.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(hud)

	big_label = Label.new()
	big_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	big_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big_label.add_theme_font_size_override("font_size", 34)
	big_label.add_theme_color_override("font_color", Color(1, 1, 1))
	big_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	big_label.add_theme_constant_override("shadow_offset_y", 3)
	big_label.text = ""
	layer.add_child(big_label)

	# Гинжин урвал зэрэг түр зуурын мэдэгдэл
	toast_label = Label.new()
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toast_label.offset_top = 90
	toast_label.offset_bottom = 140
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 26)
	toast_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	toast_label.add_theme_constant_override("shadow_offset_y", 3)
	toast_label.text = ""
	layer.add_child(toast_label)

	_update_hud()


func _update_hud() -> void:
	var record_mark: String = "  ★" if record_beaten else ""
	hud.text = "\n".join([
		"Оноо: %d%s" % [score, record_mark],
		"Дээд амжилт: %d" % high_score,
		"",
		"Устгасан блок: %d" % blocks_destroyed,
		"Цэвэрлэсэн мөр: %d" % rows_cleared,
		"Хамгийн урт гинж: x%d" % best_chain,
		"Түвшин: %d" % level,
		"Дараагийн: %s" % Pieces.NAMES[next_id],
		"",
		"Сум / WASD — хөдөлгөх (камерын дагуу)",
		"Z / X / C — 3 тэнхлэгээр эргүүлэх",
		"Shift — удаан унагах,  Space — шидэх",
		"Q / E — камер эргүүлэх",
		"P — түр зогсоох,  Enter — дахин эхлэх",
	])

	if game_over:
		var lines: Array = ["ТОГЛООМ ДУУСЛАА", "Оноо: %d" % score]
		if record_beaten:
			lines.append("★ ШИНЭ ДЭЭД АМЖИЛТ ★")
		else:
			lines.append("Дээд амжилт: %d" % high_score)
		lines.append("")
		lines.append("Enter — дахин")
		big_label.text = "\n".join(lines)
	elif paused:
		big_label.text = "ТҮР ЗОГССОН"
	else:
		big_label.text = ""


# =============================================================================
#  ТОГЛООМЫН МӨЧЛӨГ
# =============================================================================
func _process(delta: float) -> void:
	# Камерыг зөөлөн эргүүлэх
	cam_pivot.rotation.y = lerp_angle(
		cam_pivot.rotation.y, cam_yaw_target, clampf(delta * 12.0, 0.0, 1.0)
	)

	# Түр зуурын мэдэгдлийг аажим бүдгэрүүлэх
	if toast_time > 0.0:
		toast_time -= delta
		toast_label.text = toast_text
		toast_label.modulate.a = clampf(toast_time / 0.6, 0.0, 1.0)
		if toast_time <= 0.0:
			toast_label.text = ""

	if game_over or paused:
		return

	# Таймер: тодорхой хугацаа өнгөрөх бүрд дүрс 1 нүдээр доошоо
	fall_timer += delta * (10.0 if soft_drop else 1.0)
	if fall_timer >= fall_interval:
		fall_timer = 0.0
		_step_down()


func _step_down() -> void:
	if board.can_place(shape, pos + Vector3i(0, -1, 0)):
		pos.y -= 1
		_sync_piece()
	else:
		_lock_piece()


# -----------------------------------------------------------------------------
#  ДҮРС ТҮГЖИХ  →  давхарга шалгах  →  шинэ дүрс
# -----------------------------------------------------------------------------
func _lock_piece() -> void:
	board.lock(shape, pos, piece_id)

	# --- Гинжин урвалын давталт ---
	#  1. Дүүрсэн мөрүүдийг олно
	#  2. Тэдгээрийн нүдийг устгана
	#  3. Таталцал ажиллуулж, өлгөөтэй шоог доош унагана
	#  4. Унасны дараа ШИНЭ мөр үүссэн бол дахин 1 рүү буцна
	#
	#  Давталт бүрд үржүүлэгч (chain) нэгээр өснө.
	#  Шоо бүр устах бүрд талбай дээрх шооны тоо буурдаг тул
	#  давталт заавал дуусна — мөнхийн гогцоо үүсэхгүй.
	var chain: int = 0
	var gained: int = 0

	while true:
		var rows: Array = board.find_full_rows()
		if rows.is_empty():
			break
		chain += 1

		# Нэг шоо X-мөр, Z-мөр хоёуланд нь зэрэг хамаарч болно.
		# Тиймээс Dictionary ашиглан давхардлыг арилгана — эс бөгөөс
		# нэг шоог хоёр удаа тоолж, оноо буруу нэмэгдэнэ.
		var unique: Dictionary = {}
		for row in rows:
			for c in row:
				unique[c] = true
		var to_clear: Array = unique.keys()

		# --- ОНОО: устгасан ШОО бүрд ---
		gained += to_clear.size() * POINTS_PER_BLOCK * chain
		gained += rows.size() * ROW_BONUS * chain

		blocks_destroyed += to_clear.size()
		rows_cleared += rows.size()
		best_chain = maxi(best_chain, chain)

		board.clear_cells(to_clear)
		board.apply_gravity()

	if chain > 0:
		score += gained
		level = 1 + int(rows_cleared / 8)
		fall_interval = maxf(0.12, 0.85 - (level - 1) * 0.06)
		if chain >= 2:
			_toast("ГИНЖ x%d   +%d" % [chain, gained], Color(1.0, 0.82, 0.3))
		else:
			_toast("+%d" % gained, Color(0.55, 0.95, 0.75))
		_check_record()

	_refresh_locked()
	_spawn()


# -----------------------------------------------------------------------------
#  ДЭЭД АМЖИЛТ
# -----------------------------------------------------------------------------
#  ConfigFile ашиглан user:// хавтсанд хадгална.
#  Бодит зам нь үйлдлийн системээс хамаарна, жишээ нь Windows дээр:
#      %APPDATA%\Godot\app_userdata\3D Tetris\tetris3d.cfg
#  Godot доторх цэс: Project → Open User Data Folder
# -----------------------------------------------------------------------------
func _load_stats() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return  # Файл байхгүй — анхны тоглолт
	high_score = int(cfg.get_value("stats", "high_score", 0))
	high_rows = int(cfg.get_value("stats", "high_rows", 0))


func _save_stats() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "high_score", high_score)
	cfg.set_value("stats", "high_rows", high_rows)
	cfg.save(SAVE_PATH)


# Оноо дээд амжилтыг давсан эсэхийг шалгаж, шууд шинэчилнэ
func _check_record() -> void:
	var changed: bool = false
	if score > high_score:
		if not record_beaten:
			record_beaten = true
			_toast("★ ШИНЭ ДЭЭД АМЖИЛТ ★", Color(1.0, 0.85, 0.35))
		high_score = score
		changed = true
	if rows_cleared > high_rows:
		high_rows = rows_cleared
		changed = true
	if changed:
		_save_stats()


func _toast(text: String, color: Color) -> void:
	toast_text = text
	toast_time = 1.6
	toast_label.add_theme_color_override("font_color", color)


# Тоглоом хаагдахад дээд амжилтыг алдахгүйн тулд
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_stats()


func _spawn() -> void:
	piece_id = next_id
	next_id = randi() % Pieces.SHAPES.size()
	shape = (Pieces.SHAPES[piece_id] as Array).duplicate()

	# Дүрс бүхэлдээ талбайн дотор багтахаар өндрийг тооцоолно
	var top: int = 0
	for c in shape:
		top = maxi(top, c.y)
	pos = Vector3i(int(W / 2), H - 1 - top, int(D / 2))

	# Шинэ дүрс тавих зайгүй бол — тоглоом дууслаа
	if not board.can_place(shape, pos):
		game_over = true
		piece_root.visible = false
		ghost_root.visible = false
		_check_record()
		_save_stats()
		toast_time = 0.0
		toast_label.text = ""
		_update_hud()
		return

	fall_timer = 0.0
	_sync_piece()
	_update_hud()


func _restart() -> void:
	board.reset()
	score = 0
	rows_cleared = 0
	blocks_destroyed = 0
	best_chain = 1
	record_beaten = false
	level = 1
	fall_interval = 0.85
	game_over = false
	paused = false
	piece_root.visible = true
	ghost_root.visible = true
	_refresh_locked()
	next_id = randi() % Pieces.SHAPES.size()
	_spawn()


# =============================================================================
#  ХӨДӨЛГӨӨН БА ЭРГЭЛТ
# =============================================================================
func _move(dir: Vector3i) -> void:
	if board.can_place(shape, pos + dir):
		pos += dir
		_sync_piece()


# Эргүүлэхэд шинэ байрлал нь хананд мөргөж болзошгүй.
# Тиймээс бага зэрэг түлхэж ("wall kick") оролдоно —
# энэ нь эргэлтийг хамаагүй тааламжтай болгодог.
const KICKS: Array = [
	Vector3i(0, 0, 0),
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	Vector3i(0, 1, 0),
	Vector3i(2, 0, 0), Vector3i(-2, 0, 0),
	Vector3i(0, 0, 2), Vector3i(0, 0, -2),
]

func _rotate(axis: Vector3i) -> void:
	var rotated: Array = Pieces.rotate(shape, axis)
	for kick in KICKS:
		if board.can_place(rotated, pos + kick):
			shape = rotated
			pos += kick
			_sync_piece()
			return
	# Нэг ч хувилбар таарахгүй бол эргэлт хийхгүй


func _hard_drop() -> void:
	var dropped: int = 0
	while board.can_place(shape, pos + Vector3i(0, -1, 0)):
		pos.y -= 1
		dropped += 1
	score += dropped * HARD_DROP_POINTS
	_sync_piece()
	_lock_piece()


func _rotate_camera(step: int) -> void:
	cam_step = wrapi(cam_step + step, 0, 4)
	cam_yaw_target = cam_step * PI * 0.5


# =============================================================================
#  ОРОЛТ
# =============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if key.echo:
		return

	# Shift барих/тавихыг тусад нь (дарж барих төлөв)
	if key.keycode == KEY_SHIFT:
		soft_drop = key.pressed
		return

	if not key.pressed:
		return

	# --- Хэзээ ч ажилладаг товчлуурууд ---
	match key.keycode:
		KEY_Q:
			_rotate_camera(-1)
			return
		KEY_E:
			_rotate_camera(1)
			return
		KEY_ENTER, KEY_KP_ENTER:
			if game_over:
				_restart()
			return
		KEY_P:
			if not game_over:
				paused = not paused
				_update_hud()
			return
		KEY_ESCAPE:
			_save_stats()
			get_tree().quit()
			return

	if game_over or paused:
		return

	# --- Камерын одоогийн өнцгөөс хамаарсан чиглэлүүд ---
	var dirs: Dictionary = DIRS[cam_step]
	var right: Vector3i = dirs["right"]
	var fwd: Vector3i = dirs["fwd"]

	match key.keycode:
		KEY_LEFT, KEY_A:
			_move(-right)
		KEY_RIGHT, KEY_D:
			_move(right)
		KEY_UP, KEY_W:
			_move(fwd)
		KEY_DOWN, KEY_S:
			_move(-fwd)
		KEY_Z:
			_rotate(right)          # урагш хөмрөх
		KEY_X:
			_rotate(Vector3i(0, 1, 0))  # хэвтээ эргэх
		KEY_C:
			_rotate(fwd)            # хажуу тийш хөмрөх
		KEY_SPACE:
			_hard_drop()
