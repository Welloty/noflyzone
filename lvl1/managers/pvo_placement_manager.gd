extends Node2D

var active_pvo_scene: PackedScene = preload("res://lvl1/entities/towers/pvo_strela.tscn")
var ghost_instance: Node2D = null
var current_cost: int = 75

# Mobile placement UI controls
var ui_layer: CanvasLayer = null
var confirm_btn: Button = null
var cancel_btn: Button = null
var is_touch_dragging: bool = false

func _ready() -> void:
	add_to_group("placement_manager")
	z_index = 20
	call_deferred("_connect_hud")

func _connect_hud() -> void:
	var hud_ref = _get_hud()
	if hud_ref and hud_ref.has_signal("pvo_selected"):
		if not hud_ref.pvo_selected.is_connected(_on_pvo_selected):
			hud_ref.pvo_selected.connect(_on_pvo_selected)

func start_placement(pvo_type: String, cost: int) -> void:
	if is_instance_valid(ghost_instance):
		return
	
	var hud = _get_hud()
	if hud and hud.has_method("has_money") and not hud.has_money(cost):
		return
		
	current_cost = cost
	if pvo_type == "Оса" or pvo_type == "Osa":
		active_pvo_scene = preload("res://lvl1/entities/towers/pvo_osa.tscn")
	else:
		active_pvo_scene = preload("res://lvl1/entities/towers/pvo_strela.tscn")

	ghost_instance = active_pvo_scene.instantiate()
	ghost_instance.is_ghost = true
	ghost_instance.z_index = 25
	add_child(ghost_instance)

	var camera = get_viewport().get_camera_2d()
	if camera and _is_mobile_platform():
		ghost_instance.global_position = camera.get_screen_center_position()
	else:
		ghost_instance.global_position = get_global_mouse_position()

	if _is_mobile_platform():
		_create_placement_ui()

func _is_mobile_platform() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")

func cancel_placement() -> void:
	_destroy_placement_ui()
	if is_instance_valid(ghost_instance):
		ghost_instance.queue_free()
		ghost_instance = null

func _get_hud() -> CanvasLayer:
	return get_tree().get_first_node_in_group("hud") as CanvasLayer

func _process(_delta: float) -> void:
	if not is_instance_valid(ghost_instance):
		return
		
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not is_touch_dragging:
		var mouse_pos = get_global_mouse_position()
		if mouse_pos.distance_squared_to(ghost_instance.global_position) > 4.0:
			ghost_instance.global_position = mouse_pos
	
	var hud = _get_hud()
	var can_afford = true
	if hud and hud.has_method("has_money"):
		can_afford = hud.has_money(current_cost)
		
	var is_collision_free = _is_position_valid(ghost_instance)
	var is_valid = can_afford and is_collision_free
		
	if ghost_instance.has_method("set_ghost_valid"):
		ghost_instance.set_ghost_valid(is_valid)

	if is_instance_valid(confirm_btn):
		confirm_btn.disabled = not is_valid

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(ghost_instance):
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			is_touch_dragging = true
			ghost_instance.global_position = _screen_to_global(event.position)
		else:
			is_touch_dragging = false
			
	elif event is InputEventScreenDrag:
		if is_touch_dragging:
			ghost_instance.global_position = _screen_to_global(event.position)

	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			cancel_placement()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_try_place_tower()
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placement()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_try_place_tower()
			get_viewport().set_input_as_handled()

func _screen_to_global(screen_pos: Vector2) -> Vector2:
	var canvas_xform = get_canvas_transform()
	return canvas_xform.affine_inverse() * screen_pos

func _try_place_tower() -> void:
	if not is_instance_valid(ghost_instance):
		return
		
	var hud = _get_hud()
	var can_afford = true
	if hud and hud.has_method("has_money"):
		can_afford = hud.has_money(current_cost)
		
	var is_collision_free = _is_position_valid(ghost_instance)
	
	if not can_afford or not is_collision_free:
		return
		
	if hud and hud.has_method("deduct_money"):
		if not hud.deduct_money(current_cost):
			cancel_placement()
			return
			
	var towers_container = _get_towers_container()
		
	var new_tower = active_pvo_scene.instantiate()
	new_tower.is_ghost = false
	new_tower.global_position = ghost_instance.global_position
	new_tower.z_index = 10
	towers_container.add_child(new_tower)
	new_tower.add_to_group("pvo_towers")
	
	_destroy_placement_ui()
	ghost_instance.queue_free()
	ghost_instance = null

func _create_placement_ui() -> void:
	_destroy_placement_ui()

	ui_layer = CanvasLayer.new()
	ui_layer.layer = 99
	add_child(ui_layer)

	var panel = PanelContainer.new()
	panel.name = "PlacementPanel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.72
	panel.anchor_bottom = 0.72
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.1, 0.14, 0.88)
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.corner_radius_bottom_right = 16
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.28, 0.45, 0.65, 0.5)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	panel_style.shadow_size = 12
	panel_style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", panel_style)
	ui_layer.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	margin.add_child(hbox)

	confirm_btn = Button.new()
	confirm_btn.text = " ✓  ПОСТАВИТЬ "
	confirm_btn.tooltip_text = "Подтвердить установку (Enter / Space / ЛКМ)"
	confirm_btn.custom_minimum_size = Vector2(165, 54)
	confirm_btn.focus_mode = Control.FOCUS_NONE
	_style_button(confirm_btn, Color(0.16, 0.62, 0.3, 0.95), Color(0.2, 0.78, 0.38, 1.0), Color(0.12, 0.48, 0.22, 1.0))
	confirm_btn.pressed.connect(_try_place_tower)
	hbox.add_child(confirm_btn)

	cancel_btn = Button.new()
	cancel_btn.text = " ✕  ОТМЕНА "
	cancel_btn.tooltip_text = "Отменить установку (Esc / ПКМ)"
	cancel_btn.custom_minimum_size = Vector2(145, 54)
	cancel_btn.focus_mode = Control.FOCUS_NONE
	_style_button(cancel_btn, Color(0.72, 0.22, 0.22, 0.95), Color(0.88, 0.28, 0.28, 1.0), Color(0.55, 0.16, 0.16, 1.0))
	cancel_btn.pressed.connect(cancel_placement)
	hbox.add_child(cancel_btn)

func _style_button(btn: Button, base_color: Color, hover_color: Color, pressed_color: Color = Color.BLACK) -> void:
	if pressed_color == Color.BLACK:
		pressed_color = base_color.darkened(0.2)

	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = base_color
	style_normal.corner_radius_top_left = 12
	style_normal.corner_radius_top_right = 12
	style_normal.corner_radius_bottom_left = 12
	style_normal.corner_radius_bottom_right = 12

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = hover_color
	style_hover.corner_radius_top_left = 12
	style_hover.corner_radius_top_right = 12
	style_hover.corner_radius_bottom_left = 12
	style_hover.corner_radius_bottom_right = 12

	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = pressed_color
	style_pressed.corner_radius_top_left = 12
	style_pressed.corner_radius_top_right = 12
	style_pressed.corner_radius_bottom_left = 12
	style_pressed.corner_radius_bottom_right = 12

	var style_disabled = StyleBoxFlat.new()
	style_disabled.bg_color = Color(0.2, 0.23, 0.26, 0.6)
	style_disabled.corner_radius_top_left = 12
	style_disabled.corner_radius_top_right = 12
	style_disabled.corner_radius_bottom_left = 12
	style_disabled.corner_radius_bottom_right = 12

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("disabled", style_disabled)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6, 0.7))
	btn.add_theme_font_size_override("font_size", 18)

func _destroy_placement_ui() -> void:
	if is_instance_valid(ui_layer):
		ui_layer.queue_free()
		ui_layer = null
		confirm_btn = null
		cancel_btn = null

func _is_position_valid(ghost: Node2D) -> bool:
	if not is_instance_valid(ghost):
		return false
		
	var min_distance: float = 56.0
	var click_area = ghost.get_node_or_null("ClickArea") as Area2D
	if click_area:
		var shape_node = click_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node and shape_node.shape is CircleShape2D:
			min_distance = (shape_node.shape as CircleShape2D).radius * 2.0
			
	var towers_container = _get_towers_container()
	if towers_container:
		for child in towers_container.get_children():
			if is_instance_valid(child) and child != ghost and child is Node2D:
				if ghost.global_position.distance_to(child.global_position) < min_distance:
					return false

	var placed_towers = get_tree().get_nodes_in_group("pvo_towers")
	for tower in placed_towers:
		if is_instance_valid(tower) and tower != ghost and tower is Node2D:
			if ghost.global_position.distance_to(tower.global_position) < min_distance:
				return false

	if click_area:
		var overlapping_areas = click_area.get_overlapping_areas()
		for area in overlapping_areas:
			var parent_tower = area.get_parent()
			if is_instance_valid(parent_tower) and parent_tower != ghost:
				return false
				
	return true

func _on_pvo_selected(pvo_type: String, cost: int) -> void:
	start_placement(pvo_type, cost)

func _get_towers_container() -> Node2D:
	var container = get_node_or_null("../../Containers/TowersContainer") as Node2D
	if not container:
		container = get_node_or_null("../TowersContainer") as Node2D
	if not container:
		container = get_parent() as Node2D
	return container
