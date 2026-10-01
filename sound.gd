extends AudioStreamPlayer2D

var sounds: bool = true
var sound_path: String = "user://Sound.save"
@onready var sound: AudioStreamPlayer2D = $"."
var music = AudioServer.get_bus_index("Music")


func _ready() -> void:
	_load_sound()
	
	if sounds:
		sound.play()
	else:
		sound.stop()


func _save_sound() -> void:
	var config = ConfigFile.new()
	config.set_value("Main", "Setting", sounds)
	config.save(sound_path)


func _load_sound() -> void:
	var config = ConfigFile.new()
	# Проверяем, существует ли файл, перед загрузкой
	var err = config.load(sound_path)
	if err == OK:
		sounds = config.get_value("Main", "Setting", true)


# Вызывай эту функцию, когда игрок переключает звук в настройках
	
	
func _process(delta: float) -> void:
	_load_sound()
	if sounds:
		if not sound.playing:
			sound.play()
			
	else:
		sound.stop()
		
		
