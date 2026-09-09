extends Control

@onready var fade_overlay: ColorRect = $FadeOverlay

var _base_x: Dictionary = {}

@onready var help1_button: Button = $HELP1
@onready var back_button: Button = get_node_or_null("BACK")
@onready var sound_mouse: AudioStreamPlayer2D = $ClicksSound

func _ready() -> void:
	fade_overlay.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_OUT)
	
	var buttons = [help1_button]
	if is_instance_valid(back_button):
		buttons.append(back_button)
		back_button.text = tr("Back")
		
	for btn: Button in buttons:
		_base_x[btn] = btn.position.x
		btn.mouse_entered.connect(_on_btn_entered.bind(btn))
		btn.mouse_exited.connect(_on_btn_exited.bind(btn))

func _on_btn_entered(btn: Button) -> void:
	var tween := create_tween()
	tween.tween_property(btn, "position:x", _base_x[btn] + 20.0, 0.15).set_ease(Tween.EASE_OUT)
	sound_mouse.play()

func _on_btn_exited(btn: Button) -> void:
	var tween := create_tween()
	tween.tween_property(btn, "position:x", _base_x[btn], 0.15).set_ease(Tween.EASE_OUT)

func _on_help_1_pressed() -> void:
	fade_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.45).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file("res://helps/briefly.tscn")

func _on_back_pressed() -> void:
	sound_mouse.play()
	fade_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file("res://main/main.tscn")
