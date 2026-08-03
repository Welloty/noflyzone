extends CharacterBody2D

signal patrol_button_clicked()

enum State { LOITER, PATROL, INTERCEPT, RETURNING }

@export var pvo_name: String = "Самолет"
@export var cost: int = 150
@export var speed: float = 180.0
@export var loiter_radius: float = 150.0
@export var detection_radius: float = 350.0
@export var attack_range: float = 75.0
@export var damage: float = 150.0
@export var max_chase_time: float = 12.0
@export var max_chase_distance: float = 750.0

var state: State = State.LOITER
var is_ghost: bool = false
var is_valid_placement: bool = true
var show_range: bool = false
var _last_click_frame: int = -1

var loiter_center: Vector2 = Vector2.ZERO
var loiter_angle: float = 0.0
var patrol_points: Array[Vector2] = []
var patrol_index: int = 0

var current_target: Node2D = null
var detected_targets: Array[Node2D] = []
var chase_timer: float = 0.0

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
@onready var detection_zone: Area2D = get_node_or_null("DetectionZone")
@onready var click_area: Area2D = get_node_or_null("ClickArea")

func _ready() -> void:
	if not is_ghost:
		add_to_group("friendly_units")
		add_to_group("pvo_towers")
		loiter_center = global_position
		state = State.LOITER
		if detection_zone:
			detection_zone.input_pickable = false
			detection_zone.body_entered.connect(_on_detection_zone_body_entered)
			detection_zone.body_exited.connect(_on_detection_zone_body_exited)
			detection_zone.area_entered.connect(_on_detection_zone_area_entered)
			detection_zone.area_exited.connect(_on_detection_zone_area_exited)
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
		shadow_sprite.global_rotation = global_rotation + deg_to_rad(90)
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
			_check_detection_zone()
			_process_loiter(delta)
		State.PATROL:
			_check_detection_zone()
			_process_patrol(delta)
		State.INTERCEPT:
			_check_detection_zone()
			_process_intercept(delta)
		State.RETURNING:
			_check_detection_zone()
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
		patrol_index = (patrol_index + 1) % patrol_points.size()
		target_pos = patrol_points[patrol_index]

	var dir = global_position.direction_to(target_pos)
	velocity = dir * speed
	rotation = lerp_angle(rotation, dir.angle(), delta * 8.0)
	move_and_slide()

func _process_intercept(delta: float) -> void:
	if not is_instance_valid(current_target) or not current_target.is_inside_tree() or ("is_down" in current_target and current_target.is_down):
		_update_target_and_state()
		return

	chase_timer += delta
	var origin_ref = loiter_center if patrol_points.is_empty() else patrol_points[patrol_index]
	if chase_timer >= max_chase_time or global_position.distance_to(origin_ref) > max_chase_distance:
		current_target = null
		state = State.RETURNING
		return

	var dist_to_target = global_position.distance_to(current_target.global_position)

	var target_radius: float = 30.0
	if current_target.has_node("CollisionShape2D"):
		var cs = current_target.get_node("CollisionShape2D") as CollisionShape2D
		if cs and cs.shape:
			if cs.shape is CapsuleShape2D:
				target_radius = max(cs.shape.radius, cs.shape.height * 0.5) * cs.scale.x
			elif cs.shape is CircleShape2D:
				target_radius = cs.shape.radius * cs.scale.x
			elif cs.shape is RectangleShape2D:
				target_radius = cs.shape.size.length() * 0.5 * cs.scale.x

	var effective_attack_range = max(attack_range, target_radius + 35.0)

	var is_touching_target = false
	var slide_count = get_slide_collision_count()
	for i in range(slide_count):
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider == current_target or (collider and collider.is_in_group("drones")):
			is_touching_target = true
			break

	if dist_to_target <= effective_attack_range or is_touching_target:
		_attack_target(current_target)
		return

	var lead_pos = calculate_lead_position(current_target)
	var dir = global_position.direction_to(lead_pos)
	velocity = dir * speed
	rotation = lerp_angle(rotation, dir.angle(), delta * 12.0)
	move_and_slide()

func _attack_target(target: Node2D) -> void:
	if not is_instance_valid(target):
		return

	if target.has_method("take_damage"):
		target.take_damage(damage)
	elif target.has_method("_die"):
		target._die()
	else:
		target.queue_free()

	current_target = null
	_update_target_and_state()

func calculate_lead_position(target: Node2D) -> Vector2:
	if not is_instance_valid(target):
		return global_position

	var target_pos = target.global_position
	var target_vel = Vector2.ZERO

	if "velocity" in target and target.velocity is Vector2 and target.velocity.length() > 0.1:
		target_vel = target.velocity
	elif "speed" in target and ("rotation" in target or "global_rotation" in target):
		var rot = target.global_rotation if "global_rotation" in target else target.rotation
		var spd = target.speed if "speed" in target else 100.0
		target_vel = Vector2.RIGHT.rotated(rot) * spd

	if target_vel.length() < 0.1:
		return target_pos

	var rel_pos = target_pos - global_position
	var a = target_vel.length_squared() - (speed * speed)
	var b = 2.0 * rel_pos.dot(target_vel)
	var c = rel_pos.length_squared()

	var disc = b * b - 4.0 * a * c
	if disc < 0.0:
		return target_pos

	var t = 0.0
	if abs(a) < 0.001:
		if abs(b) > 0.001:
			t = -c / b
	else:
		var t1 = (-b - sqrt(disc)) / (2.0 * a)
		var t2 = (-b + sqrt(disc)) / (2.0 * a)
		if t1 > 0.0 and t2 > 0.0:
			t = min(t1, t2)
		elif t1 > 0.0:
			t = t1
		elif t2 > 0.0:
			t = t2

	if t > 0.0 and t < 8.0:
		return target_pos + target_vel * t

	return target_pos

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

func _on_detection_zone_body_entered(body: Node) -> void:
	_on_target_entered(body)

func _on_detection_zone_body_exited(body: Node) -> void:
	_on_target_exited(body)

func _on_detection_zone_area_entered(area: Area2D) -> void:
	var target = area.get_parent() if area.get_parent() and area.get_parent().is_in_group("drones") else area
	_on_target_entered(target)

func _on_detection_zone_area_exited(area: Area2D) -> void:
	var target = area.get_parent() if area.get_parent() and area.get_parent().is_in_group("drones") else area
	_on_target_exited(target)

func _on_target_entered(node: Node) -> void:
	if is_ghost or not is_instance_valid(node):
		return
	var target_node: Node2D = null
	if node is Node2D and node.is_in_group("drones"):
		target_node = node as Node2D
	elif node.get_parent() and node.get_parent().is_in_group("drones") and node.get_parent() is Node2D:
		target_node = node.get_parent() as Node2D
	
	if target_node and not detected_targets.has(target_node):
		detected_targets.append(target_node)
		_update_target_and_state()

func _on_target_exited(node: Node) -> void:
	if is_ghost or not is_instance_valid(node):
		return
	var target_node: Node2D = null
	if node is Node2D and node.is_in_group("drones"):
		target_node = node as Node2D
	elif node.get_parent() and node.get_parent().is_in_group("drones") and node.get_parent() is Node2D:
		target_node = node.get_parent() as Node2D
		
	if target_node and target_node in detected_targets:
		detected_targets.erase(target_node)
		_update_target_and_state()

func _check_detection_zone() -> void:
	if not is_instance_valid(detection_zone) or is_ghost:
		return
	var bodies = detection_zone.get_overlapping_bodies()
	for b in bodies:
		if is_instance_valid(b) and b.is_in_group("drones") and b is Node2D:
			if not detected_targets.has(b as Node2D):
				detected_targets.append(b as Node2D)
	_update_target_and_state()

func _update_target_and_state() -> void:
	var valid_targets: Array[Node2D] = []
	for t in detected_targets:
		if is_instance_valid(t) and t.is_inside_tree() and not ("is_down" in t and t.is_down):
			valid_targets.append(t)
	detected_targets = valid_targets

	if not is_instance_valid(current_target) or not current_target.is_inside_tree() or current_target not in detected_targets or ("is_down" in current_target and current_target.is_down):
		current_target = null

	if current_target == null and not detected_targets.is_empty():
		var closest_dist: float = INF
		var best_target: Node2D = null
		for t in detected_targets:
			var dist = global_position.distance_to(t.global_position)
			if dist < closest_dist:
				closest_dist = dist
				best_target = t
		current_target = best_target

	if is_instance_valid(current_target):
		if state == State.LOITER or state == State.PATROL:
			state = State.INTERCEPT
			chase_timer = 0.0
	else:
		if state == State.INTERCEPT:
			start_returning()

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
	elif show_range:
		var fill_color = Color(0.2, 0.6, 1.0, 0.12)
		var border_color = Color(0.3, 0.7, 1.0, 0.65)
		draw_circle(Vector2.ZERO, loiter_radius, fill_color)
		draw_arc(Vector2.ZERO, loiter_radius, 0, TAU, 64, border_color, 2.0)
		for i in range(8):
			var angle = i * (TAU / 8.0)
			var inner_p = Vector2.RIGHT.rotated(angle) * (loiter_radius - 8)
			var outer_p = Vector2.RIGHT.rotated(angle) * (loiter_radius + 4)
			draw_line(inner_p, outer_p, Color(0.3, 0.8, 1.0, 0.7), 1.5)

		if not patrol_points.is_empty():
			for i in range(patrol_points.size()):
				var local_p = to_local(patrol_points[i])
				draw_circle(local_p, 5.0, Color(0.2, 0.8, 1.0, 0.8))
				if i < patrol_points.size() - 1:
					var next_local = to_local(patrol_points[i + 1])
					draw_line(local_p, next_local, Color(0.2, 0.8, 1.0, 0.6), 2.0)
				elif patrol_points.size() > 2:
					var first_local = to_local(patrol_points[0])
					draw_line(local_p, first_local, Color(0.2, 0.8, 1.0, 0.4), 1.5)

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
