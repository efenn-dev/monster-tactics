class_name Hex
extends RefCounted

## Pointy-top hexagon math using axial coordinates.
##
## A hex is a Vector2i(q, r). This class is pure logic with no scene/node
## dependencies, so it can be unit-tested headless.
## Reference: https://www.redblobgames.com/grids/hexagons/

# The six axial neighbor directions, going clockwise from "east".
const DIRECTIONS := [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]


## The neighbor of `hex` in direction `dir` (0..5).
static func neighbor(hex: Vector2i, dir: int) -> Vector2i:
	return hex + DIRECTIONS[dir]


## All six neighbors of `hex` (ignores board edges; see HexGrid for valid ones).
static func neighbors(hex: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d in DIRECTIONS:
		result.append(hex + d)
	return result


## Hex distance (number of steps) between two hexes.
static func distance(a: Vector2i, b: Vector2i) -> int:
	return (abs(a.x - b.x) + abs(a.x + a.y - b.x - b.y) + abs(a.y - b.y)) / 2


## Center pixel position of a hex, given the center-to-corner `size`.
static func to_pixel(hex: Vector2i, size: float) -> Vector2:
	var x := size * sqrt(3.0) * (hex.x + hex.y / 2.0)
	var y := size * 1.5 * hex.y
	return Vector2(x, y)


## The hex containing pixel `point` (inverse of to_pixel).
static func from_pixel(point: Vector2, size: float) -> Vector2i:
	var q := (sqrt(3.0) / 3.0 * point.x - 1.0 / 3.0 * point.y) / size
	var r := (2.0 / 3.0 * point.y) / size
	return _axial_round(q, r)


## Round fractional axial coordinates to the nearest whole hex (cube rounding).
static func _axial_round(qf: float, rf: float) -> Vector2i:
	var x := qf
	var z := rf
	var y := -x - z
	var rx := roundi(x)
	var ry := roundi(y)
	var rz := roundi(z)
	var x_diff := absf(rx - x)
	var y_diff := absf(ry - y)
	var z_diff := absf(rz - z)
	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(rx, rz)
