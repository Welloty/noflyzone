extends Control

@onready var tablet_panel: PanelContainer = $TabletPanel
@onready var header_title: Label = %HeaderTitle
@onready var channel_label: Label = %ChannelLabel
@onready var wave_title_label: Label = %WaveTitle
@onready var money_title_label: Label = %MoneyTitle
@onready var status_title_label: Label = %StatusTitle
@onready var status_value_label: Label = %StatusValueLabel
@onready var targets_title_label: Label = %TargetsTitle
@onready var targets_value_label: Label = %TargetsValueLabel
@onready var timer_title_label: Label = %TimerTitle
@onready var timer_value_label: Label = %TimerValueLabel
@onready var messages_vbox: VBoxContainer = %MessagesVBox
@onready var toggle_button: Button = %ToggleButton

var wave_manager: Node = null
var is_collapsed: bool = false

func _ready() -> void:
	if toggle_button:
		toggle_button.pressed.connect(_on_toggle_pressed)
	_update_static_texts()
	
	call_deferred("_connect_wave_manager")

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_update_static_texts()

func _connect_wave_manager() -> void:
	wave_manager = get_tree().get_first_node_in_group("wave_manager")
	if wave_manager:
		if wave_manager.has_signal("wave_started"):
			wave_manager.wave_started.connect(_on_wave_started)
		if wave_manager.has_signal("wave_completed"):
			wave_manager.wave_completed.connect(_on_wave_completed)
		if wave_manager.has_signal("break_timer_updated"):
			wave_manager.break_timer_updated.connect(_on_break_timer_updated)
		
		if wave_manager.is_wave_active:
			_on_wave_started(wave_manager.current_wave, wave_manager.drones_to_spawn_this_wave)
		else:
			if wave_manager.current_wave == 0:
				_on_break_timer_updated(wave_manager.break_timer)

func _process(_delta: float) -> void:
	if is_instance_valid(wave_manager) and wave_manager.is_wave_active:
		var active_count = wave_manager.get_active_drones_count()
		var total_count = wave_manager.drones_to_spawn_this_wave
		if targets_value_label:
			targets_value_label.text = "%d / %d" % [active_count, total_count]

func _update_static_texts() -> void:
	if header_title:
		header_title.text = tr("TABLET_HEADER")
	if channel_label:
		channel_label.text = "● " + tr("TABLET_CHANNEL")
	if wave_title_label:
		wave_title_label.text = tr("WAVE") + ":"
	if money_title_label:
		money_title_label.text = tr("MONEY") + ":"
	if status_title_label:
		status_title_label.text = tr("TABLET_STATUS_TITLE")
	if targets_title_label:
		targets_title_label.text = tr("TABLET_TARGETS_TITLE")
	if timer_title_label:
		timer_title_label.text = tr("TABLET_TIMER_TITLE")
	if toggle_button:
		toggle_button.text = "◀ " + tr("TABLET_TOGGLE_OPEN") if is_collapsed else "▶ " + tr("TABLET_TOGGLE_CLOSE")

func _on_wave_started(wave_num: int, total_drones: int) -> void:
	if status_value_label:
		status_value_label.text = tr("TABLET_STATUS_ACTIVE")
		status_value_label.modulate = Color(1.0, 0.45, 0.35, 1.0)
	if timer_value_label:
		timer_value_label.text = "--"
	if targets_value_label:
		targets_value_label.text = "%d / %d" % [total_drones, total_drones]
	
	# сообщение от генштаба
	var dispatch_key = "TABLET_DISPATCH_%d" % wave_num
	var dispatch_text = tr(dispatch_key)
	if dispatch_text == dispatch_key:
		dispatch_text = tr("TABLET_DISPATCH_GENERIC")
		
	_add_message_card(tr("TABLET_GENSTAFF"), dispatch_text, Color(0.7, 0.4, 0.95, 1.0))

func _on_wave_completed(wave_num: int, reward: int) -> void:
	if status_value_label:
		status_value_label.text = tr("TABLET_STATUS_BREAK")
		status_value_label.modulate = Color(0.4, 0.95, 0.35, 1.0)
	if targets_value_label:
		targets_value_label.text = "0"
		
	var msg = tr("TABLET_WAVE_CLEARED_MSG") % [wave_num, reward]
	_add_message_card(tr("TABLET_SYSTEM"), msg, Color(0.35, 0.75, 1.0, 1.0))

func _on_break_timer_updated(time_remaining: float) -> void:
	if is_instance_valid(wave_manager) and not wave_manager.is_wave_active:
		if status_value_label:
			status_value_label.text = tr("TABLET_STATUS_BREAK")
			status_value_label.modulate = Color(0.4, 0.95, 0.35, 1.0)
		if timer_value_label:
			timer_value_label.text = "%.1f s" % time_remaining

func _add_message_card(sender: String, text: String, color: Color) -> void:
	if not messages_vbox:
		return
		
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.16, 0.11, 0.85)
	style.border_color = Color(0.2, 0.4, 0.22, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	
	var sender_label = Label.new()
	sender_label.text = sender
	sender_label.add_theme_color_override("font_color", color)
	sender_label.add_theme_font_size_override("font_size", 12)
	
	var text_label = Label.new()
	text_label.text = text
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.87, 1.0))
	text_label.add_theme_font_size_override("font_size", 11)
	
	vbox.add_child(sender_label)
	vbox.add_child(text_label)
	card.add_child(vbox)
	
	messages_vbox.add_child(card)
	
	call_deferred("_scroll_to_bottom")

func _scroll_to_bottom() -> void:
	var scroll_container = messages_vbox.get_parent() as ScrollContainer
	if scroll_container:
		scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)

func _on_toggle_pressed() -> void:
	is_collapsed = not is_collapsed
	if tablet_panel:
		tablet_panel.visible = not is_collapsed
	if toggle_button:
		toggle_button.text = "◀ " + tr("TABLET_TOGGLE_OPEN") if is_collapsed else "▶ " + tr("TABLET_TOGGLE_CLOSE")
