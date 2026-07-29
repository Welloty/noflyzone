extends Control

@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var title_label: Label = $Title
@onready var subtitle_label: Label = $Subtitle
@onready var tip_label: Label = $TipLabel

var tips: Array[String] = [
	"Join our Discord.",
	"You can modify the game using the code on GitHub.",
	"We have our own Telegram channel.",
	"Enjoy the game!",
	"Please write reviews for the game; it helps us.",
	"Improve your air defense.",
]

func _ready() -> void:
	fade_overlay.visible = true
	fade_overlay.modulate.a = 1.0
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	tip_label.modulate.a = 0.0
	tip_label.text = tr("TIP_PREFIX") + tr(tips[randi() % tips.size()])

	var tween := create_tween().set_parallel(true)
	tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(title_label, "modulate:a", 1.0, 1.0).set_delay(0.4)
	tween.tween_property(subtitle_label, "modulate:a", 1.0, 1.0).set_delay(0.65)
	tween.tween_property(tip_label, "modulate:a", 1.0, 1.0).set_delay(1.1)

	var timer := Timer.new()
	timer.wait_time = 2.5
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(_cycle_tip)

func _cycle_tip() -> void:
	var tween := create_tween()
	tween.tween_property(tip_label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): tip_label.text = tr("TIP_PREFIX") + tr(tips[randi() % tips.size()]))
	tween.tween_property(tip_label, "modulate:a", 1.0, 0.4)
