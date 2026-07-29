extends Camera2D

@export_group("Movement")
@export var move_speed: float = 800.0
@export var enable_keyboard_move: bool = true
@export var touch_drag_deadzone: float = 8.0

@export_group("Zoom")
@export var zoom_speed: float = 0.15
@export var min_zoom: float = 0.35
@export var max_zoom: float = 2.5
@export var zoom_smoothness: float = 15.0

@export_group("Bounds")
@export var enable_bounds: bool = true
@export var min_bounds: Vector2 = Vector2(-2500.0, -2500.0)
@export var max_bounds: Vector2 = Vector2(2500.0, 2500.0)

var is_dragging: bool = false
var target_zoom: Vector2

# Touch tracking for multi-touch (pinch zoom & pan)
var touches: Dictionary = {}
var initial_touch_dist: float = 0.0
var initial_zoom_val: float = 1.0
var touch_start_positions: Dictionary = {}
var is_touch_panning: bool = false

func _ready() -> void:
	add_to_group("camera")
	target_zoom = zoom

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_MOUSE_EXIT:
		is_dragging = false
		is_touch_panning = false
		touches.clear()
		touch_start_positions.clear()

func _unhandled_input(event: InputEvent) -> void:
	# Ignore synthetic mouse events if touchscreen touch is active
	if touches.size() > 0 and (event is InputEventMouseButton or event is InputEventMouseMotion):
		return

	# --- Touch handling for mobile & touchscreens ---
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			touch_start_positions[event.index] = event.position
			
			if touches.size() == 2:
				_recalculate_pinch_baseline()
		else:
			if touches.has(event.index) and touch_start_positions.has(event.index):
				var start_pos: Vector2 = touch_start_positions[event.index]
				if start_pos.distance_to(event.position) < touch_drag_deadzone and touches.size() == 1:
					_on_map_tapped(event.position)

			touches.erase(event.index)
			touch_start_positions.erase(event.index)

			if touches.size() == 1:
				is_touch_panning = false
				var remaining_idx = touches.keys()[0]
				touch_start_positions[remaining_idx] = touches[remaining_idx]
			elif touches.size() == 0:
				is_touch_panning = false

	elif event is InputEventScreenDrag:
		touches[event.index] = event.position

		if touches.size() == 1:
			var start_pos: Vector2 = touch_start_positions.get(event.index, event.position)
			if is_touch_panning or start_pos.distance_to(event.position) >= touch_drag_deadzone:
				is_touch_panning = true
				position -= event.relative / zoom

		elif touches.size() >= 2:
			is_touch_panning = true
			var touch_keys = touches.keys()
			var p0: Vector2 = touches[touch_keys[0]]
			var p1: Vector2 = touches[touch_keys[1]]
			var current_dist: float = p0.distance_to(p1)

			if initial_touch_dist > 10.0 and current_dist > 10.0:
				var zoom_factor: float = current_dist / initial_touch_dist
				var new_zoom_val: float = clamp(initial_zoom_val * zoom_factor, min_zoom, max_zoom)
				var midpoint: Vector2 = (p0 + p1) * 0.5
				_pinch_zoom_at_point(new_zoom_val, midpoint)

			position -= (event.relative * 0.5) / zoom

	# --- Mouse handling for desktop ---
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _is_placing_pvo():
					return
				is_dragging = true
			else:
				is_dragging = false
		
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			is_dragging = event.pressed
		
		elif event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at_mouse(1.0 + zoom_speed)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at_mouse(1.0 / (1.0 + zoom_speed))

	elif event is InputEventMouseMotion and is_dragging:
		position -= event.relative / zoom

func _process(delta: float) -> void:
	if zoom.distance_to(target_zoom) > 0.001:
		var mouse_before = get_global_mouse_position()
		zoom = zoom.lerp(target_zoom, delta * zoom_smoothness)
		var mouse_after = get_global_mouse_position()
		position += (mouse_before - mouse_after)
	
	if enable_keyboard_move:
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if input_dir != Vector2.ZERO:
			position += input_dir * move_speed * delta / zoom.x

	# Enforce camera bounds
	if enable_bounds:
		position.x = clamp(position.x, min_bounds.x, max_bounds.x)
		position.y = clamp(position.y, min_bounds.y, max_bounds.y)

func _zoom_at_mouse(factor: float) -> void:
	var new_zoom_val = clamp(target_zoom.x * factor, min_zoom, max_zoom)
	target_zoom = Vector2(new_zoom_val, new_zoom_val)

func _pinch_zoom_at_point(new_zoom_val: float, viewport_point: Vector2) -> void:
	var canvas_xform = get_canvas_transform()
	var world_before = canvas_xform.affine_inverse() * viewport_point
	
	target_zoom = Vector2(new_zoom_val, new_zoom_val)
	zoom = target_zoom
	
	var new_canvas_xform = get_canvas_transform()
	var world_after = new_canvas_xform.inverse() * viewport_point if new_canvas_xform.has_method("inverse") else new_canvas_xform.affine_inverse() * viewport_point
	position += (world_before - world_after)

func _recalculate_pinch_baseline() -> void:
	if touches.size() >= 2:
		var touch_keys = touches.keys()
		var p0: Vector2 = touches[touch_keys[0]]
		var p1: Vector2 = touches[touch_keys[1]]
		initial_touch_dist = p0.distance_to(p1)
		initial_zoom_val = zoom.x

func _on_map_tapped(_screen_pos: Vector2) -> void:
	if not _is_placing_pvo():
		var towers = get_tree().get_nodes_in_group("pvo_towers")
		for t in towers:
			if is_instance_valid(t) and "show_range" in t and t.show_range:
				t.show_range = false
				t.queue_redraw()

func _is_placing_pvo() -> bool:
	var mgr = get_tree().get_first_node_in_group("placement_manager")
	if mgr and "ghost_instance" in mgr and is_instance_valid(mgr.ghost_instance):
		return true
	return false
