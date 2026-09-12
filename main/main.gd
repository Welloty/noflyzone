extends Control

@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var deploy_btn: Button = $DeployButton
@onready var settings_btn: Button = $SettingsButton
@onready var abort_btn: Button = $AbortButton
@onready var help_btn: Button = $HelpButton
@onready var Endless_bth: Button = $Endless_modeButton
var data_path = "user://Saves.save"
var setting_path = "user://Settings.save"


#Достижения
var Ach1 = Ach.Ach1
@onready var Ach1_true: CheckBox = $AchPanel/ACH1Label/ACH1True
@onready var Ach_Label: Label = $AchPanel/ACH1Label


@onready var settings_overlay: ColorRect = $SettingsOverlay
@onready var settings_close_btn: Button = $SettingsOverlay/Panel/CloseButton
@onready var language_options: OptionButton = $SettingsOverlay/Panel/LanguageOptions
@onready var sound_mouse: AudioStreamPlayer2D = $SoundsMouse
@onready var AchPanel: Panel = $AchPanel
@onready var Ach_Button: Button = $AchButton
var VSYNC: int = 0
var bth_on = 0

var _base_x: Dictionary = {}

func _ready() -> void:
	_load()
	_load_Settings()
	fade_overlay.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_OUT)
	if VSYNC == 0:
		$SettingsOverlay/Panel/CheckBox.set_pressed_no_signal(false)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	else:
		$SettingsOverlay/Panel/CheckBox.set_pressed_no_signal(true)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		
	if Ach1 == 0:
		Ach1_true.set_pressed_no_signal(false)
	else:
		Ach1_true.set_pressed_no_signal(true)

	# Wire up hover animations
	for btn: Button in [deploy_btn, settings_btn, help_btn, abort_btn, Endless_bth]:
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
	language_options.add_item("Українська")
	
	# Pre-select current language from settings
	_update_language_dropdown()

func _update_language_dropdown() -> void:
	if SettingsManager.current_language == "ru":
		language_options.selected = 1
	elif SettingsManager.current_language == "uk":
		language_options.selected = 2
	else:
		language_options.selected = 0

func _on_btn_entered(btn: Button) -> void:
	var tween := create_tween()
	tween.tween_property(btn, "position:x", _base_x[btn] + 20.0, 0.15).set_ease(Tween.EASE_OUT)
	sound_mouse.play()

func _on_btn_exited(btn: Button) -> void:
	var tween := create_tween()
	tween.tween_property(btn, "position:x", _base_x[btn], 0.15).set_ease(Tween.EASE_OUT)

func _on_deploy_pressed() -> void:
	#lvl 1
	_fade_and_go("res://lvl1/scenes/mission_prep.tscn")
	sound_mouse.play()

func _on_settings_pressed() -> void:
	_update_language_dropdown()
	settings_overlay.visible = true
	settings_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(settings_overlay, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	sound_mouse.play()

func _on_settings_close_pressed() -> void:
	sound_mouse.play()
	var tween := create_tween()
	tween.tween_property(settings_overlay, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	await tween.finished
	settings_overlay.visible = false
	
func _on_language_selected(index: int) -> void:
	if index == 1:
		SettingsManager.current_language = "ru"
	elif index == 2:
		SettingsManager.current_language = "uk"
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
	sound_mouse.play()

func _fade_and_go(scene_path: String) -> void:
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)


func _on_language_options_pressed() -> void:
	sound_mouse.play()


func _on_help_button_pressed() -> void:
	#_fade_and_go("res://main/help_pred.tscn")
	pass


func _on_endless_mode_button_pressed() -> void:
	_fade_and_go("res://lvl1/scenes/Endless_pred.tscn")
	sound_mouse.play()
	#Ach1 = 1
	_save()

func _save():
	var config = ConfigFile.new()
	config.set_value("Main","Ach1", Ach1)
	config.save(data_path)
	
func _load():
	var config = ConfigFile.new()
	config.load(data_path)
	Ach1 = config.get_value("Main", "Ach1", Ach1)

func _save_Settings():
	var config = ConfigFile.new()
	config.set_value("Main","Setting", VSYNC)
	config.save(setting_path)

func _load_Settings():
	var config = ConfigFile.new()
	config.load(setting_path)
	VSYNC = config.get_value("Main", "Setting", VSYNC)

func _on_ach_button_pressed() -> void:
	if bth_on == 0:
		#AchPanel.visible = true
		#$AchButton.position = Vector2(616, 335.19)
		bth_on = 1
		slide_out()
	else:
		#AchPanel.visible = false
		$AchButton.position = Vector2(616, 488)
		bth_on = 0
		slide_exit()
		
func  _process(delta: float) -> void:
	var fps = Engine.get_frames_per_second()
	$FPS.text = "FPS: %d" % fps

func slide_out():
	var tween = create_tween()
	tween.parallel().tween_property(AchPanel, "position", Vector2(616, 544), 0.3)
	tween.parallel().tween_property(Ach_Button, "position", Vector2(616, 488), 0.3)

func slide_exit():
	var tween = create_tween()
	tween.parallel().tween_property(AchPanel, "position", Vector2(616, 392), 0.3)
	tween.parallel().tween_property(Ach_Button, "position", Vector2(616, 335.19), 0.3)

func _on_check_box_toggled(toggled_on: bool) -> void:
	if toggled_on:
		# Галочка ПОСТАВЛЕНА -> Включаем VSync
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		VSYNC += 1
		_save_Settings()
	else:
		# Галочка СНЯТА -> Выключаем VSync
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		VSYNC -= 1
		_save_Settings()
