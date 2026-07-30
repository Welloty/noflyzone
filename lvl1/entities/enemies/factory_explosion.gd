extends Node2D

@export var lifetime: float = 2.0
@export var camera_shake_amount: float = 14.0
@export var camera_shake_duration: float = 0.4

var time_passed: float = 0.0
var shockwave_radius: float = 0.0
var shockwave_alpha: float = 1.0

func _ready() -> void:
	var burst = get_node_or_null("ExplosionBurst") as CPUParticles2D
	if burst:
		burst.restart()
		burst.emitting = true
		
	var smoke = get_node_or_null("SmokePlume") as CPUParticles2D
	if smoke:
		smoke.restart()
		smoke.emitting = true
		
	var sparks = get_node_or_null("Sparks") as CPUParticles2D
	if sparks:
		sparks.restart()
		sparks.emitting = true

	_trigger_camera_shake()

func _trigger_camera_shake() -> void:
	var camera = get_viewport().get_camera_2d()
	if not is_instance_valid(camera):
		camera = get_tree().get_first_node_in_group("camera") as Camera2D
	if not is_instance_valid(camera):
		return

	if camera.has_method("shake"):
		camera.shake(camera_shake_amount, camera_shake_duration)
	elif camera.has_method("apply_shake"):
		camera.apply_shake(camera_shake_amount, camera_shake_duration)
	else:
		_shake_camera_fallback(camera)

func _shake_camera_fallback(camera: Camera2D) -> void:
	var original_offset = camera.offset
	var tween = create_tween()
	var shake_steps = 8
	for i in range(shake_steps):
		var offset = Vector2(
			randf_range(-camera_shake_amount, camera_shake_amount),
			randf_range(-camera_shake_amount, camera_shake_amount)
		)
		tween.tween_property(camera, "offset", offset, camera_shake_duration / shake_steps)
	tween.tween_property(camera, "offset", original_offset, 0.05)

func _process(delta: float) -> void:
	time_passed += delta
	if time_passed <= 0.45:
		shockwave_radius = lerp(12.0, 160.0, time_passed / 0.45)
		shockwave_alpha = 1.0 - (time_passed / 0.45)
		queue_redraw()
	elif shockwave_alpha > 0.0:
		shockwave_alpha = 0.0
		queue_redraw()

	if time_passed >= lifetime:
		queue_free()

func _draw() -> void:
	if shockwave_alpha > 0.01:
		var col_inner = Color(1.0, 0.8, 0.3, shockwave_alpha * 0.9)
		var col_outer = Color(1.0, 0.3, 0.05, shockwave_alpha * 0.6)
		draw_arc(Vector2.ZERO, shockwave_radius, 0.0, TAU, 36, col_inner, 5.0 * shockwave_alpha)
		draw_arc(Vector2.ZERO, shockwave_radius * 1.08, 0.0, TAU, 36, col_outer, 2.5 * shockwave_alpha)
		
		if time_passed < 0.18:
			var flash_alpha = (0.18 - time_passed) / 0.18
			draw_circle(Vector2.ZERO, 45.0 * (1.0 + time_passed * 3.5), Color(1.0, 0.95, 0.7, flash_alpha * 0.75))
