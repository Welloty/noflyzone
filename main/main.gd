extends Control

@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var deploy_btn: Button = $DeployButton
@onready var settings_btn: Button = $SettingsButton
@onready var abort_btn: Button = $AbortButton

@onready var settings_overlay: ColorRect = $SettingsOverlay
@onready var settings_close_btn: Button = $SettingsOverlay/Panel/CloseButton
@onready var language_options: OptionButton = $SettingsOverlay/Panel/LanguageOptions

var _base_x: Dictionary = {}

func _ready() -> void:
	fade_overlay.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_OUT)

	# Wire up hover animations
	for btn: Button in [deploy_btn, settings_btn, abort_btn]:
		_base_x[btn] = btn.position.x
		btn.mouse_entered.connect(_on_btn_entered.bind(btn))
		btn.mouse_exited.connect(_on_btn_exited.bind(btn))

	# Wire up new button signals
	settings_close_btn.pressed.connect(_on_settings_close_pressed)
	language_options.item_selected.connect(_on_language_selected)

	# Setup language dropdown options
	language_options.clear()
	language_options.add_item("English")
	language_options.add_item("Русский")
	
	# Pre-select current language from settings
	_update_language_dropdown()

func _update_language_dropdown() -> void:
	if SettingsManager.current_language == "ru":
		language_options.selected = 1
	else:
		language_options.selected = 0

func _on_btn_entered(btn: Button) -> void:
	var tween := create_tween()
	tween.tween_property(btn, "position:x", _base_x[btn] + 18.0, 0.15).set_ease(Tween.EASE_OUT)

func _on_btn_exited(btn: Button) -> void:
	var tween := create_tween()
	tween.tween_property(btn, "position:x", _base_x[btn], 0.15).set_ease(Tween.EASE_OUT)

func _on_deploy_pressed() -> void:
	#lvl 1
	_fade_and_go("res://lvl1/scenes/level_1.tscn")

func _on_settings_pressed() -> void:
	_update_language_dropdown()
	settings_overlay.visible = true
	settings_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(settings_overlay, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)

func _on_settings_close_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(settings_overlay, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	await tween.finished
	settings_overlay.visible = false

func _on_language_selected(index: int) -> void:
	if index == 1:
		SettingsManager.current_language = "ru"
	else:
		SettingsManager.current_language = "en"
	SettingsManager.apply_settings()
	SettingsManager.save_settings()

func _on_abort_pressed() -> void:
	fade_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.45).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().quit()

func _fade_and_go(scene_path: String) -> void:
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)
