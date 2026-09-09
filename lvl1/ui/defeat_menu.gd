class_name DefeatMenu
extends CanvasLayer

@onready var overlay: ColorRect = $Overlay
@onready var try_again_btn: Button = $Overlay/Panel/VBox/TryAgainButton
@onready var menu_btn: Button = $Overlay/Panel/VBox/MenuButton
@onready var fade_overlay: ColorRect = $FadeOverlay


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	overlay.visible = true
	fade_overlay.visible = false
	
	add_to_group("defeat_menu")
	
	try_again_btn.pressed.connect(_on_try_again_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)

@onready var title_label: Label = $Overlay/Panel/Title

func open(is_victory: bool = false) -> void:
	get_tree().paused = true
	visible = true
	overlay.modulate.a = 0.0
	
	if is_instance_valid(title_label):
		if is_victory:
			title_label.text = tr("VICTORY") if tr("VICTORY") != "VICTORY" else "ПОБЕДА"
			title_label.modulate = Color(0.4, 0.95, 0.35, 1.0)
		else:
			title_label.text = tr("DEFEAT") if tr("DEFEAT") != "DEFEAT" else "ПОРАЖЕНИЕ"
			title_label.modulate = Color(1.0, 0.35, 0.35, 1.0)
			
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)


func _on_try_again_pressed() -> void:
	get_tree().paused = false
	fade_overlay.visible = true
	fade_overlay.modulate.a = 0.0
	
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_IN)
	await tween.finished
	
	get_tree().change_scene_to_file("res://lvl1/scenes/mission_prep.tscn")


func _on_menu_pressed() -> void:
	get_tree().paused = false
	fade_overlay.visible = true
	fade_overlay.modulate.a = 0.0
	
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_IN)
	await tween.finished
	
	get_tree().change_scene_to_file("res://main/main.tscn")
