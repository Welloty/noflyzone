extends Camera2D

@export_group("Movement")
@export var move_speed: float = 800.0
@export var enable_keyboard_move: bool = true

@export_group("Zoom")
@export var zoom_speed: float = 0.15
@export var min_zoom: float = 0.4
@export var max_zoom: float = 2.5
@export var zoom_smoothness: float = 15.0

var is_dragging: bool = false
var target_zoom: Vector2

func _ready() -> void:
	target_zoom = zoom

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_MOUSE_EXIT:
		is_dragging = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
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

func _zoom_at_mouse(factor: float) -> void:
	var new_zoom_val = clamp(target_zoom.x * factor, min_zoom, max_zoom)
	target_zoom = Vector2(new_zoom_val, new_zoom_val)

func _is_placing_pvo() -> bool:
	var mgr = get_tree().get_first_node_in_group("placement_manager")
	if mgr and "ghost_instance" in mgr and is_instance_valid(mgr.ghost_instance):
		return true
	return false
