extends Node2D

@export var ground_sources: Array[int] = [0, 1, 3]
@export var target_map_size_px: Vector2 = Vector2(50000, 50000)
@export var tile_size: int = 1280

@export_range(0.0, 1.0) var tree_spawn_chance: float = 0.25

const GROUND_SOURCE_ID = 0
const TREE_SOURCE_ID = 1

const GROUND_LAYER = 0
const OBJECTS_LAYER = 1

const TILE_ATLAS_POS = Vector2i(0, 0)

@export var factory_positions: Array[Vector2] = [
	Vector2(296.0, 405.0),
	Vector2(-200.0, 250.0),
	Vector2(100.0, -250.0),
	Vector2(-350.0, -100.0),
	Vector2(300.0, -150.0)
]

@onready var mission_generator: Node2D = get_node_or_null("Managers/MissionGenerator")
@onready var wave_manager: Node2D = get_node_or_null("Managers/WaveManager")
@onready var camera: Camera2D = get_node_or_null("Camera2D")
@onready var ground_tile_map: TileMapLayer = get_node_or_null("Environment/Ground")
@onready var tree_tile_map: TileMapLayer = get_node_or_null("Environment/Tree")

var ground_source_id: int = 0
var tree_source_id: int = 1

func _ready() -> void:
	add_to_group("level")
	if is_instance_valid(ground_tile_map):
		generate_large_map()
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

	var tiles_x: int = int(target_map_size_px.x / tile_size)
	var tiles_y: int = int(target_map_size_px.y / tile_size)
	
	var start_x = -tiles_x / 2
	var start_y = -tiles_y / 2	
	var end_x = start_x + tiles_x
	var end_y = start_y + tiles_y
	
	for x in range(start_x, end_x):
		for y in range(start_y, end_y):
			var tile_pos = Vector2i(x, y)
			var random_ground_id = ground_sources.pick_random()
			ground_tile_map.set_cell(tile_pos, random_ground_id, Vector2i(0, 0))

	if is_instance_valid(tree_tile_map):
		var total_trees: int = 500
		var half_w = target_map_size_px.x / 2.0
		var half_h = target_map_size_px.y / 2.0
		
		for i in range(total_trees):
			var random_pos = Vector2(
				randf_range(-half_w, half_w),
				randf_range(-half_h, half_h)
			)
			var tree_cell = tree_tile_map.local_to_map(random_pos)
			tree_tile_map.set_cell(tree_cell, tree_source_id, Vector2i(0, 0))

func generate_trees_proportional() -> void:
	if not is_instance_valid(tree_tile_map) or not is_instance_valid(ground_tile_map):
		return
		
	tree_tile_map.clear()
	
	var ground_rect: Rect2i = ground_tile_map.get_used_rect()
	var total_cells: int = ground_rect.size.x * ground_rect.size.y
	
	var tree_density: float = 0.2 
	var total_trees: int = int(total_cells * tree_density)
	
	for i in range(total_trees):
		var random_ground_cell = Vector2i(
			randi_range(ground_rect.position.x, ground_rect.end.x - 1),
			randi_range(ground_rect.position.y, ground_rect.end.y - 1)
		)
		
		var global_pos = ground_tile_map.to_global(ground_tile_map.map_to_local(random_ground_cell))
		var tree_cell = tree_tile_map.local_to_map(tree_tile_map.to_local(global_pos))
		
		tree_tile_map.set_cell(tree_cell, tree_source_id, Vector2i(0, 0))

func update_camera_bounds() -> void:
	if is_instance_valid(camera):
		var half_size = target_map_size_px * 0.5
		camera.min_bounds = -half_size
		camera.max_bounds = half_size
