extends Label


@export var speed: float = 30.0

var tween: Tween

func print_text(new_text: String) -> void:
	text = new_text
	
	# Скрываем весь текст
	visible_characters = 0
	
	# Вычисляем время анимации исходя из длины строки
	var duration: float = text.length() / speed
	
	# Отменяем предыдущую анимацию, если она шла
	if tween and tween.is_running():
		tween.kill()
		
	# Запускаем постепенный показ символов
	tween = create_tween()
	tween.tween_property(self, "visible_characters", text.length(), duration)
	

func _ready() -> void:
	# Пример вызова для проверки
	print_text("STRELA-10:")
