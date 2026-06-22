extends Node3D

## 3D board: low-poly hex terrain, mouse picking (V2), and fog of war (V3).
## All game logic lives in the engine-agnostic core (HexGrid/BoardState/Unit);
## this script is presentation + input only.
##
## Dev: run with user arg `--screenshot` to auto-select a demo unit, capture
## one frame to user://shot.png, and quit.

const HEX_SIZE := 1.0
const MAP_WIDTH := 8
const MAP_HEIGHT := 6
const BASE_HEIGHT := 0.4
const MAX_ELEVATION := 1.6
const WATER_LEVEL := 0.30
const UNIT_RADIUS := 0.30
const UNIT_HEIGHT := 1.1
const TEAM_COLORS := [Color(0.25, 0.55, 0.95), Color(0.95, 0.30, 0.30)]

# Brightness multipliers for the three fog-of-war states.
const FOG_VISIBLE := 1.0
const FOG_EXPLORED := 0.45
const FOG_UNSEEN := 0.12

var _state: BoardState
var _cam: Camera3D
var _top_y: Dictionary = {}        # Vector2i -> top surface height
var _tiles: Dictionary = {}        # Vector2i -> {mat, base}
var _unit_mesh: Dictionary = {}    # Unit -> MeshInstance3D
var _explored: Dictionary = {}     # Vector2i -> true (player has ever seen it)
var _selected: Unit = null
var _reachable: Array = []
var _markers: Array = []           # highlight nodes for the current selection


func _ready() -> void:
	_state = BoardState.new(HexGrid.make_rectangle(MAP_WIDTH, MAP_HEIGHT))
	_state.add_unit(Unit.new(0, Vector2i(1, 1), 3, 2))
	_state.add_unit(Unit.new(0, Vector2i(2, 2), 4, 2))
	_state.add_unit(Unit.new(0, Vector2i(1, 3), 3, 2))
	_state.add_unit(Unit.new(1, Vector2i(6, 1), 3, 2))
	_state.add_unit(Unit.new(1, Vector2i(5, 4), 3, 2))

	_setup_environment()
	_build_terrain()
	_place_units()
	_setup_camera()
	_refresh_fog()

	if "--screenshot" in OS.get_cmdline_user_args():
		_select(_state.unit_at(Vector2i(2, 2)))
		_capture_and_quit()


func _hex_world(hex: Vector2i, y: float) -> Vector3:
	var p := Hex.to_pixel(hex, HEX_SIZE)
	return Vector3(p.x, y, p.y)


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -45, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.2
	add_child(sun)


func _build_terrain() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.12
	noise.seed = 1337

	for cell in _state.grid.all_cells():
		var wp := _hex_world(cell, 0.0)
		var n := (noise.get_noise_2d(wp.x, wp.z) + 1.0) * 0.5
		var height: float
		var color: Color
		if n < WATER_LEVEL:
			height = BASE_HEIGHT
			color = Color(0.20, 0.45, 0.70)
		else:
			var land := (n - WATER_LEVEL) / (1.0 - WATER_LEVEL)
			height = BASE_HEIGHT + land * MAX_ELEVATION
			color = _biome_color(land)

		var mesh := CylinderMesh.new()
		mesh.radial_segments = 6
		mesh.top_radius = HEX_SIZE
		mesh.bottom_radius = HEX_SIZE
		mesh.height = height
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mesh.material = mat

		var mi := MeshInstance3D.new()
		mi.mesh = mesh

		var shape := CylinderShape3D.new()
		shape.radius = HEX_SIZE
		shape.height = height
		var coll := CollisionShape3D.new()
		coll.shape = shape

		# A clickable body per tile; the mesh + collider ride along, and the
		# hex coord is stashed as metadata for the raycast to read back.
		var body := StaticBody3D.new()
		body.rotation_degrees = Vector3(0, 30, 0)  # align to pointy-top layout
		body.position = Vector3(wp.x, height * 0.5, wp.z)
		body.set_meta("hex", cell)
		body.add_child(mi)
		body.add_child(coll)
		add_child(body)

		_top_y[cell] = height
		_tiles[cell] = {"mat": mat, "base": color}


func _biome_color(land: float) -> Color:
	if land < 0.45:
		return Color(0.36, 0.62, 0.30)   # grass
	elif land < 0.75:
		return Color(0.45, 0.42, 0.32)   # dirt / hill
	return Color(0.78, 0.80, 0.85)       # rock / snow


func _place_units() -> void:
	for unit in _state.units:
		var mesh := CapsuleMesh.new()
		mesh.radius = UNIT_RADIUS
		mesh.height = UNIT_HEIGHT
		var mat := StandardMaterial3D.new()
		mat.albedo_color = TEAM_COLORS[unit.team]
		mesh.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = _unit_position(unit.coord)
		add_child(mi)
		_unit_mesh[unit] = mi


func _unit_position(hex: Vector2i) -> Vector3:
	var top: float = _top_y.get(hex, BASE_HEIGHT)
	var wp := _hex_world(hex, 0.0)
	return Vector3(wp.x, top + UNIT_HEIGHT * 0.5, wp.z)


func _setup_camera() -> void:
	var sum := Vector3.ZERO
	var cells := _state.grid.all_cells()
	for cell in cells:
		sum += _hex_world(cell, 0.0)
	var center: Vector3 = sum / float(cells.size())

	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.position = center + Vector3(0, 13, 11)   # up and back -> tilted view
	add_child(_cam)
	_cam.look_at(center, Vector3.UP)
	_cam.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var hex = _pick_hex(event.position)
	if hex == null:
		_deselect()
		return
	_handle_click(hex)


## Cast a ray from the camera through the mouse; return the hex of the tile hit,
## or null if the click missed the board.
func _pick_hex(mouse: Vector2):
	var from := _cam.project_ray_origin(mouse)
	var to := from + _cam.project_ray_normal(mouse) * 1000.0
	var params := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(params)
	if hit and hit.collider.has_meta("hex"):
		return hit.collider.get_meta("hex")
	return null


func _handle_click(hex: Vector2i) -> void:
	# Move the selected unit onto one of its reachable hexes.
	if _selected != null and hex in _reachable:
		_state.move_unit(_selected, hex)
		_unit_mesh[_selected].position = _unit_position(hex)
		_deselect()
		_refresh_fog()
		return
	# Otherwise select one of our own units.
	var clicked := _state.unit_at(hex)
	if clicked != null and clicked.team == 0:
		_select(clicked)
	else:
		_deselect()


func _select(unit: Unit) -> void:
	_deselect()
	if unit == null:
		return
	_selected = unit
	_reachable = _state.reachable_from(unit.coord, unit.move_range)
	var mat: StandardMaterial3D = _unit_mesh[unit].mesh.material
	mat.emission_enabled = true
	mat.emission = Color(1, 1, 1)
	mat.emission_energy_multiplier = 0.5
	for hex in _reachable:
		_markers.append(_make_disc(hex))


func _deselect() -> void:
	if _selected != null:
		var mat: StandardMaterial3D = _unit_mesh[_selected].mesh.material
		mat.emission_enabled = false
	_selected = null
	_reachable = []
	for m in _markers:
		m.queue_free()
	_markers = []


## A flat translucent green hex hovering just above `hex` to mark it reachable.
func _make_disc(hex: Vector2i) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 6
	mesh.top_radius = HEX_SIZE * 0.8
	mesh.bottom_radius = HEX_SIZE * 0.8
	mesh.height = 0.06
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 1.0, 0.4, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 0.3)
	mat.emission_energy_multiplier = 0.4
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.rotation_degrees = Vector3(0, 30, 0)
	var wp := _hex_world(hex, 0.0)
	mi.position = Vector3(wp.x, _top_y.get(hex, BASE_HEIGHT) + 0.05, wp.z)
	add_child(mi)
	return mi


## Recompute player visibility and repaint tiles by fog state. Enemy units are
## hidden unless they stand on a currently-visible hex.
func _refresh_fog() -> void:
	var visible: Dictionary = {}
	for hex in _state.visible_cells(0):
		visible[hex] = true
		_explored[hex] = true

	for hex in _tiles:
		var f: float
		if visible.has(hex):
			f = FOG_VISIBLE
		elif _explored.has(hex):
			f = FOG_EXPLORED
		else:
			f = FOG_UNSEEN
		var base: Color = _tiles[hex]["base"]
		_tiles[hex]["mat"].albedo_color = Color(base.r * f, base.g * f, base.b * f)

	for unit in _state.units:
		if unit.team != 0:
			_unit_mesh[unit].visible = visible.has(unit.coord)


func _capture_and_quit() -> void:
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var rect := get_viewport().get_visible_rect().size
	print("PICK_AT_CENTER: ", _pick_hex(rect * 0.5))
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shot.png")
	print("SHOT_SAVED: ", ProjectSettings.globalize_path("user://shot.png"))
	get_tree().quit()
