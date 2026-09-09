extends Node

const SAVE_PATH = "user://settings.cfg"

var current_language: String = "en"

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err == OK:
		current_language = config.get_value("general", "language", _get_default_locale())
	else:
		current_language = _get_default_locale()
	apply_settings()

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "language", current_language)
	var err := config.save(SAVE_PATH)
	if err != OK:
		push_error("Failed to save settings to " + SAVE_PATH)

func apply_settings() -> void:
	TranslationServer.set_locale(current_language)

func _get_default_locale() -> String:
	var sys_lang := OS.get_locale_language()
	if sys_lang == "ru" or sys_lang == "uk":
		return sys_lang
	return "en"
