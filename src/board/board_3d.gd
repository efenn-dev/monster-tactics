extends Node3D

## Visual slice 1: render the hex board as low-poly 3D terrain under a tilted
## "Civ-style" camera. Reuses the engine-agnostic core (HexGrid, BoardState);
## this script is pure presentation. Interaction + fog of war come next.
##
## Run with the user arg `--screenshot` to save one frame to user://shot.png
## and quit (lets the dev loop review the look headlessly-ish).

const HEX_SIZE := 1.0          # world units, hex center-to-corner
const MAP_WIDTH := 8
const MAP_HEIGHT := 6
const BASE_HEIGHT := 0.4       # minimum tile thickness
const MAX_ELEVATION := 1.6     # extra height for the tallest land
const WATER_LEVEL := 0.30      # noise below this -> water tile
const TEAM_COLORS := [Color(0.25, 0.55, 0.95), Color(0.95, 0.30, 0.30)]

var _state: BoardState
var _top_y: Dictionary = {}    # Vector2i -> top surface height


func _ready() -> void:
	_state = BoardState.new(HexGrid.make_rectangle(MAP_WIDTH, MAP_HEIGHT))
	_state.add_unit(Unit.new(0, Vector2i(1, 1), 3))
	_state.add_unit(Unit.new(0, Vector2i(2, 2), 4))
	_state.add_unit(Unit.new(0, Vector2i(1, 3), 3))
	_state.add_unit(Unit.new(1, Vector2i(6, 1), 3))
	_state.add_unit(Unit.new(1, Vector2i(5, 4), 3))

	_setup_environment()
	_build_terrain()
	_place_units()
	_setup_camera()

	if "--screenshot" in OS.get_cmdline_user_args():
		_capture_and_quit()


## Map an axial hex to a 3D world position (2D layout x->X, y->Z, height->Y).
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
		var n := (noise.get_noise_2d(wp.x, wp.z) + 1.0) * 0.5  # 0..1
		var height: float
		var color: Color
		if n < WATER_LEVEL:
			height = BASE_HEIGHT
			color = Color(0.20, 0.45, 0.70)
		else:
			var land := (n - WATER_LEVEL) / (1.0 - WATER_LEVEL)  # 0..1
			height = BASE_HEIGHT + land * MAX_ELEVATION
			color = _biome_color(land)

		var mesh := CylinderMesh.new()
		mesh.radial_segments = 6           # a 6-sided cylinder = hex prism
		mesh.top_radius = HEX_SIZE
		mesh.bottom_radius = HEX_SIZE
		mesh.height = height
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mesh.material = mat

		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.rotation_degrees = Vector3(0, 30, 0)   # align to pointy-top layout
		mi.position = Vector3(wp.x, height * 0.5, wp.z)
		add_child(mi)

		_top_y[cell] = height


func _biome_color(land: float) -> Color:
	if land < 0.45:
		return Color(0.36, 0.62, 0.30)   # grass
	elif land < 0.75:
		return Color(0.45, 0.42, 0.32)   # dirt / hill
	return Color(0.78, 0.80, 0.85)       # rock / snow


func _place_units() -> void:
	for unit in _state.units:
		var top: float = _top_y.get(unit.coord, BASE_HEIGHT)
		var mesh := CapsuleMesh.new()
		mesh.radius = HEX_SIZE * 0.30
		mesh.height = HEX_SIZE * 1.1
		var mat := StandardMaterial3D.new()
		mat.albedo_color = TEAM_COLORS[unit.team]
		mesh.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var wp := _hex_world(unit.coord, 0.0)
		mi.position = Vector3(wp.x, top + mesh.height * 0.5, wp.z)
		add_child(mi)


func _setup_camera() -> void:
	var sum := Vector3.ZERO
	var cells := _state.grid.all_cells()
	for cell in cells:
		sum += _hex_world(cell, 0.0)
	var center: Vector3 = sum / float(cells.size())

	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.position = center + Vector3(0, 13, 11)   # up and back -> tilted view
	add_child(cam)
	cam.look_at(center, Vector3.UP)              # look_at needs the node in-tree
	cam.make_current()


func _capture_and_quit() -> void:
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shot.png")
	print("SHOT_SAVED: ", ProjectSettings.globalize_path("user://shot.png"))
	get_tree().quit()
