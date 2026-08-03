extends CanvasLayer

signal pvo_selected(pvo_type: String, cost: int)

@export var money: int = 100:
	set(value):
		money = max(0, value)
		_update_money_ui()

@onready var money_value_label: Label = %MoneyValueLabel
@onready var wave_value_label: Label = %WaveValueLabel
@onready var mog_button: Button = $Control/TopPvoBar/PanelContainer/HBoxContainer/MogButton
@onready var osa_button: Button = $Control/TopPvoBar/PanelContainer/HBoxContainer/OsaButton
var plane_button: Button = null

var is_dragging: bool = false
var current_pvo_type: String = ""
var current_pvo_cost: int = 0

func _ready() -> void:
	add_to_group("hud")
	var hbox = $Control/TopPvoBar/PanelContainer/HBoxContainer
	if hbox:
		plane_button = hbox.get_node_or_null("PlaneButton")
		if not plane_button:
			plane_button = Button.new()
			plane_button.name = "PlaneButton"
			plane_button.text = "Plane (150$)"
			plane_button.tooltip_text = "Самолет-перехватчик\nРадиус LOITER: 150px\nЦена: 150$"
			hbox.add_child(plane_button)

	if mog_button:
		mog_button.custom_minimum_size = Vector2(130, 48)
		mog_button.button_down.connect(_start_drag.bind("Стрела-10", 75))
		mog_button.gui_input.connect(_on_button_gui_input)
	if osa_button:
		osa_button.custom_minimum_size = Vector2(130, 48)
		osa_button.button_down.connect(_start_drag.bind("Оса", 175))
		osa_button.gui_input.connect(_on_button_gui_input)
	if plane_button:
		plane_button.custom_minimum_size = Vector2(130, 48)
		plane_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plane_button.button_down.connect(_start_drag.bind("Самолет", 150))
		plane_button.gui_input.connect(_on_button_gui_input)
	_update_money_ui()

func _start_drag(pvo_type: String, cost: int) -> void:
	if money >= cost:
		is_dragging = true
		current_pvo_type = pvo_type
		current_pvo_cost = cost
		
		pvo_selected.emit(pvo_type, cost)
		var mgr = get_tree().get_first_node_in_group("placement_manager")
		if mgr and mgr.has_method("start_placement"):
			mgr.start_placement(pvo_type, cost)

func _on_button_gui_input(event: InputEvent) -> void:
	if not is_dragging:
		return
		
	var is_release = false
	if event is InputEventScreenTouch and not event.pressed:
		is_release = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		is_release = true
		
	if is_release:
		is_dragging = false
		var mgr = get_tree().get_first_node_in_group("placement_manager")
		if mgr and mgr.has_method("confirm_placement"):
			mgr.confirm_placement()
		elif mgr and mgr.has_method("try_place"):
			mgr.try_place()

func _update_money_ui() -> void:
	if money_value_label:
		money_value_label.text = str(money) + "$"
	if mog_button:
		mog_button.disabled = (money < 75)
		mog_button.text = "Strela-10 (75$)"
	if osa_button:
		osa_button.disabled = (money < 175)
	if plane_button:
		plane_button.disabled = (money < 150)
		plane_button.text = "Plane (150$)"

func update_wave(current: int, max_w: int) -> void:
	if wave_value_label:
		wave_value_label.text = str(current) + " / " + str(max_w)

func add_money(amount: int) -> void:
	money += amount

func deduct_money(amount: int) -> bool:
	if money >= amount:
		money -= amount
		return true
	return false

func has_money(amount: int) -> bool:
	return money >= amount
