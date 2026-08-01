extends Node2D

@export var map_textures: Array[Texture2D] = [
	preload("res://lvl1/textures/lvl1map.png")
]

@export var factory_positions: Array[Vector2] = [
	Vector2(296.0, 405.0),
	Vector2(-200.0, 250.0),
	Vector2(100.0, -250.0),
	Vector2(-350.0, -100.0),
	Vector2(300.0, -150.0)
]

@onready var mission_generator: Node2D = get_node_or_null("Managers/MissionGenerator")
@onready var wave_manager: Node2D = get_node_or_null("Managers/WaveManager")
@onready var main_path: Path2D = get_node_or_null("EnemyPaths/MainPath")
@onready var fpv_path: Path2D = get_node_or_null("EnemyPaths/FPVPath")
@onready var fp1_path: Path2D = get_node_or_null("EnemyPaths/FP1Path")
@onready var camera: Camera2D = get_node_or_null("Camera2D")
@onready var map_sprite: Sprite2D = get_node_or_null("Environment/MapSprite")

func _ready() -> void:
	add_to_group("level")
	
	# Выбор случайного фона карты
	if is_instance_valid(map_sprite) and not map_textures.is_empty():
		var chosen_map = map_textures.pick_random()
		if chosen_map:
			map_sprite.texture = chosen_map
			var size = chosen_map.get_size()
			if size != Vector2.ZERO and is_instance_valid(camera):
				var half_size = size * 0.5
				camera.min_bounds = -half_size
				camera.max_bounds = half_size
	
	# Выбор случайного места для завода из предустановленных точек
	var factory = get_tree().get_first_node_in_group("factory")
	if not factory:
		factory = get_node_or_null("Environment/Factory")
	
	if factory and not factory_positions.is_empty():
		var random_pos = factory_positions.pick_random()
		factory.global_position = random_pos
	
	# генерация пути
	if is_instance_valid(mission_generator) and mission_generator.has_method("generate_mission_paths"):
		mission_generator.generate_mission_paths()
