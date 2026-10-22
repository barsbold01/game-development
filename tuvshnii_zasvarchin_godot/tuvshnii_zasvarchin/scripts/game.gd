extends Node
## ТОГЛООМЫН ЕРӨНХИЙ ТӨЛӨВ (Autoload / Singleton)
## project.godot дээр "Game" нэрээр бүртгэгдсэн тул аль ч скриптээс
## Game.score, Game.lives гэх мэтээр шууд хандаж болно.

enum State { MENU, PLAY, OVER }   # Эхлэх дэлгэц / тоглож байна / дууссан

signal changed   # Оноо, амь, төлөв өөрчлөгдөхөд HUD-д мэдэгдэнэ
signal message(text: String)   # Дэлгэцийн голд түр харуулах бичиг (HUD сонсоно)

const BASE_SPEED := 48.0     # Гүйгчийн эхний хурд (пиксел/сек)
const MAX_SPEED := 110.0     # Хамгийн их хурд
const START_LIVES := 3
const SHIELD_GOAL_MIN := 5   # Эхэндээ хэдэн зоосоор хамгаалалт авах вэ
const SHIELD_GOAL_MAX := 10  # Хамгийн хэцүү үед хэдэн зоос шаардах вэ
const EXTRA_SHIELD_BONUS := 100   # Хамгаалалттай байхад дахин дүүргэвэл өгөх оноо

var state := State.MENU
var lives := START_LIVES
var distance := 0.0          # Хэр хол явсан (пиксел)
var bonus := 0               # Нүх давсан бүрт нэмэгдэх урамшуулал
var best := 0                # Хамгийн өндөр оноо (тоглоом хаагдах хүртэл хадгална)
var coins := 0              # Энэ раундад нийт цуглуулсан зоос
var shield_progress := 0    # Дараагийн хамгаалалт хүртэл цуглуулсан зоос
var has_shield := false     # Нэг удаагийн хамгаалалт (амь хасагдахаас аварна)
var dragging: Node = null    # Одоо чирж байгаа хэсэг (нэг л зүйл чирнэ)
var sfx: Sfx                 # Дуу гаргагч

## Оноо = явсан зай / 10 + урамшуулал
var score: int:
	get:
		return int(distance / 10.0) + bonus

## Хурд явах тусам аажмаар нэмэгдэнэ — тоглоом хэцүүрнэ
var speed: float:
	get:
		return minf(BASE_SPEED + distance / 30.0, MAX_SPEED)

## Хүндрэл 0..1 — хурднаас хамаарна
var difficulty: float:
	get:
		return clampf((speed - BASE_SPEED) / (MAX_SPEED - BASE_SPEED), 0.0, 1.0)

## Хамгаалалт авахад хэдэн зоос хэрэгтэй вэ: хүндрэлээс хамаарч 5–10
var shield_goal: int:
	get:
		return SHIELD_GOAL_MIN + roundi(difficulty * (SHIELD_GOAL_MAX - SHIELD_GOAL_MIN))


func _ready() -> void:
	sfx = Sfx.new()
	add_child(sfx)


## Шинэ тоглоом эхлэхийн өмнө бүх тоог анхны байдалд нь оруулна
func reset() -> void:
	state = State.MENU
	lives = START_LIVES
	distance = 0.0
	bonus = 0
	coins = 0
	shield_progress = 0
	has_shield = false
	dragging = null
	changed.emit()


func start() -> void:
	state = State.PLAY
	sfx.beep(660, 0.08)
	changed.emit()


func add_bonus(amount: int) -> void:
	bonus += amount
	sfx.beep(880, 0.06)
	changed.emit()


## Зоос авахад дуудагдана. Зорилгодоо хүрвэл хамгаалалт автоматаар авна.
func add_coin() -> void:
	coins += 1
	shield_progress += 1
	sfx.beep(1320, 0.05)
	if shield_progress >= shield_goal:
		shield_progress = 0
		if has_shield:
			bonus += EXTRA_SHIELD_BONUS   # Нэгээс олон хамгаалалт хуримтлагдахгүй — оронд нь оноо
			message.emit("+%d ОНОО" % EXTRA_SHIELD_BONUS)
		else:
			has_shield = true
			sfx.beep(990, 0.2)
			message.emit("ХАМГААЛАЛТ АВЛАА!")
	changed.emit()


## Гүйгч үхэхэд main.gd дуудна: хамгаалалт байвал зарцуулж true буцаана (амь хасагдахгүй)
func use_shield() -> bool:
	if not has_shield:
		return false
	has_shield = false
	sfx.beep(240, 0.2)
	message.emit("ХАМГААЛАЛТ АВАРЛАА!")
	changed.emit()
	return true


## Гүйгч нүхэнд унахад дуудагдана
func lose_life() -> void:
	lives -= 1
	sfx.beep(110, 0.3)
	if lives <= 0:
		state = State.OVER
		best = maxi(best, score)
	changed.emit()
