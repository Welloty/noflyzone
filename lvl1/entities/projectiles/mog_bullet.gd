extends Area2D

@export var speed: float = 950.0
@export var damage: float = 8.0
@export var lifetime: float = 0.85
@export var hit_radius: float = 16.0

var target: Node2D = null
var current_lifetime: float = 0.0
var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	direction = Vector2.RIGHT.rotated(rotation)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	current_lifetime += delta
	if current_lifetime >= lifetime:
		queue_free()
		return
	
	global_position += direction * speed * delta

	# Проверка попадания в цель по дистанции (для надежности при высоких скоростях)
	if is_instance_valid(target) and target.is_inside_tree() and target.is_in_group("drones"):
		if global_position.distance_to(target.global_position) <= hit_radius:
			_hit_target(target)
			return

func _on_body_entered(body: Node2D) -> void:
	if is_instance_valid(body) and body.is_in_group("drones"):
		_hit_target(body)

func _on_area_entered(area: Area2D) -> void:
	var parent_node = area.get_parent()
	if is_instance_valid(parent_node) and parent_node.is_in_group("drones"):
		_hit_target(parent_node)

func _hit_target(victim: Node2D) -> void:
	if is_instance_valid(victim) and victim.has_method("take_damage"):
		victim.take_damage(damage)
	queue_free()

func _draw() -> void:
	# Отрисовка светящегося трассера (снаряд вытянут вдоль направления полета)
	# Хвост трассера от -16px до 2px
	draw_line(Vector2(-16, 0), Vector2(2, 0), Color(1.0, 0.45, 0.1, 0.4), 4.0) # Внешнее оранжевое свечение
	draw_line(Vector2(-12, 0), Vector2(1, 0), Color(1.0, 0.85, 0.2, 0.85), 2.5) # Желтый след
	draw_line(Vector2(-4, 0), Vector2(0, 0), Color(1.0, 1.0, 0.9, 1.0), 1.5) # Белое горячее ядро
