extends Label

@onready var PrintSound: AudioStreamPlayer2D = $"../KeyboardSounds"


# Скорость печати (символов в секунду)
@export var speed: float = 30.0


var tween1: Tween

func print_text(new_text: String) -> void:
	text = new_text
	

	visible_characters = 0
	
	var duration: float = text.length() / speed
	
	if tween1 and tween1.is_running():
		tween1.kill()
		

	tween1 = create_tween()
	tween1.tween_property(self, "visible_characters", text.length(), duration)
	PrintSound.play()
	
	await tween1.finished
	PrintSound.stop()

func _ready() -> void:
	
	print_text("No fly zone - это одиночная инди игра,
 которая позволяет нам уничтожать дроны, fpv-камикадзе и ракеты.
Главная задача в игре - уничтожить все цели, и не дать врагу уничтожить завод.")


func _on_timer_timeout() -> void:
	pass # Replace with function body.
