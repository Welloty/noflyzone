extends CharacterBody2D

@export var speed: float = 40.0
@export var max_health: float = 25.0
@export var damage_to_factory: int = 25
@export var reward_money: int = 15
@export var path_follower: PathFollow2D
@export var propeller_speed: float = 1000.0

@onready var propeller_lb: Sprite2D = $Propeller 
@onready var propeller_rb: Sprite2D = $Propeller2 
@onready var propeller_rf: Sprite2D = $Propeller3 
@onready var propeller_lf: Sprite2D = $Propeller4 
@export var sun_direction := Vector2(15, 20)
@onready var shadow_sprite: Sprite2D = $Shadow

var health: float = 25.0
var is_down: bool = false
var die_velocity: Vector2 = Vector2.ZERO
var die_rot_vel: float = 0.0

func _ready() -> void:
	add_to_group("drones")
	health = max_health

func _exit_tree() -> void:
	_cleanup_path_follower()

func _cleanup_path_follower() -> void:
	if is_instance_valid(path_follower):
		path_follower.queue_free()

func _process(_delta: float) -> void:
	shadow_sprite.global_rotation = global_rotation + deg_to_rad(90)
	shadow_sprite.global_position = global_position + sun_direction

func _physics_process(delta: float) -> void:
	if is_down:
		die_velocity = die_velocity * exp(-0.6 * delta)
		die_rot_vel = lerp(die_rot_vel, 0.0, 1.8 * delta)
		global_position += die_velocity * delta
		rotation += die_rot_vel * delta
		return

	if not is_instance_valid(path_follower):
		return
		
	path_follower.progress += speed * delta
	
	if path_follower.progress_ratio >= 0.99:
		_explode_on_factory()
		return	
		
	var target_position = path_follower.global_position
	var direction = global_position.direction_to(target_position)
	var distance = global_position.distance_to(target_position)
	
	if distance > 2.0:
		velocity = direction * speed
		look_at(target_position)
	else:
		velocity = Vector2.ZERO
		
	if propeller_rb and propeller_lb and propeller_lf and propeller_rf:
		propeller_rb.rotation += propeller_speed * delta
		propeller_lb.rotation += propeller_speed * delta
		propeller_rf.rotation += propeller_speed * delta
		propeller_rf.rotation += propeller_speed * delta
		
	move_and_slide()

func _explode_on_factory() -> void:
	var factory = get_tree().get_first_node_in_group("factory")
	if factory and factory.has_method("take_damage"):
		factory.take_damage(damage_to_factory)
	
	remove_from_group("drones")
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

	die_velocity = velocity
	if die_velocity.length() < 1.0:
		die_velocity = Vector2.RIGHT.rotated(global_rotation) * speed
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var spin_dir = 1.0 if rng.randf() > 0.5 else -1.0
	die_rot_vel = spin_dir * rng.randf_range(8.0, 16.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 1.2)
	tween.tween_property(self, "modulate:a", 0.0, 1.2)
	await tween.finished
	queue_free()
