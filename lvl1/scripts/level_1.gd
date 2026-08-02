extends Node2D

@export var ground_sources: Array[int] = [0, 1, 3]
@export var target_map_size_px: Vector2 = Vector2(50000, 50000)
@export var tile_size: int = 1280
@export var total_trees_count: int = 2000

const GROUND_LAYER = 0
const OBJECTS_LAYER = 1

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
		
	randomize()

	var tiles_x: int = int(ceil(target_map_size_px.x / float(tile_size)))
	var tiles_y: int = int(ceil(target_map_size_px.y / float(tile_size)))
	
	var half_x: int = tiles_x / 2
	var half_y: int = tiles_y / 2
	
	var start_x = -half_x
	var end_x = half_x + (tiles_x % 2)
	var start_y = -half_y
	var end_y = half_y + (tiles_y % 2)
	
	for x in range(start_x, end_x + 1):
		for y in range(start_y, end_y + 1):
			var tile_pos = Vector2i(x, y)
			var random_ground_id = ground_sources.pick_random()
			ground_tile_map.set_cell(tile_pos, random_ground_id, Vector2i(0, 0))

func spawn_trees_randomly() -> void:
	if not is_instance_valid(ground_tile_map) or not is_instance_valid(tree_tile_map):
		return

	var used_rect: Rect2i = ground_tile_map.get_used_rect()
	if used_rect.size.x <= 4 or used_rect.size.y <= 4:
		return

	var margin_tiles: int = 2
	
	var min_g_x: int = used_rect.position.x + margin_tiles
	var max_g_x: int = used_rect.end.x - margin_tiles - 1
	var min_g_y: int = used_rect.position.y + margin_tiles
	var max_g_y: int = used_rect.end.y - margin_tiles - 1

	var spawned_count: int = 0
	var max_attempts: int = total_trees_count * 3 

	for attempt in range(max_attempts):
		if spawned_count >= total_trees_count:
			break

		var rand_g_x: int = randi_range(min_g_x, max_g_x)
		var rand_g_y: int = randi_range(min_g_y, max_g_y)
		var ground_cell: Vector2i = Vector2i(rand_g_x, rand_g_y)

		if ground_tile_map.get_cell_source_id(ground_cell) != -1:
			var cell_local_pos: Vector2 = ground_tile_map.map_to_local(ground_cell)
			var cell_global_pos: Vector2 = ground_tile_map.to_global(cell_local_pos)

			var offset: Vector2 = Vector2(
				randf_range(-tile_size * 0.3, tile_size * 0.3),
				randf_range(-tile_size * 0.3, tile_size * 0.3)
			)
			var tree_world_pos: Vector2 = cell_global_pos + offset

			var tree_local_pos: Vector2 = tree_tile_map.to_local(tree_world_pos)
			var tree_cell: Vector2i = tree_tile_map.local_to_map(tree_local_pos)

			var verify_g_cell: Vector2i = ground_tile_map.local_to_map(ground_tile_map.to_local(tree_world_pos))
			if verify_g_cell.x >= min_g_x and verify_g_cell.x <= max_g_x \
			and verify_g_cell.y >= min_g_y and verify_g_cell.y <= max_g_y:
				tree_tile_map.set_cell(tree_cell, tree_source_id, tree_atlas_coords)
				spawned_count += 1
			
func update_camera_bounds() -> void:
	var target_cam = get_tree().get_first_node_in_group("camera")
	if not is_instance_valid(target_cam):
		target_cam = main_camera

	if is_instance_valid(target_cam) and is_instance_valid(ground_tile_map):
		var used_rect = ground_tile_map.get_used_rect()
		var map_rect = Rect2(
			used_rect.position.x * tile_size,
			used_rect.position.y * tile_size,
			used_rect.size.x * tile_size,
			used_rect.size.y * tile_size
		)
		
		if target_cam.has_method("set_map_bounds_in_pixels"):
			target_cam.set_map_bounds_in_pixels(map_rect)
		else:
			target_cam.min_bounds = map_rect.position
			target_cam.max_bounds = map_rect.end
