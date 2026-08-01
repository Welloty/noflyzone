extends Node2D

@export var pvo_name: String = "Оса"
@export var cost: int = 175
@export var range_radius: float = 360.0
@export var damage: float = 100.0
@export var fire_rate: float = 1.75
@export var missile_scene: PackedScene = preload("res://lvl1/entities/projectiles/missile.tscn")
@export var radar_speed: float = 3.0
@export var missile_speed: float = 550.0
@export var missile_turn_speed: float = 3.5
@export var missile_max_g: float = 25.0
@export var missile_lifetime: float = 4.5

var is_ghost: bool = false
var is_valid_placement: bool = true
var show_range: bool = false
var current_target: Node2D = null
var fire_timer: float = 0.0
@onready var turret_head: Node2D = $TurretHead
@onready var barrel_left: Node2D = $TurretHead/BarrelLeft
@onready var barrel_right: Node2D = $TurretHead/BarrelRight
@onready var click_area: Area2D = $ClickArea
@onready var radar: Node2D = $Radar
@onready var radar_sprite: Node2D = $Radar/Radar
var use_left_barrel: bool = true

func _ready() -> void:
	if not is_ghost:
		add_to_group("pvo_towers")
		if click_area:
			click_area.mouse_entered.connect(_on_mouse_entered)
			click_area.mouse_exited.connect(_on_mouse_exited)
			click_area.input_event.connect(_on_click_area_input_event)

func _process(delta: float) -> void:
	if is_instance_valid(radar_sprite):
		radar.rotation += radar_speed * delta

	if is_ghost:
		return
	_update_target()
	if is_instance_valid(current_target):
		var target_angle = (current_target.global_position - turret_head.global_position).angle()
		turret_head.rotation = lerp_angle(turret_head.rotation, target_angle, delta * 12.0)
		fire_timer -= delta
		if fire_timer <= 0.0:
			_fire()
			fire_timer = fire_rate

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

func _fire() -> void:
	if not is_instance_valid(current_target) or missile_scene == null:
		return
	var spawn_pos = barrel_left.global_position if use_left_barrel else barrel_right.global_position
	use_left_barrel = not use_left_barrel
	var missile = missile_scene.instantiate()
	missile.global_position = spawn_pos
	missile.rotation = turret_head.rotation
	missile.target = current_target
	missile.damage = damage
	missile.speed = missile_speed
	missile.turn_speed = missile_turn_speed
	missile.max_g = missile_max_g
	missile.lifetime = missile_lifetime
	get_tree().current_scene.add_child(missile)

func _draw() -> void:
	if is_ghost:
		var fill_color = Color(0.2, 0.9, 0.4, 0.18) if is_valid_placement else Color(1.0, 0.2, 0.2, 0.22)
		var border_color = Color(0.3, 1.0, 0.5, 0.8) if is_valid_placement else Color(1.0, 0.3, 0.3, 0.85)
		draw_circle(Vector2.ZERO, range_radius, fill_color)
		draw_arc(Vector2.ZERO, range_radius, 0, TAU, 64, border_color, 2.5)
	elif show_range:
		# радіус
		var fill_color = Color(0.15, 0.85, 0.45, 0.12)
		var border_color = Color(0.25, 0.95, 0.5, 0.65)
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
