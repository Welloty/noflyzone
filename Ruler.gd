extends Node2D

@export_group("Scale Settings")
@export var cm_per_pixel: float = 1.18

@export_group("Visuals")
@export var line_color: Color = Color.YELLOW
@export var line_width: float = 3.0
@export var font_size: int = 18

var start_point: Vector2
var current_point: Vector2
var is_measuring: bool = false

func _unhandled_input(event: InputEvent) -> void:
	# Вызов по нажатию ПКМ (смена на МКМ/ЛКМ при необходимости)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				start_point = get_global_mouse_position()
				current_point = start_point
				is_measuring = true
				queue_redraw()
			else:
				is_measuring = false
				queue_redraw()

	elif event is InputEventMouseMotion and is_measuring:
		current_point = get_global_mouse_position()
		queue_redraw()

func _draw() -> void:
	if not is_measuring:
		return

	# Линия измерения
	draw_line(to_local(start_point), to_local(current_point), line_color, line_width)

	# Засечки на концах
	var dir = (current_point - start_point).normalized()
	var perp = Vector2(-dir.y, dir.x) * 10.0
	draw_line(to_local(start_point) - perp, to_local(start_point) + perp, line_color, line_width)
	draw_line(to_local(current_point) - perp, to_local(current_point) + perp, line_color, line_width)

	# Расчёты
	var distance_px: float = start_point.distance_to(current_point)
	var distance_cm: float = distance_px * cm_per_pixel
	var distance_m: float = distance_cm / 100.0

	# Формирование текста
	var text: String = "%.1f px\n%.2f cm (%.2f m)" % [distance_px, distance_cm, distance_m]

	# Отображение текста рядом с курсором
	var text_offset = Vector2(15, -15)
	var font = ThemeDB.fallback_font
	draw_multiline_string(
		font,
		to_local(current_point) + text_offset,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
	)
