extends Node2D

@export var fade_time: float = 2.5
@export var explosion_force_min: float = 60.0
@export var explosion_force_max: float = 180.0
@export var sun_direction := Vector2(15, 20)

var fragments: Array[Dictionary] = []
var current_time: float = 0.0
var initial_velocity: Vector2 = Vector2.ZERO
var _initialized: bool = false

func setup(drone_velocity: Vector2) -> void:
	initial_velocity = drone_velocity
	if _initialized:
		_apply_initial_velocity_to_fragments()

func _ready() -> void:
	var burst = get_node_or_null("ExplosionBurst") as CPUParticles2D
	if burst:
		burst.restart()
		burst.emitting = true

	# обломки
	var parts = [
		get_node_or_null("Engine"),
		get_node_or_null("WingLeft"),
		get_node_or_null("WingRight")
	]

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var angles = [3.14, -1.8, 1.8]

	for i in range(parts.size()):
		var part = parts[i] as Node2D
		if not is_instance_valid(part):
			continue

		var angle = angles[i] + rng.randf_range(-0.35, 0.35)
		var speed = rng.randf_range(explosion_force_min, explosion_force_max)
		var impulse = Vector2.RIGHT.rotated(part.rotation + angle) * speed

		# Calculate physical torque spin from relative position offset and explosion impulse
		var rel_pos = part.position
		var torque = rel_pos.cross(impulse)
		var spin_dir = sign(torque)
		if spin_dir == 0.0:
			spin_dir = 1.0 if rng.randf() > 0.5 else -1.0

		var base_spin = rng.randf_range(10.0, 22.0) if i > 0 else rng.randf_range(5.0, 12.0)
		var rot_vel = spin_dir * base_spin

		var fire_particles = part.get_node_or_null("FireTrail") as CPUParticles2D
		if fire_particles:
			fire_particles.restart()
			fire_particles.emitting = true

		fragments.append({
			"node": part,
			"impulse": impulse,
			"velocity": initial_velocity * rng.randf_range(0.95, 1.05) + impulse,
			"rot_vel": rot_vel,
			"angular_drag": rng.randf_range(1.2, 2.2), # Spin damping over time
			"linear_drag": rng.randf_range(0.4, 0.75), # Aerodynamic flight drag
			"flutter_phase": rng.randf_range(0.0, TAU),
			"initial_scale": part.scale
		})

	_initialized = true

func _apply_initial_velocity_to_fragments() -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for item in fragments:
		var impulse = item.get("impulse", Vector2.ZERO) as Vector2
		item["velocity"] = initial_velocity * rng.randf_range(0.95, 1.05) + impulse

func _process(delta: float) -> void:
	current_time += delta
	var alpha = clamp(1.0 - (current_time / fade_time), 0.0, 1.0)

	for item in fragments:
		var node = item["node"] as Node2D
		if not is_instance_valid(node):
			continue

		var vel = item["velocity"] as Vector2
		var rot_vel = item["rot_vel"] as float
		var angular_drag = item["angular_drag"] as float
		var linear_drag = item["linear_drag"] as float
		var flutter_phase = item["flutter_phase"] as float
		var initial_scale = item.get("initial_scale", Vector2.ONE) as Vector2

		vel = vel * exp(-linear_drag * delta)
		item["velocity"] = vel
		node.global_position += vel * delta

		#физика поворота
		rot_vel = lerp(rot_vel, 0.0, angular_drag * delta)
		rot_vel += sin(current_time * 10.0 + flutter_phase) * 1.5 * delta * alpha
		item["rot_vel"] = rot_vel
		node.rotation += rot_vel * delta

		node.modulate.a = alpha
		node.scale = initial_scale * (0.3 + 0.7 * alpha)

	if current_time >= fade_time + 0.5:
		queue_free()
