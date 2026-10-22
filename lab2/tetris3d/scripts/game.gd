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
#  АНХААР: давхарга цэвэрлэхийн тулд W * D ширхэг нүд БҮГД дүүрэх ёстой.
#  5x5 = 25 нүд. 6x6 бол 36 болж, хэцүү болно. 4x4 = 16 бол хялбар.
const W: int = 5    # өргөн
const D: int = 5    # гүн
const H: int = 12   # өндөр

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

const SCORE_TABLE: Array = [0, 100, 300, 600, 1000, 1500, 2000]

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
var layers_cleared: int = 0
var level: int = 1

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


# =============================================================================
#  ЭХЛҮҮЛЭХ
# =============================================================================
func _ready() -> void:
	randomize()

	board = Board.new(W, D, H)

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

	_update_hud()


func _update_hud() -> void:
	hud.text = "\n".join([
		"Оноо: %d" % score,
		"Цэвэрлэсэн давхар: %d" % layers_cleared,
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
		big_label.text = "ТОГЛООМ ДУУСЛАА\nОноо: %d\n\nEnter — дахин" % score
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

	var full: Array = board.full_layers()
	if full.size() > 0:
		board.remove_layers(full)
		layers_cleared += full.size()
		score += SCORE_TABLE[mini(full.size(), SCORE_TABLE.size() - 1)]
		level = 1 + int(layers_cleared / 5)
		fall_interval = maxf(0.12, 0.85 - (level - 1) * 0.07)

	_refresh_locked()
	_spawn()


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
		_update_hud()
		return

	fall_timer = 0.0
	_sync_piece()
	_update_hud()


func _restart() -> void:
	board.reset()
	score = 0
	layers_cleared = 0
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
	score += dropped * 2
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
