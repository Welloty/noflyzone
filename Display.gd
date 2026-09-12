extends Node

func _ready() -> void:
	# Получаем имя текущей операционной системы
	var os_name := OS.get_name()
	
	# Проверяем, запустилась ли игра на мобильном устройстве
	if os_name == "Android" or os_name == "iOS":
		_apply_mobile_scale()
	else:
		# Для ПК (Windows, macOS, Linux) ничего не меняем или оставляем базовый масштаб
		pass

func _apply_mobile_scale() -> void:
	# Вариант 1: Изменить масштаб отдельного интерфейса (CanvasLayer / Control)
	# Предположим, у вас есть узлы интерфейса под Control
	# $UI.scale = Vector2(1.2, 1.2)
	
	# Вариант 2: Изменить растяжение всего окна/экрана приложения через DisplayServer
	# Например, если нужно изменить режим растяжения или масштаб окна
	get_tree().root.content_scale_factor = 1.1 # Увеличивает весь UI в 1.25 раза
