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
	
	print_text("Зенитно-ракетный комплекс 9К35 «Стрела-10» 
— это советский боевой комплекс ближнего действия, 
созданный для защиты сухопутных войск на поле боя.
 По классификации НАТО он известен как SA-13 Gopher («Суслик»)")


func _on_timer_timeout() -> void:
	pass # Replace with function body.
