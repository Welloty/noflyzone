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

@export_group("Улучшение: Ремонт завода")
@export var repair_cost: int = 60
@export var repair_amount: float = 300.0

@export_group("Улучшение: Бронекаркас")
@export var armor_cost: int = 120
@export var armor_bonus: float = 500.0

# ==============================================================================
# ВНУТРЕННЕЕ СОСТОЯНИЕ
# ==============================================================================
var has_anti_drone_nets: bool = false
var has_reinforced_armor: bool = false
var is_selected: bool = false
var is_hovered: bool = false
var net_pulse_time: float = 0.0

# UI
var click_area: Area2D = null
var ui_layer: CanvasLayer = null
var upgrade_panel: PanelContainer = null
var hp_bar: ProgressBar = null
var hp_label: Label = null
var net_btn: Button = null
var repair_btn: Button = null
var armor_btn: Button = null

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
		_update_upgrade_ui()

func _unhandled_input(event: InputEvent) -> void:
	if not is_selected:
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			close_upgrade_ui()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _is_click_on_factory_area(get_global_mouse_position()):
			close_upgrade_ui()
	elif event is InputEventScreenTouch and event.pressed:
		var touch_global = _screen_to_global(event.position)
		if not _is_click_on_factory_area(touch_global):
			close_upgrade_ui()

func _screen_to_global(screen_pos: Vector2) -> Vector2:
	var canvas_xform = get_canvas_transform()
	return canvas_xform.affine_inverse() * screen_pos

func _is_click_on_factory_area(global_click_pos: Vector2) -> bool:
	if not is_instance_valid(click_area):
		return false
	var space_state = get_world_2d().direct_space_state
	if not space_state:
		return false
	var query = PhysicsPointQueryParameters2D.new()
	query.position = global_click_pos
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

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var is_click = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_click = true
	elif event is InputEventScreenTouch and event.pressed:
		is_click = true

	if is_click:
		# Проверяем, не идет ли сейчас установка башни
		var mgr = get_tree().get_first_node_in_group("placement_manager")
		if mgr and "ghost_instance" in mgr and is_instance_valid(mgr.ghost_instance):
			return

		toggle_upgrade_ui()
		if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"):
			Input.vibrate_handheld(30)
		get_viewport().set_input_as_handled()

func toggle_upgrade_ui() -> void:
	if is_selected:
		close_upgrade_ui()
	else:
		open_upgrade_ui()

func open_upgrade_ui() -> void:
	# Снимаем выделение с башен
	var mgr = get_tree().get_first_node_in_group("placement_manager")
	if mgr and mgr.has_method("deselect_tower"):
		mgr.deselect_tower()

	is_selected = true
	_create_upgrade_ui()
	queue_redraw()

func close_upgrade_ui() -> void:
	is_selected = false
	_destroy_upgrade_ui()
	queue_redraw()

# ==============================================================================
# ПОЛУЧЕНИЕ УРОНА (DAMAGE HANDLING)
# ==============================================================================
func take_damage(amount: float, source: Variant = null) -> void:
	if current_health <= 0:
		return

	var is_fpv = false
	if source != null:
		if source is String and source == "fpv":
			is_fpv = true
		elif source is Node and (source.is_in_group("fpv_drones") or source.is_in_group("fpv")):
			is_fpv = true

	if is_fpv and has_anti_drone_nets:
		var blocked_amount = amount * fpv_protection_ratio
		amount -= blocked_amount
		_spawn_floating_text("-%d HP [Сетка -75%%]" % roundi(amount), Color(0.2, 0.95, 1.0))
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
	_spawn_floating_text("🛡️ Сетки установлены! (-75% FPV)", Color(0.25, 1.0, 0.5))
	upgraded.emit("anti_drone_nets")
	_update_upgrade_ui()
	queue_redraw()

	if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"):
		Input.vibrate_handheld(45)

func repair_factory() -> void:
	if current_health >= max_health:
		return

	var hud = _get_hud()
	if not hud or not hud.has_method("deduct_money") or not hud.deduct_money(repair_cost):
		return

	var heal = min(repair_amount, max_health - current_health)
	current_health += heal
	_spawn_floating_text("+%d HP Ремонт!" % roundi(heal), Color(0.35, 1.0, 0.45))
	health_changed.emit(current_health, max_health)
	_update_upgrade_ui()
	queue_redraw()

	if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"):
		Input.vibrate_handheld(35)

func buy_reinforced_armor() -> void:
	if has_reinforced_armor:
		return

	var hud = _get_hud()
	if not hud or not hud.has_method("deduct_money") or not hud.deduct_money(armor_cost):
		return

	has_reinforced_armor = true
	max_health += armor_bonus
	current_health += armor_bonus
	_spawn_floating_text("🧱 Каркас усилен! (+500 HP)", Color(1.0, 0.85, 0.3))
	upgraded.emit("reinforced_armor")
	health_changed.emit(current_health, max_health)
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
	label.z_index = 40
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
	modulate = Color(1.4, 2.0, 2.2, 1.0)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.25).set_ease(Tween.EASE_OUT)

# ==============================================================================
# ОТРИСОВКА В МИРЕ (DRAWING IN WORLD SPACE)
# ==============================================================================
func _draw() -> void:
	var half_w = 580.0
	var half_h = 580.0
	var rect_bounds = Rect2(-half_w, -half_h, half_w * 2.0, half_h * 2.0)

	# 1. Выделение при клике на завод
	if is_selected:
		draw_rect(rect_bounds, Color(0.2, 0.85, 1.0, 0.12), true)
		draw_rect(rect_bounds, Color(0.25, 0.9, 1.0, 0.85), false, 4.0)
		# Угловые скобки
		var bracket_len = 70.0
		var corners = [
			Vector2(-half_w, -half_h), Vector2(half_w, -half_h),
			Vector2(-half_w, half_h), Vector2(half_w, half_h)
		]
		for c in corners:
			var dx = 1.0 if c.x < 0 else -1.0
			var dy = 1.0 if c.y < 0 else -1.0
			draw_line(c, c + Vector2(dx * bracket_len, 0), Color(0.4, 1.0, 1.0, 0.95), 8.0)
			draw_line(c, c + Vector2(0, dy * bracket_len), Color(0.4, 1.0, 1.0, 0.95), 8.0)
	elif is_hovered:
		draw_rect(rect_bounds, Color(0.3, 1.0, 0.6, 0.08), true)
		draw_rect(rect_bounds, Color(0.3, 1.0, 0.6, 0.45), false, 3.0)

	# 2. Отрисовка установленной антидроновой сетки
	if has_anti_drone_nets:
		var net_bounds = Rect2(-540, -540, 1080, 1080)
		# Каркас сетки
		draw_rect(net_bounds, Color(0.18, 0.65, 0.9, 0.09), true)
		draw_rect(net_bounds, Color(0.3, 0.8, 1.0, 0.75), false, 4.0)

		# Сетка из проволоки (горизонтальные и вертикальные струны)
		var step = 120.0
		var wire_col = Color(0.65, 0.88, 1.0, 0.35)
		var x = -540.0 + step
		while x < 540.0:
			draw_line(Vector2(x, -540), Vector2(x, 540), wire_col, 2.0)
			x += step
		var y = -540.0 + step
		while y < 540.0:
			draw_line(Vector2(-540, y), Vector2(540, y), wire_col, 2.0)
			y += step

		# Диагональные защитные тросы
		var diag_col = Color(0.4, 0.85, 1.0, 0.4)
		draw_line(Vector2(-540, -540), Vector2(540, 540), diag_col, 3.0)
		draw_line(Vector2(540, -540), Vector2(-540, 540), diag_col, 3.0)

		# Пульсирующие маячки на углах сетки
		var pulse = 0.65 + 0.35 * sin(net_pulse_time * 5.0)
		var beacon_corners = [
			Vector2(-540, -540), Vector2(540, -540),
			Vector2(-540, 540), Vector2(540, 540)
		]
		for bc in beacon_corners:
			draw_circle(bc, 16.0, Color(0.2, 0.8, 1.0, 0.4 * pulse))
			draw_circle(bc, 9.0, Color(0.5, 0.95, 1.0, 0.9 * pulse))

	# 3. Индикатор прочности (HP Bar) над заводом
	if current_health < max_health or is_selected or is_hovered:
		var bar_w = 700.0
		var bar_h = 32.0
		var bar_pos = Vector2(-bar_w * 0.5, -half_h - 60.0)
		var hp_ratio = clampf(current_health / max(1.0, max_health), 0.0, 1.0)

		# Фон полосы
		draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.06, 0.08, 0.1, 0.85), true)
		draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.25, 0.4, 0.55, 0.8), false, 2.5)

		# Заполнение цветом в зависимости от здоровья
		var fill_color = Color(0.2, 0.85, 0.35, 0.9)
		if hp_ratio < 0.3:
			fill_color = Color(0.9, 0.22, 0.22, 0.95)
		elif hp_ratio < 0.6:
			fill_color = Color(0.95, 0.75, 0.2, 0.95)

		if hp_ratio > 0.0:
			draw_rect(Rect2(bar_pos + Vector2(2, 2), Vector2((bar_w - 4.0) * hp_ratio, bar_h - 4.0)), fill_color, true)

# ==============================================================================
# ИНТЕРФЕЙС УЛУЧШЕНИЙ ЗАВОДА (CANVAS LAYER UI)
# ==============================================================================
func _create_upgrade_ui() -> void:
	_destroy_upgrade_ui()

	ui_layer = CanvasLayer.new()
	ui_layer.layer = 98
	add_child(ui_layer)

	upgrade_panel = PanelContainer.new()
	upgrade_panel.name = "FactoryUpgradePanel"
	upgrade_panel.custom_minimum_size = Vector2(490, 310)
	upgrade_panel.anchor_left = 0.5
	upgrade_panel.anchor_right = 0.5
	upgrade_panel.anchor_top = 0.68
	upgrade_panel.anchor_bottom = 0.68
	upgrade_panel.offset_left = -245.0
	upgrade_panel.offset_right = 245.0
	upgrade_panel.offset_top = -155.0
	upgrade_panel.offset_bottom = 155.0
	upgrade_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	upgrade_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.09, 0.13, 0.95)
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.corner_radius_bottom_right = 16
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.24, 0.52, 0.78, 0.8)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	panel_style.shadow_size = 18
	panel_style.shadow_offset = Vector2(0, 5)
	upgrade_panel.add_theme_stylebox_override("panel", panel_style)
	ui_layer.add_child(upgrade_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	upgrade_panel.add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)

	# --- 1. ШАПКА ОКНА ---
	var header_hbox = HBoxContainer.new()
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(header_hbox)

	var title_lbl = Label.new()
	title_lbl.text = "🏭 ЗАВОД — КОМПЛЕКС ОБОРОНЫ"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0))
	header_hbox.add_child(title_lbl)

	var close_btn = Button.new()
	close_btn.text = " ✕ "
	close_btn.custom_minimum_size = Vector2(34, 30)
	close_btn.focus_mode = Control.FOCUS_NONE
	_style_btn(close_btn, Color(0.25, 0.28, 0.32, 0.8), Color(0.38, 0.42, 0.48, 1.0))
	close_btn.pressed.connect(close_upgrade_ui)
	header_hbox.add_child(close_btn)

	# --- 2. ПОЛОСА ПРОЧНОСТИ ---
	var hp_vbox = VBoxContainer.new()
	hp_vbox.add_theme_constant_override("separation", 3)
	main_vbox.add_child(hp_vbox)

	var hp_info_hbox = HBoxContainer.new()
	hp_vbox.add_child(hp_info_hbox)

	var hp_title = Label.new()
	hp_title.text = "Прочность объекта:"
	hp_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_title.add_theme_font_size_override("font_size", 13)
	hp_title.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
	hp_info_hbox.add_child(hp_title)

	hp_label = Label.new()
	hp_label.add_theme_font_size_override("font_size", 13)
	hp_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.45))
	hp_info_hbox.add_child(hp_label)

	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 14)
	hp_bar.show_percentage = false
	hp_bar.min_value = 0.0
	hp_bar.max_value = max_health
	hp_bar.value = current_health

	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.08, 0.12, 0.16, 0.9)
	bar_bg.corner_radius_top_left = 6
	bar_bg.corner_radius_top_right = 6
	bar_bg.corner_radius_bottom_left = 6
	bar_bg.corner_radius_bottom_right = 6

	var bar_fg = StyleBoxFlat.new()
	bar_fg.bg_color = Color(0.2, 0.8, 0.35, 1.0)
	bar_fg.corner_radius_top_left = 6
	bar_fg.corner_radius_top_right = 6
	bar_fg.corner_radius_bottom_left = 6
	bar_fg.corner_radius_bottom_right = 6

	hp_bar.add_theme_stylebox_override("background", bar_bg)
	hp_bar.add_theme_stylebox_override("fill", bar_fg)
	hp_vbox.add_child(hp_bar)

	# Разделитель
	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	main_vbox.add_child(sep)

	# --- 3. КАРТОЧКИ УЛУЧШЕНИЙ ---
	var upgrades_vbox = VBoxContainer.new()
	upgrades_vbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(upgrades_vbox)

	# 3.1 Антидроновые сетки
	net_btn = Button.new()
	_build_upgrade_row(
		upgrades_vbox,
		"🛡️ Антидроновые сетки",
		"Защита от FPV-дронов: -75% входящего урона",
		net_btn,
		"Купить (%d$)" % net_cost,
		Callable(self, "buy_anti_drone_nets")
	)

	# 3.2 Экстренный ремонт
	repair_btn = Button.new()
	_build_upgrade_row(
		upgrades_vbox,
		"🔧 Экстренный ремонт",
		"Восстановление +%d HP прочности завода" % roundi(repair_amount),
		repair_btn,
		"Починить (%d$)" % repair_cost,
		Callable(self, "repair_factory")
	)

	# 3.3 Усиление каркаса
	armor_btn = Button.new()
	_build_upgrade_row(
		upgrades_vbox,
		"🧱 Усиление конструкции",
		"Увеличение максимальной прочности на +%d HP" % roundi(armor_bonus),
		armor_btn,
		"Укрепить (%d$)" % armor_cost,
		Callable(self, "buy_reinforced_armor")
	)

	_update_upgrade_ui()

	# Анимация плавного открытия
	upgrade_panel.modulate.a = 0.0
	upgrade_panel.scale = Vector2(0.95, 0.95)
	upgrade_panel.pivot_offset = upgrade_panel.custom_minimum_size * 0.5
	var tween = create_tween().set_parallel(true)
	tween.tween_property(upgrade_panel, "modulate:a", 1.0, 0.16).set_ease(Tween.EASE_OUT)
	tween.tween_property(upgrade_panel, "scale", Vector2.ONE, 0.16).set_ease(Tween.EASE_OUT)

func _build_upgrade_row(parent: VBoxContainer, title: String, desc: String, btn: Button, default_btn_text: String, action: Callable) -> void:
	var row_panel = PanelContainer.new()
	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0.1, 0.14, 0.2, 0.6)
	row_style.corner_radius_top_left = 10
	row_style.corner_radius_top_right = 10
	row_style.corner_radius_bottom_left = 10
	row_style.corner_radius_bottom_right = 10
	row_style.border_width_left = 1
	row_style.border_width_top = 1
	row_style.border_width_right = 1
	row_style.border_width_bottom = 1
	row_style.border_color = Color(0.2, 0.35, 0.5, 0.5)
	row_panel.add_theme_stylebox_override("panel", row_style)
	parent.add_child(row_panel)

	var row_margin = MarginContainer.new()
	row_margin.add_theme_constant_override("margin_left", 12)
	row_margin.add_theme_constant_override("margin_top", 6)
	row_margin.add_theme_constant_override("margin_right", 12)
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
	title_l.add_theme_font_size_override("font_size", 14)
	title_l.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	text_vbox.add_child(title_l)

	var desc_l = Label.new()
	desc_l.text = desc
	desc_l.add_theme_font_size_override("font_size", 11)
	desc_l.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
	text_vbox.add_child(desc_l)

	btn.text = default_btn_text
	btn.custom_minimum_size = Vector2(135, 36)
	btn.focus_mode = Control.FOCUS_NONE
	_style_btn(btn, Color(0.18, 0.52, 0.82, 0.95), Color(0.24, 0.65, 0.98, 1.0))
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
				fill_style.bg_color = Color(0.9, 0.22, 0.22, 1.0)
			elif pct < 60:
				fill_style.bg_color = Color(0.95, 0.75, 0.2, 1.0)
			else:
				fill_style.bg_color = Color(0.2, 0.8, 0.35, 1.0)

	var hud = _get_hud()
	var current_money: int = hud.money if (hud and "money" in hud) else 0

	# 1. Кнопка Антидроновых сеток
	if is_instance_valid(net_btn):
		if has_anti_drone_nets:
			net_btn.text = "✓ Установлено"
			net_btn.disabled = true
			_style_btn(net_btn, Color(0.16, 0.48, 0.25, 0.8), Color(0.16, 0.48, 0.25, 0.8))
		else:
			net_btn.text = "Купить (%d$)" % net_cost
			net_btn.disabled = (current_money < net_cost)
			_style_btn(net_btn, Color(0.18, 0.52, 0.82, 0.95), Color(0.24, 0.65, 0.98, 1.0))

	# 2. Кнопка Ремонта
	if is_instance_valid(repair_btn):
		if current_health >= max_health:
			repair_btn.text = "✓ Полная целость"
			repair_btn.disabled = true
			_style_btn(repair_btn, Color(0.2, 0.24, 0.28, 0.6), Color(0.2, 0.24, 0.28, 0.6))
		else:
			repair_btn.text = "Починить (%d$)" % repair_cost
			repair_btn.disabled = (current_money < repair_cost)
			_style_btn(repair_btn, Color(0.2, 0.62, 0.32, 0.95), Color(0.26, 0.78, 0.4, 1.0))

	# 3. Кнопка Усиления каркаса
	if is_instance_valid(armor_btn):
		if has_reinforced_armor:
			armor_btn.text = "✓ Укреплено"
			armor_btn.disabled = true
			_style_btn(armor_btn, Color(0.16, 0.48, 0.25, 0.8), Color(0.16, 0.48, 0.25, 0.8))
		else:
			armor_btn.text = "Укрепить (%d$)" % armor_cost
			armor_btn.disabled = (current_money < armor_cost)
			_style_btn(armor_btn, Color(0.72, 0.48, 0.15, 0.95), Color(0.9, 0.62, 0.2, 1.0))

func _style_btn(btn: Button, base_color: Color, hover_color: Color) -> void:
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = base_color
	style_normal.corner_radius_top_left = 10
	style_normal.corner_radius_top_right = 10
	style_normal.corner_radius_bottom_left = 10
	style_normal.corner_radius_bottom_right = 10

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = hover_color
	style_hover.corner_radius_top_left = 10
	style_hover.corner_radius_top_right = 10
	style_hover.corner_radius_bottom_left = 10
	style_hover.corner_radius_bottom_right = 10

	var style_disabled = StyleBoxFlat.new()
	style_disabled.bg_color = Color(0.18, 0.21, 0.25, 0.6)
	style_disabled.corner_radius_top_left = 10
	style_disabled.corner_radius_top_right = 10
	style_disabled.corner_radius_bottom_left = 10
	style_disabled.corner_radius_bottom_right = 10

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_normal)
	btn.add_theme_stylebox_override("disabled", style_disabled)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.65, 0.7, 0.7))
	btn.add_theme_font_size_override("font_size", 13)

func _destroy_upgrade_ui() -> void:
	if is_instance_valid(ui_layer):
		ui_layer.queue_free()
		ui_layer = null
		upgrade_panel = null
		hp_bar = null
		hp_label = null
		net_btn = null
		repair_btn = null
		armor_btn = null
