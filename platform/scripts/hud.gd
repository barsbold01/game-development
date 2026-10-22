extends CanvasLayer
## HUD — оноо, амь, эхлэх ба дуусах самбар.
## Бүх элементийг кодоор үүсгэнэ (сцен дээр гараар байрлуулах ч болно).

const HEART := preload("res://sprites/heart.png")
const HEART_EMPTY := preload("res://sprites/heart_empty.png")

var score_label: Label
var best_label: Label
var hearts: Array[TextureRect] = []
var start_panel: Control
var over_panel: Control
var over_body: Label
var coin_bar: Control      # Хамгаалалт хүртэлх зоосны явц (цэгүүд) + хамгаалалтын тэмдэг
var message_label: Label
var message_tween: Tween


func _ready() -> void:
	# Дээд хар мөр
	var bar := ColorRect.new()
	bar.color = Color("2f3542")
	bar.size = Vector2(256, 14)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	score_label = _label(Vector2(4, 1), "")
	best_label = _label(Vector2(176, 1), "")

	for i in 3:
		var h := TextureRect.new()
		h.texture = HEART
		h.position = Vector2(100 + i * 9, 4)
		add_child(h)
		hearts.append(h)

	# Зоосны явц: зорилгын тоогоор саарал цэг, цуглуулсныг шараар будна
	coin_bar = Control.new()
	coin_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_bar.draw.connect(_draw_coin_bar)
	add_child(coin_bar)

	# Тавиурын зөвлөмж
	var hint := _label(Vector2(150, 19), "← хаана ч дарж чир")
	hint.modulate = Color(1, 1, 1, 0.8)

	start_panel = _panel("JUST IN TIME",
		"Гүйгч өөрөө гүйнэ, зогсдоггүй!\nБанзаар нүх хаа, трамплинаар\nсаад давуул. Зоос цуглуулбал\nнэг удаагийн хамгаалалт авна.\n▶ Дарж эхлэх")
	over_panel = _panel("УНАЧИХЛАА!", "")
	over_body = over_panel.get_meta("body")

	# Дэлгэцийн голын түр бичиг ("ХАМГААЛАЛТ АВЛАА!" гэх мэт)
	message_label = _label(Vector2(0, 40), "", 9)
	message_label.size = Vector2(256, 14)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_color", Color("ffe66d"))
	message_label.add_theme_color_override("font_outline_color", Color("2f3542"))
	message_label.add_theme_constant_override("outline_size", 3)
	message_label.modulate.a = 0.0
	Game.message.connect(_show_message)

	Game.changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	score_label.text = "ОНОО %05d" % Game.score
	coin_bar.queue_redraw()   # Зорилго хурдаас хамаарч өөрчлөгдөнө


## Дээд мөрөнд: хамгаалалтын цэнхэр тойрог (зүрхний зүүн талд) ба зоосны цэгүүд
func _draw_coin_bar() -> void:
	if Game.has_shield:
		coin_bar.draw_circle(Vector2(92, 7), 3.5, Color(0.45, 0.9, 1.0, 0.35))
		coin_bar.draw_arc(Vector2(92, 7), 3.5, 0.0, TAU, 12, Color(0.55, 0.95, 1.0), 1.0)
	for i in Game.shield_goal:
		var col := Color("ffd93d") if i < Game.shield_progress else Color("57606f")
		coin_bar.draw_rect(Rect2(132 + i * 4, 5, 3, 3), col)


func _show_message(text: String) -> void:
	message_label.text = text
	if message_tween:
		message_tween.kill()
	message_label.modulate.a = 1.0
	message_tween = create_tween()
	message_tween.tween_interval(1.4)
	message_tween.tween_property(message_label, "modulate:a", 0.0, 0.4)


func _refresh() -> void:
	for i in 3:
		hearts[i].texture = HEART if i < Game.lives else HEART_EMPTY
	best_label.text = "ДЭЭД %05d" % Game.best
	start_panel.visible = Game.state == Game.State.MENU
	over_panel.visible = Game.state == Game.State.OVER
	if Game.state == Game.State.OVER:
		over_body.text = "Оноо: %d\nЗоос: %d\nДээд: %d\n\n▶ Дарж дахин тоглох" % [Game.score, Game.coins, Game.best]


func _label(pos: Vector2, text: String, size := 8) -> Label:
	var l := Label.new()
	l.position = pos
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	add_child(l)
	return l


## Хагас тунгалаг хар самбар + гарчиг + тайлбар
func _panel(title: String, body_text: String) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.78)
	bg.position = Vector2(32, 30)
	bg.size = Vector2(192, 90)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	var t := Label.new()
	t.text = title
	t.position = Vector2(32, 36)
	t.size = Vector2(192, 14)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 11)
	t.add_theme_color_override("font_color", Color("ffe66d"))
	root.add_child(t)

	var b := Label.new()
	b.text = body_text
	b.position = Vector2(32, 54)
	b.size = Vector2(192, 64)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override("font_size", 8)
	root.add_child(b)

	root.set_meta("body", b)
	return root
