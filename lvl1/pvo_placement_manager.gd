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

func start_placement(_pvo_type: String, cost: int) -> void:
	if is_instance_valid(ghost_instance):
		return
	
	var hud = _get_hud()
	if hud and hud.has_method("has_money") and not hud.has_money(cost):
		return
		
	current_cost = cost
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
		
	if ghost_instance.has_method("set_ghost_valid"):
		ghost_instance.set_ghost_valid(can_afford)

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
	if hud and hud.has_method("deduct_money"):
		if not hud.deduct_money(current_cost):
			cancel_placement()
			return
			
	var towers_container = get_node_or_null("../TowersContainer")
	if not towers_container:
		towers_container = get_parent()
		
	var new_tower = active_pvo_scene.instantiate()
	new_tower.global_position = ghost_instance.global_position
	new_tower.is_ghost = false
	new_tower.z_index = 10
	towers_container.add_child(new_tower)
	
	# Завершаем установку, если денег на следующую башню недостаточно
	if hud and hud.has_method("has_money") and not hud.has_money(current_cost):
		cancel_placement()

func _on_pvo_selected(pvo_type: String, cost: int) -> void:
	start_placement(pvo_type, cost)
