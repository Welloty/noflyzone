extends Node

func _ready() -> void:
	if OS.get_name() == "Android" or not ClassDB.class_exists("DiscordRPC"):
		set_process(false)
		return

func _process(_delta: float) -> void:
	if ClassDB.class_exists("DiscordRPC"):
		DiscordRPC.call("run_callbacks")
