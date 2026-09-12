extends Node

const MOBILE_WIDTH = 800
const MOBILE_HEIGHT = 600

func _ready() -> void:
	if _is_mobile_device():
		_setup_mobile_viewport()

func _is_mobile_device() -> bool:
	return OS.has_feature("mobile") # Более надежный способ проверки, чем OS.get_name()

func _setup_mobile_viewport() -> void:
	var root = get_tree().root
	
	# Устанавливаем базовое целевое разрешение
	root.content_scale_size = Vector2i(MOBILE_WIDTH, MOBILE_HEIGHT)
	
	# Включаем адаптивное масштабирование
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
