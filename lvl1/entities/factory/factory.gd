extends Sprite2D

signal factory_destroyed

@export var max_health: float = 100
@onready var current_health: float = max_health


func _ready() -> void:
	add_to_group("factory")


func take_damage(amount: float) -> void:
	if current_health <= 0:
		return
	
	current_health -= amount
	
	if current_health <= 0:
		current_health = 0
		factory_destroyed.emit()

		var defeat_menu = get_tree().get_first_node_in_group("defeat_menu")
		
		if not defeat_menu:
			defeat_menu = get_tree().root.find_child("Defeatmenu", true, false)
			
		if defeat_menu and defeat_menu.has_method("open"):
			defeat_menu.open()
