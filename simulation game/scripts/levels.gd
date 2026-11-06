class_name Levels
## ТҮВШНҮҮД — түвшин бүр симуляцид нэг шинэ хүчин зүйл нэмнэ.
## bushes: Vector3(x, y, радиус), water: Rect2 (гүүр нь хоёр усны хоорондох зай).

const LIST := [
	{
		"name": "Бэлчээр",
		"desc": "Сүргээ ардаас нь зөөлөн шахаж сур.",
		"sheep": 12, "goal": 10, "time": 60,
		"bushes": [], "water": [], "wolves": 0, "wind": false,
	},
	{
		"name": "Бут",
		"desc": "Шинэ: бутнууд сүргийг хэсэг хэсэгт хуваана.",
		"sheep": 16, "goal": 14, "time": 60,
		"bushes": [Vector3(190, 80, 18), Vector3(230, 210, 22), Vector3(310, 100, 16),
			Vector3(140, 245, 15), Vector3(320, 232, 18), Vector3(275, 158, 12)],
		"water": [], "wolves": 0, "wind": false,
	},
	{
		"name": "Чоно",
		"desc": "Шинэ: чоно хонь агнана. Ойртож эсвэл хуцаж хөө.",
		"sheep": 16, "goal": 12, "time": 75,
		"bushes": [Vector3(210, 70, 16), Vector3(250, 232, 20)],
		"water": [], "wolves": 1, "wind": false,
	},
	{
		"name": "Гол",
		"desc": "Шинэ: хонь усанд ордоггүй. Гүүрээр гаргах хэрэгтэй.",
		"sheep": 18, "goal": 14, "time": 80,
		"bushes": [Vector3(322, 70, 16), Vector3(322, 235, 16)],
		"water": [Rect2(250, 22, 22, 108), Rect2(250, 170, 22, 110)], "wolves": 1, "wind": false,
	},
	{
		"name": "Шуурга",
		"desc": "Шинэ: салхи сүргийг тараана. Хоёр чоно.",
		"sheep": 20, "goal": 15, "time": 90,
		"bushes": [Vector3(200, 85, 16), Vector3(215, 220, 18), Vector3(315, 150, 13)],
		"water": [], "wolves": 2, "wind": true,
	},
]
