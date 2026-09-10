extends Area2D

@export var speed: float = 450.0
@export var damage: float = 1000.0
@export var turn_speed: float = 3.5
@export var max_g: float = 15.0 # Перегрузка
@export var lifetime: float = 4.0 # максимальное время жизни ракеты
@export var hit_radius: float = 14.0 

@export_range(0.0, 100.0) var accuracy: float = 85.0 # Шанс влучання у % (наприклад, 70%)
@export var max_miss_offset: float = 100.0 # Наскільки сильно ракета зіб'ється з курсу при промаху (в пікселях)

@export_group("Маневренность и ГСН (Seeker & Maneuver)")
@export var max_seeker_angle_deg: float = 75.0 # Максимальный угол визирования ГСН (если цель дальше вбок/сзади - срыв захвата)
@export var max_turn_from_launch_deg: float = 110.0 # Максимальное отклонение от направления пуска
@export var max_accumulated_turn_deg: float = 140.0 # Максимальный суммарный поворот за всё время (запрет разворота на 360)
@export var lost_tracking_grace_time: float = 1.2 # Время полета по прямой после потери цели до самоликвидации

var target: Node2D = null
var current_lifetime: float = 0.0
var tracking_lost: bool = false
var target_offset: Vector2 = Vector2.ZERO # Офсет промаху
var initial_rotation: float = 0.0
var total_turn_accumulated: float = 0.0
var lost_tracking_timer: float = 0.0

func _ready() -> void:
	initial_rotation = rotation
	# При створенні ракети вираховуємо, чи буде промах
	if randf() * 100.0 > accuracy:
		# Генеруємо випадкову точку навколо цілі
		target_offset = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(max_miss_offset * 0.5, max_miss_offset)

func _process(delta: float) -> void:
		
	current_lifetime += delta
	if current_lifetime >= lifetime:
		queue_free()
		return

	if tracking_lost:
		lost_tracking_timer += delta
		if lost_tracking_timer >= lost_tracking_grace_time:
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

			# 1. Если цель вышла за пределы угла визирования ГСН (позади ракеты или сильно сбоку)
			var max_seeker_rad = deg_to_rad(max_seeker_angle_deg)
			if angle_diff > max_seeker_rad:
				tracking_lost = true
			else:
				var prev_rot = rotation
				var target_angle = target_dir.angle()
				var new_rot = rotate_toward(rotation, target_angle, turn_speed * delta)
				var turn_step = abs(angle_difference(prev_rot, new_rot))
				total_turn_accumulated += turn_step

				# 2. Проверка лимитов суммарного поворота и отклонения от курса пуска
				var dev_from_launch = abs(angle_difference(initial_rotation, new_rot))
				if total_turn_accumulated >= deg_to_rad(max_accumulated_turn_deg) or dev_from_launch >= deg_to_rad(max_turn_from_launch_deg):
					tracking_lost = true
				else:
					rotation = new_rot
	else:
		tracking_lost = true

func _hit_target() -> void:
	if is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(damage)
	queue_free()
