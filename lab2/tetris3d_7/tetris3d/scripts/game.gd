extends Node3D


const W: int = 6
const D: int = 6
const H: int = 12

const POINTS_PER_BLOCK: int = 12
const ROW_BONUS: int = 30
const HARD_DROP_POINTS: int = 2

const SAVE_PATH: String = "user://tetris3d.cfg"

const CUBE_SIZE: float = 0.94
const GHOST_SCALE: float = 0.90
const GHOST_ALPHA: float = 0.32
const PROJ_ALPHA: float = 0.38

const CAM_PITCH_DEG: float = 35.264
const CAM_YAW_DEG: float = 45.0

const ZOOM_MIN: float = 0.65
const ZOOM_MAX: float = 2.00
const ZOOM_DEFAULT: float = 1.00
const ZOOM_STEP: float = 0.07

const MOVE_RIGHT: Vector3i = Vector3i(1, 0, 0)
const MOVE_FWD: Vector3i = Vector3i(0, 0, -1)

const SHOW_GHOST: bool = true
const CAST_SHADOWS: bool = false

# Унах хурд
const FALL_INTERVAL: float = 1.0
const SOFT_DROP_MULT: float = 10.0

# Газардсаны дараа түгжигдэх хүртэлх хугацаа, хөдөлгөөнөөр хэдэн удаа сэргээж болох
const LOCK_DELAY: float = 0.5
const LOCK_RESETS: int = 15

# Товч дарж барихад давтан хөдлөх
const DAS_DELAY: float = 0.17
const DAS_RATE: float = 0.06

const MOVE_KEYS: Dictionary = {
	KEY_LEFT: Vector3i(-1, 0, 0), KEY_A: Vector3i(-1, 0, 0),
	KEY_RIGHT: Vector3i(1, 0, 0), KEY_D: Vector3i(1, 0, 0),
	KEY_UP: Vector3i(0, 0, -1), KEY_W: Vector3i(0, 0, -1),
	KEY_DOWN: Vector3i(0, 0, 1), KEY_S: Vector3i(0, 0, 1),
}

# Мини-газрын зураг: нэг нүдний хагас диагональ (px)
const MAP_K: float = 16.0
const PANEL_W: float = 250.0
const PANEL_H: float = 360.0

@onready var cam_pivot: Node3D = $CamPivot
@onready var camera: Camera3D = $CamPivot/Camera3D
@onready var sun: DirectionalLight3D = $DirectionalLight3D

var board: Board

var shape: Array = []
var pos: Vector3i
var piece_id: int = 0
var next_id: int = 0
var bag: Array = []

var hold_id: int = -1
var hold_used: bool = false

var fall_timer: float = 0.0
var soft_drop: bool = false

var lock_timer: float = 0.0
var lock_resets: int = 0

var held_key: int = 0
var held_dir: Vector3i = Vector3i.ZERO
var das_timer: float = 0.0

var started: bool = false
var paused: bool = false
var game_over: bool = false
var score: int = 0
var rows_cleared: int = 0
var blocks_destroyed: int = 0
var best_chain: int = 1

var high_score: int = 0
var high_rows: int = 0
var record_beaten: bool = false

var toast_text: String = ""
var toast_time: float = 0.0

var show_help: bool = true

var cam_home: Vector3 = Vector3.ZERO
var zoom: float = ZOOM_DEFAULT
var zoom_target: float = ZOOM_DEFAULT
var shake: float = 0.0

var locked_root: Node3D
var piece_root: Node3D
var ghost_root: Node3D
var proj_x_root: Node3D
var proj_z_root: Node3D
var fx_root: Node3D
var cube_mesh: BoxMesh
var proj_x_mesh: BoxMesh
var proj_z_mesh: BoxMesh
var flash_mat: StandardMaterial3D
var _materials: Dictionary = {}

var hud: RichTextLabel
var panel_style: StyleBoxFlat
var big_label: Label
var toast_label: Label
var side_panel: Control


func _ready() -> void:
	randomize()

	board = Board.new(W, D, H)
	_load_stats()

	locked_root = Node3D.new()
	piece_root = Node3D.new()
	ghost_root = Node3D.new()
	proj_x_root = Node3D.new()
	proj_z_root = Node3D.new()
	fx_root = Node3D.new()
	for r in [locked_root, piece_root, ghost_root, proj_x_root, proj_z_root, fx_root]:
		add_child(r)

	cube_mesh = BoxMesh.new()
	cube_mesh.size = Vector3.ONE * CUBE_SIZE
	proj_x_mesh = BoxMesh.new()
	proj_x_mesh.size = Vector3(0.02, 0.9, 0.9)
	proj_z_mesh = BoxMesh.new()
	proj_z_mesh.size = Vector3(0.9, 0.9, 0.02)

	flash_mat = StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.albedo_color = Color(1.0, 0.95, 0.85)

	_setup_camera()
	_setup_light()
	_build_well()
	_build_floor_labels()
	_build_hud()

	next_id = _random_piece_id()
	_spawn()


func _setup_camera() -> void:
	cam_pivot.position = Vector3(0, H * 0.32, 0)
	cam_pivot.rotation.y = deg_to_rad(CAM_YAW_DEG)

	var half_fov: float = deg_to_rad(camera.fov * 0.5)
	var aspect: float = camera.get_viewport().get_visible_rect().size.aspect()
	var yaw: float = deg_to_rad(CAM_YAW_DEG)

	var need_v: float = maxf(H - cam_pivot.position.y, cam_pivot.position.y) + 1.0
	var dist_v: float = need_v / tan(half_fov)

	var half_w: float = (W * absf(cos(yaw)) + D * absf(sin(yaw))) * 0.5 + 1.0
	var dist_h: float = half_w / (tan(half_fov) * aspect)

	var dist: float = maxf(dist_v, dist_h)

	var pitch: float = deg_to_rad(CAM_PITCH_DEG)
	cam_home = Vector3(0.0, sin(pitch) * dist, cos(pitch) * dist)

	camera.position = cam_home
	camera.look_at(cam_pivot.global_position)

	camera.position = cam_home * zoom


func _zoom_by(amount: float) -> void:
	var before: float = zoom_target
	zoom_target = clampf(zoom_target + amount, ZOOM_MIN, ZOOM_MAX)
	if not is_equal_approx(before, zoom_target):
		_save_stats()


func _update_camera(delta: float) -> void:
	if absf(zoom - zoom_target) > 0.001:
		zoom = lerpf(zoom, zoom_target, clampf(delta * 12.0, 0.0, 1.0))

	shake = maxf(0.0, shake - delta * 2.5)
	var off := Vector3.ZERO
	if shake > 0.0:
		off = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * shake * 0.12
	camera.position = cam_home * zoom + camera.basis * off


func _setup_light() -> void:
	sun.rotation_degrees = Vector3(-55, -40, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = CAST_SHADOWS


func cell_to_world(c: Vector3i) -> Vector3:
	return Vector3(
		float(c.x) - W * 0.5 + 0.5,
		float(c.y) + 0.5,
		float(c.z) - D * 0.5 + 0.5
	)


func _build_well() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)

	var hx: float = W * 0.5
	var hz: float = D * 0.5

	var floor_col := Color(0.50, 0.62, 0.85, 0.65)
	for i in range(W + 1):
		_line(im, Vector3(-hx + i, 0, -hz), Vector3(-hx + i, 0, hz), floor_col, floor_col)
	for i in range(D + 1):
		_line(im, Vector3(-hx, 0, -hz + i), Vector3(hx, 0, -hz + i), floor_col, floor_col)

	# Арын хоёр хананы тор: дүрсний проекц аль нүдэнд байгааг уншихад
	var wall := Color(0.40, 0.52, 0.80, 0.10)
	for i in range(D + 1):
		_line(im, Vector3(-hx, 0, -hz + i), Vector3(-hx, H, -hz + i), wall, wall)
	for i in range(W + 1):
		_line(im, Vector3(-hx + i, 0, -hz), Vector3(-hx + i, H, -hz), wall, wall)
	for y in range(1, H + 1):
		_line(im, Vector3(-hx, y, -hz), Vector3(-hx, y, hz), wall, wall)
		_line(im, Vector3(-hx, y, -hz), Vector3(hx, y, -hz), wall, wall)

	var edge_a := Color(0.45, 0.58, 0.85, 0.55)
	var edge_b := Color(0.45, 0.58, 0.85, 0.0)
	for p in [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]:
		_line(im, Vector3(p.x, 0, p.y), Vector3(p.x, H, p.y), edge_a, edge_b)

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


# Шалны дөрвөн талд аль товч тийшээ хөдөлгөдгийг бичнэ
func _build_floor_labels() -> void:
	var hx: float = W * 0.5 + 0.8
	var hz: float = D * 0.5 + 0.8
	var items: Array = [
		["W", Vector3(0, 0.1, -hz)],
		["S", Vector3(0, 0.1, hz)],
		["A", Vector3(-hx, 0.1, 0)],
		["D", Vector3(hx, 0.1, 0)],
	]
	for it in items:
		var l := Label3D.new()
		l.text = it[0]
		l.position = it[1]
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 56
		l.outline_size = 10
		l.pixel_size = 0.01
		l.modulate = Color(0.75, 0.85, 1.0, 0.75)
		add_child(l)


func _line(im: ImmediateMesh, a: Vector3, b: Vector3, ca: Color, cb: Color) -> void:
	im.surface_set_color(ca)
	im.surface_add_vertex(a)
	im.surface_set_color(cb)
	im.surface_add_vertex(b)


# Буусан шоог давхаргын өндрөөр будна: доод нь хөх → ногоон → шар → дээд нь шүрэн улаан
const LAYER_GRADIENT: Array = [
	Color8(91, 127, 214),
	Color8(79, 179, 191),
	Color8(124, 196, 138),
	Color8(230, 201, 106),
	Color8(229, 138, 110),
]

func _layer_color(y: int) -> Color:
	var t: float = clampf(float(y) / float(H - 1), 0.0, 1.0) * (LAYER_GRADIENT.size() - 1)
	var i: int = mini(int(t), LAYER_GRADIENT.size() - 2)
	return (LAYER_GRADIENT[i] as Color).lerp(LAYER_GRADIENT[i + 1], t - i)


func _material(id: int, ghost: bool) -> StandardMaterial3D:
	var key: String = "%d|%s" % [id, ghost]
	if _materials.has(key):
		return _materials[key]

	var c: Color = Pieces.COLORS[id]
	var m := StandardMaterial3D.new()
	if ghost:
		m.albedo_color = Color(c.r, c.g, c.b, GHOST_ALPHA)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		_solid(m, c)
	_materials[key] = m
	return m


func _layer_material(y: int) -> StandardMaterial3D:
	var key: String = "layer|%d" % y
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		_solid(m, _layer_color(y))
		_materials[key] = m
	return _materials[key]


func _proj_material(id: int) -> StandardMaterial3D:
	var key: String = "proj|%d" % id
	if not _materials.has(key):
		var c: Color = Pieces.COLORS[id]
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(c.r, c.g, c.b, PROJ_ALPHA)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials[key] = m
	return _materials[key]


func _solid(m: StandardMaterial3D, c: Color) -> void:
	m.albedo_color = c
	m.metallic = 0.05
	m.roughness = 0.6
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.15


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
					mi.material_override = _layer_material(y)
					mi.position = cell_to_world(Vector3i(x, y, z))
					locked_root.add_child(mi)


func _ghost_pos() -> Vector3i:
	var g: Vector3i = pos
	while board.can_place(shape, g + Vector3i(0, -1, 0)):
		g.y -= 1
	return g


func _sync_piece() -> void:
	_fill(piece_root, shape, pos, piece_id, false)
	if SHOW_GHOST:
		_fill(ghost_root, shape, _ghost_pos(), piece_id, true)
	_sync_projections()
	if side_panel:
		side_panel.queue_redraw()


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
			node.scale = Vector3.ONE * (GHOST_SCALE if ghost else 1.0)
		else:
			node.visible = false


# Дүрсийг арын хоёр хананд тусгана (x = -W/2 ба z = -D/2 хана)
func _sync_projections() -> void:
	var on_x: Dictionary = {}
	var on_z: Dictionary = {}
	for off in shape:
		var c: Vector3i = pos + off
		var w: Vector3 = cell_to_world(c)
		on_x[Vector2i(c.y, c.z)] = Vector3(-W * 0.5 + 0.012, w.y, w.z)
		on_z[Vector2i(c.x, c.y)] = Vector3(w.x, w.y, -D * 0.5 + 0.012)
	_fill_proj(proj_x_root, proj_x_mesh, on_x.values())
	_fill_proj(proj_z_root, proj_z_mesh, on_z.values())


func _fill_proj(root: Node3D, mesh: Mesh, points: Array) -> void:
	while root.get_child_count() < points.size():
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		root.add_child(mi)

	for i in root.get_child_count():
		var node: MeshInstance3D = root.get_child(i)
		node.visible = i < points.size()
		if node.visible:
			node.material_override = _proj_material(piece_id)
			node.position = points[i]


func _set_piece_visible(v: bool) -> void:
	for r in [piece_root, ghost_root, proj_x_root, proj_z_root]:
		r.visible = v


# Цэвэрлэгдсэн шоо цагаан гялсхийгээд жижгэрч алга болно
func _burst(cells: Array) -> void:
	for c in cells:
		var mi := MeshInstance3D.new()
		mi.mesh = cube_mesh
		mi.material_override = flash_mat
		mi.position = cell_to_world(c)
		fx_root.add_child(mi)
		var tw := mi.create_tween()
		tw.tween_property(mi, "scale", Vector3.ONE * 1.2, 0.07)
		tw.tween_property(mi, "scale", Vector3.ZERO, 0.28) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)


# =============================================================================
#  HUD
# =============================================================================
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.03, 0.04, 0.08, 0.6)
	panel_style.border_color = Color(0.45, 0.55, 0.8, 0.18)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(14)

	var hud_box := PanelContainer.new()
	hud_box.position = Vector2(14, 14)
	hud_box.add_theme_stylebox_override("panel", panel_style)
	hud_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud_box)

	hud = RichTextLabel.new()
	hud.bbcode_enabled = true
	hud.fit_content = true
	hud.scroll_active = false
	hud.autowrap_mode = TextServer.AUTOWRAP_OFF
	hud.custom_minimum_size = Vector2(330, 0)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_theme_font_size_override("normal_font_size", 15)
	hud.add_theme_color_override("default_color", Color(0.9, 0.93, 1.0))
	hud_box.add_child(hud)

	side_panel = Control.new()
	side_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	side_panel.offset_left = -PANEL_W - 14
	side_panel.offset_right = -14
	side_panel.offset_top = 14
	side_panel.offset_bottom = 14 + PANEL_H
	side_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side_panel.draw.connect(_draw_panel)
	layer.add_child(side_panel)

	big_label = Label.new()
	big_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	big_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big_label.add_theme_font_size_override("font_size", 34)
	big_label.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	big_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	big_label.add_theme_constant_override("shadow_offset_y", 3)
	big_label.text = ""
	layer.add_child(big_label)

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


# Дээрээс харсан байдлыг камертай ижил 45° эргүүлж зурна:
# +x (D) баруун-доош, -z (W) баруун-дээш — 3D дэлгэцтэй ижил чиглэл.
func _iso(center: Vector2, u: float, v: float, k: float) -> Vector2:
	return center + Vector2(u - v, u + v) * k


func _cell_poly(center: Vector2, u: float, v: float, k: float) -> PackedVector2Array:
	return PackedVector2Array([
		_iso(center, u - 0.5, v - 0.5, k),
		_iso(center, u + 0.5, v - 0.5, k),
		_iso(center, u + 0.5, v + 0.5, k),
		_iso(center, u - 0.5, v + 0.5, k),
	])


func _outline(poly: PackedVector2Array, color: Color, width: float) -> void:
	var closed := poly.duplicate()
	closed.append(poly[0])
	side_panel.draw_polyline(closed, color, width, true)


func _draw_shape(sh: Array, id: int, center: Vector2, k: float, dim: bool) -> void:
	var mid := Vector2.ZERO
	for c in sh:
		mid += Vector2(c.x, c.z)
	mid /= sh.size()
	var col: Color = Pieces.COLORS[id]
	if dim:
		col = col.darkened(0.45)
	var seen: Dictionary = {}
	for c in sh:
		var key := Vector2i(c.x, c.z)
		if seen.has(key):
			continue
		seen[key] = true
		var poly := _cell_poly(center, c.x - mid.x, c.z - mid.y, k)
		side_panel.draw_colored_polygon(poly, col)
		_outline(poly, Color(0, 0, 0, 0.5), 1.0)


func _draw_panel() -> void:
	var font: Font = ThemeDB.fallback_font
	var text_col := Color(0.85, 0.9, 1.0)
	var sub_col := Color(0.6, 0.68, 0.85)

	side_panel.draw_style_box(panel_style, Rect2(0, 0, PANEL_W, PANEL_H))

	# Дараагийн ба хадгалсан дүрс
	var half: float = PANEL_W * 0.5
	side_panel.draw_string(font, Vector2(0, 24), "Дараагийн", HORIZONTAL_ALIGNMENT_CENTER, half, 15, text_col)
	side_panel.draw_string(font, Vector2(half, 24), "Хадгалсан (Q)", HORIZONTAL_ALIGNMENT_CENTER, half, 15, text_col)
	_draw_shape(Pieces.SHAPES[next_id], next_id, Vector2(half * 0.5, 66), 8.0, false)
	if hold_id >= 0:
		_draw_shape(Pieces.SHAPES[hold_id], hold_id, Vector2(half * 1.5, 66), 8.0, hold_used)
	else:
		side_panel.draw_string(font, Vector2(half, 71), "—", HORIZONTAL_ALIGNMENT_CENTER, half, 18, sub_col)

	# Дээрээс харсан газрын зураг
	side_panel.draw_string(font, Vector2(0, 124), "Дээрээс харахад", HORIZONTAL_ALIGNMENT_CENTER, PANEL_W, 15, text_col)
	var center := Vector2(half, 238)
	var k: float = MAP_K

	var piece_cells: Dictionary = {}
	if not game_over:
		for off in shape:
			piece_cells[Vector2i(pos.x + off.x, pos.z + off.z)] = true

	for z in D:
		for x in W:
			var u: float = x - W * 0.5 + 0.5
			var v: float = z - D * 0.5 + 0.5
			var poly := _cell_poly(center, u, v, k)
			var h: int = board.column_height(x, z)
			var fill := Color(1, 1, 1, 0.05)
			if h > 0:
				fill = _layer_color(h - 1).darkened(0.25)
			side_panel.draw_colored_polygon(poly, fill)
			_outline(poly, Color(0.5, 0.6, 0.85, 0.35), 1.0)
			if h > 0:
				var p := _iso(center, u, v, k)
				side_panel.draw_string(font, p + Vector2(-16, 5), str(h), HORIZONTAL_ALIGNMENT_CENTER, 32, 13, Color(0, 0, 0, 0.85))

	var pc: Color = Pieces.COLORS[piece_id]
	for key in piece_cells:
		var u: float = key.x - W * 0.5 + 0.5
		var v: float = key.y - D * 0.5 + 0.5
		var poly := _cell_poly(center, u, v, k)
		side_panel.draw_colored_polygon(poly, Color(pc.r, pc.g, pc.b, 0.45))
		_outline(poly, Color(1, 1, 1, 0.95), 2.0)

	# Товчны шошго: 3D шалан дээрхтэй ижил байрлалд
	var r: float = D * 0.5 + 0.75
	for it in [["W", 0.0, -r], ["S", 0.0, r], ["A", -r, 0.0], ["D", r, 0.0]]:
		var p := _iso(center, it[1], it[2], k)
		side_panel.draw_string(font, p + Vector2(-10, 6), it[0], HORIZONTAL_ALIGNMENT_CENTER, 20, 16, sub_col)


const HELP_LINES: Array = [
	["WASD / сум", "хөдөлгөх (шалан дээрх үсгийг хар)"],
	["Z / X / C", "3 тэнхлэгээр эргүүлэх"],
	["Shift", "хурдан унагах"],
	["Space", "шидэх"],
	["Q", "дүрс хадгалах / солих"],
	["+ / − / дугуй", "томруулах"],
	["P", "түр зогсоох"],
	["Enter", "эхлэх / дахин"],
]

const C_LABEL: String = "#8C98BA"
const C_VALUE: String = "#E6EAF5"
const C_SCORE: String = "#F2D06B"
const C_KEY: String = "#C9D3EE"
const C_HELP: String = "#7F8AA8"


func _row(label: String, value: String, color: String = C_VALUE) -> String:
	return "[color=%s]%s[/color]  [color=%s]%s[/color]" % [C_LABEL, label, color, value]


func _update_hud() -> void:
	var record_mark: String = "  [color=%s]★[/color]" % C_SCORE if record_beaten else ""
	var lines: Array = [
		"[font_size=24][color=%s]%d[/color][/font_size]%s" % [C_SCORE, score, record_mark],
		_row("Дээд амжилт", str(high_score)),
		"",
		_row("Цэвэрлэсэн мөр", str(rows_cleared)),
		_row("Устгасан блок", str(blocks_destroyed)),
		_row("Хамгийн урт гинж", "x%d" % best_chain),
		"",
	]

	var help: Array = []
	if show_help:
		for h in HELP_LINES:
			help.append("[color=%s]%s[/color]  [color=%s]%s[/color]" % [C_KEY, h[0], C_HELP, h[1]])
		help.append("[color=%s]H[/color]  [color=%s]энэ жагсаалтыг нуух[/color]" % [C_KEY, C_HELP])
	else:
		help.append("[color=%s]H[/color]  [color=%s]удирдлага[/color]" % [C_KEY, C_HELP])
	lines.append("[font_size=13]%s[/font_size]" % "\n".join(help))

	hud.text = "\n".join(lines)

	if not started:
		big_label.text = "3D ТЕТРИС\n\nEnter — эхлэх"
	elif game_over:
		var over_lines: Array = ["ТОГЛООМ ДУУСЛАА", "Оноо: %d" % score]
		if record_beaten:
			over_lines.append("★ ШИНЭ ДЭЭД АМЖИЛТ ★")
		else:
			over_lines.append("Дээд амжилт: %d" % high_score)
		over_lines.append("")
		over_lines.append("Enter — дахин")
		big_label.text = "\n".join(over_lines)
	elif paused:
		big_label.text = "ТҮР ЗОГССОН"
	else:
		big_label.text = ""

	side_panel.queue_redraw()


func _process(delta: float) -> void:
	_update_camera(delta)

	if toast_time > 0.0:
		toast_time -= delta
		toast_label.text = toast_text
		toast_label.modulate.a = clampf(toast_time / 0.6, 0.0, 1.0)
		if toast_time <= 0.0:
			toast_label.text = ""

	if game_over or paused or not started:
		return

	_update_repeat(delta)

	if _grounded():
		lock_timer += delta
		if lock_timer >= LOCK_DELAY:
			_lock_piece()
	else:
		lock_timer = 0.0
		fall_timer += delta * (SOFT_DROP_MULT if soft_drop else 1.0)
		if fall_timer >= FALL_INTERVAL:
			fall_timer = 0.0
			pos.y -= 1
			_sync_piece()


func _update_repeat(delta: float) -> void:
	if held_dir == Vector3i.ZERO:
		return
	das_timer -= delta
	while das_timer <= 0.0:
		_move(held_dir)
		das_timer += DAS_RATE


func _grounded() -> bool:
	return not board.can_place(shape, pos + Vector3i(0, -1, 0))


# Газардсан дүрсийг хөдөлгөхөд түгжих хугацааг сэргээнэ (хязгаартай)
func _on_piece_moved() -> void:
	if lock_timer > 0.0 and lock_resets < LOCK_RESETS:
		lock_timer = 0.0
		lock_resets += 1


func _lock_piece() -> void:
	board.lock(shape, pos, piece_id)

	var chain: int = 0
	var gained: int = 0
	var total_rows: int = 0

	while true:
		var rows: Array = board.find_full_rows()
		if rows.is_empty():
			break
		chain += 1

		var unique: Dictionary = {}
		for row in rows:
			for c in row:
				unique[c] = true
		var to_clear: Array = unique.keys()

		gained += to_clear.size() * POINTS_PER_BLOCK * chain
		gained += rows.size() * ROW_BONUS * chain

		blocks_destroyed += to_clear.size()
		rows_cleared += rows.size()
		total_rows += rows.size()
		best_chain = maxi(best_chain, chain)

		_burst(to_clear)
		board.clear_cells(to_clear)
		board.apply_gravity()

	if chain > 0:
		score += gained
		shake = minf(1.0, 0.2 + 0.1 * total_rows + 0.25 * (chain - 1))
		if chain >= 2:
			_toast("ГИНЖ x%d   +%d" % [chain, gained], Color(0.95, 0.82, 0.42))
		else:
			_toast("+%d" % gained, Color(0.48, 0.80, 0.52))
		_check_record()

	_refresh_locked()
	hold_used = false
	_spawn()


func _load_stats() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	high_score = int(cfg.get_value("stats", "high_score", 0))
	high_rows = int(cfg.get_value("stats", "high_rows", 0))

	zoom_target = clampf(float(cfg.get_value("view", "zoom", ZOOM_DEFAULT)), ZOOM_MIN, ZOOM_MAX)
	zoom = zoom_target
	show_help = bool(cfg.get_value("view", "show_help", true))


func _save_stats() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "high_score", high_score)
	cfg.set_value("stats", "high_rows", high_rows)
	cfg.set_value("view", "zoom", zoom_target)
	cfg.set_value("view", "show_help", show_help)
	cfg.save(SAVE_PATH)


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


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_stats()


# "7-bag": бүх дүрс нэг удаа гарсны дараа л дахин холино — нэг дүрс
# дараалан олон ирэх, эсвэл удаан ирэхгүй байх явдал гарахгүй.
func _random_piece_id() -> int:
	if bag.is_empty():
		bag = Pieces.ACTIVE.duplicate()
		bag.shuffle()
	return int(bag.pop_back())


func _spawn() -> void:
	var id: int = next_id
	next_id = _random_piece_id()
	_spawn_piece(id)


func _spawn_piece(id: int) -> void:
	piece_id = id
	shape = (Pieces.SHAPES[piece_id] as Array).duplicate()

	var top: int = 0
	for c in shape:
		top = maxi(top, c.y)
	pos = Vector3i(int(W / 2), H - 1 - top, int(D / 2))

	fall_timer = 0.0
	lock_timer = 0.0
	lock_resets = 0

	if not board.can_place(shape, pos):
		game_over = true
		held_dir = Vector3i.ZERO
		_set_piece_visible(false)
		_check_record()
		_save_stats()
		toast_time = 0.0
		toast_label.text = ""
		_update_hud()
		return

	_sync_piece()
	_update_hud()


func _hold() -> void:
	if hold_used:
		return
	hold_used = true
	var cur: int = piece_id
	if hold_id < 0:
		hold_id = cur
		_spawn()
	else:
		var swap: int = hold_id
		hold_id = cur
		_spawn_piece(swap)


func _restart() -> void:
	board.reset()
	score = 0
	rows_cleared = 0
	blocks_destroyed = 0
	best_chain = 1
	record_beaten = false
	game_over = false
	paused = false
	hold_id = -1
	hold_used = false
	held_dir = Vector3i.ZERO
	bag.clear()
	_set_piece_visible(true)
	_refresh_locked()
	next_id = _random_piece_id()
	_spawn()


func _move(dir: Vector3i) -> void:
	if board.can_place(shape, pos + dir):
		pos += dir
		_on_piece_moved()
		_sync_piece()


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
			_on_piece_moved()
			_sync_piece()
			return


func _hard_drop() -> void:
	var dropped: int = 0
	while board.can_place(shape, pos + Vector3i(0, -1, 0)):
		pos.y -= 1
		dropped += 1
	score += dropped * HARD_DROP_POINTS
	shake = maxf(shake, 0.12)
	_sync_piece()
	_lock_piece()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_by(-ZOOM_STEP)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_by(ZOOM_STEP)
		return

	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if key.echo:
		return

	if key.keycode == KEY_SHIFT:
		soft_drop = key.pressed
		return

	if not key.pressed:
		if key.keycode == held_key:
			held_dir = Vector3i.ZERO
			held_key = 0
		return

	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			if not started:
				started = true
				_update_hud()
			elif game_over:
				_restart()
			return
		KEY_P:
			if started and not game_over:
				paused = not paused
				held_dir = Vector3i.ZERO
				_update_hud()
			return
		KEY_H:
			show_help = not show_help
			_save_stats()
			_update_hud()
			return
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_zoom_by(-ZOOM_STEP)
			return
		KEY_MINUS, KEY_KP_SUBTRACT:
			_zoom_by(ZOOM_STEP)
			return
		KEY_0, KEY_KP_0:
			zoom_target = ZOOM_DEFAULT
			_save_stats()
			return
		KEY_ESCAPE:
			# Браузерт Esc нь fullscreen-ээс гаргадаг тул тоглоомыг хаахгүй
			if OS.has_feature("web"):
				return
			_save_stats()
			get_tree().quit()
			return

	if game_over or paused or not started:
		return

	if MOVE_KEYS.has(key.keycode):
		held_key = key.keycode
		held_dir = MOVE_KEYS[key.keycode]
		das_timer = DAS_DELAY
		_move(held_dir)
		return

	match key.keycode:
		KEY_Z:
			_rotate(MOVE_RIGHT)
		KEY_X:
			_rotate(Vector3i(0, 1, 0))
		KEY_C:
			_rotate(MOVE_FWD)
		KEY_Q:
			_hold()
		KEY_SPACE:
			_hard_drop()
