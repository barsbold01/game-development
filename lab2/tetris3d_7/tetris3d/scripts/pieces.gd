class_name Pieces
extends RefCounted


const SHAPES: Array = [
	[Vector3i(-1, 0, 0), Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0)],

	[Vector3i(-1, 0, -1), Vector3i(-1, 0, 0), Vector3i(0, 0, 0), Vector3i(1, 0, 0)],

	[Vector3i(1, 0, -1), Vector3i(-1, 0, 0), Vector3i(0, 0, 0), Vector3i(1, 0, 0)],

	[Vector3i(0, 0, -1), Vector3i(1, 0, -1), Vector3i(0, 0, 0), Vector3i(1, 0, 0)],

	[Vector3i(0, 0, -1), Vector3i(1, 0, -1), Vector3i(-1, 0, 0), Vector3i(0, 0, 0)],

	[Vector3i(0, 0, -1), Vector3i(-1, 0, 0), Vector3i(0, 0, 0), Vector3i(1, 0, 0)],

	[Vector3i(-1, 0, -1), Vector3i(0, 0, -1), Vector3i(0, 0, 0), Vector3i(1, 0, 0)],
]

const NAMES: Array = ["I", "J", "L", "O", "S", "T", "Z"]

const ACTIVE: Array = [0, 1, 2, 3, 5]

# Нүдэнд ээлтэй, зөөлөн өнгөнүүд (сонгодог өнгөний тод неон хувилбарын оронд)
const COLORS: Array = [
	Color8(92, 200, 204),
	Color8(108, 142, 235),
	Color8(240, 164, 92),
	Color8(242, 208, 107),
	Color8(122, 203, 132),
	Color8(176, 138, 224),
	Color8(232, 120, 122),
]


static func _rot_x(c: Vector3i) -> Vector3i:
	return Vector3i(c.x, -c.z, c.y)

static func _rot_y(c: Vector3i) -> Vector3i:
	return Vector3i(c.z, c.y, -c.x)

static func _rot_z(c: Vector3i) -> Vector3i:
	return Vector3i(-c.y, c.x, c.z)


static func _rotate_once(shape: Array, axis: Vector3i) -> Array:
	var out: Array = []
	for c in shape:
		if axis.x != 0:
			out.append(_rot_x(c))
		elif axis.y != 0:
			out.append(_rot_y(c))
		else:
			out.append(_rot_z(c))
	return out


static func rotate(shape: Array, axis: Vector3i) -> Array:
	var base: Vector3i = axis
	var times: int = 1
	if axis.x + axis.y + axis.z < 0:
		base = -axis
		times = 3

	var out: Array = shape.duplicate()
	for i in times:
		out = _rotate_once(out, base)
	return out
