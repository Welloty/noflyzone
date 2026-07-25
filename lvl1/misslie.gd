extends Area2D

@export var speed: float = 450.0
@export var damage: float = 1000.0

var target: Node2D = null

func _process(delta: float) -> void:
	# Якщо ціль знищена під час польоту — ракета самознищується
	if not is_instance_valid(target) or not target.is_inside_tree():
		queue_free()
		return
	var direction = (target.global_position - global_position).normalized()
	rotation = direction.angle()
	global_position += direction * speed * delta
	if global_position.distance_to(target.global_position) < 10.0:
		_hit_target()

func _hit_target() -> void:
	if is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(damage)
	queue_free()
