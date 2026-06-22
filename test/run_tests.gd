extends SceneTree

## Zero-dependency headless test runner. No addons required yet.
## Run with:  godot --headless --script test/run_tests.gd
## (We'll migrate to the GUT addon once the suite grows.)

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		print("  FAIL  ", label)


func _eq(actual, expected, label: String) -> void:
	_check(actual == expected, "%s (got %s, expected %s)" % [label, actual, expected])


func _run() -> void:
	print("Hex math")
	_eq(Hex.neighbors(Vector2i(0, 0)).size(), 6, "a hex has 6 neighbors")
	_eq(Hex.distance(Vector2i(0, 0), Vector2i(0, 0)), 0, "distance to self is 0")
	_eq(Hex.distance(Vector2i(0, 0), Vector2i(1, 0)), 1, "adjacent distance is 1")
	_eq(Hex.distance(Vector2i(0, 0), Vector2i(2, -1)), 2, "two steps away")
	_eq(Hex.distance(Vector2i(0, 0), Vector2i(-3, 1)), 3, "distance is symmetric magnitude")
	var h := Vector2i(2, -1)
	_eq(Hex.from_pixel(Hex.to_pixel(h, 32.0), 32.0), h, "pixel round-trip recovers the hex")

	print("HexGrid")
	var grid := HexGrid.make_rectangle(5, 5)
	_eq(grid.all_cells().size(), 25, "5x5 rectangle has 25 cells")
	_check(grid.is_valid(Vector2i(0, 0)), "origin is on the board")
	_eq(grid.cells_within_range(Vector2i(0, 0), 0).size(), 1, "range 0 is just the center")
	var interior := Vector2i(2, 2)
	if grid.is_valid(interior):
		_eq(grid.valid_neighbors(interior).size(), 6, "interior cell has 6 valid neighbors")
