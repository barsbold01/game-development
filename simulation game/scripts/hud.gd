class_name Hud
extends CanvasLayer
## HUD — дээд мөр (түвшин, хонь, цаг, чоно, хуцалт), доод хоосон мөр,
## симуляцийн самбар, түр бичиг, цэс ба үр дүнгийн самбар. Бүгдийг кодоор үүсгэнэ.

const HISTORY := 40

var level_label: Label
var count_label: Label
var time_label: Label
var eaten_label: Label
var bark_label: Label
var experiment_label: Label
var message_label: Label
var message_tween: Tween
var stats: Control
var panel: ColorRect
var title_label: Label
var sub_label: Label
var body_label: Label
var stars: Control
var _stars := -1            # -1 = од харуулахгүй
var _fear := 0.0
var _groups := 1
var _spread := 0.0
var _fear_hist := PackedFloat32Array()
var _group_hist := PackedFloat32Array()


func _ready() -> void:
	# Дээд мөр
	add_child(_bar(Rect2(0, 0, 480, 22)))
	level_label = _label(self, Vector2(8, 3), 12)
	count_label = _label(self, Vector2(96, 3), 12)
	time_label = _label(self, Vector2(194, 3), 12)
	eaten_label = _label(self, Vector2(252, 3), 12)
	bark_label = _label(self, Vector2(376, 3), 12)

	# Доод мөр: хоосон хүрээ (тоглогчид товчны жагсаалт харуулахгүй)
	add_child(_bar(Rect2(0, 280, 480, 20)))

	# Симуляцийн самбар: айдас, бүлэг, тархалт, 10 секундын график
	stats = Control.new()
	stats.position = Vector2(338, 26)
	stats.size = Vector2(136, 66)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.draw.connect(_draw_stats)
	add_child(stats)

	experiment_label = _label(self, Vector2(8, 25), 10)
	experiment_label.text = "ТУРШИЛТ: дүрэм өөрчилсөн тул од хадгалагдахгүй"
	experiment_label.add_theme_color_override("font_color", Color("ffd43b"))
	experiment_label.visible = false

	# Дэлгэцийн голын түр бичиг ("Чоно гарч ирлээ!" гэх мэт)
	message_label = _label(self, Vector2(0, 44), 16)
	message_label.size = Vector2(480, 22)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_color", Color("ffe66d"))
	message_label.modulate.a = 0.0

	# Цэс ба үр дүнгийн самбар
	panel = _bar(Rect2(0, 0, 480, 300))
	panel.color = Color(0.05, 0.07, 0.12, 0.66)
	add_child(panel)
	title_label = _centered(panel, 46, 30)
	sub_label = _centered(panel, 92, 18)
	sub_label.add_theme_color_override("font_color", Color("ffd43b"))
	stars = Control.new()
	stars.position = Vector2(0, 138)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.draw.connect(_draw_stars)
	panel.add_child(stars)
	body_label = _centered(panel, 158, 13)
	body_label.size.y = 110


func update_status(num: int, level_name: String, inside: int, goal: int, time_left: float,
		eaten: int, max_eaten: int, wolves: bool, bark_ready: bool) -> void:
	level_label.text = "%d. %s" % [num, level_name]
	count_label.text = "Хашаанд %d/%d" % [inside, goal]
	time_label.text = "Цаг %d" % ceili(time_left)
	time_label.modulate = Color("ff8a75") if time_left <= 10.0 else Color.WHITE
	eaten_label.visible = wolves
	eaten_label.text = "Чоно идсэн %d/%d" % [eaten, max_eaten]
	eaten_label.modulate = Color("ff8a75") if eaten > 0 and eaten >= max_eaten else Color.WHITE
	bark_label.text = "Хуцах: бэлэн" if bark_ready else "Хуцах: хүлээ"
	bark_label.modulate.a = 1.0 if bark_ready else 0.5


func set_experiment(experiment: bool) -> void:
	experiment_label.visible = experiment


func update_stats(fear: float, groups: int, spread: float, fear_hist: PackedFloat32Array, group_hist: PackedFloat32Array) -> void:
	_fear = fear
	_groups = groups
	_spread = spread
	_fear_hist = fear_hist
	_group_hist = group_hist
	stats.queue_redraw()


func toggle_stats() -> void:
	stats.visible = not stats.visible


func flash(text: String) -> void:
	message_label.text = text
	if message_tween:
		message_tween.kill()
	message_label.modulate.a = 1.0
	message_tween = create_tween()
	message_tween.tween_interval(1.2)
	message_tween.tween_property(message_label, "modulate:a", 0.0, 0.5)


func show_menu(num: int, total: int, level_name: String, desc: String, sheep: int, goal: int,
		seconds: int, best: int, can_prev: bool, can_next: bool) -> void:
	_stars = best
	var arrows := "%s%d/%d. %s%s" % ["<   " if can_prev else "", num, total, level_name, "   >" if can_next else ""]
	var locked := "" if can_next or num == total else "\nДараагийн түвшин энэ түвшинг давахад нээгдэнэ"
	_show("ХОНЬ ТУУГЧ", arrows, "%s\nЗорилго: %d хонины %d нь хашаанд, %d секунд%s\n\nДарж эхлэх    < > түвшин сонгох" % [desc, sheep, goal, seconds, locked])


func show_result(win: bool, star_count: int, reason: String, num: int, level_name: String,
		inside: int, goal: int, used_time: float, has_next: bool, experiment: bool) -> void:
	var note := "\n(Туршилтын горим: од хадгалагдаагүй)" if experiment else ""
	var sub := "%d. %s" % [num, level_name]
	if win:
		_stars = star_count
		var next := "Дарж дараагийн түвшин" if has_next else "Бүх түвшинг давлаа! Дарж дахин тоглох"
		_show("СҮРЭГ ГЭРТЭЭ!", sub, "%d секундэд %d хонь хашаанд орлоо.%s\n\n%s    Esc цэс" % [roundi(used_time), inside, note, next])
	elif reason == "eaten":
		_stars = -1
		_show("ЧОНО ХЭТ ОЛОН ХОНЬ ИДЛЭЭ", sub, "Чоно ойртоход хуцаж хөө. Сүргээ ганцааранг нь бүү орхи.%s\n\nДарж дахин оролдох    Esc цэс" % note)
	else:
		_stars = -1
		_show("ЦАГ ДУУСЛАА", sub, "%d/%d хонь орсон. Сүргийн ард байж зөөлөн шах.%s\n\nДарж дахин оролдох    Esc цэс" % [inside, goal, note])


func hide_panel() -> void:
	panel.visible = false


func _show(title: String, sub: String, body: String) -> void:
	title_label.text = title
	sub_label.text = sub
	body_label.text = body
	panel.visible = true
	stars.queue_redraw()


## Од (0–3): цэс дээр хамгийн сайн үр дүн, ялалтад шинэ үр дүн
func _draw_stars() -> void:
	if _stars < 0:
		return
	for i in 3:
		var c := Vector2(240 + (i - 1) * 34, 0)
		var pts := PackedVector2Array()
		for k in 10:
			var r := 13.0 if k % 2 == 0 else 5.5
			pts.append(c + Vector2.from_angle(-PI / 2 + k * PI / 5) * r)
		stars.draw_colored_polygon(pts, Color("ffd43b") if i < _stars else Color(1, 1, 1, 0.2))


func _draw_stats() -> void:
	var font := ThemeDB.fallback_font
	stats.draw_rect(Rect2(Vector2.ZERO, stats.size), Color(0.09, 0.11, 0.18, 0.72))
	stats.draw_string(font, Vector2(6, 13), "Айдас", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	stats.draw_rect(Rect2(42, 6, 62, 6), Color(1, 1, 1, 0.15))
	stats.draw_rect(Rect2(42, 6, 62 * clampf(_fear, 0.0, 1.0), 6), Color("ff6b5b"))
	stats.draw_string(font, Vector2(108, 13), "%d%%" % roundi(_fear * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	stats.draw_string(font, Vector2(6, 28), "Бүлэг %d, тархалт %d" % [_groups, roundi(_spread)], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	var top := 5.0
	for g in _group_hist:
		top = maxf(top, g)
	_spark(_group_hist, top, Color(1, 1, 1, 0.8))
	_spark(_fear_hist, 1.0, Color("ff6b5b"))


## Сүүлийн 10 секундын график: улаан = айдас, цагаан = бүлгийн тоо
func _spark(values: PackedFloat32Array, top: float, col: Color) -> void:
	if values.size() < 2:
		return
	var pts := PackedVector2Array()
	for i in values.size():
		pts.append(Vector2(6 + 124.0 * i / (HISTORY - 1), 62 - 28 * clampf(values[i] / top, 0.0, 1.0)))
	stats.draw_polyline(pts, col, 1.0)


func _bar(rect: Rect2) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color(0.09, 0.11, 0.18, 0.7)
	bar.position = rect.position
	bar.size = rect.size
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE   # Дарсныг тоглоом руу нэвтрүүлнэ
	return bar


func _centered(parent: Node, y: float, font_size: int) -> Label:
	var l := _label(parent, Vector2(0, y), font_size)
	l.size = Vector2(480, font_size + 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _label(parent: Node, pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color("1b2030"))
	l.add_theme_constant_override("outline_size", 3)
	parent.add_child(l)
	return l
