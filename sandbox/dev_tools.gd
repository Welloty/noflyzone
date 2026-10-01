extends CanvasLayer

signal notification_posted(text: String, color: Color)

# Загруженные сцены с юнитами
const SCENE_SHAHED136 = preload("res://lvl1/entities/enemies/drone.tscn")
const SCENE_FPV = preload("res://lvl1/entities/enemies/fpv.tscn")
const SCENE_FP1 = preload("res://lvl1/entities/enemies/fp-1.tscn")
const SCENE_KALIBR = preload("res://lvl1/entities/enemies/Roctetks.tscn")
const SCENE_SHAHED238 = preload("res://lvl1/entities/enemies/shahed238.tscn")
const SCENE_FRIENDLY_PLANE = preload("res://lvl1/entities/planes/FriendlyPlane.tscn")
const SCENE_SHAHED = preload("res://lvl1/entities/planes/ShahedTest.tscn")
const SCENE_KALIBR_CONTROLLED = preload("res://lvl1/entities/planes/KalibrTest.tscn")

# Состояние
var is_god_mode: bool = false
var is_infinite_money: bool = false
var is_auto_wave_active: bool = false
var selected_enemy_type: String = "shahed136"
var selected_path_name: String = "auto"
var spawn_batch_count: int = 1

# Узлы интерфейса
@onready var main_panel: PanelContainer = $RootControl/MainPanel
@onready var toggle_btn: Button = $RootControl/ToggleBtn
@onready var toast_label: Label = $RootControl/ToastLabel
@onready var stats_label: Label = $RootControl/MainPanel/VBox/StatsLabelBar
@onready var close_btn: Button = $RootControl/MainPanel/VBox/Header/CloseBtn

# Интерфейс целей
@onready var path_option_btn: OptionButton = $RootControl/MainPanel/VBox/Content/TabContainer/Enemies/VBox/PathHBox/PathOptionBtn
@onready var enemy_count_spin: SpinBox = $RootControl/MainPanel/VBox/Content/TabContainer/Enemies/VBox/CountHBox/CountSpin
@onready var auto_wave_btn: Button = $RootControl/MainPanel/VBox/Content/TabContainer/Enemies/VBox/WaveHBox/AutoWaveBtn
@onready var timer_spawn: Timer = $RootControl/MainPanel/VBox/Content/TabContainer/Enemies/VBox/CountHBox/CountSpin/Timer
@onready var health_spin: SpinBox = $RootControl/MainPanel/VBox/Content/TabContainer/Factory/VBox/Customhealth/HealthSpin

# Интерфейс денег
@onready var money_spin: SpinBox = $RootControl/MainPanel/VBox/Content/TabContainer/Economy/VBox/CustomMoneyHBox/MoneySpin
@onready var inf_money_check: CheckBox = $RootControl/MainPanel/VBox/Content/TabContainer/Economy/VBox/InfMoneyCheck

# Интерфейс завода
@onready var hp_slider: HSlider = $RootControl/MainPanel/VBox/Content/TabContainer/Factory/VBox/HPSlider
@onready var hp_value_label: Label = $RootControl/MainPanel/VBox/Content/TabContainer/Factory/VBox/HPHeader/HPValueLabel
@onready var god_mode_check: CheckBox = $RootControl/MainPanel/VBox/Content/TabContainer/Factory/VBox/GodModeCheck
@onready var net_upgrade_check: CheckBox = $RootControl/MainPanel/VBox/Content/TabContainer/Factory/VBox/NetCheck

# Интерфейс управления временем
@onready var pause_btn: Button = $RootControl/MainPanel/VBox/Content/TabContainer/System/VBox/TimeHBox/PauseBtn

var _toast_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_path_options()
	_setup_signals()
	_update_ui_state()
	post_toast("Режим Sandbox активирован. Нажмите [~] для скрытия меню.", Color(0.3, 0.9, 1.0))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT or event.physical_keycode == KEY_QUOTELEFT or event.keycode == KEY_F1:
			toggle_panel()
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	_update_telemetry()
	
	# Блокировка режима бога
	if is_god_mode:
		var factory = _get_factory()
		if factory and factory.current_health < factory.max_health:
			factory.current_health = factory.max_health
			if factory.has_signal("health_changed"):
				factory.health_changed.emit(factory.current_health, factory.max_health)
	
	# Бесконечные деньги
	if is_infinite_money:
		var hud = _get_hud()
		if hud and "money" in hud and hud.money < 99999:
			hud.money = 99999

func _setup_path_options() -> void:
	if not path_option_btn:
		return
	path_option_btn.clear()
	path_option_btn.add_item("Автоматический (по типу врага)", 0)
	path_option_btn.add_item("MainPath (Основной)", 1)
	path_option_btn.add_item("FPVPath (Малый)", 2)
	path_option_btn.add_item("FP1Path (FP-1)", 3)
	path_option_btn.add_item("KalibrPath (Калибр)", 4)
	path_option_btn.add_item("Shahed238Path (Реактивный)", 5)
	path_option_btn.selected = 0

func _setup_signals() -> void:
	if toggle_btn:
		toggle_btn.pressed.connect(toggle_panel)
	if close_btn:
		close_btn.pressed.connect(toggle_panel)
	
	if path_option_btn:
		path_option_btn.item_selected.connect(_on_path_selected)

	# Кнопки целей
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Enemies/VBox/EnemyGrid/Shahed136Btn", _on_enemy_btn_pressed.bind("shahed136"))
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Enemies/VBox/EnemyGrid/FPVBtn", _on_enemy_btn_pressed.bind("fpv"))
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Enemies/VBox/EnemyGrid/FP1Btn", _on_enemy_btn_pressed.bind("fp1"))
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Enemies/VBox/EnemyGrid/KalibrBtn", _on_enemy_btn_pressed.bind("kalibr"))
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Enemies/VBox/EnemyGrid/Shahed238Btn", _on_enemy_btn_pressed.bind("shahed238"))
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Enemies/VBox/EnemyGrid/PlaneBtn", _on_spawn_friendly_plane_pressed)

	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Enemies/VBox/EnemyGrid/ShahedTest", _on_spawn_shahed_pressed)
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Enemies/VBox/EnemyGrid/KalibrTest", _on_spawn_Kalibr_pressed)
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Enemies/VBox/CountHBox/Btn1", _on_set_batch_count.bind(1))
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Enemies/VBox/CountHBox/Btn3", _on_set_batch_count.bind(3))
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Enemies/VBox/CountHBox/Btn5", _on_set_batch_count.bind(5))
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Enemies/VBox/CountHBox/Btn10", _on_set_batch_count.bind(10))

	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Enemies/VBox/ClearEnemiesBtn", _on_clear_enemies_pressed)
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Enemies/VBox/WaveHBox/NextWaveBtn", _on_next_wave_pressed)
	if auto_wave_btn:
		auto_wave_btn.pressed.connect(_on_toggle_auto_waves_pressed)

	# Кнопки Экономики
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Economy/VBox/Grid/Add100Btn", _on_add_money_pressed.bind(100))
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Economy/VBox/Grid/Add500Btn", _on_add_money_pressed.bind(500))
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Economy/VBox/Grid/Add1000Btn", _on_add_money_pressed.bind(1000))
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Economy/VBox/Grid/Add10000Btn", _on_add_money_pressed.bind(10000))
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Economy/VBox/CustomMoneyHBox/SetMoneyBtn", _on_set_custom_money_pressed)
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Economy/VBox/ResetMoneyBtn", _on_reset_money_pressed)
	if inf_money_check:
		inf_money_check.toggled.connect(_on_inf_money_toggled)

	# Кнопки Завода
	if hp_slider:
		hp_slider.value_changed.connect(_on_hp_slider_value_changed)
	if health_spin:
		health_spin.value_changed.connect(_on_custom_hp_custom)

	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Factory/VBox/PresetsHBox/Hp100Btn", _on_preset_hp_pressed.bind(1.0))
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Factory/VBox/PresetsHBox/Hp50Btn", _on_preset_hp_pressed.bind(0.5))
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Factory/VBox/PresetsHBox/Hp10Btn", _on_preset_hp_pressed.bind(0.1))
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Factory/VBox/PresetsHBox/Hp1Btn", _on_preset_hp_custom.bind(1.0))
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Factory/VBox/PresetsHBox/Hp0Btn", _on_preset_hp_custom.bind(0.0))
	
	if god_mode_check:
		god_mode_check.toggled.connect(_on_god_mode_toggled)
	if net_upgrade_check:
		net_upgrade_check.toggled.connect(_on_net_upgrade_toggled)
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/Factory/VBox/RelocateBtn", _on_relocate_factory_pressed)

	# Кнопки системы
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/System/VBox/TimeHBox/Spd025Btn", _on_set_time_scale.bind(0.25))
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/System/VBox/TimeHBox/Spd05Btn", _on_set_time_scale.bind(0.5))
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/System/VBox/TimeHBox/Spd1Btn", _on_set_time_scale.bind(1.0))
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/System/VBox/TimeHBox/Spd2Btn", _on_set_time_scale.bind(2.0))
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/System/VBox/TimeHBox/Spd4Btn", _on_set_time_scale.bind(4.0))
	if pause_btn:
		pause_btn.pressed.connect(_on_toggle_pause_pressed)
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/System/VBox/RestartBtn", _on_restart_sandbox_pressed)
	_connect_btn("RootControl/MainPanel/VBox/Content/TabContainer/System/VBox/MainMenuBtn", _on_main_menu_pressed)

func _connect_btn(node_path: String, callable: Callable) -> void:
	var btn = get_node_or_null(node_path) as Button
	if btn:
		btn.pressed.connect(callable)

func _on_preset_hp_custom(hp_amount: float) -> void:
	if hp_slider:
		hp_slider.value = hp_amount
	_set_factory_hp(hp_amount)

func _on_custom_hp_custom(hp_amount: float) -> void:
	if hp_slider:
		hp_slider.value = hp_amount
	_set_factory_hp(hp_amount)

func toggle_panel() -> void:
	if not main_panel:
		return
	main_panel.visible = not main_panel.visible
	if toggle_btn:
		toggle_btn.text = "🛠 DEV TOOLS [~]" if not main_panel.visible else "✖ СКРЫТЬ [~]"

func post_toast(message: String, color: Color = Color.WHITE) -> void:
	if not toast_label:
		return
	toast_label.text = message
	toast_label.modulate = color
	toast_label.visible = true
	
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
		
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.1)
	_toast_tween.tween_interval(2.5)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func(): toast_label.visible = false)

func _update_telemetry() -> void:
	if not stats_label or not main_panel.visible:
		return
	var fps = Engine.get_frames_per_second()
	var drones_count = get_tree().get_nodes_in_group("drones").size()
	var hud = _get_hud()
	var money_val = hud.money if hud and "money" in hud else 0
	var factory = _get_factory()
	var hp_val = roundi(factory.current_health) if factory and "current_health" in factory else 0
	
	stats_label.text = "FPS: %d | Враги: %d | Деньги: %d$ | Завод: %d HP" % [fps, drones_count, money_val, hp_val]

func _update_ui_state() -> void:
	var factory = _get_factory()
	if factory and hp_slider:
		hp_slider.max_value = factory.max_health
		hp_slider.value = factory.current_health
		_update_hp_label(factory.current_health, factory.max_health)
		if net_upgrade_check and "has_anti_drone_nets" in factory:
			net_upgrade_check.button_pressed = factory.has_anti_drone_nets

func _get_hud() -> Node:
	var hud = get_tree().get_first_node_in_group("hud")
	if not hud:
		var level = get_tree().get_first_node_in_group("level")
		if level:
			hud = level.get_node_or_null("UI/HUD")
	return hud

func _get_factory() -> Node:
	var factory = get_tree().get_first_node_in_group("factory")
	if not factory:
		var level = get_tree().get_first_node_in_group("level")
		if level:
			factory = level.get_node_or_null("Environment/Factory")
	return factory

func _get_wave_manager() -> Node:
	return get_tree().get_first_node_in_group("wave_manager")

# Спавн целей
func _on_enemy_btn_pressed(enemy_type: String) -> void:
	var count = int(enemy_count_spin.value) if enemy_count_spin else 1
	var spawned = 0
	
	for i in range(count):
		if _spawn_single_enemy(enemy_type):
			spawned += 1
			if timer_spawn:
				timer_spawn.start()
				await timer_spawn.timeout
			
	post_toast("Заспавнено: %d x %s" % [spawned, _get_enemy_title(enemy_type)], Color(0.4, 1.0, 0.5))

func _spawn_single_enemy(enemy_type: String) -> bool:
	var scene: PackedScene = null
	var default_path = "MainPath"
	var scale_override = Vector2.ONE
	
	match enemy_type:
		"shahed136":
			scene = SCENE_SHAHED136
			default_path = "MainPath"
			scale_override = Vector2(0.4, 0.4)
		"fpv":
			scene = SCENE_FPV
			default_path = "FPVPath"
		"fp1":
			scene = SCENE_FP1
			default_path = "FP1Path"
		"kalibr":
			scene = SCENE_KALIBR
			default_path = "KalibrPath"
		"shahed238":
			scene = SCENE_SHAHED238
			default_path = "Shahed238Path"

	if not scene:
		return false

	var target_path = default_path
	if selected_path_name != "auto" and selected_path_name != "":
		target_path = selected_path_name

	var enemy_paths = null
	var level = get_tree().get_first_node_in_group("level")
	if level:
		enemy_paths = level.get_node_or_null("EnemyPaths")
	if not enemy_paths:
		enemy_paths = get_tree().root.find_child("EnemyPaths", true, false)

	if not enemy_paths:
		post_toast("Ошибка: EnemyPaths не найден!", Color.RED)
		return false

	var path_node: Path2D = enemy_paths.get_node_or_null(target_path) as Path2D
	if not path_node:
		path_node = enemy_paths.get_node_or_null("MainPath") as Path2D

	if not path_node:
		post_toast("Ошибка: Путь " + target_path + " не найден!", Color.RED)
		return false

	var follower = PathFollow2D.new()
	follower.rotates = true
	follower.loop = false
	path_node.add_child(follower)
	follower.progress_ratio = 0.0

	var enemy: CharacterBody2D = scene.instantiate()
	enemy.path_follower = follower
	if enemy_type == "shahed136":
		enemy.scale = scale_override

	if level:
		level.add_child(enemy)
	else:
		get_parent().add_child(enemy)

	enemy.global_position = follower.global_position
	return true

func _get_enemy_title(enemy_type: String) -> String:
	match enemy_type:
		"shahed136": return "Шахед-136"
		"fpv": return "FPV-дрон"
		"fp1": return "FP-1"
		"kalibr": return "Ракета Калибр"
		"shahed238": return "Шахед-238"
	return enemy_type

func _on_path_selected(idx: int) -> void:
	match idx:
		0: selected_path_name = "auto"
		1: selected_path_name = "MainPath"
		2: selected_path_name = "FPVPath"
		3: selected_path_name = "FP1Path"
		4: selected_path_name = "KalibrPath"
		5: selected_path_name = "Shahed238Path"
	post_toast("Выбран путь: " + selected_path_name, Color(0.8, 0.8, 1.0))

func _on_set_batch_count(cnt: int) -> void:
	if enemy_count_spin:
		enemy_count_spin.value = cnt

func _on_clear_enemies_pressed() -> void:
	var drones = get_tree().get_nodes_in_group("drones")
	var count = drones.size()
	for d in drones:
		if is_instance_valid(d):
			d.queue_free()
	post_toast("Уничтожено врагов: %d" % count, Color(1.0, 0.4, 0.4))

func _on_spawn_friendly_plane_pressed() -> void:
	var scene = SCENE_FRIENDLY_PLANE
	var level = get_tree().get_first_node_in_group("level")
	var container = level.get_node_or_null("Containers/TowersContainer") if level else null
	var plane = scene.instantiate()
	
	var camera = get_viewport().get_camera_2d()
	var spawn_pos = camera.get_screen_center_position() if camera else Vector2.ZERO
	plane.global_position = spawn_pos
	
	if container:
		container.add_child(plane)
	elif level:
		level.add_child(plane)
	else:
		get_parent().add_child(plane)
	post_toast("✈️ Дружественный самолет заспавнен!", Color(0.4, 0.8, 1.0))

func _on_spawn_shahed_pressed() -> void:
	var scene = SCENE_SHAHED
	var level = get_tree().get_first_node_in_group("level")
	var container = level.get_node_or_null("Containers/TowersContainer") if level else null
	var plane = scene.instantiate()
	
	var camera = get_viewport().get_camera_2d()
	var spawn_pos = camera.get_screen_center_position() if camera else Vector2.ZERO
	plane.global_position = spawn_pos
	
	if container:
		container.add_child(plane)
	elif level:
		level.add_child(plane)
	else:
		get_parent().add_child(plane)
	post_toast("Управляемый шахед создан!", Color(0.729, 0.071, 0.0, 1.0))

func _on_spawn_Kalibr_pressed() -> void:
	var scene = SCENE_KALIBR_CONTROLLED
	var level = get_tree().get_first_node_in_group("level")
	var container = level.get_node_or_null("Containers/TowersContainer") if level else null
	var plane = scene.instantiate()
	
	var camera = get_viewport().get_camera_2d()
	var spawn_pos = camera.get_screen_center_position() if camera else Vector2.ZERO
	plane.global_position = spawn_pos
	
	if container:
		container.add_child(plane)
	elif level:
		level.add_child(plane)
	else:
		get_parent().add_child(plane)
	post_toast("Управляемый шахед создан!", Color(0.729, 0.071, 0.0, 1.0))

func _on_next_wave_pressed() -> void:
	var wm = _get_wave_manager()
	if wm and wm.has_method("_start_next_wave"):
		wm._start_next_wave()
		post_toast("Запущена следующая волна!", Color(1.0, 0.8, 0.2))

func _on_toggle_auto_waves_pressed() -> void:
	var wm = _get_wave_manager()
	if not wm:
		return
	is_auto_wave_active = not is_auto_wave_active
	wm.set_process(is_auto_wave_active)
	if auto_wave_btn:
		auto_wave_btn.text = "Авто-волны: ВКЛ" if is_auto_wave_active else "Авто-волны: ВЫКЛ"
	post_toast("Авто-волны: " + ("ВКЛЮЧЕНЫ" if is_auto_wave_active else "ОСТАНОВЛЕНЫ"), Color(0.9, 0.7, 0.2))

# Экономика / Деньги
func _on_add_money_pressed(amount: int) -> void:
	var hud = _get_hud()
	if hud and hud.has_method("add_money"):
		hud.add_money(amount)
		post_toast("💰 Выдано: +%d$" % amount, Color(0.4, 1.0, 0.4))

func _on_set_custom_money_pressed() -> void:
	if not money_spin:
		return
	var val = int(money_spin.value)
	var hud = _get_hud()
	if hud and "money" in hud:
		hud.money = val
		post_toast("💰 Баланс установлен: %d$" % val, Color(0.4, 1.0, 0.4))

func _on_reset_money_pressed() -> void:
	var hud = _get_hud()
	if hud and "money" in hud:
		hud.money = 0
		post_toast("Баланс сброшен в 0$", Color(1.0, 0.6, 0.4))

func _on_inf_money_toggled(toggled: bool) -> void:
	is_infinite_money = toggled
	if toggled:
		var hud = _get_hud()
		if hud and "money" in hud:
			hud.money = 99999
		post_toast("Бесконечные деньги: ВКЛ (99,999$)", Color(1.0, 0.85, 0.2))
	else:
		post_toast("Бесконечные деньги: ВЫКЛ", Color.WHITE)

# Управление заводом
func _on_hp_slider_value_changed(value: float) -> void:
	_set_factory_hp(value)

func _on_preset_hp_pressed(ratio: float) -> void:
	var factory = _get_factory()
	if not factory:
		return
	var new_hp = factory.max_health * ratio
	if hp_slider:
		hp_slider.value = new_hp
	_set_factory_hp(new_hp)

func _set_factory_hp(new_val: float) -> void:
	var factory = _get_factory()
	if not factory:
		return
	factory.current_health = clamp(new_val, 0.0, factory.max_health)
	if factory.has_signal("health_changed"):
		factory.health_changed.emit(factory.current_health, factory.max_health)
	
	_update_hp_label(factory.current_health, factory.max_health)
	
	if factory.current_health > 0:
		var defeat_menu = get_tree().get_first_node_in_group("defeat_menu")
		if defeat_menu:
			defeat_menu.visible = false
	else:
		if factory.has_method("take_damage"):
			factory.take_damage(1.0)
			
	post_toast("HP завода: %d / %d" % [roundi(factory.current_health), roundi(factory.max_health)], Color(0.4, 0.9, 1.0))

func _update_hp_label(cur: float, mx: float) -> void:
	if hp_value_label:
		hp_value_label.text = "%d / %d HP (%d%%)" % [roundi(cur), roundi(mx), roundi((cur / mx) * 100.0)]

func _on_god_mode_toggled(toggled: bool) -> void:
	is_god_mode = toggled
	if toggled:
		var factory = _get_factory()
		if factory:
			_set_factory_hp(factory.max_health)
		post_toast("🛡️ Режим Бога завода: ВКЛ", Color(0.2, 1.0, 0.5))
	else:
		post_toast("Режим Бога завода: ВЫКЛ", Color.WHITE)

func _on_net_upgrade_toggled(toggled: bool) -> void:
	var factory = _get_factory()
	if factory and "has_anti_drone_nets" in factory:
		factory.has_anti_drone_nets = toggled
		factory.queue_redraw()
		post_toast("Антидроновая сетка: " + ("УСТАНОВЛЕНА" if toggled else "СНЯТА"), Color(0.4, 0.9, 1.0))

func _on_relocate_factory_pressed() -> void:
	var level = get_tree().get_first_node_in_group("level")
	var factory = _get_factory()
	if not factory:
		return
		
	if level and "factory_positions" in level and not level.factory_positions.is_empty():
		var pos: Vector2 = level.factory_positions.pick_random()
		factory.global_position = pos
		var mission_gen = level.get_node_or_null("Managers/MissionGenerator")
		if mission_gen and mission_gen.has_method("generate_mission_paths"):
			mission_gen.generate_mission_paths()
		post_toast("Завод перемещен на: %s" % str(pos), Color(0.5, 0.9, 1.0))
	else:
		post_toast("Не удалось найти factory_positions в уровне", Color.RED)

# Система & Время
func _on_set_time_scale(scale_val: float) -> void:
	Engine.time_scale = scale_val
	post_toast("Скорость времени: %.2fx" % scale_val, Color(0.5, 1.0, 0.8))

func _on_toggle_pause_pressed() -> void:
	var paused = not get_tree().paused
	get_tree().paused = paused
	if pause_btn:
		pause_btn.text = "Возобновить" if paused else "Пауза"
	post_toast("Игра " + ("на паузе" if paused else "возобновлена"), Color(1.0, 0.8, 0.3))

func _on_restart_sandbox_pressed() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://main/main.tscn")

func _on_set_health_pressed() -> void:
	if not health_spin:
		return
	var val = float(health_spin.value)
	_set_factory_hp(val)
