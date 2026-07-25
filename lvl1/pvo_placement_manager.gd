extends Node2D

var active_pvo_scene: PackedScene = preload("res://lvl1/pvo_strela.tscn")
var ghost_instance: Node2D = null
var current_cost: int = 50

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
		active_pvo_scene = preload("res://lvl1/pvo_osa.tscn")
	else:
		active_pvo_scene = preload("res://lvl1/pvo_strela.tscn")

	ghost_instance = active_pvo_scene.instantiate()
	ghost_instance.is_ghost = true
	ghost_instance.z_index = 25
	add_child(ghost_instance)

func cancel_placement() -> void:
	if is_instance_valid(ghost_instance):
		ghost_instance.queue_free()
		ghost_instance = null

func _get_hud() -> CanvasLayer:
	return get_tree().get_first_node_in_group("hud") as CanvasLayer

func _process(_delta: float) -> void:
	if not is_instance_valid(ghost_instance):
		return
		
	var mouse_pos = get_global_mouse_position()
	ghost_instance.global_position = mouse_pos
	
	var hud = _get_hud()
	var can_afford = true
	if hud and hud.has_method("has_money"):
		can_afford = hud.has_money(current_cost)
		
	var is_collision_free = _is_position_valid(ghost_instance)
	var is_valid = can_afford and is_collision_free
		
	if ghost_instance.has_method("set_ghost_valid"):
		ghost_instance.set_ghost_valid(is_valid)

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(ghost_instance):
		return
		
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_place_tower()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placement()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_placement()
		get_viewport().set_input_as_handled()

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
			
	var towers_container = get_node_or_null("../TowersContainer")
	if not towers_container:
		towers_container = get_parent()
		
	var new_tower = active_pvo_scene.instantiate()
	new_tower.is_ghost = false
	new_tower.global_position = ghost_instance.global_position
	new_tower.z_index = 10
	towers_container.add_child(new_tower)
	new_tower.add_to_group("pvo_towers")
	
	if hud and hud.has_method("has_money") and not hud.has_money(current_cost):
		cancel_placement()

func _is_position_valid(ghost: Node2D) -> bool:
	if not is_instance_valid(ghost):
		return false
		
	var min_distance: float = 56.0
	var click_area = ghost.get_node_or_null("ClickArea") as Area2D
	if click_area:
		var shape_node = click_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node and shape_node.shape is CircleShape2D:
			min_distance = (shape_node.shape as CircleShape2D).radius * 2.0
			
	var towers_container = get_node_or_null("../TowersContainer")
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
