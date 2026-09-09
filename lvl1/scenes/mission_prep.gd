extends Control

@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var title_label: Label = $Title
@onready var subtitle_label: Label = $Subtitle
@onready var tagline_label: Label = $Tagline
@onready var tip_label: Label = $TipLabel
@onready var status_label: Label = $StatusLabel
@onready var progress_bar: ProgressBar = $ProgressBar

var tips: Array[String] = [
	"Join our Discord.",
	"You can modify the game using the code on GitHub.",
	"We have our own Telegram channel.",
	"Enjoy the game!",
	"Please write reviews for the game; it helps us.",
	"Improve your air defense.",
]

var done: bool = false
var prep_progress: float = 0.0

func _ready() -> void:
	fade_overlay.visible = true
	fade_overlay.modulate.a = 1.0
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	tagline_label.modulate.a = 0.0
	tip_label.modulate.a = 0.0
	status_label.modulate.a = 0.0
	
	tip_label.text = tr("TIP_PREFIX") + tr(tips[randi() % tips.size()])
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(title_label, "modulate:a", 1.0, 0.4).set_delay(0.15)
	tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.4).set_delay(0.25)
	tween.tween_property(tagline_label, "modulate:a", 1.0, 0.4).set_delay(0.35)
	tween.tween_property(status_label, "modulate:a", 1.0, 0.4).set_delay(0.35)
	tween.tween_property(tip_label, "modulate:a", 1.0, 0.4).set_delay(0.45)

func _process(delta: float) -> void:
	if done:
		return
		
	prep_progress += 75.0 * delta
	progress_bar.value = min(prep_progress, 100.0)
	
	var is_ru := SettingsManager.current_language == "ru"
	if prep_progress < 35.0:
		status_label.text = "Сканирование местности сектора..." if is_ru else "Scanning sector terrain..."
	elif prep_progress < 70.0:
		status_label.text = "Расчёт тактических маршрутов..." if is_ru else "Plotting tactical flight paths..."
	elif prep_progress < 100.0:
		status_label.text = "Развёртывание сил ПВО..." if is_ru else "Deploying air defense forces..."
	else:
		status_label.text = "Миссия готова!" if is_ru else "Mission ready!"

	if prep_progress >= 100.0:
		done = true
		_finish_prep()

func _finish_prep() -> void:
	fade_overlay.visible = true
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file("res://lvl1/scenes/level_1.tscn")
