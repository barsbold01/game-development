class_name Board
extends RefCounted


var w: int
var d: int
var h: int

var cells: Array = []


func _init(width: int, depth: int, height: int) -> void:
	w = width
	d = depth
	h = height
	reset()


func _empty_layer() -> Array:
	var layer: Array = []
	for z in d:
		var row: Array = []
		row.resize(w)
		row.fill(-1)
		layer.append(row)
	return layer


func reset() -> void:
	cells = []
	for y in h:
		cells.append(_empty_layer())


func is_free(c: Vector3i) -> bool:
	if c.x < 0 or c.x >= w:
		return false
	if c.z < 0 or c.z >= d:
		return false
	if c.y < 0 or c.y >= h:
		return false
	return cells[c.y][c.z][c.x] == -1


func can_place(shape: Array, pos: Vector3i) -> bool:
	for off in shape:
		if not is_free(pos + off):
			return false
	return true


func lock(shape: Array, pos: Vector3i, color_id: int) -> void:
	for off in shape:
		var c: Vector3i = pos + off
		if c.y >= 0 and c.y < h:
			cells[c.y][c.z][c.x] = color_id


func find_full_rows() -> Array:
	var rows: Array = []
	for y in h:
		for z in d:
			var ok_x: bool = true
			for x in w:
				if cells[y][z][x] == -1:
					ok_x = false
					break
			if ok_x:
				var row_x: Array = []
				for x in w:
					row_x.append(Vector3i(x, y, z))
				rows.append(row_x)

		for x in w:
			var ok_z: bool = true
			for z in d:
				if cells[y][z][x] == -1:
					ok_z = false
					break
			if ok_z:
				var row_z: Array = []
				for z in d:
					row_z.append(Vector3i(x, y, z))
				rows.append(row_z)
	return rows


func clear_cells(list: Array) -> void:
	for c in list:
		cells[c.y][c.z][c.x] = -1


func apply_gravity() -> bool:
	var moved: bool = false
	for z in d:
		for x in w:
			var stack: Array = []
			for y in h:
				if cells[y][z][x] != -1:
					stack.append(cells[y][z][x])
			for y in h:
				var v: int = stack[y] if y < stack.size() else -1
				if cells[y][z][x] != v:
					moved = true
				cells[y][z][x] = v
	return moved


func block_count() -> int:
	var n: int = 0
	for y in h:
		for z in d:
			for x in w:
				if cells[y][z][x] != -1:
					n += 1
	return n


func column_height(x: int, z: int) -> int:
	for y in range(h - 1, -1, -1):
		if cells[y][z][x] != -1:
			return y + 1
	return 0


func stack_height() -> int:
	for y in range(h - 1, -1, -1):
		for z in d:
			for x in w:
				if cells[y][z][x] != -1:
					return y + 1
	return 0
