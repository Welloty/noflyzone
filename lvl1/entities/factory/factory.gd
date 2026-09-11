extends Sprite2D

signal factory_destroyed
signal health_changed(current: float, maximum: float)
signal upgraded(upgrade_name: String)

# ==============================================================================
# НАСТРОЙКИ ЗАВОДА И УЛУЧШЕНИЙ
# ==============================================================================
@export_group("Параметры здоровья (Health)")
@export var max_health: float = 1000.0
@export var current_health: float = 1000.0

@export_group("Улучшение: Антидроновые сетки")
@export var net_cost: int = 80
@export var fpv_protection_ratio: float = 0.75 # 75% защита от урона FPV

# ==============================================================================
# ВНУТРЕННЕЕ СОСТОЯНИЕ
# ==============================================================================
var has_anti_drone_nets: bool = false
var is_selected: bool = false
var is_hovered: bool = false
var net_pulse_time: float = 0.0
var last_toggle_time: float = -1.0

# UI
var click_area: Area2D = null
var ui_layer: CanvasLayer = null
var upgrade_panel: PanelContainer = null
var hp_bar: ProgressBar = null
var hp_label: Label = null
var net_btn: Button = null

func _ready() -> void:
	add_to_group("factory")
	current_health = max_health
	_setup_click_area()

func _setup_click_area() -> void:
	click_area = get_node_or_null("ClickArea") as Area2D
	if not click_area:
		click_area = Area2D.new()
		click_area.name = "ClickArea"
		var col = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		# Текстура завода 1280x1280, задаем подходящую зону клика
		rect.size = Vector2(1150, 1150)
		col.shape = rect
		click_area.add_child(col)
		add_child(click_area)

	if not click_area.mouse_entered.is_connected(_on_mouse_entered):
		click_area.mouse_entered.connect(_on_mouse_entered)
	if not click_area.mouse_exited.is_connected(_on_mouse_exited):
		click_area.mouse_exited.connect(_on_mouse_exited)
	if not click_area.input_event.is_connected(_on_click_area_input_event):
		click_area.input_event.connect(_on_click_area_input_event)

func _process(delta: float) -> void:
	if has_anti_drone_nets:
		net_pulse_time += delta
		queue_redraw()

	if is_selected and is_instance_valid(upgrade_panel):
		_update_panel_position()
		_update_upgrade_ui()

# ==============================================================================
# ОБРАБОТКА НАЖАТИЙ / КЛИКОВ (CLICK & TOUCH HANDLING)
# ==============================================================================

## Вызывается из TouchScreenButton (при наличии в сцене level_1.tscn)
func _on_touch_screen_button_pressed() -> void:
	var mgr = get_tree().get_first_node_in_group("placement_manager")
	if mgr and "ghost_instance" in mgr and is_instance_valid(mgr.ghost_instance):
		return

	toggle_upgrade_ui()
	if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"):
		Input.vibrate_handheld(30)

## Вызывается из Area2D при клике мышью или тапе
func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var is_click = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_click = true
	elif event is InputEventScreenTouch and event.pressed:
		is_click = true

	if is_click:
		var mgr = get_tree().get_first_node_in_group("placement_manager")
		if mgr and "ghost_instance" in mgr and is_instance_valid(mgr.ghost_instance):
			return

		toggle_upgrade_ui()
		if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"):
			Input.vibrate_handheld(30)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	# 1. Если меню открыто
	if is_selected:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_ESCAPE:
				close_upgrade_ui()
				get_viewport().set_input_as_handled()
				return

		var click_screen_pos = Vector2.ZERO
		var is_press = false

		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			click_screen_pos = event.position
			is_press = true
		elif event is InputEventScreenTouch and event.pressed:
			click_screen_pos = event.position
			is_press = true

		if is_press:
			# Если клик внутри панели меню — не закрываем
			if is_instance_valid(upgrade_panel):
				var panel_rect = upgrade_panel.get_global_rect()
				if panel_rect.has_point(click_screen_pos):
					return

			# Если клик по самому заводу — оставляем открытым или переключаем
			var click_global = _screen_to_global(click_screen_pos)
			if _is_point_inside_factory(click_global):
				return

			# Клик снаружи — закрываем меню
			close_upgrade_ui()
		return

	# 2. Если меню закрыто, проверяем клик по заводу через мир
	var mouse_or_touch_pos = Vector2.ZERO
	var is_start_click = false

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_or_touch_pos = event.position
		is_start_click = true
	elif event is InputEventScreenTouch and event.pressed:
		mouse_or_touch_pos = event.position
		is_start_click = true

	if is_start_click:
		var mgr = get_tree().get_first_node_in_group("placement_manager")
		if mgr and "ghost_instance" in mgr and is_instance_valid(mgr.ghost_instance):
			return

		var global_click = _screen_to_global(mouse_or_touch_pos)
		if _is_point_inside_factory(global_click):
			open_upgrade_ui()
			if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"):
				Input.vibrate_handheld(30)
			get_viewport().set_input_as_handled()

func _screen_to_global(screen_pos: Vector2) -> Vector2:
	var canvas_xform = get_viewport().get_canvas_transform()
	return canvas_xform.affine_inverse() * screen_pos

func _is_point_inside_factory(global_pos: Vector2) -> bool:
	var local_pos = to_local(global_pos)
	var half_w = 590.0
	var half_h = 590.0
	if Rect2(-half_w, -half_h, half_w * 2.0, half_h * 2.0).has_point(local_pos):
		return true

	# Запасная проверка через Area2D
	if is_instance_valid(click_area):
		var space_state = get_world_2d().direct_space_state
		if space_state:
			var query = PhysicsPointQueryParameters2D.new()
			query.position = global_pos
			query.collide_with_areas = true
			var results = space_state.intersect_point(query)
			for res in results:
				if res.collider == click_area:
					return true
	return false

func _on_mouse_entered() -> void:
	is_hovered = true
	queue_redraw()

func _on_mouse_exited() -> void:
	is_hovered = false
	queue_redraw()

func toggle_upgrade_ui() -> void:
	var cur_time = Time.get_ticks_msec() / 1000.0
	if cur_time - last_toggle_time < 0.15:
		return
	last_toggle_time = cur_time

	if is_selected:
		close_upgrade_ui()
	else:
		open_upgrade_ui()

func open_upgrade_ui() -> void:
	# Снимаем выделение с установленных башен
	var mgr = get_tree().get_first_node_in_group("placement_manager")
	if mgr and mgr.has_method("deselect_tower"):
		mgr.deselect_tower()

	is_selected = true
	_create_upgrade_ui()
	_update_panel_position()
	queue_redraw()

func close_upgrade_ui() -> void:
	is_selected = false
	_destroy_upgrade_ui()
	queue_redraw()

# ==============================================================================
# ПОЛУЧЕНИЕ УРОНА (DAMAGE HANDLING & BUFF CALCULATION)
# ==============================================================================
func take_damage(amount: float, source: Variant = null) -> void:
	if current_health <= 0:
		return

	var is_fpv = false
	if source != null:
		var s_str = str(source).to_lower()
		if source is String and (s_str == "fpv" or s_str == "fpv_drones"):
			is_fpv = true
		elif source is Node and (source.is_in_group("fpv_drones") or source.is_in_group("fpv") or "fpv" in s_str):
			is_fpv = true

	# Применение бафа антидроновых сеток (-75% урона от FPV)
	if is_fpv and has_anti_drone_nets:
		var blocked_amount = amount * fpv_protection_ratio
		amount -= blocked_amount
		_spawn_floating_text("-%d HP [Сетка -75%%]" % roundi(amount), Color(0.4, 0.95, 0.35))
		_flash_net_effect()
	else:
		_spawn_floating_text("-%d HP" % roundi(amount), Color(1.0, 0.28, 0.28))

	current_health -= amount
	health_changed.emit(current_health, max_health)

	if is_instance_valid(upgrade_panel):
		_update_upgrade_ui()

	queue_redraw()

	if current_health <= 0:
		current_health = 0
		factory_destroyed.emit()
		close_upgrade_ui()

		var defeat_menu = get_tree().get_first_node_in_group("defeat_menu")
		if defeat_menu and defeat_menu.has_method("open"):
			defeat_menu.open()

# ==============================================================================
# ДЕЙСТВИЯ УЛУЧШЕНИЙ (UPGRADE ACTIONS)
# ==============================================================================
func buy_anti_drone_nets() -> void:
	if has_anti_drone_nets:
		return

	var hud = _get_hud()
	if not hud or not hud.has_method("deduct_money") or not hud.deduct_money(net_cost):
		return

	has_anti_drone_nets = true
	_spawn_floating_text("🛡️ Сетки установлены! (-75% урона FPV)", Color(0.4, 0.95, 0.35))
	upgraded.emit("anti_drone_nets")
	_update_upgrade_ui()
	queue_redraw()

	if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"):
		Input.vibrate_handheld(45)

func _get_hud() -> CanvasLayer:
	return get_tree().get_first_node_in_group("hud") as CanvasLayer

# ==============================================================================
# ВСПОМОГАТЕЛЬНЫЕ ЭФФЕКТЫ (VFX)
# ==============================================================================
func _spawn_floating_text(text: String, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.z_index = 50
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)

	get_tree().current_scene.add_child(label)
	label.global_position = global_position + Vector2(-60 + randf_range(-15, 15), -120 + randf_range(-10, 10))

	var tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 50.0, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)

func _flash_net_effect() -> void:
	var tween = create_tween()
	modulate = Color(1.3, 1.9, 1.4, 1.0)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.25).set_ease(Tween.EASE_OUT)

# ==============================================================================
# ОТРИСОВКА В МИРЕ (DRAWING IN WORLD SPACE)
# ==============================================================================
func _draw() -> void:
	var half_w = 580.0
	var half_h = 580.0
	var rect_bounds = Rect2(-half_w, -half_h, half_w * 2.0, half_h * 2.0)

	# 1. Выделение при клике на завод (тактический оливково-зеленый стиль)
	if is_selected:
		draw_rect(rect_bounds, Color(0.29, 0.486, 0.145, 0.12), true)
		draw_rect(rect_bounds, Color(0.35, 0.75, 0.2, 0.85), false, 4.0)
		# Угловые тактические скобки
		var bracket_len = 70.0
		var corners = [
			Vector2(-half_w, -half_h), Vector2(half_w, -half_h),
			Vector2(-half_w, half_h), Vector2(half_w, half_h)
		]
		for c in corners:
			var dx = 1.0 if c.x < 0 else -1.0
			var dy = 1.0 if c.y < 0 else -1.0
			draw_line(c, c + Vector2(dx * bracket_len, 0), Color(0.4, 0.95, 0.35, 0.95), 8.0)
			draw_line(c, c + Vector2(0, dy * bracket_len), Color(0.4, 0.95, 0.35, 0.95), 8.0)
	elif is_hovered:
		draw_rect(rect_bounds, Color(0.29, 0.486, 0.145, 0.08), true)
		draw_rect(rect_bounds, Color(0.35, 0.75, 0.2, 0.45), false, 3.0)

	# 2. Отрисовка установленной антидроновой сетки
	if has_anti_drone_nets:
		var net_bounds = Rect2(-540, -540, 1080, 1080)
		# Каркас сетки
		draw_rect(net_bounds, Color(0.12, 0.32, 0.15, 0.12), true)
		draw_rect(net_bounds, Color(0.32, 0.72, 0.35, 0.75), false, 4.0)

		# Сетка из струн / тросов
		var step = 120.0
		var wire_col = Color(0.55, 0.82, 0.6, 0.32)
		var x = -540.0 + step
		while x < 540.0:
			draw_line(Vector2(x, -540), Vector2(x, 540), wire_col, 2.0)
			x += step
		var y = -540.0 + step
		while y < 540.0:
			draw_line(Vector2(-540, y), Vector2(540, y), wire_col, 2.0)
			y += step

		# Диагональные тросы
		var diag_col = Color(0.35, 0.8, 0.4, 0.38)
		draw_line(Vector2(-540, -540), Vector2(540, 540), diag_col, 3.0)
		draw_line(Vector2(540, -540), Vector2(-540, 540), diag_col, 3.0)

		# Пульсирующие маячки на углах сетки
		var pulse = 0.65 + 0.35 * sin(net_pulse_time * 5.0)
		var beacon_corners = [
			Vector2(-540, -540), Vector2(540, -540),
			Vector2(-540, 540), Vector2(540, 540)
		]
		for bc in beacon_corners:
			draw_circle(bc, 16.0, Color(0.2, 0.8, 0.3, 0.35 * pulse))
			draw_circle(bc, 9.0, Color(0.4, 0.95, 0.35, 0.9 * pulse))

	# 3. Индикатор прочности (HP Bar) над заводом
	if current_health < max_health or is_selected or is_hovered:
		var bar_w = 700.0
		var bar_h = 32.0
		var bar_pos = Vector2(-bar_w * 0.5, -half_h - 60.0)
		var hp_ratio = clampf(current_health / max(1.0, max_health), 0.0, 1.0)

		# Фон полосы
		draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.038, 0.078, 0.045, 0.9), true)
		draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.29, 0.486, 0.145, 0.8), false, 2.5)

		# Заполнение цветом в зависимости от здоровья
		var fill_color = Color(0.29, 0.75, 0.2, 0.95)
		if hp_ratio < 0.3:
			fill_color = Color(0.85, 0.2, 0.2, 0.95)
		elif hp_ratio < 0.6:
			fill_color = Color(0.88, 0.7, 0.15, 0.95)

		if hp_ratio > 0.0:
			draw_rect(Rect2(bar_pos + Vector2(2, 2), Vector2((bar_w - 4.0) * hp_ratio, bar_h - 4.0)), fill_color, true)

# ==============================================================================
# ИНТЕРФЕЙС УЛУЧШЕНИЙ ЗАВОДА (CANVAS LAYER UI — НАД ЗАВОДОМ В СТИЛЕ ПРОЕКТА)
# ==============================================================================
func _create_upgrade_ui() -> void:
	_destroy_upgrade_ui()

	ui_layer = CanvasLayer.new()
	ui_layer.layer = 98
	add_child(ui_layer)

	upgrade_panel = PanelContainer.new()
	upgrade_panel.name = "FactoryUpgradePanel"
	upgrade_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	upgrade_panel.custom_minimum_size = Vector2(340, 150)

	# Стиль панели в стиле StyleBoxFlat_tablet и SBF_panel проекта
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.063, 0.133, 0.071, 0.96)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.29, 0.486, 0.145, 0.85)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	panel_style.shadow_size = 14
	panel_style.shadow_offset = Vector2(0, 4)
	upgrade_panel.add_theme_stylebox_override("panel", panel_style)
	ui_layer.add_child(upgrade_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	upgrade_panel.add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 7)
	margin.add_child(main_vbox)

	# --- 1. ШАПКА ОКНА (HEADER) ---
	var header_hbox = HBoxContainer.new()
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	header_hbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(header_hbox)

	# Тактический бейдж (как StyleBoxFlat_pvo_badge в HUD)
	var badge_panel = PanelContainer.new()
	var badge_style = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.15, 0.35, 0.18, 0.9)
	badge_style.border_width_left = 1
	badge_style.border_width_top = 1
	badge_style.border_width_right = 1
	badge_style.border_width_bottom = 1
	badge_style.border_color = Color(0.4, 0.8, 0.3, 0.9)
	badge_style.corner_radius_top_left = 4
	badge_style.corner_radius_top_right = 4
	badge_style.corner_radius_bottom_left = 4
	badge_style.corner_radius_bottom_right = 4
	badge_style.content_margin_left = 6
	badge_style.content_margin_top = 2
	badge_style.content_margin_right = 6
	badge_style.content_margin_bottom = 2
	badge_panel.add_theme_stylebox_override("panel", badge_style)
	header_hbox.add_child(badge_panel)

	var badge_lbl = Label.new()
	badge_lbl.text = "ОБЪЕКТ"
	badge_lbl.add_theme_font_size_override("font_size", 11)
	badge_lbl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.35, 1.0))
	badge_panel.add_child(badge_lbl)

	var title_lbl = Label.new()
	title_lbl.text = "ОБОРОНА ЗАВОДА"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9, 1.0))
	header_hbox.add_child(title_lbl)

	var close_btn = Button.new()
	close_btn.text = " ✕ "
	close_btn.custom_minimum_size = Vector2(28, 24)
	close_btn.focus_mode = Control.FOCUS_NONE
	_style_close_btn(close_btn)
	close_btn.pressed.connect(close_upgrade_ui)
	header_hbox.add_child(close_btn)

	# --- 2. ПОЛОСА ПРОЧНОСТИ (HP BAR) ---
	var hp_vbox = VBoxContainer.new()
	hp_vbox.add_theme_constant_override("separation", 3)
	main_vbox.add_child(hp_vbox)

	var hp_info_hbox = HBoxContainer.new()
	hp_vbox.add_child(hp_info_hbox)

	var hp_title = Label.new()
	hp_title.text = "Прочность объекта:"
	hp_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_title.add_theme_font_size_override("font_size", 11)
	hp_title.add_theme_color_override("font_color", Color(0.741, 0.765, 0.78, 0.75))
	hp_info_hbox.add_child(hp_title)

	hp_label = Label.new()
	hp_label.add_theme_font_size_override("font_size", 11)
	hp_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.35, 1.0))
	hp_info_hbox.add_child(hp_label)

	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 10)
	hp_bar.show_percentage = false
	hp_bar.min_value = 0.0
	hp_bar.max_value = max_health
	hp_bar.value = current_health

	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.038, 0.078, 0.045, 0.9)
	bar_bg.border_width_left = 1
	bar_bg.border_width_top = 1
	bar_bg.border_width_right = 1
	bar_bg.border_width_bottom = 1
	bar_bg.border_color = Color(0.2, 0.38, 0.14, 0.6)
	bar_bg.corner_radius_top_left = 3
	bar_bg.corner_radius_top_right = 3
	bar_bg.corner_radius_bottom_left = 3
	bar_bg.corner_radius_bottom_right = 3

	var bar_fg = StyleBoxFlat.new()
	bar_fg.bg_color = Color(0.29, 0.75, 0.2, 1.0)
	bar_fg.corner_radius_top_left = 3
	bar_fg.corner_radius_top_right = 3
	bar_fg.corner_radius_bottom_left = 3
	bar_fg.corner_radius_bottom_right = 3

	hp_bar.add_theme_stylebox_override("background", bar_bg)
	hp_bar.add_theme_stylebox_override("fill", bar_fg)
	hp_vbox.add_child(hp_bar)

	# Тактический разделитель
	var sep = HSeparator.new()
	var sep_style = StyleBoxLine.new()
	sep_style.color = Color(0.2, 0.38, 0.14, 0.55)
	sep_style.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	main_vbox.add_child(sep)

	# --- 3. КАРТОЧКА УЛУЧШЕНИЯ: ПРОТИВОДРОНОВАЯ СЕТКА ---
	var upgrades_vbox = VBoxContainer.new()
	main_vbox.add_child(upgrades_vbox)

	net_btn = Button.new()
	_build_upgrade_row(
		upgrades_vbox,
		"🛡️ Противодроновая сетка",
		"Защита: -75% урона от FPV-дронов",
		net_btn,
		"Купить (%d$)" % net_cost,
		Callable(self, "buy_anti_drone_nets")
	)

	_update_upgrade_ui()

	# Анимация плавного открытия
	upgrade_panel.modulate.a = 0.0
	upgrade_panel.scale = Vector2(0.95, 0.95)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(upgrade_panel, "modulate:a", 1.0, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(upgrade_panel, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_panel_position() -> void:
	if not is_instance_valid(upgrade_panel):
		return

	var canvas_xform = get_viewport().get_canvas_transform()
	var world_scale_y = absf(global_scale.y)
	var half_h = 580.0 * world_scale_y
	var top_world = global_position + Vector2(0, -half_h)
	var screen_pos = canvas_xform * top_world

	var panel_size = upgrade_panel.size
	if panel_size.x <= 0 or panel_size.y <= 0:
		panel_size = upgrade_panel.custom_minimum_size

	var vp_rect = get_viewport_rect()
	var pad = 12.0
	var target_x = clampf(screen_pos.x - panel_size.x * 0.5, pad, vp_rect.size.x - panel_size.x - pad)
	var target_y = screen_pos.y - panel_size.y - 16.0

	# Если завод слишком близко к верхней кромке экрана — позиционируем под заводом
	if target_y < pad:
		var bottom_world = global_position + Vector2(0, half_h)
		var screen_bottom = canvas_xform * bottom_world
		if screen_bottom.y + panel_size.y + pad <= vp_rect.size.y:
			target_y = screen_bottom.y + 16.0
		else:
			target_y = clampf(target_y, pad, vp_rect.size.y - panel_size.y - pad)

	upgrade_panel.position = Vector2(target_x, target_y)

func _build_upgrade_row(parent: VBoxContainer, title: String, desc: String, btn: Button, default_btn_text: String, action: Callable) -> void:
	var row_panel = PanelContainer.new()
	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0.038, 0.078, 0.045, 0.85)
	row_style.border_width_left = 1
	row_style.border_width_top = 1
	row_style.border_width_right = 1
	row_style.border_width_bottom = 1
	row_style.border_color = Color(0.2, 0.38, 0.14, 0.75)
	row_style.corner_radius_top_left = 4
	row_style.corner_radius_top_right = 4
	row_style.corner_radius_bottom_left = 4
	row_style.corner_radius_bottom_right = 4

	row_panel.add_theme_stylebox_override("panel", row_style)
	parent.add_child(row_panel)

	var row_margin = MarginContainer.new()
	row_margin.add_theme_constant_override("margin_left", 10)
	row_margin.add_theme_constant_override("margin_top", 6)
	row_margin.add_theme_constant_override("margin_right", 10)
	row_margin.add_theme_constant_override("margin_bottom", 6)
	row_panel.add_child(row_margin)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	row_margin.add_child(hbox)

	var text_vbox = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 1)
	hbox.add_child(text_vbox)

	var title_l = Label.new()
	title_l.text = title
	title_l.add_theme_font_size_override("font_size", 12)
	title_l.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9, 1.0))
	text_vbox.add_child(title_l)

	var desc_l = Label.new()
	desc_l.text = desc
	desc_l.add_theme_font_size_override("font_size", 10)
	desc_l.add_theme_color_override("font_color", Color(0.4, 0.85, 0.35, 0.9))
	text_vbox.add_child(desc_l)

	btn.text = default_btn_text
	btn.custom_minimum_size = Vector2(130, 32)
	btn.focus_mode = Control.FOCUS_NONE
	_style_tactical_btn(btn, false, false)
	btn.pressed.connect(action)
	hbox.add_child(btn)

func _update_upgrade_ui() -> void:
	if not is_instance_valid(upgrade_panel):
		return

	# Обновление здоровья
	if is_instance_valid(hp_bar) and is_instance_valid(hp_label):
		hp_bar.max_value = max_health
		hp_bar.value = current_health
		var pct = roundi((current_health / max(1.0, max_health)) * 100.0)
		hp_label.text = "%d / %d HP (%d%%)" % [roundi(current_health), roundi(max_health), pct]

		var fill_style = hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill_style:
			if pct < 30:
				fill_style.bg_color = Color(0.85, 0.2, 0.2, 1.0)
			elif pct < 60:
				fill_style.bg_color = Color(0.88, 0.7, 0.15, 1.0)
			else:
				fill_style.bg_color = Color(0.29, 0.75, 0.2, 1.0)

	var hud = _get_hud()
	var current_money: int = hud.money if (hud and "money" in hud) else 0

	# Кнопка Антидроновых сеток
	if is_instance_valid(net_btn):
		if has_anti_drone_nets:
			net_btn.text = "✓ Установлена"
			net_btn.disabled = true
			_style_tactical_btn(net_btn, true, true)
		else:
			net_btn.text = "Купить (%d$)" % net_cost
			var can_afford = (current_money >= net_cost)
			net_btn.disabled = not can_afford
			_style_tactical_btn(net_btn, false, not can_afford)

func _style_close_btn(btn: Button) -> void:
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.169, 0.059, 0.059, 1.0)
	style_normal.border_width_left = 1
	style_normal.border_width_top = 1
	style_normal.border_width_right = 1
	style_normal.border_width_bottom = 1
	style_normal.border_color = Color(0.545, 0.125, 0.125, 0.75)
	style_normal.corner_radius_top_left = 3
	style_normal.corner_radius_top_right = 3
	style_normal.corner_radius_bottom_left = 3
	style_normal.corner_radius_bottom_right = 3

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.247, 0.078, 0.078, 1.0)
	style_hover.border_width_left = 1
	style_hover.border_width_top = 1
	style_hover.border_width_right = 1
	style_hover.border_width_bottom = 1
	style_hover.border_color = Color(0.8, 0.2, 0.2, 1.0)
	style_hover.corner_radius_top_left = 3
	style_hover.corner_radius_top_right = 3
	style_hover.corner_radius_bottom_left = 3
	style_hover.corner_radius_bottom_right = 3

	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.098, 0.035, 0.035, 1.0)
	style_pressed.border_width_left = 1
	style_pressed.border_width_top = 1
	style_pressed.border_width_right = 1
	style_pressed.border_width_bottom = 1
	style_pressed.border_color = Color(0.545, 0.125, 0.125, 0.5)
	style_pressed.corner_radius_top_left = 3
	style_pressed.corner_radius_top_right = 3
	style_pressed.corner_radius_bottom_left = 3
	style_pressed.corner_radius_bottom_right = 3

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.85, 1.0))
	btn.add_theme_font_size_override("font_size", 12)

func _style_tactical_btn(btn: Button, is_active: bool, is_disabled: bool) -> void:
	var corner_r = 3

	var style_normal = StyleBoxFlat.new()
	style_normal.corner_radius_top_left = corner_r
	style_normal.corner_radius_top_right = corner_r
	style_normal.corner_radius_bottom_left = corner_r
	style_normal.corner_radius_bottom_right = corner_r
	style_normal.border_width_left = 1
	style_normal.border_width_top = 1
	style_normal.border_width_right = 1
	style_normal.border_width_bottom = 1

	var style_hover = StyleBoxFlat.new()
	style_hover.corner_radius_top_left = corner_r
	style_hover.corner_radius_top_right = corner_r
	style_hover.corner_radius_bottom_left = corner_r
	style_hover.corner_radius_bottom_right = corner_r
	style_hover.border_width_left = 1
	style_hover.border_width_top = 1
	style_hover.border_width_right = 1
	style_hover.border_width_bottom = 1

	var style_disabled = StyleBoxFlat.new()
	style_disabled.corner_radius_top_left = corner_r
	style_disabled.corner_radius_top_right = corner_r
	style_disabled.corner_radius_bottom_left = corner_r
	style_disabled.corner_radius_bottom_right = corner_r
	style_disabled.border_width_left = 1
	style_disabled.border_width_top = 1
	style_disabled.border_width_right = 1
	style_disabled.border_width_bottom = 1

	if is_active:
		style_disabled.bg_color = Color(0.082, 0.168, 0.051, 0.95)
		style_disabled.border_color = Color(0.35, 0.7, 0.25, 0.85)
		btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.95, 0.35, 1.0))
	else:
		style_normal.bg_color = Color(0.082, 0.168, 0.051, 1.0)
		style_normal.border_color = Color(0.29, 0.486, 0.145, 0.75)

		style_hover.bg_color = Color(0.122, 0.247, 0.075, 1.0)
		style_hover.border_color = Color(0.4, 0.85, 0.3, 1.0)

		style_disabled.bg_color = Color(0.04, 0.065, 0.04, 0.7)
		style_disabled.border_color = Color(0.18, 0.26, 0.14, 0.45)
		btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.62, 0.55, 0.6))

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_normal)
	btn.add_theme_stylebox_override("disabled", style_disabled)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9, 1.0))
	btn.add_theme_font_size_override("font_size", 12)

func _destroy_upgrade_ui() -> void:
	if is_instance_valid(ui_layer):
		ui_layer.queue_free()
		ui_layer = null
		upgrade_panel = null
		hp_bar = null
		hp_label = null
		net_btn = null
