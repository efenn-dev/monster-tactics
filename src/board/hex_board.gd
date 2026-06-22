extends Node2D

## M2: place units, click a player unit to see its movement range, then
## click a highlighted hex to move it there. Enemy units aren't selectable
## yet — turns and combat come in M3/M4.

const HEX_SIZE := 36.0
const MAP_WIDTH := 8
const MAP_HEIGHT := 6
const NONE := Vector2i(-999, -999)
const TEAM_COLORS := [Color(0.30, 0.55, 0.90), Color(0.90, 0.35, 0.35)]  # 0 player, 1 enemy

var _state: BoardState
var _hovered: Vector2i = NONE
var _selected: Unit = null
var _reachable: Array = []


func _ready() -> void:
	_state = BoardState.new(HexGrid.make_rectangle(MAP_WIDTH, MAP_HEIGHT))
	# Player team (blue)
	_state.add_unit(Unit.new(0, Vector2i(1, 1), 3))
	_state.add_unit(Unit.new(0, Vector2i(1, 3), 3))
	_state.add_unit(Unit.new(0, Vector2i(2, 2), 4))
	# Enemy team (red)
	_state.add_unit(Unit.new(1, Vector2i(6, 1), 3))
	_state.add_unit(Unit.new(1, Vector2i(5, 4), 3))
	position = Vector2(120, 90)


func _process(_delta: float) -> void:
	var h := Hex.from_pixel(get_local_mouse_position(), HEX_SIZE)
	if h != _hovered:
		_hovered = h
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var h := Hex.from_pixel(get_local_mouse_position(), HEX_SIZE)
	if not _state.grid.is_valid(h):
		_deselect()
		return
	# Move: a unit is selected and we clicked one of its reachable hexes.
	if _selected != null and h in _reachable:
		_state.move_unit(_selected, h)
		_deselect()
		queue_redraw()
		return
	# Select: clicked one of our own units.
	var clicked := _state.unit_at(h)
	if clicked != null and clicked.team == 0:
		_selected = clicked
		_reachable = _state.reachable_from(clicked.coord, clicked.move_range)
	else:
		_deselect()
	queue_redraw()


func _deselect() -> void:
	_selected = null
	_reachable = []


func _draw() -> void:
	for cell in _state.grid.all_cells():
		var center: Vector2 = Hex.to_pixel(cell, HEX_SIZE)
		var pts := _hex_polygon(center, HEX_SIZE)
		var fill := Color(0.18, 0.21, 0.27)
		if cell in _reachable:
			fill = Color(0.20, 0.42, 0.30)  # reachable = green
		elif cell == _hovered:
			fill = Color(0.24, 0.30, 0.40)
		draw_colored_polygon(pts, fill)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.05, 0.06, 0.08), 2.0)

	for unit in _state.units:
		var c: Vector2 = Hex.to_pixel(unit.coord, HEX_SIZE)
		draw_circle(c, HEX_SIZE * 0.55, TEAM_COLORS[unit.team])
		if unit == _selected:
			draw_arc(c, HEX_SIZE * 0.72, 0.0, TAU, 32, Color.WHITE, 3.0)


func _hex_polygon(center: Vector2, size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 90.0)
		pts.append(center + Vector2(size * cos(angle), size * sin(angle)))
	return pts
