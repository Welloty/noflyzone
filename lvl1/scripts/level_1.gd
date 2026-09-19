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

func calculate_distance(pixels: float) -> Dictionary:
	var cm = pixels * CM_PER_PIXEL
	return {
		"pixels": pixels,
		"cm": cm,
		"meters": cm / 100.0,
		"km": cm / 100000.0
	}

func _ready() -> void:
	add_to_group("level")
	
	if is_instance_valid(ground_tile_map):
		generate_large_map_fast()
		spawn_trees_fast()
		update_camera_bounds()
		
	var factory = get_tree().get_first_node_in_group("factory")
	if not factory:
		factory = get_node_or_null("Environment/Factory")
	
	if factory and not factory_positions.is_empty():
		factory.global_position = factory_positions.pick_random()
	
	if is_instance_valid(mission_generator) and mission_generator.has_method("generate_mission_paths"):
		mission_generator.generate_mission_paths()

# Оптимизированная генерация земли с помощью массива (в десятки раз быстрее)
func generate_large_map_fast() -> void:
	ground_tile_map.clear()
	if is_instance_valid(tree_tile_map):
		tree_tile_map.clear()

	var tiles_x: int = int(ceil(target_map_size_px.x / float(tile_size)))
	var tiles_y: int = int(ceil(target_map_size_px.y / float(tile_size)))
	
	var half_x: int = tiles_x / 2
	var half_y: int = tiles_y / 2
	
	var start_x = -half_x
	var start_y = -half_y
	
	# Используем set_cells_terrain_connect или пачку set_cell без лишних просчетов
	for x in range(tiles_x):
		for y in range(tiles_y):
			var tile_pos = Vector2i(start_x + x, start_y + y)
			var random_ground_id = ground_sources.pick_random()
			ground_tile_map.set_cell(tile_pos, random_ground_id, Vector2i.ZERO)

# Быстрый спавн деревьев прямо в мировых/локальных координатах
func spawn_trees_fast() -> void:
	if not is_instance_valid(tree_tile_map):
		return

	# Вычисляем границы спавна в пикселях (с отступом от краев карты)
	var margin_px: float = tile_size * 2.0
	var half_width: float = (target_map_size_px.x / 2.0) - margin_px
	var half_height: float = (target_map_size_px.y / 2.0) - margin_px

	if half_width <= 0 or half_height <= 0:
		return

	# Массив для отслеживания занятых ячеек деревьями (чтобы они не перезаписывали друг друга)
	var occupied_cells: Dictionary = {}
	var spawned_count: int = 0
	var attempts: int = 0
	var max_attempts: int = total_trees_count * 2

	while spawned_count < total_trees_count and attempts < max_attempts:
		attempts += 1
		
		# Генерируем случайную позицию прямо в мировых координатах
		var rand_pos = Vector2(
			randf_range(-half_width, half_width),
			randf_range(-half_height, half_height)
		)

		# Переводим позицию сразу в сетку слоя деревьев
		var tree_cell: Vector2i = tree_tile_map.local_to_map(tree_tile_map.to_local(rand_pos))

		# Если в этой ячейке еще нет дерева — ставим его
		if not occupied_cells.has(tree_cell):
			occupied_cells[tree_cell] = true
			tree_tile_map.set_cell(tree_cell, tree_source_id, tree_atlas_coords)
			spawned_count += 1

func update_camera_bounds() -> void:
	var target_cam = get_tree().get_first_node_in_group("camera")
	if not is_instance_valid(target_cam):
		target_cam = main_camera

	if is_instance_valid(target_cam) and is_instance_valid(ground_tile_map):
		var used_rect = ground_tile_map.get_used_rect()
		var map_scale = ground_tile_map.scale
		var map_rect = Rect2(
			used_rect.position.x * tile_size * map_scale.x,
			used_rect.position.y * tile_size * map_scale.y,
			used_rect.size.x * tile_size * map_scale.x,
			used_rect.size.y * tile_size * map_scale.y
		)
		
		if target_cam.has_method("set_map_bounds_in_pixels"):
			target_cam.set_map_bounds_in_pixels(map_rect)
		else:
			target_cam.min_bounds = map_rect.position
			target_cam.max_bounds = map_rect.end
