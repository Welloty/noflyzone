extends CharacterBody2D

@export var speed: float = 100.0
@export var max_health: float = 80.0
@export var damage_to_factory: float = 25.0
@export var reward_money: int = 20
@export var path_follower: PathFollow2D
@export var sun_direction := Vector2(15, 20)
@export var destruction_scene: PackedScene = preload("res://lvl1/entities/enemies/drone_destruction.tscn")
@export var factory_explosion_scene: PackedScene = preload("res://lvl1/entities/enemies/factory_explosion.tscn")

@onready var shadow_sprite: Sprite2D = $Shadow

var health: float = 80.0
var is_down: bool = false


func _ready() -> void:
	add_to_group("drones")
	health = max_health


func _exit_tree() -> void:
	_cleanup_path_follower()


func _cleanup_path_follower() -> void:
	if is_instance_valid(path_follower):
		path_follower.queue_free()


func _process(_delta: float) -> void:
	if is_instance_valid(shadow_sprite):
		shadow_sprite.global_rotation = global_rotation + deg_to_rad(90)
		shadow_sprite.global_position = global_position + sun_direction


func _physics_process(delta: float) -> void:
	if not is_instance_valid(path_follower):
		return
	
	path_follower.progress += speed * delta
	
	if path_follower.progress_ratio >= 0.95:
		_explode_on_factory()
		return
		
	var target_position := path_follower.global_position
	var direction := global_position.direction_to(target_position)
	var distance := global_position.distance_to(target_position)
	
	if distance > 2.0:
		velocity = direction * speed
		look_at(target_position)
	else:
		velocity = Vector2.ZERO
		
	move_and_slide()


func _explode_on_factory() -> void:
	if is_down:
		return
	is_down = true

	var factory = get_tree().get_first_node_in_group("factory")
	if not factory:
		factory = get_tree().root.find_child("Factory", true, false)
	
	if factory and factory.has_method("take_damage"):
		factory.take_damage(damage_to_factory)
	
	remove_from_group("drones")

	if factory_explosion_scene != null:
		var explosion = factory_explosion_scene.instantiate()
		explosion.global_position = global_position
		explosion.rotation = global_rotation
		if get_parent():
			get_parent().add_child(explosion)
		else:
			get_tree().current_scene.add_child(explosion)
	elif destruction_scene != null:
		var destruction = destruction_scene.instantiate()
		destruction.global_position = global_position
		destruction.rotation = global_rotation
		
		var move_vel = velocity
		if move_vel.length() < 1.0:
			move_vel = Vector2.RIGHT.rotated(global_rotation) * speed
			
		if destruction.has_method("setup"):
			destruction.setup(move_vel)
			
		if get_parent():
			get_parent().add_child(destruction)
		else:
			get_tree().current_scene.add_child(destruction)

	queue_free()


func take_damage(amount: float) -> void:
	if is_down:
		return
	health -= amount
	if health <= 0:
		_die()


func _die() -> void:
	if is_down:
		return
	is_down = true

	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("add_money"):
		hud.add_money(reward_money)
	
	remove_from_group("drones")

	if destruction_scene != null:
		var destruction = destruction_scene.instantiate()
		destruction.global_position = global_position
		destruction.rotation = global_rotation
		
		var move_vel = velocity
		if move_vel.length() < 1.0:
			move_vel = Vector2.RIGHT.rotated(global_rotation) * speed
			
		if destruction.has_method("setup"):
			destruction.setup(move_vel)
			
		if get_parent():
			get_parent().add_child(destruction)
		else:
			get_tree().current_scene.add_child(destruction)

	queue_free()
