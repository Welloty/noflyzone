extends Camera2D

@export_group("Movement")
@export var move_speed: float = 800.0
@export var enable_keyboard_move: bool = true

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

var touches: Dictionary = {}
var initial_touch_dist: float = 0.0
var initial_zoom_val: float = 1.0

func _ready() -> void:
	add_to_group("camera")
	target_zoom = zoom

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_MOUSE_EXIT:
		is_dragging = false
		touches.clear()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)

		if touches.size() == 2:
			var touch_keys = touches.keys()
			var p0: Vector2 = touches[touch_keys[0]]
			var p1: Vector2 = touches[touch_keys[1]]
			initial_touch_dist = p0.distance_to(p1)
			initial_zoom_val = target_zoom.x
		elif touches.size() == 0:
			is_dragging = false

	elif event is InputEventScreenDrag:
		touches[event.index] = event.position

		if _is_placing_pvo():
			return

		if touches.size() == 1:
			position -= event.relative / zoom.x

		elif touches.size() >= 2:
			var touch_keys = touches.keys()
			var p0: Vector2 = touches[touch_keys[0]]
			var p1: Vector2 = touches[touch_keys[1]]
			var current_dist: float = p0.distance_to(p1)

			if initial_touch_dist > 5.0 and current_dist > 5.0:
				var zoom_factor: float = current_dist / initial_touch_dist
				var new_zoom_val: float = clamp(initial_zoom_val * zoom_factor, min_zoom, max_zoom)

				target_zoom = Vector2(new_zoom_val, new_zoom_val)

			position -= (event.relative * 0.5) / zoom.x

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
		if not _is_placing_pvo():
			position -= event.relative / zoom.x

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

	if enable_bounds:
		position.x = clamp(position.x, min_bounds.x, max_bounds.x)
		position.y = clamp(position.y, min_bounds.y, max_bounds.y)

func _zoom_at_mouse(factor: float) -> void:
	var new_zoom_val = clamp(target_zoom.x * factor, min_zoom, max_zoom)
	target_zoom = Vector2(new_zoom_val, new_zoom_val)

func _is_placing_pvo() -> bool:
	var mgr = get_tree().get_first_node_in_group("placement_manager")
	if mgr:
		if "ghost_instance" in mgr and is_instance_valid(mgr.ghost_instance):
			return true
		if "is_dragging" in mgr and mgr.is_dragging:
			return true
	return false

func shake(amount: float = 14.0, duration: float = 0.4) -> void:
	var original_offset = offset
	var tween = create_tween()
	var steps = int(duration * 25.0)
	for i in range(steps):
		var random_offset = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
		tween.tween_property(self, "offset", random_offset, duration / max(1, steps))
	tween.tween_property(self, "offset", original_offset, 0.05)
