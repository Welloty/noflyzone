extends Node2D

@export var ground_sources: Array[int] = [0, 1, 3]
@export var target_map_size_px: Vector2 = Vector2(50000, 50000)
@export var tile_size: int = 1280
@export var total_trees_count: int = 2000

const CM_PER_PIXEL: float = 1.18

@export var factory_positions: Array[Vector2] = [
	Vector2(296.0, 405.0),
	Vector2(-200.0, 250.0),
	Vector2(100.0, -250.0),
	Vector2(-350.0, -100.0),
	Vector2(300.0, -150.0)
]

@onready var mission_generator: Node2D = get_node_or_null("Managers/MissionGenerator")
@onready var wave_manager: Node2D = get_node_or_null("Managers/WaveManager")
@onready var main_camera: Camera2D = get_node_or_null("Camera2D")
@onready var ground_tile_map: TileMapLayer = get_node_or_null("Environment/Ground")
@onready var tree_tile_map: TileMapLayer = get_node_or_null("Environment/Tree")

@export var tree_source_id: int = 1
@export var tree_atlas_coords: Vector2i = Vector2i(0, 0)


func calculate_distance_meters(pixels: float) -> float:
	return (pixels * CM_PER_PIXEL) / 100.0


func _ready() -> void:
	add_to_group("level")
	
	if is_instance_valid(ground_tile_map):
		generate_large_map()
		spawn_trees_randomly()
		update_camera_bounds()
	
	var factory = get_tree().get_first_node_in_group("factory")
	if not factory:
		factory = get_node_or_null("Environment/Factory")
	
	if factory and not factory_positions.is_empty():
		factory.global_position = factory_positions.pick_random()
	
	if is_instance_valid(mission_generator) and mission_generator.has_method("generate_mission_paths"):
		mission_generator.generate_mission_paths()


func generate_large_map() -> void:
	if is_instance_valid(ground_tile_map):
		ground_tile_map.clear()
	if is_instance_valid(tree_tile_map):
		tree_tile_map.clear()

	var tiles_x: int = int(ceil(target_map_size_px.x / float(tile_size)))
	var tiles_y: int = int(ceil(target_map_size_px.y / float(tile_size)))
	
	var start_x: int = -tiles_x / 2
	var end_x: int = start_x + tiles_x
	var start_y: int = -tiles_y / 2
	var end_y: int = start_y + tiles_y

	for x in range(start_x, end_x):
		for y in range(start_y, end_y):
			var tile_pos := Vector2i(x, y)
			var random_ground_id: int = ground_sources.pick_random()
			ground_tile_map.set_cell(tile_pos, random_ground_id, Vector2i(0, 0))


func spawn_trees_randomly() -> void:
	if not is_instance_valid(ground_tile_map) or not is_instance_valid(tree_tile_map):
		return

	randomize()

	var used_rect: Rect2i = ground_tile_map.get_used_rect()
	if used_rect.size.x <= 4 or used_rect.size.y <= 4:
		return

	# Враховуємо масштаб і розмір тайла землі
	var ground_scale: Vector2 = ground_tile_map.scale
	var cell_real_size: Vector2 = Vector2(tile_size, tile_size) * ground_scale

	var min_world_x: float = used_rect.position.x * cell_real_size.x
	var max_world_x: float = used_rect.end.x * cell_real_size.x
	var min_world_y: float = used_rect.position.y * cell_real_size.y
	var max_world_y: float = used_rect.end.y * cell_real_size.y

	var margin_px: float = cell_real_size.x * 1.0

	min_world_x += margin_px
	max_world_x -= margin_px
	min_world_y += margin_px
	max_world_y -= margin_px

	if min_world_x >= max_world_x or min_world_y >= max_world_y:
		return

	var placed_tree_cells: Dictionary = {}
	var attempts: int = 0
	var max_attempts: int = total_trees_count * 10

	while placed_tree_cells.size() < total_trees_count and attempts < max_attempts:
		attempts += 1

		var rand_world_pos := Vector2(
			randf_range(min_world_x, max_world_x),
			randf_range(min_world_y, max_world_y)
		)

		var tree_cell: Vector2i = tree_tile_map.local_to_map(tree_tile_map.to_local(rand_world_pos))

		if not placed_tree_cells.has(tree_cell):
			placed_tree_cells[tree_cell] = true

	for cell in placed_tree_cells.keys():
		tree_tile_map.set_cell(cell, tree_source_id, tree_atlas_coords)
		
func update_camera_bounds() -> void:
	var target_cam = get_tree().get_first_node_in_group("camera")
	if not is_instance_valid(target_cam):
		target_cam = main_camera

	if is_instance_valid(target_cam) and is_instance_valid(ground_tile_map):
		var used_rect: Rect2i = ground_tile_map.get_used_rect()
		var map_scale: Vector2 = ground_tile_map.scale
		
		var map_rect = Rect2(
			used_rect.position.x * tile_size * map_scale.x,
			used_rect.position.y * tile_size * map_scale.y,
			used_rect.size.x * tile_size * map_scale.x,
			used_rect.size.y * tile_size * map_scale.y
		)
		
		if target_cam.has_method("set_map_bounds_in_pixels"):
			target_cam.set_map_bounds_in_pixels(map_rect)
		elif "min_bounds" in target_cam and "max_bounds" in target_cam:
			target_cam.min_bounds = map_rect.position
			target_cam.max_bounds = map_rect.end
