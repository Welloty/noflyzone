extends CanvasLayer

signal pvo_selected(pvo_type: String, cost: int)

@export var money: int = 200:
	set(value):
		money = max(0, value)
		_update_money_ui()

@onready var money_value_label: Label = $Control/MarginContainer/HBoxContainer/MoneyPanel/HBoxContainer/VBoxContainer/MoneyValueLabel
@onready var wave_value_label: Label = $Control/MarginContainer/HBoxContainer/WavePanel/HBoxContainer/VBoxContainer/WaveValueLabel
@onready var mog_button: Button = $Control/TopPvoBar/PanelContainer/HBoxContainer/MogButton
@onready var osa_button: Button = $Control/TopPvoBar/PanelContainer/HBoxContainer/OsaButton

func _ready() -> void:
	add_to_group("hud")
	if mog_button:
		mog_button.pressed.connect(_on_mog_pressed)
	if osa_button:
		osa_button.pressed.connect(_on_osa_pressed)
	_update_money_ui()

func _update_money_ui() -> void:
	if money_value_label:
		money_value_label.text = str(money) + "$"
	if mog_button:
		mog_button.disabled = (money < 50)
		mog_button.text = "Strela-10 (50$)"
	if osa_button:
		osa_button.disabled = (money < 100)
		
func _on_osa_pressed() -> void:
	var osa_cost = 100
	if money >= osa_cost:
		pvo_selected.emit("Оса", osa_cost)
		var mgr = get_tree().get_first_node_in_group("placement_manager")
		if mgr and mgr.has_method("start_placement"):
			mgr.start_placement("Оса", osa_cost)

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

func _on_mog_pressed() -> void:
	if money >= 50:
		pvo_selected.emit("Стрела-10", 50)
		var mgr = get_tree().get_first_node_in_group("placement_manager")
		if mgr and mgr.has_method("start_placement"):
			mgr.start_placement("Стрела-10", 50)
