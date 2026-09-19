extends CharacterBody2D

signal patrol_button_clicked()

enum State { LOITER, PATROL, INTERCEPT, RETURNING }

#@export var pvo_name: String = "Самолет"
@export var max_health: float = 80.0
@export var cost: int = 150
@export var speed: float = 500
@export var loiter_radius: float = 200.0
var is_down: bool = false
@onready var explosion_zone: Area2D = $DetectionZone

@export var damage_to_factory: float = 250.0
@export var factory_explosion_scene: PackedScene = preload("res://lvl1/entities/enemies/factory_explosion.tscn")
@export var destruction_scene: PackedScene = preload("res://lvl1/entities/enemies/drone_destruction.tscn")
var factory = "res://lvl1/entities/factory/factory.tscn"

var state: State = State.LOITER
var is_ghost: bool = false
var is_valid_placement: bool = true
var show_range: bool = false
var _last_click_frame: int = -1

var loiter_center: Vector2 = Vector2.ZERO
var loiter_angle: float = 0.0
var patrol_points: Array[Vector2] = []
var patrol_index: int = 0
var health: float = 80.0


func on_patrol_button_pressed() -> void:
	patrol_button_clicked.emit()

func set_patrol(points: Array[Vector2]) -> void:
	patrol_points = points.duplicate()
	patrol_index = 0
	if not patrol_points.is_empty():
		state = State.PATROL
	else:
		state = State.LOITER
	queue_redraw()

@onready var shadow_sprite: Sprite2D = get_node_or_null("Shadow")
@onready var main_sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var click_area: Area2D = get_node_or_null("ClickArea")

func _ready() -> void:
	add_to_group("drones")
	if not is_ghost:
		add_to_group("friendly_units")
		add_to_group("pvo_towers")
		loiter_center = global_position
		state = State.LOITER
		if click_area:
			click_area.mouse_entered.connect(_on_mouse_entered)
			click_area.mouse_exited.connect(_on_mouse_exited)
			click_area.input_event.connect(_on_click_area_input_event)
		input_event.connect(_on_click_area_input_event)
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)

var prev_rotation: float = 0.0

func _process(delta: float) -> void:
	if is_instance_valid(shadow_sprite):
		shadow_sprite.global_rotation = global_rotation + deg_to_rad(0)
		shadow_sprite.global_position = global_position + Vector2(15, 20)

	if is_instance_valid(main_sprite) and not is_ghost:
		var turn_rate = wrapf(rotation - prev_rotation, -PI, PI) / max(delta, 0.001)
		prev_rotation = rotation
		var target_skew = clamp(turn_rate * 0.12, -0.3, 0.3)
		main_sprite.skew = lerp(main_sprite.skew, target_skew, delta * 10.0)

	if show_range:
		queue_redraw()

func _physics_process(delta: float) -> void:
	if is_ghost:
		return

	match state:
		State.LOITER:
			_process_loiter(delta)
		State.PATROL:
			_process_patrol(delta)
		State.RETURNING:
			_process_returning(delta)

func _process_loiter(delta: float) -> void:
	if loiter_center == Vector2.ZERO and not is_ghost:
		loiter_center = global_position

	loiter_angle += (speed / loiter_radius) * delta
	if loiter_angle > TAU:
		loiter_angle -= TAU

	var target_pos = loiter_center + Vector2(cos(loiter_angle), sin(loiter_angle)) * loiter_radius
	var dir = global_position.direction_to(target_pos)
	var dist = global_position.distance_to(target_pos)

	if dist > 2.0:
		velocity = dir * speed
		rotation = lerp_angle(rotation, dir.angle(), delta * 8.0)
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func _process_patrol(delta: float) -> void:
	if patrol_points.is_empty():
		state = State.LOITER
		return

	var target_pos = patrol_points[patrol_index]
	var dist = global_position.distance_to(target_pos)

	if dist <= 20.0:
		patrol_index += 1
		# Если прошли последнюю точку — удаляем самолет
		if patrol_index >= patrol_points.size():
			_explode()
			return
		target_pos = patrol_points[patrol_index]

	var dir = global_position.direction_to(target_pos)
	velocity = dir * speed
	rotation = lerp_angle(rotation, dir.angle(), delta * 8.0)
	move_and_slide()



func start_returning() -> void:
	state = State.RETURNING
	if not patrol_points.is_empty():
		var closest_idx: int = 0
		var closest_dist: float = INF
		for i in range(patrol_points.size()):
			var dist = global_position.distance_to(patrol_points[i])
			if dist < closest_dist:
				closest_dist = dist
				closest_idx = i
		patrol_index = closest_idx

func _process_returning(delta: float) -> void:
	if not patrol_points.is_empty():
		var target_pos = patrol_points[patrol_index]
		var dist = global_position.distance_to(target_pos)
		if dist <= 25.0:
			state = State.PATROL
			return
		var dir = global_position.direction_to(target_pos)
		velocity = dir * speed
		rotation = lerp_angle(rotation, dir.angle(), delta * 8.0)
		move_and_slide()
	else:
		var dist = global_position.distance_to(loiter_center)
		if dist <= 25.0:
			state = State.LOITER
			return
		var dir = global_position.direction_to(loiter_center)
		velocity = dir * speed
		rotation = lerp_angle(rotation, dir.angle(), delta * 8.0)
		move_and_slide()



func _explode() -> void:
	if is_down:
		return
	is_down = true

	var damaged_objects: Array = []

	for area in explosion_zone.get_overlapping_areas():
		# Вариант А: Если скрипт take_damage висит прямо на Area2D
		var target = area
		
		# Вариант Б: Если Area2D — это хитбокс, а скрипт фабрики висит на родителе
		if not target.has_method("take_damage"):
			target = area.get_parent()
		
		# Проверяем, принадлежит ли попавший объект к фабрикам и не получал ли урон за этот взрыв
		if target and target.is_in_group("factory") and target not in damaged_objects:
			if target.has_method("take_damage"):
				target.take_damage(damage_to_factory)
				damaged_objects.append(target) # Запоминаем, что эта фабрика уже получила урон
		
		# Вариант Б: Если Area2D — это дочерний хитбокс, а скрипт фабрики висит на её родителе
		elif area.get_parent().has_method("take_damage"):
			area.get_parent().take_damage(damage_to_factory)
	
	if factory_explosion_scene != null:
		var explosion = factory_explosion_scene.instantiate()
		explosion.global_position = global_position
		explosion.rotation = global_rotation
		if get_parent():
			get_parent().add_child(explosion)
		else:
			get_tree().current_scene.add_child(explosion)
	
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



func set_ghost_valid(valid: bool) -> void:
	is_valid_placement = valid
	modulate = Color(1, 1, 1, 0.75) if valid else Color(1, 0.4, 0.4, 0.75)
	queue_redraw()

func _draw() -> void:
	if is_ghost:
		var fill_color = Color(0.2, 0.9, 0.4, 0.18) if is_valid_placement else Color(1.0, 0.2, 0.2, 0.22)
		var border_color = Color(0.3, 1.0, 0.5, 0.8) if is_valid_placement else Color(1.0, 0.3, 0.3, 0.85)
		draw_circle(Vector2.ZERO, loiter_radius, fill_color)
		draw_arc(Vector2.ZERO, loiter_radius, 0, TAU, 64, border_color, 2.5)

func _on_mouse_entered() -> void:
	if not DisplayServer.is_touchscreen_available() and not OS.has_feature("mobile"):
		show_range = true
		queue_redraw()

func _on_mouse_exited() -> void:
	if not DisplayServer.is_touchscreen_available() and not OS.has_feature("mobile"):
		show_range = false
		queue_redraw()

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if is_ghost:
		return

	var is_click = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_click = true
	elif event is InputEventScreenTouch and event.pressed:
		is_click = true

	if is_click:
		var current_frame = Engine.get_process_frames()
		if current_frame == _last_click_frame:
			return
		_last_click_frame = current_frame

		var mgr = get_tree().get_first_node_in_group("placement_manager")
		if mgr and mgr.has_method("toggle_tower_selection"):
			mgr.toggle_tower_selection(self)
		else:
			show_range = not show_range
			queue_redraw()
		get_viewport().set_input_as_handled()


func _area_damage(area: Area2D) -> void:
	# 1. Проверяем, принадлежит ли входящая area группе "factory"
	if area.is_in_group("factory"):
		if area.has_method("take_damage"):
			area.take_damage(damage_to_factory)
		remove_from_group("drones")
		queue_free() # Опционально: обычно дроны уничтожаются после нанесения урона
			
			
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
	#if hud and hud.has_method("add_money"):
		#hud.add_money(reward_money)
	
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
