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

func open() -> void:
	get_tree().paused = true
	visible = true
	overlay.modulate.a = 0.0
	
	var tween := create_tween()
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
