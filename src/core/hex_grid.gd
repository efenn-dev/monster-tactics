class_name HexGrid
extends RefCounted

## The set of hexes that make up a map, plus queries over them
## (validity, neighbors, range). Pure logic, no scene dependencies.

var cells: Dictionary = {}  # Vector2i -> true


func _init(cell_list: Array = []) -> void:
	for c in cell_list:
		cells[c] = true


## Is this hex part of the board?
func is_valid(hex: Vector2i) -> bool:
	return cells.has(hex)


## Every hex on the board.
func all_cells() -> Array:
	return cells.keys()


## Neighbors of `hex` that are actually on the board.
func valid_neighbors(hex: Vector2i) -> Array:
	var result: Array = []
	for n in Hex.neighbors(hex):
		if is_valid(n):
			result.append(n)
	return result


## All on-board hexes reachable within `n` steps of `center` (inclusive).
## Breadth-first, so it respects board holes/edges.
func cells_within_range(center: Vector2i, n: int) -> Array:
	var visited: Dictionary = {center: 0}
	var frontier: Array = [center]
	var result: Array = [center]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var dist: int = visited[current]
		if dist >= n:
			continue
		for nb in valid_neighbors(current):
			if not visited.has(nb):
				visited[nb] = dist + 1
				frontier.append(nb)
				result.append(nb)
	return result


## Build a rectangular hex map `width` x `height` (pointy-top, offset rows).
static func make_rectangle(width: int, height: int) -> HexGrid:
	var cell_list: Array = []
	for r in height:
		var r_offset := floori(r / 2.0)
		for q in range(-r_offset, width - r_offset):
			cell_list.append(Vector2i(q, r))
	return HexGrid.new(cell_list)
