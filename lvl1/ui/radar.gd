extends Control

@export var strela_max_range_px: float = 460.0
@export var osa_max_range_px: float = 2700.0
@export var min_visible_dist_px: float = 10.0

@onready var toggle_button: Button = $ToggleButton
@onready var strela_button: Button = $Strela
@onready var osa_button: Button = $Osa

@onready var background = $Background
@onready var pvo_icon: Sprite2D = $Pvo
@onready var enemy_icon: Sprite2D = $Target

var active_zrk_node: Node2D
var target_node: Node2D

var is_osa: bool = false
var is_radar_visible: bool = true

func _ready() -> void:
	if is_instance_valid(toggle_button) and not toggle_button.pressed.is_connected(_on_toggle_button_pressed):
		toggle_button.pressed.connect(_on_toggle_button_pressed)
		
	if is_instance_valid(strela_button):
		strela_button.pressed.connect(func(): set_radar_mode(false))
	if is_instance_valid(osa_button):
		osa_button.pressed.connect(func(): set_radar_mode(true))

func set_radar_mode(osa_mode: bool) -> void:
	is_osa = osa_mode
	active_zrk_node = null

func _on_toggle_button_pressed() -> void:
	is_radar_visible = !is_radar_visible
	
	if is_instance_valid(background):
		background.visible = is_radar_visible
		
	if is_instance_valid(strela_button):
		strela_button.visible = is_radar_visible
	if is_instance_valid(osa_button):
		osa_button.visible = is_radar_visible
		
	if is_instance_valid(toggle_button):
		toggle_button.text = "► Скрыть" if is_radar_visible else "► Показать"
func _process(_delta: float) -> void:
	if not is_instance_valid(background) or not is_radar_visible:
		if is_instance_valid(pvo_icon): pvo_icon.visible = false
		if is_instance_valid(enemy_icon): enemy_icon.visible = false
		return

	var selected_pvo_name: String = "Оса" if is_osa else "Стрела-10"
	
	if not is_instance_valid(active_zrk_node):
		var zrks = get_tree().get_nodes_in_group("zrk")
		for zrk in zrks:
			if is_instance_valid(zrk):
				if "pvo_name" in zrk and zrk.pvo_name == selected_pvo_name:
					active_zrk_node = zrk
					break

	if not is_instance_valid(active_zrk_node):
		if is_instance_valid(pvo_icon): pvo_icon.visible = false
		if is_instance_valid(enemy_icon): enemy_icon.visible = false
		return

	var bg_local_center: Vector2 = background.position
	var radius_px: float = 0.0

	if background is Sprite2D:
		if background.texture:
			radius_px = (background.texture.get_size().x * background.scale.x) * 0.5
		if not background.centered:
			bg_local_center += Vector2(radius_px, radius_px)
	elif background is Control:
		radius_px = background.size.x * 0.5
		bg_local_center += background.size * 0.5

	if is_instance_valid(pvo_icon):
		pvo_icon.visible = true
		pvo_icon.position = bg_local_center

	target_node = null
	var drones = get_tree().get_nodes_in_group("drones")
	var min_d: float = INF
	
	for drone in drones:
		if drone != active_zrk_node and is_instance_valid(drone):
			var d: float = active_zrk_node.global_position.distance_to(drone.global_position)
			if d < min_d:
				min_d = d
				target_node = drone

	if not is_instance_valid(target_node):
		if is_instance_valid(enemy_icon): enemy_icon.visible = false
		return

	var rel_world_pos: Vector2 = target_node.global_position - active_zrk_node.global_position
	var dist_px: float = rel_world_pos.length()
	
	var max_range_px: float = osa_max_range_px if is_osa else strela_max_range_px

	if dist_px <= max_range_px and dist_px >= min_visible_dist_px:
		enemy_icon.visible = true
		enemy_icon.z_index = 5
		
		var dist_ratio: float = dist_px / max_range_px
		var dir: Vector2 = rel_world_pos.normalized()
		var offset: Vector2 = dir * (dist_ratio * radius_px)

		enemy_icon.position = bg_local_center + offset
		
		enemy_icon.rotation = target_node.global_rotation + deg_to_rad(90)
	else:
		enemy_icon.visible = false
