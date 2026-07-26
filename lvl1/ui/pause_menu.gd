extends CanvasLayer

@onready var overlay: ColorRect = $Overlay
@onready var resume_btn: Button = $Overlay/Panel/VBox/ResumeButton
@onready var menu_btn: Button = $Overlay/Panel/VBox/MenuButton
@onready var fade_overlay: ColorRect = $FadeOverlay

func _ready() -> void:
	visible = false
	resume_btn.pressed.connect(_on_resume_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			_on_resume_pressed()
		else:
			open()

func open() -> void:
	get_tree().paused = true
	visible = true
	overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)

func _on_resume_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
	await tween.finished
	visible = false
	get_tree().paused = false

func _on_menu_pressed() -> void:
	get_tree().paused = false
	fade_overlay.visible = true
	fade_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file("res://main/main.tscn")
