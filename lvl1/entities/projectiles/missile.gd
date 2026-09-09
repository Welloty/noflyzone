extends Area2D

@export var speed: float = 450.0
@export var damage: float = 1000.0
@export var turn_speed: float = 3.5
@export var max_g: float = 15.0 # Перегрузка
@export var lifetime: float = 4.0 # максимальное время жизни ракеты
@export var hit_radius: float = 14.0 

@export_range(0.0, 100.0) var accuracy: float = 85.0 # Шанс влучання у % (наприклад, 70%)
@export var max_miss_offset: float = 100.0 # Наскільки сильно ракета зіб'ється з курсу при промаху (в пікселях)

var target: Node2D = null
var current_lifetime: float = 0.0
var tracking_lost: bool = false
var target_offset: Vector2 = Vector2.ZERO # Офсет промаху

func _ready() -> void:
	# При створенні ракеты вираховуємо, чи буде промах
	if randf() * 100.0 > accuracy:
		# Генеруємо випадкову точку навколо цілі
		target_offset = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(max_miss_offset * 0.5, max_miss_offset)

func _process(delta: float) -> void:
	current_lifetime += delta
	if current_lifetime >= lifetime:
		queue_free()
		return
	
	var forward_dir = Vector2.RIGHT.rotated(rotation)
	global_position += forward_dir * speed * delta
	
	# Перевірка влучання або наведення
	if is_instance_valid(target) and target.is_inside_tree() and target.is_in_group("drones"):
		var dist = global_position.distance_to(target.global_position)
		if dist <= hit_radius:
			_hit_target()
			return
		
		if not tracking_lost:
			# Наводимося на позицію цілі з урахуванням зміщення (офсету)
			var target_pos = target.global_position + target_offset
			var target_dir = (target_pos - global_position).normalized()
			var angle_diff = abs(forward_dir.angle_to(target_dir))
			
			if angle_diff > PI / 2.0 and dist < 60.0:
				tracking_lost = true
			else:
				rotation = rotate_toward(rotation, target_dir.angle(), turn_speed * delta)
	else:
		tracking_lost = true

func _hit_target() -> void:
	if is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(damage)
	queue_free()
