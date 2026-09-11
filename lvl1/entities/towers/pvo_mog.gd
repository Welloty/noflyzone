extends Node2D

# НАСТРОЙКИ БАЛАНСА МОБИЛЬНОЙ ОГНЕВОЙ ГРУППЫ (МОГ)
@export_group("Параметры башни (Tower Stats)")
@export var pvo_name: String = "МОГ"
@export var cost: int = 50                 # Цена покупки в долларах ($)
@export var range_radius: float = 340.0    # Дальность стрельбы в пикселях
@export var damage: float = 9.0            # Урон за одну пулю
@export var fire_rate: float = 0.08        # Время между выстрелами внутри очереди (сек)
@export var burst_count: int = 5           # Количество выстрелов в одной очереди
@export var burst_pause: float = 0.45      # Пауза между очередями (сек)

@export_group("Параметры стрельбы (Ballistics)")
@export var bullet_scene: PackedScene = preload("res://lvl1/entities/projectiles/mog_bullet.tscn")
@export var bullet_speed: float = 950.0    # Скорость полета пули
@export var bullet_spread_deg: float = 2.5 # Разброс пулемета в градусах (+/-)
@export var turret_turn_speed: float = 14.0 # Скорость наведения пулемета

# ВНУТРЕННЕЕ СОСТОЯНИЕ
var is_ghost: bool = false
var is_valid_placement: bool = true
var show_range: bool = false
var current_target: Node2D = null

var shots_in_current_burst: int = 0
var shot_timer: float = 0.0
var burst_pause_timer: float = 0.0
var use_left_barrel: bool = true
var flash_timer: float = 0.0

@onready var turret_head: Node2D = $TurretHead
@onready var barrel_left: Node2D = $TurretHead/BarrelLeft
@onready var barrel_right: Node2D = $TurretHead/BarrelRight
@onready var muzzle_flash: Node2D = $TurretHead/MuzzleFlash
@onready var click_area: Area2D = $ClickArea

func _ready() -> void:
	add_to_group("zrk")
	if not is_ghost:
		add_to_group("pvo_towers")
		if click_area:
			click_area.mouse_entered.connect(_on_mouse_entered)
			click_area.mouse_exited.connect(_on_mouse_exited)
			click_area.input_event.connect(_on_click_area_input_event)

func _process(delta: float) -> void:
	if is_ghost:
		return
		
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0 and is_instance_valid(muzzle_flash):
			muzzle_flash.visible = false

	_update_target()

	if is_instance_valid(current_target):
		var target_angle = (current_target.global_position - turret_head.global_position).angle()
		turret_head.rotation = lerp_angle(turret_head.rotation, target_angle, delta * turret_turn_speed)

		# Обработка таймеров стрельбы очередями
		if burst_pause_timer > 0.0:
			burst_pause_timer -= delta
		else:
			shot_timer -= delta
			if shot_timer <= 0.0:
				_fire_shot()
				shot_timer = fire_rate
				shots_in_current_burst += 1
				if shots_in_current_burst >= burst_count:
					shots_in_current_burst = 0
					burst_pause_timer = burst_pause
	else:
		shots_in_current_burst = 0

func _update_target() -> void:
	if not is_instance_valid(current_target) or not current_target.is_inside_tree() or global_position.distance_to(current_target.global_position) > range_radius or not current_target.is_in_group("drones"):
		current_target = null

	if current_target != null:
		return

	var drones = get_tree().get_nodes_in_group("drones")
	var closest_dist: float = range_radius + 1.0
	var best_drone: Node2D = null

	for drone in drones:
		if is_instance_valid(drone) and drone.is_inside_tree():
			var dist = global_position.distance_to(drone.global_position)
			if dist <= range_radius and dist < closest_dist:
				closest_dist = dist
				best_drone = drone

	current_target = best_drone

func _fire_shot() -> void:
	if not is_instance_valid(current_target) or bullet_scene == null:
		return

	var spawn_pos = barrel_left.global_position if use_left_barrel else barrel_right.global_position
	var barrel_node = barrel_left if use_left_barrel else barrel_right
	use_left_barrel = not use_left_barrel

	# Легкий случайный разброс для реалистичной пулеметной очереди
	var spread_rad = deg_to_rad(randf_range(-bullet_spread_deg, bullet_spread_deg))
	var shot_rotation = turret_head.rotation + spread_rad

	var bullet = bullet_scene.instantiate()
	bullet.global_position = spawn_pos
	bullet.rotation = shot_rotation
	bullet.target = current_target
	bullet.damage = damage
	bullet.speed = bullet_speed

	get_tree().current_scene.add_child(bullet)

	# Вспышка выстрела
	if is_instance_valid(muzzle_flash):
		muzzle_flash.position = barrel_node.position + Vector2(2, 0)
		muzzle_flash.visible = true
		flash_timer = 0.04

func _draw() -> void:
	if is_ghost:
		var fill_color = Color(0.2, 0.9, 0.4, 0.18) if is_valid_placement else Color(1.0, 0.2, 0.2, 0.22)
		var border_color = Color(0.3, 1.0, 0.5, 0.8) if is_valid_placement else Color(1.0, 0.3, 0.3, 0.85)
		draw_circle(Vector2.ZERO, range_radius, fill_color)
		draw_arc(Vector2.ZERO, range_radius, 0, TAU, 64, border_color, 2.5)
	elif show_range:
		var fill_color = Color(0.2, 0.8, 0.4, 0.12)
		var border_color = Color(0.3, 0.95, 0.5, 0.65)
		draw_circle(Vector2.ZERO, range_radius, fill_color)
		draw_arc(Vector2.ZERO, range_radius, 0, TAU, 64, border_color, 2.0)
		for i in range(8):
			var angle = i * (TAU / 8.0)
			var inner_p = Vector2.RIGHT.rotated(angle) * (range_radius - 8)
			var outer_p = Vector2.RIGHT.rotated(angle) * (range_radius + 4)
			draw_line(inner_p, outer_p, Color(0.3, 1.0, 0.6, 0.7), 1.5)

func set_ghost_valid(valid: bool) -> void:
	is_valid_placement = valid
	modulate = Color(1, 1, 1, 0.75) if valid else Color(1, 0.4, 0.4, 0.75)
	queue_redraw()

func _on_mouse_entered() -> void:
	if not DisplayServer.is_touchscreen_available() and not OS.has_feature("mobile"):
		show_range = true
		queue_redraw()

func _on_mouse_exited() -> void:
	if not DisplayServer.is_touchscreen_available() and not OS.has_feature("mobile"):
		show_range = false
		queue_redraw()

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var is_click = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_click = true
	elif event is InputEventScreenTouch and event.pressed:
		is_click = true

	if is_click:
		var mgr = get_tree().get_first_node_in_group("placement_manager")
		if mgr and mgr.has_method("toggle_tower_selection"):
			mgr.toggle_tower_selection(self)
		else:
			show_range = not show_range
			if show_range and (DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")):
				Input.vibrate_handheld(30)
			queue_redraw()
		get_viewport().set_input_as_handled()
