extends "res://lvl1/scripts/level_1.gd"

## Sandbox Controller Script
## Управляет окружением песочницы и координирует инструменты разработчика

@onready var dev_tools: CanvasLayer = get_node_or_null("UI/DevTools")

func _ready() -> void:
	super._ready()
	add_to_group("sandbox")
	
	# По умолчанию в песочнице останавливаем автоматический таймер волн,
	# чтобы разработчик мог спокойно тестировать спавн вручную.
	# Авто-волны можно включить кнопкой "Авто-волны: ВКЛ" в DevTools.
	if wave_manager:
		wave_manager.set_process(false)
		
	# Первоначальный баланс для удобства тестирования
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and "money" in hud:
		hud.money = 500
