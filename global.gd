extends Node

var score: int = 0
var player_name: String = "Player"

var _snd_buffer: Array[String] = []
var _snd_timer: float = 0.0

func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

func _process(delta: float) -> void:
	if _snd_timer > 0.0:
		_snd_timer -= delta
		if _snd_timer <= 0.0:
			_snd_buffer.clear()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			toggle_fullscreen()
		_check_sandbox_shortcut(event)

func _check_sandbox_shortcut(event: InputEventKey) -> void:
	# 1. Проверка одновременного зажатия S + N + D (с поддержкой любой раскладки клавиатуры)
	var s_held = Input.is_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_S)
	var n_held = Input.is_key_pressed(KEY_N) or Input.is_physical_key_pressed(KEY_N)
	var d_held = Input.is_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_D)

	if s_held and n_held and d_held:
		open_sandbox()
		return

	# 2. Проверка последовательного ввода S -> N -> D (за короткий промежуток времени)
	var key_char = ""
	if event.keycode == KEY_S or event.physical_keycode == KEY_S:
		key_char = "S"
	elif event.keycode == KEY_N or event.physical_keycode == KEY_N:
		key_char = "N"
	elif event.keycode == KEY_D or event.physical_keycode == KEY_D:
		key_char = "D"

	if key_char != "":
		_snd_buffer.append(key_char)
		_snd_timer = 1.8
		if _snd_buffer.size() > 3:
			_snd_buffer.pop_front()
		if _snd_buffer == ["S", "N", "D"]:
			_snd_buffer.clear()
			open_sandbox()

func open_sandbox() -> void:
	if get_tree().current_scene and get_tree().current_scene.scene_file_path == "res://sandbox/sandbox.tscn":
		return
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://sandbox/sandbox.tscn")

func toggle_fullscreen() -> void:
	var current_mode = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

