extends Node2D

## M1: draws a hex board procedurally (no art assets) and lets you
## hover and click to select a hex. This is the visible foundation that
## later milestones (units, movement, combat) build on.

const HEX_SIZE := 36.0
const MAP_WIDTH := 8
const MAP_HEIGHT := 6
const NONE := Vector2i(-999, -999)

var _grid: HexGrid
var _selected: Vector2i = NONE
var _hovered: Vector2i = NONE


func _ready() -> void:
	_grid = HexGrid.make_rectangle(MAP_WIDTH, MAP_HEIGHT)
	position = Vector2(120, 90)  # nudge the board away from the corner


func _process(_delta: float) -> void:
	var h := Hex.from_pixel(get_local_mouse_position(), HEX_SIZE)
	if h != _hovered:
		_hovered = h
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var h := Hex.from_pixel(get_local_mouse_position(), HEX_SIZE)
		if _grid.is_valid(h):
			_selected = h
			queue_redraw()


func _draw() -> void:
	for cell in _grid.all_cells():
		var center: Vector2 = Hex.to_pixel(cell, HEX_SIZE)
		var pts := _hex_polygon(center, HEX_SIZE)
		var fill := Color(0.18, 0.21, 0.27)
		if cell == _selected:
			fill = Color(0.30, 0.55, 0.90)
		elif cell == _hovered:
			fill = Color(0.24, 0.30, 0.40)
		draw_colored_polygon(pts, fill)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.05, 0.06, 0.08), 2.0)


## The six corner points of a pointy-top hex centered at `center`.
func _hex_polygon(center: Vector2, size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 90.0)
		pts.append(center + Vector2(size * cos(angle), size * sin(angle)))
	return pts
