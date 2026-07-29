extends Node2D

@onready var mission_generator: Node2D = get_node_or_null("Managers/MissionGenerator")
@onready var wave_manager: Node2D = get_node_or_null("Managers/WaveManager")
@onready var main_path: Path2D = get_node_or_null("EnemyPaths/MainPath")
@onready var fpv_path: Path2D = get_node_or_null("EnemyPaths/FPVPath")
@onready var camera: Camera2D = get_node_or_null("Camera2D")

func _ready() -> void:
	add_to_group("level")
	
	# генерация пути
	if is_instance_valid(mission_generator) and mission_generator.has_method("generate_mission_paths"):
		mission_generator.generate_mission_paths()
