extends Control

@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var deploy_btn: Button = $Panel/DeployButton
@onready var settings_btn: Button = $Panel/SettingsButton
@onready var abort_btn: Button = $Panel/AbortButton
@onready var help_btn: Button = $Panel/HelpButton
@onready var Endless_bth: Button = $Panel/Endless_modeButton
var data_path = "user://Saves.save"
var setting_path = "user://Settings.save"
var sound_path = "user://Sound.save"
@onready var TelegramLink_bth: LinkButton = $Telegram/TelegramLink
var telegramlink_pressed: bool = false
#@onready var title_bth: TouchScreenButton = $Title/TouchScreenButton


#Достижения
var Ach1 = Ach.Ach1
var Ach2 = Ach.Ach2
var pressed_title: int = 0
@onready var Ach1_true: CheckBox = $AchOverlay/AchPanel/ACH1True
@onready var Ach2_true: CheckBox = $AchOverlay/AchPanel/ACH2True
#@onready var Ach_Label: Label = $AchOverlay/AchPanel/ACH1Label
var music = S_script.music
@onready var Hslider2 = $SettingsOverlay/Panel/SoundVolume/HSlider


@onready var settings_overlay: ColorRect = $SettingsOverlay
@onready var settings_close_btn: Button = $SettingsOverlay/Panel/CloseButton
@onready var language_options: OptionButton = $SettingsOverlay/Panel/LanguageOptions
@onready var sound_mouse: AudioStreamPlayer2D = $SoundsMouse
@onready var AchPanel: Panel = $AchOverlay/AchPanel
@onready var Ach_Button: Button = $AchButton
@onready var Ach_close_button: Button = $AchOverlay/AchPanel/AchCloseButton
var sounds: bool = S_script.sounds
var VSYNC: int = 0
var bth_on = 0

@onready var ach_overlay: ColorRect = $AchOverlay

var _base_x: Dictionary = {}

func _ready() -> void:
	_load_sound()
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
	if sounds == false:
		$SettingsOverlay/Panel/SoundOn/CheckSounds.set_pressed_no_signal(false)
	else:
		$SettingsOverlay/Panel/SoundOn/CheckSounds.set_pressed_no_signal(true)
		
	if Ach1 == 0:
		Ach1_true.set_pressed_no_signal(false)
	else:
		Ach1_true.set_pressed_no_signal(true)
	if Ach2 == 0:
		Ach2_true.set_pressed_no_signal(false)
	else:
		Ach2_true.set_pressed_no_signal(true)
	if pressed_title >= 1:
		Ach2 = 1

	# Wire up hover animations
	for btn: Button in [deploy_btn, settings_btn, help_btn, abort_btn, Endless_bth]:
		#_base_x[btn] = btn.position.x
		btn.mouse_entered.connect(_on_btn_entered.bind(btn))
		#btn.mouse_exited.connect(_on_btn_exited.bind(btn))

	# Wire up new button signals
	settings_close_btn.pressed.connect(_on_settings_close_pressed)
	language_options.item_selected.connect(_on_language_selected)
	Ach_close_button.pressed.connect(_on_ach_close_pressed)
	#TelegramLink_bth.pressed.connect(_ach2)

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
	#var tween := create_tween()
	#tween.tween_property(btn, "position:x", _base_x[btn] + 20.0, 0.15).set_ease(Tween.EASE_OUT)
	sound_mouse.play()

#func _on_btn_exited(btn: Button) -> void:
	#var tween := create_tween()
	#tween.tween_property(btn, "position:x", _base_x[btn], 0.15).set_ease(Tween.EASE_OUT)

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
	Ach1 = 1
	_save()

func _save():
	var config = ConfigFile.new()
	config.set_value("Main","Ach1", Ach1)
	config.set_value("Main","Ach2", Ach2)
	config.save(data_path)
	
func _load():
	var config = ConfigFile.new()
	config.load(data_path)
	Ach1 = config.get_value("Main", "Ach1", Ach1)
	Ach2 = config.get_value("Main", "Ach2", Ach2)
	
func _save_Settings():
	var config = ConfigFile.new()
	config.set_value("Main","Setting", VSYNC)
	config.save(setting_path)

func _load_Settings():
	var config = ConfigFile.new()
	config.load(setting_path)
	VSYNC = config.get_value("Main", "Setting", VSYNC)
	
func _save_sound():
	var config = ConfigFile.new()
	config.set_value("Main", "Setting", sounds)
	config.set_value("Main", "Volume", Hslider2.value)
	config.save(sound_path)

func _load_sound():
	var config = ConfigFile.new()
	config.load(sound_path)
	sounds = config.get_value("Main", "Setting", sounds)
	Hslider2.value = config.get_value("Main", "Volume", Hslider2.value)


func _on_ach_button_pressed() -> void:
	ach_overlay.visible = true
	ach_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(ach_overlay, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	sound_mouse.play()
		
func _process(delta: float) -> void:
	_load()
	_update_ach()
	var fps = Engine.get_frames_per_second()
	$FPS.text = "FPS: %d" % fps
	if telegramlink_pressed == true:
		Ach2 = 1
		_save()
	

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


func _on_check_sounds_toggled(toggled_on: bool) -> void:
	if toggled_on:
		sounds = true
		_save_sound()
	else:
		sounds = false
		_save_sound()


func _on_ach_close_pressed() -> void:
	sound_mouse.play()
	var tween := create_tween()
	tween.tween_property(ach_overlay, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	await tween.finished
	ach_overlay.visible = false
#func _ach2():
	#telegramlink_pressed += 1


func _on_telegram_link_pressed() -> void:
	telegramlink_pressed = true

func _update_ach():
	if Ach2 == 0:
		Ach2_true.set_pressed_no_signal(false)
	else:
		Ach2_true.set_pressed_no_signal(true)

func _on_update_button_pressed() -> void:
	_load()
	_update_ach()


func _on_h_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(music, linear_to_db(value))
	_save_sound()
