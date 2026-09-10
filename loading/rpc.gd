extends Node

func _ready() -> void:
	if OS.get_name() == "Android" or not ClassDB.class_exists("DiscordRPC"):
		set_process(false)
		return

	# На ПК безпечно встановлюємо всі значення
	DiscordRPC.set("app_id", 1530222816421609472)
	DiscordRPC.set("details", "air!")
	DiscordRPC.set("state", "https://github.com/Welloty/noflyzone")
	DiscordRPC.set("large_image", "ico")
	DiscordRPC.set("large_image_text", "game")
	DiscordRPC.set("small_image", "")
	DiscordRPC.set("small_image_text", "")
	DiscordRPC.set("start_timestamp", int(Time.get_unix_time_from_system()))

	DiscordRPC.call("refresh")
