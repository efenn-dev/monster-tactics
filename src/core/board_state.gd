class_name BoardState
extends RefCounted

## The mutable game state: the map plus every unit on it, with the
## occupancy queries the board (and later the AI) need. Pure logic, no nodes.

var grid: HexGrid
var units: Array[Unit] = []
var _by_coord: Dictionary = {}  # Vector2i -> Unit


func _init(p_grid: HexGrid) -> void:
	grid = p_grid


func add_unit(unit: Unit) -> void:
	units.append(unit)
	_by_coord[unit.coord] = unit


func unit_at(coord: Vector2i) -> Unit:
	if _by_coord.has(coord):
		return _by_coord[coord]
	return null


func is_occupied(coord: Vector2i) -> bool:
	return _by_coord.has(coord)


func move_unit(unit: Unit, to: Vector2i) -> void:
	_by_coord.erase(unit.coord)
	unit.coord = to
	_by_coord[to] = unit


## Empty hexes a unit can reach within `move_range` steps. Other units block
## movement — you can't pass through or stop on an occupied hex.
func reachable_from(start: Vector2i, move_range: int) -> Array:
	var visited: Dictionary = {start: 0}
	var frontier: Array = [start]
	var result: Array = []
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var dist: int = visited[current]
		if dist >= move_range:
			continue
		for nb in grid.valid_neighbors(current):
			if visited.has(nb):
				continue
			if is_occupied(nb):
				continue
			visited[nb] = dist + 1
			frontier.append(nb)
			result.append(nb)
	return result


## Hexes currently visible to a team: the union of every friendly unit's
## sight radius. Units do not block sight (radius vision, no line-of-sight yet).
func visible_cells(team: int) -> Array:
	var seen: Dictionary = {}
	for unit in units:
		if unit.team == team:
			for c in grid.cells_within_range(unit.coord, unit.sight_range):
				seen[c] = true
	return seen.keys()
