extends Node2D

@export var min_bounds: Vector2 = Vector2(-2500.0, -2500.0)
@export var max_bounds: Vector2 = Vector2(2500.0, 2500.0)

@export_group("Main Path Configuration")
@export var main_waypoint_count: int = 3
@export var main_max_scatter: float = 200.0
@export var main_min_length: float = 1200.0

@export_group("FPV Path Configuration")
@export var fpv_waypoint_count: int = 1
@export var fpv_max_scatter: float = 100.0
@export var fpv_min_length: float = 800.0

@export_group("Path Smoothing")
@export var enable_smoothing: bool = true
@export var curve_smoothness: float = 0.25

@onready var main_path_node: Path2D = get_node_or_null("../../EnemyPaths/MainPath") if get_node_or_null("../../EnemyPaths/MainPath") else get_node_or_null("../MainPath")
@onready var fpv_path_node: Path2D = get_node_or_null("../../EnemyPaths/FPVPath") if get_node_or_null("../../EnemyPaths/FPVPath") else get_node_or_null("../FPVPath")

func _ready() -> void:
	add_to_group("mission_generator")
	_update_bounds_from_camera()
	generate_mission_paths()

func _update_bounds_from_camera() -> void:
	var camera = get_tree().get_first_node_in_group("camera")
	if not camera:
		camera = get_viewport().get_camera_2d()
	if camera and "min_bounds" in camera and "max_bounds" in camera:
		min_bounds = camera.min_bounds
		max_bounds = camera.max_bounds

func get_factory_position() -> Vector2:
	var factory = get_tree().get_first_node_in_group("factory")
	if factory:
		return factory.global_position
	return Vector2(296.0, 405.0)

func select_spawn_point(min_b: Vector2 = min_bounds, max_b: Vector2 = max_bounds) -> Vector2:
	var side := randi() % 4
	var spawn := Vector2.ZERO
	match side:
		0: # Top
			spawn.x = randf_range(min_b.x, max_b.x)
			spawn.y = min_b.y
		1: # Right
			spawn.x = max_b.x
			spawn.y = randf_range(min_b.y, max_b.y)
		2: # Bottom
			spawn.x = randf_range(min_b.x, max_b.x)
			spawn.y = max_b.y
		3: # Left
			spawn.x = min_b.x
			spawn.y = randf_range(min_b.y, max_b.y)
	return spawn

func apply_curve_smoothing(curve: Curve2D, smoothness: float = 0.25) -> void:
	var count := curve.point_count
	if count < 2:
		return

	for i in range(count):
		var p_curr := curve.get_point_position(i)

		if i == 0:
			var p_next := curve.get_point_position(1)
			var out_handle := (p_next - p_curr) * smoothness
			curve.set_point_out(0, out_handle)
			curve.set_point_in(0, Vector2.ZERO)
		elif i == count - 1:
			var p_prev := curve.get_point_position(count - 2)
			var in_handle := (p_prev - p_curr) * smoothness
			curve.set_point_in(count - 1, in_handle)
			curve.set_point_out(count - 1, Vector2.ZERO)
		else:
			var p_prev := curve.get_point_position(i - 1)
			var p_next := curve.get_point_position(i + 1)
			var tangent := (p_next - p_prev).normalized()
			
			var dist_prev := p_curr.distance_to(p_prev)
			var dist_next := p_curr.distance_to(p_next)
			
			var in_handle := -tangent * dist_prev * smoothness
			var out_handle := tangent * dist_next * smoothness
			
			curve.set_point_in(i, in_handle)
			curve.set_point_out(i, out_handle)

func generate_path(spawn: Vector2, target: Vector2, waypoint_count: int, max_scatter: float = 200.0) -> Curve2D:
	var curve := Curve2D.new()
	curve.add_point(spawn)
	var dir := (target - spawn).normalized()
	var perp := dir.rotated(PI / 2)
	for i in range(1, waypoint_count + 1):
		var t := float(i) / (waypoint_count + 1)
		var base_point := spawn.lerp(target, t)
		curve.add_point(base_point + perp * randf_range(-max_scatter, max_scatter))
	curve.add_point(target)
	
	if enable_smoothing:
		apply_curve_smoothing(curve, curve_smoothness)
		
	return curve

func validate_path(curve: Curve2D, min_length: float, min_b: Vector2 = min_bounds, max_b: Vector2 = max_bounds) -> bool:
	if curve.get_baked_length() < min_length:
		return false
		
	var margin := 10.0
	for i in range(curve.point_count):
		var pt := curve.get_point_position(i)
		if pt.x < min_b.x - margin or pt.x > max_b.x + margin or pt.y < min_b.y - margin or pt.y > max_b.y + margin:
			return false
			
	return true

func generate_valid_path(spawn: Vector2, target: Vector2, waypoint_count: int, max_scatter: float, min_length: float, max_attempts: int = 50) -> Curve2D:
	for attempt in range(max_attempts):
		var curve := generate_path(spawn, target, waypoint_count, max_scatter)
		if validate_path(curve, min_length):
			return curve
			
	var fallback := Curve2D.new()
	fallback.add_point(spawn)
	fallback.add_point(target)
	return fallback

func generate_mission_paths() -> void:
	_update_bounds_from_camera()
	var target := get_factory_position()
	
	# Generate Main Drone Path
	var main_spawn := select_spawn_point()
	var main_curve := generate_valid_path(main_spawn, target, main_waypoint_count, main_max_scatter, main_min_length)
	
	# Generate FPV Drone Path
	var fpv_spawn := select_spawn_point()
	var fpv_curve := generate_valid_path(fpv_spawn, target, fpv_waypoint_count, fpv_max_scatter, fpv_min_length)
	
	if is_instance_valid(main_path_node):
		main_path_node.position = Vector2.ZERO
		main_path_node.scale = Vector2.ONE
		main_path_node.curve = main_curve
		print("Generated MainPath: length=", main_curve.get_baked_length(), ", points=", main_curve.point_count)
		
	if is_instance_valid(fpv_path_node):
		fpv_path_node.position = Vector2.ZERO
		fpv_path_node.scale = Vector2.ONE
		fpv_path_node.curve = fpv_curve
		print("Generated FPVPath: length=", fpv_curve.get_baked_length(), ", points=", fpv_curve.point_count)
