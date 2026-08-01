extends Node2D

var active_pvo_scene: PackedScene = preload("res://lvl1/entities/towers/pvo_strela.tscn")
var ghost_instance: Node2D = null
var current_cost: int = 75

# Mobile placement UI controls
var ui_layer: CanvasLayer = null
var confirm_btn: Button = null
var cancel_btn: Button = null
var is_touch_dragging: bool = false
var touch_drag_index: int = -1

# Tower Selection & Selling UI controls
var selected_tower: Node2D = null
var sell_ui_layer: CanvasLayer = null
var sell_panel: PanelContainer = null
var sell_btn: Button = null

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
	deselect_tower()
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
		Input.vibrate_handheld(30)

func _is_mobile_platform() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")

func cancel_placement() -> void:
	_destroy_placement_ui()
	is_touch_dragging = false
	touch_drag_index = -1
	if is_instance_valid(ghost_instance):
		ghost_instance.queue_free()
		ghost_instance = null
	if _is_mobile_platform():
		Input.vibrate_handheld(20)

func _get_hud() -> CanvasLayer:
	return get_tree().get_first_node_in_group("hud") as CanvasLayer

func _process(_delta: float) -> void:
	if is_instance_valid(selected_tower) and is_instance_valid(sell_panel):
		var screen_pos = get_viewport().get_canvas_transform() * selected_tower.global_position
		sell_panel.position = screen_pos + Vector2(-sell_panel.size.x * 0.5, -95.0)

	if not is_instance_valid(ghost_instance):
		return
		
	# On desktop without touch, track mouse cursor smoothly
	if not _is_mobile_platform() and not is_touch_dragging:
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
		if is_instance_valid(selected_tower):
			if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
				deselect_tower()
				get_viewport().set_input_as_handled()
			elif event is InputEventMouseButton and event.pressed:
				deselect_tower()
			elif event is InputEventScreenTouch and event.pressed:
				deselect_tower()
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			# Check if user touched near ghost tower to drag it
			var screen_ghost_pos = get_viewport().get_canvas_transform() * ghost_instance.global_position
			if event.position.distance_to(screen_ghost_pos) <= 120.0:
				is_touch_dragging = true
				touch_drag_index = event.index
				ghost_instance.global_position = _screen_to_global(event.position)
				get_viewport().set_input_as_handled()
			else:
				is_touch_dragging = false
		else:
			if event.index == touch_drag_index:
				is_touch_dragging = false
				touch_drag_index = -1

	elif event is InputEventScreenDrag:
		if is_touch_dragging and (touch_drag_index == -1 or event.index == touch_drag_index):
			ghost_instance.global_position = _screen_to_global(event.position)
			get_viewport().set_input_as_handled()

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
		elif event.button_index == MOUSE_BUTTON_LEFT and not _is_mobile_platform():
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
		if _is_mobile_platform():
			Input.vibrate_handheld(80)
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
	
	if _is_mobile_platform():
		Input.vibrate_handheld(50)

	_destroy_placement_ui()
	ghost_instance.queue_free()
	ghost_instance = null
	is_touch_dragging = false
	touch_drag_index = -1

func _create_placement_ui() -> void:
	_destroy_placement_ui()

	ui_layer = CanvasLayer.new()
	ui_layer.layer = 99
	add_child(ui_layer)

	var panel = PanelContainer.new()
	panel.name = "PlacementPanel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.78
	panel.anchor_bottom = 0.88
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.1, 0.14, 0.92)
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.corner_radius_bottom_right = 16
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.28, 0.45, 0.65, 0.6)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	panel_style.shadow_size = 14
	panel_style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", panel_style)
	ui_layer.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)
	margin.add_child(hbox)

	confirm_btn = Button.new()
	confirm_btn.text = " ✓  ПОСТАВИТЬ "
	confirm_btn.tooltip_text = "Подтвердить установку"
	confirm_btn.custom_minimum_size = Vector2(175, 60)
	confirm_btn.focus_mode = Control.FOCUS_NONE
	_style_button(confirm_btn, Color(0.16, 0.62, 0.3, 0.95), Color(0.2, 0.78, 0.38, 1.0), Color(0.12, 0.48, 0.22, 1.0))
	confirm_btn.pressed.connect(_try_place_tower)
	hbox.add_child(confirm_btn)

	cancel_btn = Button.new()
	cancel_btn.text = " ✕  ОТМЕНА "
	cancel_btn.tooltip_text = "Отменить установку"
	cancel_btn.custom_minimum_size = Vector2(155, 60)
	cancel_btn.focus_mode = Control.FOCUS_NONE
	_style_button(cancel_btn, Color(0.72, 0.22, 0.22, 0.95), Color(0.88, 0.28, 0.28, 1.0), Color(0.55, 0.16, 0.16, 1.0))
	cancel_btn.pressed.connect(cancel_placement)
	hbox.add_child(cancel_btn)

func _style_button(btn: Button, base_color: Color, hover_color: Color, pressed_color: Color = Color.BLACK) -> void:
	if pressed_color == Color.BLACK:
		pressed_color = base_color.darkened(0.2)

	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = base_color
	style_normal.corner_radius_top_left = 14
	style_normal.corner_radius_top_right = 14
	style_normal.corner_radius_bottom_left = 14
	style_normal.corner_radius_bottom_right = 14

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = hover_color
	style_hover.corner_radius_top_left = 14
	style_hover.corner_radius_top_right = 14
	style_hover.corner_radius_bottom_left = 14
	style_hover.corner_radius_bottom_right = 14

	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = pressed_color
	style_pressed.corner_radius_top_left = 14
	style_pressed.corner_radius_top_right = 14
	style_pressed.corner_radius_bottom_left = 14
	style_pressed.corner_radius_bottom_right = 14

	var style_disabled = StyleBoxFlat.new()
	style_disabled.bg_color = Color(0.2, 0.23, 0.26, 0.6)
	style_disabled.corner_radius_top_left = 14
	style_disabled.corner_radius_top_right = 14
	style_disabled.corner_radius_bottom_left = 14
	style_disabled.corner_radius_bottom_right = 14

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("disabled", style_disabled)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6, 0.7))
	btn.add_theme_font_size_override("font_size", 20)

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

func select_tower(tower: Node2D) -> void:
	if is_instance_valid(ghost_instance):
		return
		
	if is_instance_valid(selected_tower) and selected_tower != tower:
		_set_tower_show_range(selected_tower, false)
		
	selected_tower = tower
	if is_instance_valid(selected_tower):
		_set_tower_show_range(selected_tower, true)
		_create_sell_ui()
		if _is_mobile_platform():
			Input.vibrate_handheld(30)
	else:
		deselect_tower()

func deselect_tower() -> void:
	if is_instance_valid(selected_tower):
		_set_tower_show_range(selected_tower, false)
		selected_tower = null
	_destroy_sell_ui()

func toggle_tower_selection(tower: Node2D) -> void:
	if selected_tower == tower:
		deselect_tower()
	else:
		select_tower(tower)

func _set_tower_show_range(tower: Node2D, show: bool) -> void:
	if is_instance_valid(tower):
		tower.show_range = show
		tower.queue_redraw()

func sell_selected_tower() -> void:
	if not is_instance_valid(selected_tower):
		_destroy_sell_ui()
		return
		
	var tower_cost: int = 75
	if "cost" in selected_tower:
		tower_cost = selected_tower.cost
	var refund: int = roundi(tower_cost * 0.9)
	
	var hud = _get_hud()
	if hud and hud.has_method("add_money"):
		hud.add_money(refund)
		
	var sold_tower = selected_tower
	selected_tower = null
	_destroy_sell_ui()
	
	if _is_mobile_platform():
		Input.vibrate_handheld(40)
		
	if is_instance_valid(sold_tower):
		sold_tower.queue_free()

func _create_sell_ui() -> void:
	_destroy_sell_ui()
	if not is_instance_valid(selected_tower):
		return

	sell_ui_layer = CanvasLayer.new()
	sell_ui_layer.layer = 98
	add_child(sell_ui_layer)

	sell_panel = PanelContainer.new()
	sell_panel.name = "SellPanel"
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.11, 0.16, 0.94)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.85, 0.35, 0.25, 0.8)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	panel_style.shadow_size = 10
	panel_style.shadow_offset = Vector2(0, 3)
	sell_panel.add_theme_stylebox_override("panel", panel_style)
	sell_ui_layer.add_child(sell_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	sell_panel.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var tower_name: String = "ПВО"
	if "pvo_name" in selected_tower:
		tower_name = selected_tower.pvo_name
	var tower_cost: int = 75
	if "cost" in selected_tower:
		tower_cost = selected_tower.cost
	var refund: int = roundi(tower_cost * 0.9)

	var info_vbox = VBoxContainer.new()
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_vbox.add_theme_constant_override("separation", 0)

	var title_lbl = Label.new()
	title_lbl.text = tower_name
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))

	var price_lbl = Label.new()
	price_lbl.text = "+%d$" % refund
	price_lbl.add_theme_font_size_override("font_size", 13)
	price_lbl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.45))

	info_vbox.add_child(title_lbl)
	info_vbox.add_child(price_lbl)
	hbox.add_child(info_vbox)

	sell_btn = Button.new()
	sell_btn.text = " ПРОДАТЬ "
	sell_btn.tooltip_text = "Продать ПВО за %d$" % refund
	sell_btn.custom_minimum_size = Vector2(100, 36)
	sell_btn.focus_mode = Control.FOCUS_NONE
	_style_button(sell_btn, Color(0.78, 0.25, 0.2, 0.95), Color(0.92, 0.32, 0.25, 1.0), Color(0.55, 0.18, 0.15, 1.0))
	sell_btn.pressed.connect(sell_selected_tower)
	hbox.add_child(sell_btn)

	var close_btn = Button.new()
	close_btn.text = " ✕ "
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.focus_mode = Control.FOCUS_NONE
	_style_button(close_btn, Color(0.25, 0.28, 0.32, 0.8), Color(0.35, 0.4, 0.45, 1.0), Color(0.18, 0.2, 0.24, 1.0))
	close_btn.pressed.connect(deselect_tower)
	hbox.add_child(close_btn)

	if is_instance_valid(selected_tower):
		var screen_pos = get_viewport().get_canvas_transform() * selected_tower.global_position
		sell_panel.position = screen_pos + Vector2(-sell_panel.size.x * 0.5, -95.0)

func _destroy_sell_ui() -> void:
	if is_instance_valid(sell_ui_layer):
		sell_ui_layer.queue_free()
		sell_ui_layer = null
		sell_panel = null
		sell_btn = null
