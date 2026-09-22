extends ProgressBar

var done: bool = false

func _ready() -> void:
	max_value = 100
	value = 0

func _process(delta: float) -> void:
	if done:
		return
	value += 50 * delta
	if value >= max_value:
		done = true
		_finish_loading()

func _finish_loading() -> void:
	var fade_overlay := get_parent().find_child("FadeOverlay") as ColorRect
	if fade_overlay:
		fade_overlay.visible = true
		var tween := create_tween()
		tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_IN)
		await tween.finished
	get_tree().change_scene_to_file("res://main/main.tscn")
