extends Node2D

signal wave_started(wave_number: int, total_drones: int)
signal wave_completed(wave_number: int, reward_money: int)
signal break_timer_updated(time_remaining: float)

@export var max_waves: int = 10
@export var break_duration: float = 4.0

var current_wave: int = 0
var drones_to_spawn_this_wave: int = 0
var drones_spawned: int = 0
var is_wave_active: bool = false
var is_spawning: bool = false
var spawn_timer: float = 0.0
var spawn_interval: float = 2.0
var break_timer: float = 2.0

var drone_scene: PackedScene = preload("res://lvl1/entities/enemies/drone.tscn")
var fpv_scene: PackedScene = preload("res://lvl1/entities/enemies/fpv.tscn")
var fp1_scene: PackedScene = preload("res://lvl1/entities/enemies/fp-1.tscn")

@onready var main_path: Path2D = get_node_or_null("../../EnemyPaths/MainPath") if get_node_or_null("../../EnemyPaths/MainPath") else get_node_or_null("../Path2D")
@onready var fpv_path: Path2D = get_node_or_null("../../EnemyPaths/FPVPath") if get_node_or_null("../../EnemyPaths/FPVPath") else get_node_or_null("../fpvdrun")
@onready var fp1_path: Path2D = get_node_or_null("../../EnemyPaths/FP1Path") if get_node_or_null("../../EnemyPaths/FP1Path") else get_node_or_null("../FP1Path")

func _ready() -> void:
	add_to_group("wave_manager")
	break_timer = 3.0
	_update_hud()

func _process(delta: float) -> void:
	if not is_wave_active:
		if current_wave >= max_waves:
			return
		break_timer -= delta
		break_timer_updated.emit(max(0.0, break_timer))
		if break_timer <= 0.0:
			_start_next_wave()
		return

	if is_spawning:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn_single_drone()
			spawn_timer = spawn_interval
			if drones_spawned >= drones_to_spawn_this_wave:
				is_spawning = false
	else:
		# Проверка: уничтожены ли все дроны
		var active_drones = get_tree().get_nodes_in_group("drones")
		if active_drones.size() == 0:
			_on_wave_completed()

func _start_next_wave() -> void:
	if current_wave >= max_waves:
		return
		
	current_wave += 1
	is_wave_active = true
	is_spawning = true
	drones_spawned = 0
	
	drones_to_spawn_this_wave = 4 + (current_wave * 3)
	spawn_interval = max(0.6, 2.2 - (current_wave * 0.15))
	spawn_timer = 0.1
	
	_update_hud()
	wave_started.emit(current_wave, drones_to_spawn_this_wave)
	print("Wave ", current_wave, " started. Spawning ", drones_to_spawn_this_wave, " drones.")

func _spawn_single_drone() -> void:
	drones_spawned += 1
	
	# выбор типа дрона
	var scene: PackedScene = drone_scene
	var path_node: Path2D = main_path
	
	if current_wave >= 2:
		var roll := randf()
		if roll < 0.35:
			scene = fpv_scene
			path_node = fpv_path
		elif roll < 0.70:
			scene = fp1_scene
			path_node = fp1_path
	
	if not is_instance_valid(path_node):
		path_node = main_path
		
	# создания нового patchfollow
	var path_follower = PathFollow2D.new()
	path_follower.rotates = true
	path_node.add_child(path_follower)
	path_follower.progress_ratio = 0.0
	
	# инициализированние дрона
	var new_drone: CharacterBody2D = scene.instantiate()
	new_drone.path_follower = path_follower
	
	new_drone.speed = new_drone.speed * (1.0 + (current_wave * 0.05))
	new_drone.max_health = new_drone.max_health * (1.0 + (current_wave * 0.08))
	new_drone.health = new_drone.max_health
	
	if scene == drone_scene:
		new_drone.scale = Vector2(0.4, 0.4)
		
	get_parent().add_child(new_drone)
	new_drone.global_position = path_follower.global_position

func _on_wave_completed() -> void:
	is_wave_active = false
	break_timer = break_duration
	
	# награда за завершение волны
	var reward = 40 + (current_wave * 10)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("add_money"):
		hud.add_money(reward)
		
	wave_completed.emit(current_wave, reward)
	print("Wave ", current_wave, " completed. Next wave in ", break_duration, " seconds.")

func _update_hud() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("update_wave"):
		hud.update_wave(current_wave, max_waves)

func get_active_drones_count() -> int:
	return get_tree().get_nodes_in_group("drones").size()
