class_name Unit
extends RefCounted

## A monster on the board. Pure data for now; stats / abilities / evolution
## arrive in later milestones (M6+).

var team: int        # 0 = player, 1 = enemy
var coord: Vector2i  # the axial hex it stands on
var move_range: int


func _init(p_team: int, p_coord: Vector2i, p_move_range: int = 3) -> void:
	team = p_team
	coord = p_coord
	move_range = p_move_range
