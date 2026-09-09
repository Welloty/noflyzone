extends Control


func _on_strela_10_info_pressed() -> void:
	get_tree().change_scene_to_file("res://helps/strela_10_info.tscn")


func _on_osasa_8_info_pressed() -> void:
	get_tree().change_scene_to_file("res://helps/OSAinfo.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://helps/help_scene.tscn")
